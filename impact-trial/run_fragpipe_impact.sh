#!/bin/bash

set -e
set -o pipefail

# Set tools and input directories
input_dir=input
tools_dir=/fragpipe_bin/fragPipe-22.0/fragpipe/tools/

#Initialize variables
query=""

# define parameter variables 
while [ $# -gt 0 ]; do
  case "$1" in
    --query)
      if [[ "$1" != *=* ]]; then shift; fi # Value is next arg if no `=`
      query="${1#*=}"
      ;;    
    --help|-h)
        echo "Usage: $0 [--query]"
        echo ""
        echo "Options:"
        echo "  --query                           fasta file containing query peptides"
        echo "  -h/--help                         Display usage information"
            exit 0
      ;;
    *)
      >&2 printf "Error: Invalid argument\n"
      exit 1
      ;;
  esac
  shift
done

# Require --query
if [[ -z "$query" ]]; then
  >&2 echo "Error: Missing required argument --query"
  >&2 echo "Usage: $0 --query <fasta_file>"
  exit 1
fi

# # Error out if no custom.fasta is provided
# if [ ! -e "$input_dir/custom.fasta" ]; then
#   echo "Error: must supply a custom.fasta file in the input directory ($input_dir)"
#   exit 1
# fi

# obtain full path of query fasta
query_fullpath=$(realpath "$query")

# filter out peptides with 100% match to uniprot canonical peptides
echo "Filtering out 100% matches to canonical peptides..."
bash scripts/run_blast_filter.sh --fasta $query_fullpath

echo "Adding decoys and contaminants to FASTA files.."
cd $input_dir

# Initialize the Philosopher workspace
$tools_dir/Philosopher/philosopher-v5.1.1 workspace --init

# define uniprot canonical fasta
Uniprot_canonical=/home/rstudio/fragpipe/refs/UP000005640_9606.fasta

# Add decoys and contaminants to the custom FASTA file
gunzip -c $Uniprot_canonical | $tools_dir/Philosopher/philosopher-v5.1.1 database --custom custom.filtered.fasta --add /dev/stdin --contam

# Remove canonical peptides annotated to genes in custom fasta
grep "^>" custom.filtered.fasta | awk -F'[:_]' '{print "GN=" $2 " "}' | sort -u > gene_symbols.txt

awk 'BEGIN{while((getline k < "gene_symbols.txt") > 0){a[k]=1}}
     /^>/{
         keep=1
         for (g in a) {
             if (index($0,g)) {keep=0; break}
         }
     }
     keep' *decoys-contam-custom.filtered.fasta.fas > decoys-contam-custom-canonical.fasta

# Clean intermediate files
$tools_dir/Philosopher/philosopher-v5.1.1 workspace --clean

# Return to the previous directory
cd -

# check if tmp directory exists, and create it if not
tmp_dir=(/home/rstudio/fragpipe/impact-trial/tmp)

if [ ! -d $tmp_dir ]; then
  mkdir -p $tmp_dir
  echo "Temporary directory does not exist, creating..."
fi

## clear contents of tmp directory, if not already empty
rm -rf $tmp_dir/*

# set workflow, manifest, results and tools directories
echo "Starting Fragpipe run..."

wf=/home/rstudio/fragpipe/impact-trial/input/impact-test-LFQ-MBR.workflow
manifest=/home/rstudio/fragpipe/impact-trial/input/impact-test-filesmanifest.fp-manifest

res_dir=/home/rstudio/fragpipe/impact-trial/results

/fragpipe_bin/fragPipe-22.0/fragpipe/bin/fragpipe --headless --workflow $wf --manifest $manifest --workdir $res_dir --config-tools-folder $tools_dir

# clear tmp directory
rm -rf $tmp_dir/*
