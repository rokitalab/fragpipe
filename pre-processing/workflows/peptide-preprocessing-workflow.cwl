cwlVersion: v1.2
class: Workflow

label: FragPipe Peptide Preprocessing Workflow
doc: |
  This workflow replicates the exact functionality of the first 27 lines of run_fragpipe.sh.
  Uses Philosopher to combine custom sequences with canonical UniProt sequences,
  add contaminants from Philosopher's database, and generate decoy sequences.

requirements:
  - class: ShellCommandRequirement
  - class: StepInputExpressionRequirement

inputs:
  custom_fasta:
    type: File
    label: Custom peptide sequences
    doc: FASTA file containing custom peptide sequences of interest
    
  uniprot_canonical_fasta:
    type: File
    label: UniProt canonical sequences (gzipped)
    doc: Gzipped FASTA file containing UniProt canonical protein sequences (UP000005640_9606.fasta.gz)

outputs:
  merged_fasta:
    type: File
    label: Final merged FASTA with decoys and contaminants
    doc: Combined FASTA file with custom sequences, canonical sequences, contaminants, and decoys
    outputSource: philosopher_database/output_fasta
    
  philosopher_log:
    type: File?
    label: Philosopher processing log
    doc: Log file from Philosopher database processing
    outputSource: philosopher_database/log_file

steps:
  philosopher_database:
    run: ../tools/philosopher-database.cwl
    in:
      custom_fasta: custom_fasta
      canonical_fasta_gz: uniprot_canonical_fasta
    out: [output_fasta, log_file]

$namespaces:
  sbg: https://sevenbridges.com

hints:
  - class: sbg:maxNumberOfParallelInstances
    value: 1
