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
cohort=""
run_subset=FALSE

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
    --cohort)
      cohort="$2"
      shift 2
      ;;
    --cohort=*)
      cohort="${1#*=}"
      shift
      ;;
    --run_subset)
      run_subset=TRUE  # Set run_subset to true when the flag is provided
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--query FILE] [--manifest FILE] [--workflow FILE] [--res_dir DIR] [--cohort <cohort>]"
      echo ""
      echo "Options:"
      echo "  --query FILE          FASTA file containing query peptides"
      echo "  --manifest FILE       Manifest file specifying sample mzML paths"
      echo "  --workflow FILE       FragPipe workflow file"
      echo "  --res_dir DIR         Output directory for FragPipe results"
      echo "  --cohort <cohort>     Either 'cptac' or 'hope'; if specified, mzML files will be copied from associated cavatica project and unzipped"
      echo "  --run_subset          If specified, fragpipe will be run on first experiment from above cohort; only applicable when '--cohort' specified. Default: FALSE"
      echo "  -h, --help            Display usage information"
      exit 0
      ;;
    *)
      >&2 echo "Error: Invalid argument '$1'"
      exit 1
      ;;
  esac
done

# Check that required arguments are specified 
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
Uniprot_canonical=/home/rstudio/fragpipe/refs/UP000005640_9606.fasta.gz

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

# check if --cohort parameter defined
if [[ -n "$cohort" ]]; then

    # define directory to mount cavatica project; create if it does not exist
    data_dir=/home/rstudio/fragpipe/cavatica-data
    
    if [ ! -d $data_dir ]; then
      mkdir -p $data_dir
      echo "Creating cavatica-data directory to mount cavatica project..."
    fi

    # Check if cohort is "hope" or "cptac"
    if [[ "$cohort" == "hope" ]]; then
        echo "Fragpipe will be run on HOPE cohort"
        # set cavatica dir
        cavatica_dir=(/home/rstudio/fragpipe/cavatica-data/projects/harenzaj/hope-proteomics/HOPE_TotalProteome_mzML)
        # define cavatica project
        project=harenzaj/hope-proteomics
        
    elif [[ "$cohort" == "cptac" ]]; then
        echo "Fragpipe will be run on CPTAC cohort"
        cavatica_dir=/home/rstudio/fragpipe/cavatica-data/projects/harenzaj/proteomics
        project=harenzaj/proteomics
        
    else
        echo "Error: Invalid cohort. Use 'hope' or 'cptac'."
        exit 1
    fi
    
    if [ ! -d $cavatica_dir ]; then
      echo "Error: path to cavatica project directory does not exist. Attempting to mount project with sbfs mount..."
    
      sbfs mount --profile default --project $project cavatica-data

    fi
    
    # check if tmp directory exists, and create it if not
    tmp_dir=(/home/rstudio/fragpipe/tmp)
    
    if [ ! -d $tmp_dir ]; then
      mkdir -p $tmp_dir
      echo "Temporary directory does not exist, creating..."
    fi
    
    # clear contents of tmp directory, if not already empty
    rm -rf $tmp_dir/*
    
    # copy mzML files to temporary directory, maintaining directory structure
    echo "copying mzML files to temporary directory..."
    
    if [[ "$cohort" == "cptac" ]]; then
    
       if [ "$run_subset" = TRUE ]; then
    
       cp -R $cavatica_dir/*01CBTTC_PBT_Proteome* $tmp_dir
    
       else
    
       cp -R $cavatica_dir/*CBTTC_PBT_Proteome* $tmp_dir
    
       fi
    
    # unzip mzML files, force overwrite if files exist
    echo "unzipping mzML files..."
    gunzip -f $tmp_dir/*CBTTC_PBT_Proteome*/*mzML.gz
    
    elif [[ "$cohort" == "hope" ]]; then
    
       if [ "$run_subset" = TRUE ]; then
    
       cp -R $cavatica_dir/*01CPTAC_AYA_Proteome* $tmp_dir
    
       else
    
       cp -R $cavatica_dir/*CPTAC_AYA_Proteome* $tmp_dir
    
     fi
     
    #unzip mzML files, force overwrite if files exist
     echo "unzipping mzML files..."
     gunzip -f $tmp_dir/*CPTAC_AYA_Proteome*/*mzML.gz
    
    fi
    
    sbfs unmount cavatica-data

fi

# if run_subset specified, subset file manifest
if [[ "$run_subset" = TRUE ]]; then

  grep "01C" $manifest > /home/rstudio/fragpipe/input/manifest.fp-manifest_sub
  manifest=/home/rstudio/fragpipe/input/manifest.fp-manifest_sub
  manifest_fullpath=$(realpath "$manifest")

fi

# run fragpipe
echo "Starting Fragpipe run..."

/fragpipe_bin/fragPipe-22.0/fragpipe/bin/fragpipe --headless --workflow $workflow_fullpath --manifest $manifest_fullpath --workdir $res_dir --config-tools-folder $tools_dir

# clear tmp directory
rm -rf $tmp_dir/*
