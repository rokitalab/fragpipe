#!/bin/bash

set -e
set -o pipefail

# Set tools and input directories
input_dir=input
tools_dir=/fragpipe_bin/fragPipe-22.0/fragpipe/tools/

#Initialize variables
query=""
manifest=""
workflow=""
res_dir=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --query)
      query="$2"
      shift 2
      ;;
    --query=*)
      query="${1#*=}"
      shift
      ;;
    --manifest)
      manifest="$2"
      shift 2
      ;;
    --manifest=*)
      manifest="${1#*=}"
      shift
      ;;
    --workflow)
      workflow="$2"
      shift 2
      ;;
    --workflow=*)
      workflow="${1#*=}"
      shift
      ;;
    --res_dir)
      res_dir="$2"
      shift 2
      ;;
    --res_dir=*)
      res_dir="${1#*=}"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--query FILE] [--manifest FILE] [--workflow FILE] [--res_dir DIR]"
      echo ""
      echo "Options:"
      echo "  --query FILE          FASTA file containing query peptides"
      echo "  --manifest FILE       Manifest file specifying sample mzML paths"
      echo "  --workflow FILE       FragPipe workflow file"
      echo "  --res_dir DIR         Output directory for FragPipe results"
      echo "  -h, --help            Display usage information"
      exit 0
      ;;
    *)
      >&2 echo "Error: Invalid argument '$1'"
      exit 1
      ;;
  esac
done

# Require --query
if [[ -z "$query" ]]; then
  >&2 echo "Error: Missing required argument --query"
  >&2 echo "Usage: $0 --query <fasta_file> --manifest <manifest_file> --workflow <workflow_file> --res_dir <res_directory_path>"
  exit 1
fi

# Require --manifest
if [[ -z "$manifest" ]]; then
  >&2 echo "Error: Missing required argument --manifest"
  >&2 echo "Usage: $0 --query <fasta_file> --manifest <manifest_file> --workflow <workflow_file> --res_dir <res_directory_path>"
  exit 1
fi

# Require --workflow
if [[ -z "$workflow" ]]; then
  >&2 echo "Error: Missing required argument --workflow"
  >&2 echo "Usage: $0 --query <fasta_file> --manifest <manifest_file> --workflow <workflow_file> --res_dir <res_directory_path>"
  exit 1
fi

# Require --res_dir
if [[ -z "$res_dir" ]]; then
  >&2 echo "Error: Missing required argument --res_dir"
  >&2 echo "Usage: $0 --query <fasta_file> --manifest <manifest_file> --workflow <workflow_file> --res_dir <res_directory_path>"
  exit 1
fi

if [ ! -d $res_dir ]; then
  mkdir -p $res_dir
  echo "Specified results directory does not exist, creating..."
fi

# obtain full path of query fasta
query_fullpath=$(realpath "$query")
manifest_fullpath=$(realpath "$manifest")
workflow_fullpath=$(realpath "$workflow")

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
tmp_dir=(/home/rstudio/fragpipe/tmp)

if [ ! -d $tmp_dir ]; then
  mkdir -p $tmp_dir
  echo "Temporary directory does not exist, creating..."
fi

## clear contents of tmp directory, if not already empty
rm -rf $tmp_dir/*

# set workflow, manifest, results and tools directories
echo "Starting Fragpipe run..."

/fragpipe_bin/fragPipe-22.0/fragpipe/bin/fragpipe --headless --workflow $workflow_fullpath --manifest $manifest_fullpath --workdir $res_dir --config-tools-folder $tools_dir

# clear tmp directory
rm -rf $tmp_dir/*
