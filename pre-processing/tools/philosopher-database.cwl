cwlVersion: v1.2
class: CommandLineTool

label: Philosopher Database Processing
doc: |
  Replicates the exact Philosopher commands from run_fragpipe.sh:
  1. philosopher workspace --init
  2. gunzip -c UP000005640_9606.fasta.gz | philosopher database --custom custom.fasta --add /dev/stdin --contam
  3. mv *decoys-contam-custom.fasta.fas to output
  4. philosopher workspace --clean

requirements:
  - class: ShellCommandRequirement
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.custom_fasta)
      - $(inputs.canonical_fasta_gz)
  - class: DockerRequirement
    dockerPull: pgc-images.sbgenomics.com/rokita-lab/fragpipe:latest

baseCommand: ["/bin/bash"]

arguments:
  - valueFrom: |
      set -e
      set -o pipefail

      # Get input file paths
      CUSTOM_FASTA="$(inputs.custom_fasta.path)"
      CANONICAL_FASTA_GZ="$(inputs.canonical_fasta_gz.path)"

      # Use the philosopher binary from the FragPipe container, note this path is different from the copied tools
      PHILOSOPHER_BIN="/fragpipe_bin/fragPipe-23.1/fragpipe-23.1/tools/Philosopher/philosopher-v5.1.2"
      
      echo "Starting Philosopher database processing..."
      echo "Custom FASTA: $CUSTOM_FASTA"
      echo "Canonical FASTA (gzipped): $CANONICAL_FASTA_GZ"
      
      # Initialize the Philosopher workspace
      echo "Initializing Philosopher workspace..."
      $PHILOSOPHER_BIN workspace --init
      
      # Add canonical UniProt FASTA sequences and contaminants to the custom FASTA file
      echo "Adding canonical UniProt FASTA sequences and contaminants..."
      gunzip -c "$CANONICAL_FASTA_GZ" | $PHILOSOPHER_BIN database --custom "$CUSTOM_FASTA" --add /dev/stdin --contam
      
      # Find the output file (should match pattern *decoys-contam-custom.fasta.fas)
      OUTPUT_FILE=`ls *decoys-contam-custom.fasta.fas 2>/dev/null | head -1`
      if [ -z "$OUTPUT_FILE" ]; then
        echo "Error: Could not find expected output file *decoys-contam-custom.fasta.fas"
        echo "Available files:"
        ls -la
        exit 1
      fi
      
      echo "Found output file: $OUTPUT_FILE"
      
      # Copy to standard output name for CWL
      cp "$OUTPUT_FILE" decoys-contam-custom-canonical.fasta
      
      # Create log file with detailed information
      echo "Philosopher database processing completed successfully" > philosopher.log
      echo "Command executed: gunzip -c $CANONICAL_FASTA_GZ | philosopher database --custom $CUSTOM_FASTA --add /dev/stdin --contam" >> philosopher.log
      echo "Input files:" >> philosopher.log
      echo "  - Custom FASTA: $CUSTOM_FASTA" >> philosopher.log
      echo "  - Canonical FASTA (gzipped): $CANONICAL_FASTA_GZ" >> philosopher.log
      echo "Output file generated: $OUTPUT_FILE" >> philosopher.log
      echo "Final output: decoys-contam-custom-canonical.fasta" >> philosopher.log
      
      # Count sequences in files
      echo "Sequence counts:" >> philosopher.log
      echo "  - Custom sequences: `grep -c '^>' "$CUSTOM_FASTA" || echo 0`" >> philosopher.log
      echo "  - Final combined (with decoys/contaminants): `grep -c '^>' decoys-contam-custom-canonical.fasta || echo 0`" >> philosopher.log
      
      # Clean intermediate files (replicates: philosopher workspace --clean)
      echo "Cleaning workspace..."
      $PHILOSOPHER_BIN workspace --clean
      
      echo "Philosopher database processing completed successfully"
    position: 1
    prefix: "-c"

inputs:
  custom_fasta:
    type: File
    doc: Custom FASTA file with peptide sequences of interest
    
  canonical_fasta_gz:
    type: File
    doc: Gzipped canonical UniProt FASTA file (UP000005640_9606.fasta.gz)

outputs:
  output_fasta:
    type: File
    outputBinding:
      glob: "decoys-contam-custom-canonical.fasta"
    doc: FASTA file with custom sequences, canonical sequences, contaminants, and decoys
    
  log_file:
    type: File
    outputBinding:
      glob: "philosopher.log"
    doc: Log file from Philosopher processing

hints:
  - class: ResourceRequirement
    coresMin: 1
    ramMin: 2048
