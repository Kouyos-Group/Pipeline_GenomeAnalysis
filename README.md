# Genome Analysis pipeline

by Judith Bergadà Pijuan

This pipeline is aimed to perform the assembly and annotation of paired-end
sequencing reads, as well as to compare the genome content of the given
DNA sequences. In addition, it performs a variant calling analysis in order to
detect the SNPs across sequences, and it also determines the spa type.
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
- SpaTyper

Later, you need to download the tool:
```bash
cd $HOME
git clone https://github.com/judithbergada/Pipeline_GenomeAnalysis
```

## Usage

The pipeline expects you to have the following folder:
- FASTQ folder: this is a folder containing only your sequencing reads
(FASTQ files). You must have all your FASTQ files here, and it is important
that the pairs of files have the same prefix in the name.

To get information about the usage, please try:

```bash
./genomeanalysis.sh -h
```

The Genome Analysis tool can be used with these parameters:

```
Usage: genomeanalysis.sh    [-h or --help]
                            [-f or --fastqfolder]
                            [-o or --outname]
                            [-t or --threads]
                            [-r or --referencefolder]

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
    -r, --referencefolder:
                Path to the folder that contains an external REFERENCE genome.
                The following files are needed: FASTA, GFF, GenBank.
Required arguments:
    -f, --fastqfolder:
                Path to the folder that contains ALL your FASTQ files.
                Only FASTQ files should be placed in it.
                You need forward and reverse paired-end reads.
```

Enjoy using the tool!


# Genes Analysis option

This new command is part of the pipeline and is aimed to determine whether the
mutations identified by the tool are synonymous or non-synonymous mutations.
In addition, users can choose one or more genes of interest and the pipeline
provides the whole amino acid sequences of these genes. It can be useful,
for example, to compare the amino acid sequences using external tools such as
Clustal-Omega.

## Installation

To use this command, you don't need to install any dependencies.

However, please make sure you downloaded the last version of the tool:
```bash
cd $HOME
git clone https://github.com/judithbergada/Pipeline_GenomeAnalysis
```

## Usage

The new command expects you to have the following folder:
- Outputs folder: this is a folder containing the outputs from the
genomeanalysis.sh pipeline. You must have all your output files here,
and it is important not to delete or modify anything until all the analyses
have been completed.

Furthermore, you need to provide the names of your genes of interest:
- Specific genes: you can add one or more gene names, all of them within
quotes and separated with a space. It is important that the gene names match
the gene names from your annotation files. For this reason, it is recommended
to get the information of the gene names from your
"gene_presence_absence.csv" file (3rd column of the file, the column is named
  annotation). This file is located in the GenomeContent folder.

To get information about the usage, please try:
```bash
./genesanalysis.sh -h
```

The new command (Genes Analysis) can be used with these parameters:

```
Usage: genesanalysis.sh   [-h or --help]
                          [-s or --specific_genes]
                          [-o or --outputs_folder]
                          [-t or --threads]

Optional arguments:
    -h, --help:
                Show this help message and exit.
    -t, --threads:
                Number of threads that will be used.
                It must be an integer.
                Default: 8.
Required arguments:
    -s, --specific_genes:
                Names of the genes that you want to compare.
                Write all of them within quotes and separated with a space.
                E.g.: 'murF' 'fabZ' 'rplL'.
    -o, --outputs_folder:
                Path to the folder that contains ALL your outputs from
                the genomeanalysis.sh pipeline.
```

Enjoy using the new command!
