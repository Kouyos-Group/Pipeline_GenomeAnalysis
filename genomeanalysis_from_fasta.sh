#!/bin/bash

set -e

###################
## Assign inputs ##
###################

# Define usage of the script
function print_usage {
  printf """
Usage: genomeanalysis.sh    [-h or --help]
                            [-f or --fastafolder]
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
    -f, --fastafolder:
                Path to the folder that contains ALL your FASTA files.
                Only FASTA files should be placed in it.
"""
}

# Define inputs
for ARGS in "$@"; do
  shift
        case "$ARGS" in
                "--fastafolder") set -- "$@" "-f" ;;
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
                f) fastafolder=${OPTARG} ;;
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
# Check if directory containing FASTA files exists
if [ ! -d ${fastafolder} ]; then
  echo "Error: --fastafolder doesn't exist."
  echo "Solution: check if the path to this directory is correct."
  exit 1
fi

# Check if only FASTA files are provided in the fastafolder
for seqfile in ${fastafolder}/*; do
  # Get the extension of the file, if file is compressed
  if file --mime-type "${seqfile}" | grep -q gzip; then
    filename=${seqfile%.*}
    extension=${filename##*.}
  else # Get the extension of the file, if file is NOT compressed
    extension=${seqfile##*.}
  fi
  # Check if extension is fasta or fa or ffn or fna
  extension=$(tr "[:upper:]" "[:lower:]" <<< ${extension})
  if [[ ${extension} != "fa" && ${extension} != "fasta" && \
        ${extension} != "ffn" && ${extension} != "fna" ]]; then
    echo "Error: --fastafolder should only contain FASTA files."
    echo "Solution: remove any other file from this directory."
    exit 1
  fi
done
# Count number of files that are found in the folder
end=$(ls -1q ${fastafolder} | wc -l)
# If there are less than 2 FASTA (less than 2 strains), show the error
if [ ${end} -lt 2 ]; then
  if [ "${referencefolder}" == "" ]; then
    echo "Error: --fastafolder should contain at least 2 FASTA files."
    echo "Reason: comparisons only possible if you have >2 strains."
    echo "Solution: add FASTA files to the folder OR add a REFERENCE folder."
    exit 1
  else # If reference strain is provided, then only 1 extra strain is needed
    if [ ${end} -lt 1 ]; then
      echo "Error: --fastafolder should contain at least 1 FASTA files."
      echo "Reason: comparisons only possible if you have >2 strains."
      echo "Solution: add FASTA files to the folder to compare with your ref."
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
  # Count number of files that are found in the folder
  numbrefs=$(ls -1q ${referencefolder} | wc -l)
  # If there are less than 3 files, show the error
  if [ ${numbrefs} -ne 3 ]; then
    echo "Error: --referencefolder should contain exactly 3 files."
    echo "Reason: FASTA, GFF and GenBank files needed."
    echo "Solution: add/remove files in the reference folder."
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


###############################
## Compute Prokka annotation ##
###############################

printf "\nPerforming gene annotations...\n"
i=1
for fnames in ${fastafolder}/*; do
  # Compute annotation
  prokka --outdir ${outn}_${i}/annotation --prefix prokka --cpus ${threads} \
    ${fnames}
  i=$((i+1))
done
echo "Gene annotations finished sucessfully."


#####################################
## Copy results to temporal folder ##
#####################################

# Remove temporal directory if existing and create new one with all permissions
rm -rf tmp_genome && \
  mkdir tmp_genome && \
  chmod +xwr tmp_genome

for i in $(seq 1  1 ${end}); do
  # Get name of the file
  filefirst=$(ls -1q ${fastafolder} | head -n$i | tail -n1)
  # Check if file is compressed and get file name without the extension
  if file --mime-type ${fastafolder}/${filefirst} | grep -q gzip; then
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
  minvalstart=1
else
  reference_genome="${outn}_1/annotation/prokka.ffn"
  minvalstart=2
fi

# Compute variant calling with Snippy and identify SNPs
i=1
for fnames in ${fastafolder}/*; do
  snippy --report --cpus ${threads} \
  --outdir ${outn}_SNPs_${i} --ref ${reference_genome} \
  --ctgs ${fnames}
  i=$((i+1))
done

# If there are more than 2 strains to compare, identify core SNPs.
if [ "${referencefolder}" != "" ]; then
  if [ ${end} -gt 1 ]; then
    snippy-core --ref ${reference_genome} --prefix ${outn}_SNPsCore ${outn}_SNPs_*
  fi
else
  if [ ${end} -gt 2 ]; then
    snippy-core --ref ${reference_genome} --prefix ${outn}_SNPsCore ${outn}_SNPs_*
  fi
fi
echo "SNPs were detected sucessfully."


################################################
## Rename folders for an easier understanding ##
################################################

for i in $(seq 1  1 ${end}); do
  # Get name of the file
  filefirst=$(ls -1q ${fastafolder} | head -n$i | tail -n1)
  # Check if file is compressed and get file name without the extension
  if file --mime-type ${fastafolder}/${filefirst} | grep -q gzip; then
    nameext=${filefirst%.*}
    fname=${nameext%.*}
  else
    fname=${filefirst%.*}
  fi
  # Move the folder to a new name matching the files names
  mv ${outn}_${i} ${outn}_${fname}
  if [ "${referencefolder}" != "" ]; then
    mv ${outn}_SNPs_${i} ${outn}_SNPs_${fname}
  else
    if [ ${i} -gt 2 ]; then
      mv ${outn}_SNPs_${i} ${outn}_SNPs_${fname}
    fi
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
