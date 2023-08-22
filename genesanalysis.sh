#!/bin/bash

set -e

###################
## Assign inputs ##
###################

# Define usage of the script
function print_usage {
  printf """
Usage: genesalysis.sh   [-h or --help]
                        [-s or --specific_genes]
                        [-o or --outputs_folder]
                        [-t or --threads]
"""
}
# Describe usage of the tool and provide help
function print_help {
  print_usage
  printf """
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
                E.g.: 'murF fabZ rplL'.
    -o, --outputs_folder:
                Path to the folder that contains ALL your outputs from
                the genomeanalysis.sh pipeline.
"""
}

# Define inputs
for ARGS in "$@"; do
  shift
        case "$ARGS" in
                "--outputs_folder") set -- "$@" "-o" ;;
                "--specific_genes") set -- "$@" "-s" ;;
                "--threads") set -- "$@" "-t" ;;
                "--help") set -- "$@" "-h" ;;
                *) set - "$@" "$ARGS"
        esac
done

# Define defaults
threads=8

# Define all parameters
while getopts 'o:s:t::h' flag; do
        case "${flag}" in
                o) outputs_folder=${OPTARG} ;;
                s) specific_genes=${OPTARG} ;;
                t) threads=${OPTARG} ;;
                h) print_help
                   exit 1;;
                *) print_usage
                    exit 1;;
        esac
done


########################################
## Identify Errors in Inputs Required ##
########################################

printf "\nChecking if required inputs are correct...\n"
# Check if directory containing output files exists
if [ ! -d ${outputs_folder} ]; then
  echo "Error: --outputs_folder doesn't exist."
  echo "Solution: check if the path to this directory is correct."
  exit 1
fi

# Check if any gene names are provided
if [[ ${specific_genes} == "" ]]; then
  echo "Error: --specific_genes cannot be empty."
  echo "Solution: add the name of your genes of interest."
  exit 1
fi
echo "Required inputs seem correct."


########################################
## Identify Errors in Optional Inputs ##
########################################

printf "\nChecking if optional inputs are correct...\n"
# Check if the number of threads is an integer
if ! [[ ${threads} =~ ^[0-9]+$ ]]; then
  echo "Error: --threads is not an integer."
  echo "Solution: remove this optional parameter or use an integer."
  exit 1
fi
echo "Optional inputs seem correct."


##################################################################
## Identify Gene Sequences to later use them with Clustal Omega ##
##################################################################

printf "\nIdentifying gene sequences...\n"
pathout=$(realpath ${outputs_folder}/*allSNPs*/)
for genename in ${specific_genes}; do
  # Remove results if existing and create new ones with all permissions
  rm -f ${pathout}/SNPs_AA_${genename}.txt && \
    touch ${pathout}/SNPs_AA_${genename}.txt && \
    chmod +xwr ${pathout}/SNPs_AA_${genename}.txt
  for strain_name in ${outputs_folder}/*; do
    # Reject folders containing GenomeContent or SNPs information
    if ! [[ ${strain_name} =~ .*GenomeContent.*|.*allSNPs.* ]]; then
      # Get name of the outputs (not the whole path)
      namefolder=$(basename ${outputs_folder})
      # Remove, from the whole path, all redundant info to get the strain name
      sname=$(echo ${strain_name#${outputs_folder}/${namefolder}_})
      # Find gene sequence for each gene
      geneseq=$(cat ${strain_name}/annotation/prokka.faa | \
        grep -A100000 ${genename} | tail -n +2 | \
        grep -m1 -B100000 ">" | sed '$d')
      echo ">"${sname}_${genename} >> ${pathout}/SNPs_AA_${genename}.txt
      echo ${geneseq} >> ${pathout}/SNPs_AA_${genename}.txt
    fi
  done
done
echo "Gene sequences identified sucessfully."


####################################################
## Obtain positions of mutations within the genes ##
####################################################

printf "\nIdentifying amino acid mutations within all genes...\n"
# Obtain positions of mutations in genes
positions=$(cat ${outputs_folder}/*_allSNPs/*_SNPsCore.tab | \
  cut -f 2 | tail -n +2)
# Obtain positions of amino acids in genes
positions_aa=$(echo $positions | awk '{for(i=1;i<=NF;i++) print int($i/3+0.8)}')
# Obtain gene names
allgenes=$(cat ${outputs_folder}/*_allSNPs/*_SNPsCore.tab | \
  cut -f 1 | tail -n +2)

# Create file of outputs
rm -f ${pathout}/SNPs_AA_allgenes.txt && \
  touch ${pathout}/SNPs_AA_allgenes.txt && \
  chmod +xwr ${pathout}/SNPs_AA_allgenes.txt

# Write 1st line of output
cat ${outputs_folder}/*_allSNPs/*_SNPsCore.tab | head -n1 > \
  ${pathout}/SNPs_AA_allgenes.txt

i=1
# Write the amino acid of each position that has been found for each strain
for j in ${positions_aa}; do
  gnamelist=$(echo $allgenes | cut -d " " -f${i})
  printf "${gnamelist}\t";
  printf "${j}\t";
  column_number=14 # This is the gene column in the gene_presence_absence file
  for strain_name in ${outputs_folder}/*; do
    # Reject folders containing GenomeContent or SNPs information
    if ! [[ ${strain_name} =~ .*GenomeContent.*|.*allSNPs.* ]]; then
      column_number=$((column_number+1))
      # Find gene name in all the other strains
      gname=$(cat ${outputs_folder}/*GenomeContent*/gene_presence_absence.csv | \
        grep ${gnamelist} | sed "s/\,\"/\t/g" | \
        cut -f${column_number} | sed "s/\"//g" | tr -d "[:space:]")
      # Find amino acid
      if [[ ${gname} != "" ]]; then
        seqaa=$(cat ${strain_name}/annotation/prokka.faa | \
          grep -s -A100000 ${gname} | tail -n +2 | \
          grep -m1 -B100000 ">" | sed '$d' | tr -d '\n' | cut -c ${j})
        printf "${seqaa}\t";
      fi
    fi
  done
  i=$((i+1))
  printf "\n";
done >> ${pathout}/SNPs_AA_allgenes.txt
echo "Mutations identified sucessfully."

echo "All analyses finished sucessfully. Good luck with the results!"
echo "Please, consider that the final table of amino acids is ONLY correct if
you are not using an external reference. Otherwise, the REF is taken as if
it was the first strain of your collection, ignoring the external one."
