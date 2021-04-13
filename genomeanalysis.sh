#!/bin/bash

set -e

###################
## Assign inputs ##
###################

# Define usage of the script
function print_usage {
  printf """
Usage: genomeanalysis.sh    [-h or --help]
                            [-f or --fastqfolder]
                            [-o or --outname]
                            [-t or --threads]
                            [-r or --referencefolder]
"""
}
# Describe usage of the tool and provide help
function print_help {
  print_usage
  printf """
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
"""
}

# Define inputs
for ARGS in "$@"; do
  shift
        case "$ARGS" in
                "--fastqfolder") set -- "$@" "-f" ;;
                "--referencefolder") set -- "$@" "-r" ;;
                "--outname") set -- "$@" "-o" ;;
                "--threads") set -- "$@" "-t" ;;
                "--help") set -- "$@" "-h" ;;
                *) set - "$@" "$ARGS"
        esac
done

# Define defaults
outn="mygenomes"; threads=8; referencefolder=""

# Define all parameters
while getopts 'f:r::o::t::h' flag; do
        case "${flag}" in
                f) fastqfolder=${OPTARG} ;;
                r) referencefolder=${OPTARG} ;;
                o) outn=${OPTARG} ;;
                t) threads=${OPTARG} ;;
                h) print_help
                   exit 1;;
                *) print_usage
                    exit 1;;
        esac
done


##############################
## Identify Software Errors ##
##############################

printf "\nChecking if required software is installed...\n"
# Check installation of the required software.
# If something is missing, show how to install it.
if ! [ -x "$(command -v spades.py)" ]; then
  echo "Missing: SPAdes not found"
  echo "Information on the installation:"
  echo "https://github.com/ablab/spades"
  exit 127
fi
if ! [ -x "$(command -v prokka)" ]; then
  echo "Missing: Prokka not found"
  echo "Information on the installation:"
  echo "https://github.com/tseemann/prokka"
  exit 127
fi
if ! [ -x "$(command -v roary)" ]; then
  echo "Missing: Roary not found"
  echo "Information on the installation:"
  echo "https://github.com/sanger-pathogens/Roary"
  exit 127
fi
if ! [ -x "$(command -v snippy)" ]; then
  echo "Missing: Snippy not found"
  echo "Information on the installation:"
  echo "https://github.com/tseemann/snippy"
  exit 127
fi
echo "Required software is properly installed."


########################################
## Identify Errors in Inputs Required ##
########################################

printf "\nChecking if required inputs are correct...\n"
# Check if directory containing FASTQ files exists
if [ ! -d ${fastqfolder} ]; then
  echo "Error: --fastqfolder doesn't exist."
  echo "Solution: check if the path to this directory is correct."
  exit 1
fi

