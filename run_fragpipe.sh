#!/bin/bash

set -e
set -o pipefail

# Set tools and input directories
input_dir=input
tools_dir=/fragpipe_bin/fragPipe-22.0/fragpipe/tools

# Error out if no custom.fasta is provided
if [ ! -e "$input_dir/custom.fasta" ]; then
  echo "Error: must supply a custom.fasta file in the input directory ($input_dir)"
  exit 1
fi

echo "Adding decoys and contaminants to FASTA files.."
cd $input_dir
gunzip UP000005640_9606.fasta.gz

# Initialize the Philosopher workspace
$tools_dir/Philosopher/philosopher-v5.1.1 workspace --init

# Add decoys and contaminants to the custom FASTA file
$tools_dir/Philosopher/philosopher-v5.1.1 database --custom custom.fasta --add UP000005640_9606.fasta --contam
mv *decoys-contam-custom.fasta.fas decoys-contam-custom-canonical.fasta

# Clean intermediate files
$tools_dir/Philosopher/philosopher-v5.1.1 workspace --clean 
gzip UP000005640_9606.fasta

# Return to the previous directory
cd -

# set cavatica directory
cavatica_dir=(/home/rstudio/fragpipe/data/projects/harenzaj/proteomics)

if [ ! -d $cavatica_dir ]; then
  echo "Error: path to cavatica project directory does not exist. Confirm that proteomics cavatica project is mounted to data/ directory"
  exit 1
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

if ! [[ " $* " == *" --run_subset "* ]]; then

cp -R $cavatica_dir/*CBTTC_PBT_Proteome* /home/rstudio/fragpipe/tmp/

else

cp -R $cavatica_dir/01CBTTC_PBT_Proteome* /home/rstudio/fragpipe/tmp/

fi

# unzip mzML files, force overwrite if files exist
echo "unzipping mzML files..."
gunzip -f /home/rstudio/fragpipe/tmp/*CBTTC_PBT_Proteome*/*mzML.gz

# set workflow, manifest, results and tools directories
echo "Starting Fragpipe run..."

wf=/home/rstudio/fragpipe/input/PDC000180customworkflow.workflow
manifest=/home/rstudio/fragpipe/input/PDC000180filesmanifest.fp-manifest

if [[ " $* " == *" --run_subset "* ]]; then

grep "01CBTTC_" $manifest > /home/rstudio/fragpipe/input/PDC000180filesmanifest.fp-manifest_sub
manifest=/home/rstudio/fragpipe/input/PDC000180filesmanifest.fp-manifest_sub

fi

res_dir=/home/rstudio/fragpipe/results
tools_dir=/fragpipe_bin/fragPipe-22.0/fragpipe/tools

/fragpipe_bin/fragPipe-22.0/fragpipe/bin/fragpipe --headless --workflow $wf --manifest $manifest --workdir $res_dir --config-tools-folder $tools_dir

# clear tmp directory
rm -rf $tmp_dir/*
