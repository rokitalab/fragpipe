set -e
set -o pipefail

# Set tools and input directories
input_dir=input
tools_dir=/fragpipe_bin/fragPipe-22.0/fragpipe/tools

#Initialize variables
cohort=""
run_subset=FALSE

# define parameter variables 
while [ $# -gt 0 ]; do
  case "$1" in
    --cohort)
      if [[ "$1" != *=* ]]; then shift; fi # Value is next arg if no `=`
      cohort="${1#*=}"
      ;;    
    --run_subset)
      run_subset=TRUE  # Set run_subset to true when the flag is provided
      ;;
    --help|-h)
        echo "Usage: $0 [--run_subset] [--cohort [cptac|hope]]"
        echo ""
        echo "Options:"
        echo "  --run_subset                      Run fragpipe on first experiment in cohort only"
        echo "  --cohort                          Cohort, cptac or hope"
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


# Error out if no custom.fasta is provided
if [ ! -e "$input_dir/custom.fasta" ]; then
  echo "Error: must supply a custom.fasta file in the input directory ($input_dir)"
  exit 1
fi

echo "Adding decoys and contaminants to FASTA files.."
cd $input_dir

# Initialize the Philosopher workspace
$tools_dir/Philosopher/philosopher-v5.1.1 workspace --init

# Add decoys and contaminants to the custom FASTA file
gunzip -c UP000005640_9606.fasta.gz | $tools_dir/Philosopher/philosopher-v5.1.1 database --custom custom.fasta --add /dev/stdin --contam
mv *decoys-contam-custom.fasta.fas decoys-contam-custom-canonical.fasta

# Clean intermediate files
$tools_dir/Philosopher/philosopher-v5.1.1 workspace --clean 

# Return to the previous directory
cd -

# set cavatica directory based on --cohort argument
if [[ -n "$cohort" ]]; then

    # Check if the next argument is "hope" or "cptac"
    if [[ "$cohort" == "hope" ]]; then
        echo "Fragpipe will be run on HOPE cohort"
        cavatica_dir=(/home/rstudio/fragpipe/data/projects/harenzaj/hope-proteomics/HOPE_TotalProteome_mzML)
        
    elif [[ "$cohort" == "cptac" ]]; then
        echo "Fragpipe will be run on CPTAC cohort"
        cavatica_dir=(/home/rstudio/fragpipe/data/projects/harenzaj/proteomics)
        
    else
        echo "Error: Invalid cohort. Use 'hope' or 'cptac'."
        exit 1
    fi
else
    echo "Error: Missing --cohort argument."
    echo "Usage: bash run_fragpipe.sh --cohort [hope|cptac]"
    exit 1
fi

# check that cavatica project directory path exists
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
 
 if [[ "$cohort" == "cptac" ]]; then

    if [ "$run_subset" = TRUE ]; then

    cp -R $cavatica_dir/*01CBTTC_PBT_Proteome* /home/rstudio/fragpipe/tmp/
 
    else

    cp -R $cavatica_dir/*CBTTC_PBT_Proteome* /home/rstudio/fragpipe/tmp/
 
    fi

 # unzip mzML files, force overwrite if files exist
 echo "unzipping mzML files..."
 gunzip -f /home/rstudio/fragpipe/tmp/*CBTTC_PBT_Proteome*/*mzML.gz

 else

    if [ "$run_subset" = TRUE ]; then

    cp -R $cavatica_dir/*01CPTAC_AYA_Proteome* /home/rstudio/fragpipe/tmp/

    else
 
    cp -R $cavatica_dir/*CPTAC_AYA_Proteome* /home/rstudio/fragpipe/tmp/
 
  fi
 # unzip mzML files, force overwrite if files exist
 echo "unzipping mzML files..."
 gunzip -f /home/rstudio/fragpipe/tmp/*CPTAC_AYA_Proteome*/*mzML.gz
 
fi


# set workflow, manifest, results and tools directories
echo "Starting Fragpipe run..."

# set manifest and workflow paths based on cohort
if [[ "$cohort" == "cptac" ]]; then

  wf=/home/rstudio/fragpipe/input/PDC000180customworkflow.workflow
  manifest=/home/rstudio/fragpipe/input/PDC000180filesmanifest.fp-manifest

else

  wf=/home/rstudio/fragpipe/input/HOPEproteome_TMT11workflow.workflow
  manifest=/home/rstudio/fragpipe/input/HOPE-files-manifest.fp-manifest

fi

if [[ "$run_subset" = TRUE ]]; then

grep "01C" $manifest > /home/rstudio/fragpipe/input/manifest.fp-manifest_sub
manifest=/home/rstudio/fragpipe/input/manifest.fp-manifest_sub

fi

res_dir=/home/rstudio/fragpipe/results
tools_dir=/fragpipe_bin/fragPipe-22.0/fragpipe/tools

/fragpipe_bin/fragPipe-22.0/fragpipe/bin/fragpipe --headless --workflow $wf --manifest $manifest --workdir $res_dir --config-tools-folder $tools_dir

# clear tmp directory
rm -rf $tmp_dir/*
