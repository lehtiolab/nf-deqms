# lehtiolab/nf-deqms : Output

This document describes the output produced by the pipeline. 

## Output files
The output is a number of text, SQLite and HTML files. Depending somewhat on inputs, the following can be obtained from the output directory:

* a peptide table (TSV)
* protein and genes tables (TSV)
* a QC report (HTML)


## File columns
For all output tables, the columns are identical as input tables, and the following fields get added or substituted:

* logFC, count, sca.P.Value, sca.adj.pval, all output from (https://github.com/yafeng/DEqMS/)[DEqMS] analysis


## DEqMS
[DEqMS](https://github.com/yafeng/deqms) is an R package for testing differential protein expression in quantitative proteomic analysis, built on top of the Limma package. [PMID 32205417](https://pubmed.ncbi.nlm.nih.gov/32205417/)