# Check if only FASTQ files are provided in the fastqfolder
for seqfile in ${fastqfolder}/*; do
  # Get the extension of the file, if file is compressed
  if file --mime-type "${seqfile}" | grep -q gzip; then
    filename=${seqfile%.*}
    extension=${filename##*.}
  else # Get the extension of the file, if file is NOT compressed
    extension=${seqfile##*.}
  fi
  # Check if extension is fastq or fq
  extension=$(tr "[:upper:]" "[:lower:]" <<< ${extension})
  if [[ ${extension} != "fq" && ${extension} != "fastq" ]]; then
    echo "Error: --fastqfolder should only contain FASTQ files."
    echo "Solution: remove any other file from this directory."
    exit 1
  fi
done
# Count number of files that are found in the folder
end=$(ls -1q ${fastqfolder} | wc -l)
# If there are less than 4 FASTQ (less than 2 strains), show the error
if [ ${end} -lt 4 ]; then
  if [ "${referencefolder}" == "" ]; then
    echo "Error: --fastqfolder should contain at least 4 FASTQ files."
    echo "Reason: comparisons only possible if you have >2 strains."
    echo "Solution: add FASTQ files to the folder OR add a REFERENCE folder."
    exit 1
  else # If reference strain is provided, then only 1 extra strain is needed
    if [ ${end} -lt 2 ]; then
      echo "Error: --fastqfolder should contain at least 2 FASTQ files."
      echo "Reason: comparisons only possible if you have >2 strains."
      echo "Solution: add FASTQ files to the folder to compare with your ref."
      exit 1
    fi
  fi
fi
echo "Required inputs seem correct."


########################################
## Identify Errors in Optional Inputs ##
########################################

printf "\nChecking if optional inputs are correct...\n"
# Check if directory containing the REFERENCE files exists
if [ "${referencefolder}" != "" ]; then
  if [ ! -d ${referencefolder} ]; then
    echo "Error: --referencefolder doesn't exist."
    echo "Solution: check if the path to this directory is correct."
    exit 1
  fi
  # Make sure that reference folder contains the proper files
  for reffile in ${referencefolder}/*; do
    # Get the extension of the file
    extension=${reffile##*.}
    # Check if extension is fasta, gff or
    extension=$(tr "[:upper:]" "[:lower:]" <<< ${extension})
    if [[ ${extension} != "fasta" && ${extension} != "fa" && \
          ${extension} != "gff" && ${extension} != "gff3" && \
          ${extension} != "gbk" && ${extension} != "gb" ]]; then
      echo "Error: --referencefolder should contain FASTA, GFF and GBK files."
      echo "Solution: remove any other file from this directory."
      exit 1
    fi
  done
fi

# Check if the number of threads is an integer
if ! [[ ${threads} =~ ^[0-9]+$ ]]; then
  echo "Error: --threads is not an integer."
  echo "Solution: remove this optional parameter or use an integer."
  exit 1
fi
echo "Optional inputs seem correct."


############################
## Perfrom Reads Assembly ##
############################

printf "\nPerforming genome assemblies...\n"
for i in $(seq 2  2 ${end}); do
  # Get the 1st file of a pair
  filefirst=$(ls -1q ${fastqfolder} | head -n$i | tail -n2 | head -n1)
  # Get the 2nd file of a pair
  filesecond=$(ls -1q ${fastqfolder} | head -n$i | tail -n1)
  # Perform assembly with spades
  spades.py -1 ${fastqfolder}/${filefirst} \
    -2 ${fastqfolder}/${filesecond} \
    --careful --threads ${threads} --cov-cutoff auto -o ${outn}_${i}/assembly
  # Concatenate contigs into one long sequence that could be used as reference
  echo ">Assembly" > ${outn}_${i}/assembly/ref_assembly.fasta
  sed '/^>/d' ${outn}_${i}/assembly/contigs.fasta >> \
    ${outn}_${i}/assembly/ref_assembly.fasta
done
echo "Genome assemblies finished sucessfully."


###############################
## Compute Prokka annotation ##
###############################

printf "\nPerforming gene annotations...\n"
for i in $(seq 2  2 ${end}); do
  # Compute annotation
  prokka --outdir ${outn}_${i}/annotation --prefix prokka --cpus ${threads} \
    ${outn}_${i}/assembly/contigs.fasta
done
echo "Gene annotations finished sucessfully."


#####################################
## Copy results to temporal folder ##
#####################################

# Remove temporal directory if existing and create new one with all permissions
rm -rf tmp_genome && \
  mkdir tmp_genome && \
  chmod +xwr tmp_genome

for i in $(seq 2  2 ${end}); do
  # Get name of the file
  filefirst=$(ls -1q ${fastqfolder} | head -n$i | tail -n1)
  # Check if file is compressed and get file name without the extension
  if file --mime-type ${fastqfolder}/${filefirst} | grep -q gzip; then
    nameext=${filefirst%.*}
    fname=${nameext%.*}
  else
    fname=${filefirst%.*}
  fi
  # Copy the annotation results to the temporal folder
  cp ${outn}_${i}/annotation/prokka.gff tmp_genome/${fname}.gff
done
# If there is a reference genome, copy it into the temporal folder too
if [ "${referencefolder}" != "" ]; then
  cat ${referencefolder}/*.gff* ${referencefolder}/*.fa* > tmp_genome/refg.gff
fi


############################
## Compare genome content ##
############################

printf "\nComparing genome content...\n"
roary -e --mafft -p ${threads} -f ${outn}_GenomeContent -r tmp_genome/*.gff
echo "Genome content analysis finished sucessfully."


###########################
## Remove temporal files ##
###########################

rm -r tmp_genome


############################
## Compute SNPs detection ##
############################

printf "\nPerforming variant calling analysis...\n"
# Use as a reference genome the first strain that is provided
if [ "${referencefolder}" != "" ]; then
  reference_genome="${referencefolder}/*.gb*"
  minvalstart=2
else
  reference_genome="${outn}_2/annotation/prokka.ffn"
  minvalstart=4
fi

# Compute variant calling with Snippy and identify SNPs
for i in $(seq ${minvalstart} 2 ${end}); do
  snippy --report --cpus ${threads} \
  --outdir ${outn}_SNPs_${i} --ref ${reference_genome} \
  --ctgs ${outn}_${i}/assembly/contigs.fasta
done

# If there are more than 2 strains to compare, identify core SNPs.
if [ ${end} -gt 4 ]; then
  snippy-core --ref ${reference_genome} --prefix ${outn}_SNPsCore ${outn}_SNPs_*
fi
echo "SNPs were detected sucessfully."


################################################
## Rename folders for an easier understanding ##
################################################

for i in $(seq 2  2 ${end}); do
  # Get name of the file
  filefirst=$(ls -1q ${fastqfolder} | head -n$i | tail -n1)
  # Check if file is compressed and get file name without the extension
  if file --mime-type ${fastqfolder}/${filefirst} | grep -q gzip; then
    nameext=${filefirst%.*}
    fname=${nameext%.*}
  else
    fname=${filefirst%.*}
  fi
  # Move the folder to a new name matching the files names
  mv ${outn}_${i} ${outn}_${fname}
  if [ ${i} -gt 2 ]; then
    mv ${outn}_SNPs_${i} ${outn}_SNPs_${fname}
  fi
done

# Remove folder of SNPs if existing and create new one with all permissions
rm -rf ${outn}_allSNPs && \
  mkdir ${outn}_allSNPs && \
  chmod +xwr ${outn}_allSNPs

# Move all results with SNPs detection into the same folder
mv ${outn}_SNPs* ${outn}_allSNPs

# Remove final directory if existing and create new one with all permissions
rm -rf ${outn} && \
  mkdir ${outn} && \
  chmod +xwr ${outn}

# Move outputs inside final directory
mv ${outn}_* ${outn}
echo "All analyses finished sucessfully. Good luck with the results!"
