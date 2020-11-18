# lehtiolab/nf-deqms
**A small pipeline to re-run DEqMS on existing results**

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A520.01.0-brightgreen.svg)](https://www.nextflow.io/)

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg)](http://bioconda.github.io/)
[![Docker](https://img.shields.io/docker/automated/lehtiolab/nf-deqms.svg)](https://hub.docker.com/r/lehtiolab/nf-deqms)
![Singularity Container available](
https://img.shields.io/badge/singularity-available-7E4C74.svg)

### Introduction
This workflow reruns DEqMS analysis on existing results, e.g. from the [lehtiolab/ddamsproteomics](https://github.com/lehtiolab/ddamsproteomics) pipeline. It exists so one can use orthogonal sample groups (CTRL vs TREAT, old vs young) and rerun, or perhaps correct a mistake in the sample annotation, without having to re-search an entire set of spectra against a protein sequence database.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker / singularity containers making installation trivial and results highly reproducible.


## How to run

- install [Nextflow](https://nextflow.io)
- install [Docker](https://docs.docker.com/engine/installation/), [Singularity](https://www.sylabs.io/guides/3.0/user-guide/), or [Conda](https://conda.io/miniconda.html)
- run pipeline:

```
nextflow run lehtiolab/nf-deqms --proteins proteins.txt --peptides peptides.txt --genes genes.txt --ensg ensg.txt --sampletable samples.txt -profile standard,docker
```

You can leave out any accession that you do not have or are not interested in (e.g. `--ensg` in a Swissprot analysis).

The lehtiolab/nf-deqms pipeline comes with documentation about the pipeline, found in the `docs/` directory:

- [Running the pipeline](docs/usage.md)
- [Output and how to interpret the results](docs/output.md)
- [Troubleshooting](https://nf-co.re/usage/troubleshooting)

There is more extensive documentation on the options inside the main.nf file.


## Credits
lehtiolab/nf-deqms was originally written by Jorrit Boekel and tries to follow the [nf-core](https://nf-co.re) best practices and templates.
