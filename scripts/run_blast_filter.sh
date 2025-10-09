#!/bin/bash

set -e
set -o pipefail

#Initialize variables
fasta=""

# define parameter variables 
while [ $# -gt 0 ]; do
  case "$1" in
    --fasta)
      if [[ "$1" != *=* ]]; then shift; fi # Value is next arg if no `=`
      fasta="${1#*=}"
      ;;    
    --help|-h)
        echo "Usage: $0 [--fasta]"
        echo ""
        echo "Options:"
        echo "  --fasta                           fasta file"
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

# cd to the directory where this script is located
cd "$(dirname "$0")"

# 1. Run BLASTP
blastp -query $fasta \
       -db ../refs/uniprot_human \
       -out ../input/blast_results.tsv \
       -outfmt "6 qseqid sseqid pident length qlen slen"

# 2. Extract query IDs with full-length 100% matches
awk '$3 == 100 && $4 == $5 {print $1}' ../input/blast_results.tsv | sort -u > ../input/full_matches.txt

# 3. Count matches and total peptides
total=$(grep -c "^>" $fasta)
matches=$(wc -l < ../input/full_matches.txt)
remaining=$(( total - matches ))

echo "Total peptides: $total"
echo "Filtered out (100% UniProt matches): $matches"
echo "Remaining peptides: $remaining"

# 4. Filter FASTA
seqkit grep -v -f ../input/full_matches.txt $fasta \
    > ../input/custom.filtered.fasta
