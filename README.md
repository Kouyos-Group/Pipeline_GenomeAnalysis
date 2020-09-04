# Genome Analysis pipeline

by Judith Bergadà Pijuan

This pipeline is aimed to perform the assembly and annotation of paired-end
sequencing reads, as well as to compare the genome content of the given
DNA sequences. In addition, it performs a variant calling analysis in order to
detect the SNPs across sequences.
Given multiple paired-end sequencing reads (FASTQ files),
it provides a table file showing the genome content comparison, and (multiple)
tables showing the SNPs detected across strains.
Outputs have the same format as given by software Roary and Snippy.
The pipeline also provides the de novo assembly of the sequencing reads
and their annotation.

## Installation

To use this pipeline, you need to install the following dependencies:
- SPAdes
- Prokka
- Roary
- Snippy

Later, you need to download the tool:
```bash
cd $HOME
git clone https://github.com/judithbergada/Pipeline_GenomeAnalysis
```

## Usage

The pipeline expects you to have the following folder:
- FASTQ folder: this is a folder containing only your sequencing reads (FASTQ files).
You must have all your FASTQ files here, and it is important that the pairs of files have the
same prefix in the name.

To get information about the usage, please try:

```bash
./genomeanalysis.sh -h
```

The MLST tool can be used with these parameters:

```
Usage: genomeanalysis.sh    [-h or --help]
                            [-f or --fastqfolder]
                            [-o or --outname]
                            [-t or --threads]

Optional arguments:
    -h, --help:
                Show this help message and exit.
    -o, --outname:
                Name of your analysis.
                It will be used to name the output files.
                Default: mygenomes.
    -t, --threads:
                Number of threads that will be used.
                It must be an integer.
                Default: 8.
Required arguments:
    -f, --fastqfolder:
                Path to the folder that contains ALL your FASTQ files.
                Only FASTQ files should be placed in it.
                You need forward and reverse paired-end reads.
```

Enjoy using the tool!
