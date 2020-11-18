#!/usr/bin/env nextflow
/*
========================================================================================
                         lehtiolab/nf-deqms
========================================================================================
 lehtiolab/nf-deqms Analysis Pipeline.
 #### Homepage / Documentation
 https://github.com/lehtiolab/nf-deqms
----------------------------------------------------------------------------------------
*/


def helpMessage() {
    log.info"""
    =========================================
     lehtiolab/nf-deqms v${workflow.manifest.version}
    =========================================
    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run lehtiolab/nf-deqms --proteins proteins.txt --peptides peptides.txt --ensg ensg.txt --genes genes.txt --sampletable samples.txt -profile standard,docker

    Mandatory arguments:
      --sampletable                 Path to sample annotation table in case of isobaric analysis
      -profile                      Configuration profile to use. Can use multiple (comma separated)
                                    Available: standard, conda, docker, singularity, awsbatch, test

    Other options:
      --peptides                    Path to peptide table with set-annotated quantitative results
      --proteins                    Path to protein table with set-annotated quantitative results
      --genes                       Path to gene table with set-annotated quantitative results
      --ensg                        Path to ENSG table with set-annotated quantitative results
      --outdir                      The output directory where the results will be saved
      --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.

    AWSBatch options:
      --awsqueue                    The AWSBatch JobQueue that needs to be set when running on AWSBatch
      --awsregion                   The AWS Region for your AWS Batch job to run on
    """.stripIndent()
}

/*
 * SET UP CONFIGURATION VARIABLES
 */

// Show help message
if (params.help){
    helpMessage()
    exit 0
}

// Configurable variables
params.outdir = 'results'
params.name = false
params.email = false
params.plaintext_email = false
params.peptides = false
params.proteins = false
params.genes = false
params.ensg = false
params.sampletable = false

output_docs = file("$baseDir/docs/output.md")

// set constant variables
accolmap = [peptides: 13, proteins: 15, ensg: 18, genes: 19]

availProcessors = Runtime.runtime.availableProcessors()

// AWSBatch sanity checking
if(workflow.profile == 'awsbatch'){
    if (!params.awsqueue || !params.awsregion) exit 1, "Specify correct --awsqueue and --awsregion parameters on AWSBatch!"
    if (!workflow.workDir.startsWith('s3') || !params.outdir.startsWith('s3')) exit 1, "Specify S3 URLs for workDir and outdir parameters on AWSBatch!"
}


// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}

// Check workDir/outdir paths to be S3 buckets if running on AWSBatch
// related: https://github.com/nextflow-io/nextflow/issues/813
if( workflow.profile == 'awsbatch') {
    if(!workflow.workDir.startsWith('s3:') || !params.outdir.startsWith('s3:')) exit 1, "Workdir or Outdir not on S3 - specify S3 Buckets for each to run on AWSBatch!"
}


