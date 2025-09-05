#!/bin/bash

set -e
set -o pipefail

# Set tools and input directories
input_dir=input
tools_dir=/fragpipe_bin/fragPipe-23.1/fragpipe-23.1/tools/

# Error out if no custom.fasta is provided
if [ ! -e "$input_dir/custom.fasta" ]; then
  echo "Error: must supply a custom.fasta file in the input directory ($input_dir)"
  exit 1
fi

echo "Adding decoys and contaminants to FASTA files.."
cd $input_dir

# Initialize the Philosopher workspace
$tools_dir/Philosopher/philosopher-v5.1.2 workspace --init

Uniprot_canonical=/home/rstudio/fragpipe/refs/UP000005640_9606.fasta.gz

# Add decoys and contaminants to the custom FASTA file
gunzip -c $Uniprot_canonical | $tools_dir/Philosopher/philosopher-v5.1.2 database --custom custom.fasta --add /dev/stdin --contam
mv *decoys-contam-custom.fasta.fas decoys-contam-custom-canonical.fasta

# Clean intermediate files
$tools_dir/Philosopher/philosopher-v5.1.2 workspace --clean 

# Return to the previous directory
cd -

# define directory to mount cavatica project; create if it does not exist
data_dir=/home/rstudio/fragpipe/tumor-enriched-splicing/cavatica-data

if [ ! -d $data_dir ]; then
  mkdir -p $data_dir
  echo "Creating cavatica-data directory to mount cavatica project..."
fi

# set cavatica directory
cavatica_dir=/home/rstudio/fragpipe/tumor-enriched-splicing/cavatica-data/projects/harenzaj/proteomics

if [ ! -d $cavatica_dir ]; then
  echo "Error: path to cavatica project directory does not exist. Attempting to mount project with sbfs mount..."
  
  sbfs mount --profile default --project harenzaj/proteomics cavatica-data

fi

# check if tmp directory exists, and create it if not
tmp_dir=(/home/rstudio/fragpipe/tumor-enriched-splicing/tmp)

if [ ! -d $tmp_dir ]; then
  mkdir -p $tmp_dir
  echo "Temporary directory does not exist, creating..."
fi

# clear contents of tmp directory, if not already empty
rm -rf $tmp_dir/*

# copy mzML files to temporary directory, maintaining directory structure
echo "copying mzML files to temporary directory..."

if ! [[ " $* " == *" --run_subset "* ]]; then

cp -R $cavatica_dir/*CBTTC_PBT_Proteome* $tmp_dir

else

cp -R $cavatica_dir/01CBTTC_PBT_Proteome* $tmp_dir

fi

# unzip mzML files, force overwrite if files exist
echo "unzipping mzML files..."
gunzip -f $tmp_dir/*CBTTC_PBT_Proteome*/*mzML.gz

# set workflow, manifest, results and tools directories
echo "Starting Fragpipe run..."

wf=/home/rstudio/fragpipe/tumor-enriched-splicing/input/PDC000180customworkflow.workflow
manifest=/home/rstudio/fragpipe/tumor-enriched-splicing/input/PDC000180filesmanifest.fp-manifest

if [[ " $* " == *" --run_subset "* ]]; then

grep "01CBTTC_" $manifest > /home/rstudio/fragpipe/tumor-enriched-splicing/input/PDC000180filesmanifest.fp-manifest_sub
manifest=/home/rstudio/fragpipe/tumor-enriched-splicing/input/PDC000180filesmanifest.fp-manifest_sub

fi

res_dir=/home/rstudio/fragpipe/tumor-enriched-splicing/results-cptac
tools_dir=/fragpipe_bin/fragPipe-23.1/fragpipe-23.1/tools/

/fragpipe_bin/fragPipe-23.1/fragpipe-23.1/bin/fragpipe --headless --workflow $wf --manifest $manifest --workdir $res_dir --config-tools-folder $tools_dir

# clear tmp directory
rm -rf $tmp_dir/*
