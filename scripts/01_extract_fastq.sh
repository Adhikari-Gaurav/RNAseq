#!/bin/bash
#SBATCH --job-name=extract_fastq
#SBATCH --partition=tsl-medium
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=06:00:00
#SBATCH --output=extract_fastq_%j.out
#SBATCH --error=extract_fastq_%j.err

set -euo pipefail

module purge
module load sra-tools/2.8.2

# BASE_DIR override: BASE_DIR=/path/to/your/project SAMPLE=SRR12345 sbatch 01_extract_fastq.sh
BASE_DIR="${BASE_DIR:-$(pwd)}"
SAMPLE="${SAMPLE:-SRR37923508}"

cd "${BASE_DIR}"

rm -f "fastq/${SAMPLE}.lite.1_1.fastq.gz" "fastq/${SAMPLE}.lite.1_2.fastq.gz"
mkdir -p fastq tmp

vdb-validate "${SAMPLE}.lite.1"

fasterq-dump "${SAMPLE}.lite.1" \
  --split-files \
  --threads "${SLURM_CPUS_PER_TASK}" \
  --outdir fastq \
  --temp tmp

gzip -f fastq/*.fastq