// Header log info
log.info """=======================================================
                                          ,--./,-.
          ___     __   __   __   ___     /,-._.--~\'
    |\\ | |__  __ /  ` /  \\ |__) |__         }  {
    | \\| |       \\__, \\__/ |  \\ |___     \\`-._,-`-,
                                          `._,._,\'

lehtiolab/nf-deqms v${workflow.manifest.version}"
======================================================="""
def summary = [:]
summary['Pipeline Name']  = 'lehtiolab/nf-deqms'
summary['Pipeline Version'] = workflow.manifest.version
summary['Run Name']     = custom_runName ?: workflow.runName
summary['Sample annotations'] = params.sampletable
summary['Input peptides'] = params.peptides
summary['Input proteins'] = params.proteins
summary['Input genes'] = params.genes
summary['Input ensg'] = params.ensg
summary['Max Memory']   = params.max_memory
summary['Max CPUs']     = params.max_cpus
summary['Max Time']     = params.max_time
summary['Output dir']   = params.outdir
summary['Working dir']  = workflow.workDir
summary['Container Engine'] = workflow.containerEngine
if(workflow.containerEngine) summary['Container'] = workflow.container
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Output dir']     = params.outdir
summary['Script dir']     = workflow.projectDir
summary['Config Profile'] = workflow.profile
if(workflow.profile == 'awsbatch'){
   summary['AWS Region'] = params.awsregion
   summary['AWS Queue'] = params.awsqueue
}
if(params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="


def create_workflow_summary(summary) {

    def yaml_file = workDir.resolve('workflow_summary_mqc.yaml')
    yaml_file.text  = """
    id: 'lehtiolab-nf-deqms-summary'
    description: " - this information is collected when the pipeline is started."
    section_name: 'lehtiolab/nf-deqms Workflow Summary'
    section_href: 'https://github.com/lehtiolab/nf-deqms'
    plot_type: 'html'
    data: |
        <dl class=\"dl-horizontal\">
${summary.collect { k,v -> "            <dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }.join("\n")}
        </dl>
    """.stripIndent()

   return yaml_file
}


/*
 * Parse software version numbers
 */
process get_software_versions {

    publishDir "${params.outdir}", mode: 'copy'

    output:
    file 'software_versions.yaml' into software_versions_qc

    script:
    """
    echo $workflow.manifest.version > v_pipeline.txt
    echo $workflow.nextflow.version > v_nextflow.txt
    Rscript <(echo "packageVersion('DEqMS')") > v_deqms.txt
    scrape_software_versions.py > software_versions.yaml
    """
}


tables = [["peptides", params.peptides], ["proteins", params.proteins], ["genes", params.genes], ["ensg", params.ensg]]
Channel.from(tables.findAll { it[1] })
.map { it -> [it[0], file(it[1])] }
.view()
  .combine(Channel.fromPath(params.sampletable))
  .set { deqms_input }

process DEqMS {

  input:
  set val(acctype), path('mergedtable'), path('sampletable') from deqms_input
 
  output:
  set val(acctype), file('proteintable'), path('sampletable') into ready_feats
  
  """
  # Remove any existing DEqMS fields and clean header
  nodqfields=\$(head mergedtable -n1| tr '\\t' '\\n' | grep -nvE '_logFC\$|_count\$|_sca.P.Value\$|_sca.adj.pval\$' | cut -f1 -d':' | tr '\n' ',' | sed 's/\\,\$//')
  head -n1 mergedtable | cut -f"\$nodqfields" | sed 's/\\#/Amount/g' > header
  # R does not like strange characters, clean up sampletable also
  sed "s/[^A-Za-z0-9_\\t]/_/g" sampletable > clean_sampletable
  # Re-label the header fields with sample groups
  while read line ; do read -a arr <<< \$line ; sed -i "s/\\t[^\\t]\\+_\\(\${arr[1]}_[a-z0-9]*plex_\${arr[0]}\\)/\\t\${arr[3]}_\${arr[2]}_\\1/" header ; done < clean_sampletable
  # Create input for DEqMS and run it
  cat header <(tail -n+2 mergedtable | cut -f"\$nodqfields") > feats
  numfields=\$(head -n1 feats | tr '\t' '\n' | wc -l)
  deqms.R
  paste <(head -n1 feats) <(head -n1 deqms_output | cut -f \$(( numfields+1 ))-\$(head -n1 deqms_output|wc -w)) > tmpheader
  cat tmpheader <(tail -n+2 deqms_output) > proteintable
  """
}


process featQC {
  publishDir "${params.outdir}", mode: 'copy', overwrite: true, saveAs: {it == "feats" ? "${acctype}_table.txt": null}

  input:
  set val(acctype), file('feats'), file(sampletable) from ready_feats

  output:
  file('feats') into featsout
  set val(acctype), file("${acctype}.html") into qccollect

  script:
  """
  # Create QC plots and put them base64 into HTML
  qc.R --feattype ${acctype} --sampletable $sampletable 
  echo '<html><body><div class="chunk" id="deqms">' >> ${acctype}.html
  for graph in deqms_volcano_*;
    do
    paste -d \\\\0  <(echo '<div><img src="data:image/png;base64,') <(base64 -w 0 \$graph) <(echo '"></div>') >> ${acctype}.html
    done
  ls deqms_volcano_* && echo '</div>' >> ${acctype}.html
  [ -e pca ] && echo '<div class="chunk" id="pca">' >> ${acctype}.html && for graph in pca scree;
    do 
    echo "<div> \$(sed "s/id=\\"/id=\\"${acctype}-\${graph}/g;s/\\#/\\#${acctype}-\${graph}/g" <\$graph) </div>" >> ${acctype}.html
    done
    [ -e pca ] && echo '</div>' >> ${acctype}.html
  echo "</body></html>" >> ${acctype}.html
  """
}

qccollect
  .toList()
  .map { it -> [it.collect() { it[0] }, it.collect() { it[1] } ] }
  .set { collected_feats_qc }


process collectQC {

  publishDir "${params.outdir}", mode: 'copy', overwrite: true

  input:
  set val(acctypes), file(featqc) from collected_feats_qc
  file('sw_ver') from software_versions_qc

  output:
  set file('qc.html')

  script:
  """
  # remove Yaml from software_versions to get HTML
  grep -A \$(wc -l sw_ver | cut -f 1 -d ' ') "data\\:" sw_ver | tail -n+2 > sw_ver_cut
  # collect and generate HTML report
  qc_collect.py $baseDir/assets/qc_full.html $params.name
  """
}


/* 
 * STEP 3 - Output Description HTML
*/
process output_documentation {
    tag "$prefix"

    publishDir "${params.outdir}/Documentation", mode: 'copy'

    input:
    file output_docs

    output:
    file "results_description.html"

    script:
    """
    markdown_to_html.r $output_docs results_description.html
    """
}



/*
 * Completion e-mail notification
 */
workflow.onComplete {

    // Set up the e-mail variables
    def subject = "[lehtiolab/nf-deqms] Successful: $workflow.runName"
    if(!workflow.success){
      subject = "[lehtiolab/nf-deqms] FAILED: $workflow.runName"
    }
    def email_fields = [:]
    email_fields['version'] = workflow.manifest.version
    email_fields['runName'] = custom_runName ?: workflow.runName
    email_fields['success'] = workflow.success
    email_fields['dateComplete'] = workflow.complete
    email_fields['duration'] = workflow.duration
    email_fields['exitStatus'] = workflow.exitStatus
    email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    email_fields['errorReport'] = (workflow.errorReport ?: 'None')
    email_fields['commandLine'] = workflow.commandLine
    email_fields['projectDir'] = workflow.projectDir
    email_fields['summary'] = summary
    email_fields['summary']['Date Started'] = workflow.start
    email_fields['summary']['Date Completed'] = workflow.complete
    email_fields['summary']['Pipeline script file path'] = workflow.scriptFile
    email_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
    if(workflow.repository) email_fields['summary']['Pipeline repository Git URL'] = workflow.repository
    if(workflow.commitId) email_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
    if(workflow.revision) email_fields['summary']['Pipeline Git branch/tag'] = workflow.revision
    email_fields['summary']['Nextflow Version'] = workflow.nextflow.version
    email_fields['summary']['Nextflow Build'] = workflow.nextflow.build
    email_fields['summary']['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp

    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$baseDir/assets/email_template.txt")
    def txt_template = engine.createTemplate(tf).make(email_fields)
    def email_txt = txt_template.toString()

    // Render the HTML template
    def hf = new File("$baseDir/assets/email_template.html")
    def html_template = engine.createTemplate(hf).make(email_fields)
    def email_html = html_template.toString()

    // Render the sendmail template
    def smail_fields = [ email: params.email, subject: subject, email_txt: email_txt, email_html: email_html, baseDir: "$baseDir" ]
    def sf = new File("$baseDir/assets/sendmail_template.txt")
    def sendmail_template = engine.createTemplate(sf).make(smail_fields)
    def sendmail_html = sendmail_template.toString()

    // Send the HTML e-mail
    if (params.email) {
        try {
          if( params.plaintext_email ){ throw GroovyException('Send plaintext e-mail, not HTML') }
          // Try to send HTML e-mail using sendmail
          [ 'sendmail', '-t' ].execute() << sendmail_html
          log.info "[lehtiolab/nf-deqms] Sent summary e-mail to $params.email (sendmail)"
        } catch (all) {
          // Catch failures and try with plaintext
          [ 'mail', '-s', subject, params.email ].execute() << email_txt
          log.info "[lehtiolab/nf-deqms] Sent summary e-mail to $params.email (mail)"
        }
    }

    // Write summary e-mail HTML to a file
    def output_d = new File( "${params.outdir}/Documentation/" )
    if( !output_d.exists() ) {
      output_d.mkdirs()
    }
    def output_hf = new File( output_d, "pipeline_report.html" )
    output_hf.withWriter { w -> w << email_html }
    def output_tf = new File( output_d, "pipeline_report.txt" )
    output_tf.withWriter { w -> w << email_txt }

    log.info "[lehtiolab/nf-deqms] Pipeline Complete"

}
