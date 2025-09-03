# FragPipe Peptide Preprocessing Workflow

This CWL workflow replicates the exact functionality of the first 27 lines of `run_fragpipe.sh` for preprocessing peptide sequences before FragPipe analysis.

## Overview

The workflow uses Philosopher to process two input files:
1. **Custom peptide sequences** (custom.fasta)
2. **UniProt canonical human proteome** (UP000005640_9606.fasta.gz - gzipped)

Philosopher automatically:
- Adds the canonical sequences via stdin (`--add /dev/stdin`)
- Adds contaminants from its built-in database (`--contam`)
- Generates decoy sequences by reversing/shuffling
- Outputs a combined FASTA file ready for FragPipe

## Directory Structure

```
pre-processing/
├── workflows/
│   └── peptide-preprocessing-workflow.cwl    # Main workflow
├── tools/
│   └── philosopher-database.cwl              # Philosopher database processing tool
├── params/
│   └── example-inputs.yml                    # Example input configuration
├── tests/
│   └── test_data/                            # Test FASTA files
└── README.md                                 # This file
```

## Input Files Required

1. **custom_fasta**: Your custom peptide sequences (FASTA format)
2. **uniprot_canonical_fasta**: UniProt canonical human proteome (gzipped FASTA)

## Philosopher Processing

The workflow executes these exact commands from the original script:

```bash
# Initialize workspace
philosopher workspace --init

# Process databases with decoys and contaminants
gunzip -c UP000005640_9606.fasta.gz | philosopher database --custom custom.fasta --add /dev/stdin --contam

# Output file is automatically created: *decoys-contam-custom.fasta.fas
# Renamed to: decoys-contam-custom-canonical.fasta

# Clean workspace
philosopher workspace --clean
```

## Usage

### Local Testing

```bash
# Install cwltool
pip install cwltool

# Run workflow locally (from pre-processing directory)
cd pre-processing
cwltool --outdir ../results workflows/peptide-preprocessing-workflow.cwl params/example-inputs.yml
```

## Input Configuration

Edit the YAML input file to specify your files:

```yaml
custom_fasta:
  class: File
  path: "custom.fasta"
  format: "http://edamontology.org/format_1929"

uniprot_canonical_fasta:
  class: File
  path: "UP000005640_9606.fasta.gz"
  format: "http://edamontology.org/format_3989"
```

## Workflow Steps

The workflow consists of a single step:

1. **philosopher_database**: Runs the complete Philosopher database processing
   - Initializes workspace
   - Processes custom sequences with canonical sequences via stdin
   - Adds contaminants from Philosopher's built-in database
   - Generates decoy sequences automatically
   - Renames output file to `decoys-contam-custom-canonical.fasta`
   - Cleans workspace

## Outputs

- **merged_fasta**: Final combined FASTA file (`decoys-contam-custom-canonical.fasta`)
- **philosopher_log**: Processing log with command details and sequence counts

## Docker Requirements

The workflow uses the FragPipe Docker image:
- Image: `pgc-images.sbgenomics.com/rokita-lab/fragpipe:latest`
- Philosopher v5.1.2 tool at `/fragpipe_bin/fragPipe-23.1/fragpipe-23.1/tools/Philosopher/philosopher-v5.1.2`
- All required dependencies included

## Notes

- This workflow exactly replicates the Philosopher commands from `run_fragpipe.sh`
- Philosopher handles all the complex processing: decompression, merging, decoy generation, and contamination
- The `--contam` flag uses Philosopher's built-in contaminant database
- The `--add /dev/stdin` approach allows piping the gzipped canonical sequences directly
- Output file naming and renaming is handled within the single processing step
- The workflow has been simplified to use a single step instead of separate processing and renaming steps
