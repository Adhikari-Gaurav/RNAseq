#!/bin/bash
#SBATCH --job-name=hisat2_align
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=hisat2_align_%j.out
#SBATCH --error=hisat2_align_%j.err

set -euo pipefail

# BASE_DIR override: BASE_DIR=/path/to/your/project SAMPLE=SRR12345 sbatch 05_hisat2_align.sh
BASE_DIR="${BASE_DIR:-$(pwd)}"
SAMPLE="${SAMPLE:-SRR37923508}"

cd "${BASE_DIR}"

mkdir -p "${BASE_DIR}/hisat2_align/bam"

module purge
module load hisat2
module load samtools/1.23

echo "Step 1: Define trimmed RNA-seq read inputs"

R1="${BASE_DIR}/fastp_trim/${SAMPLE}_1.trim.fastq.gz"
R2="${BASE_DIR}/fastp_trim/${SAMPLE}_2.trim.fastq.gz"

ls -lh "${R1}"
ls -lh "${R2}"

echo "Step 2: Define HISAT2 index"

IDX="${BASE_DIR}/hisat2_index/palm_foa_hisat2_default"

echo "Using HISAT2 index prefix:"
echo "${IDX}"

echo "Index files found:"
ls -lh "${IDX}".*.ht2* || ls -lh "${IDX}".*.ht2l

echo "Step 3: Define alignment outputs"

BAM="${BASE_DIR}/hisat2_align/bam/${SAMPLE}_palm_foa.default.sorted.bam"

HISAT_LOG="${BASE_DIR}/hisat2_align/${SAMPLE}_palm_foa.default.hisat2.log"

echo "Sorted BAM output:"
echo "${BAM}"

echo "BAM index output will be:"
echo "${BAM}.bai"

echo "HISAT2 alignment log:"
echo "${HISAT_LOG}"

echo "Step 4: Align trimmed paired reads and sort into BAM"

echo "Using --no-discordant:"
echo "  Do not report abnormal paired alignments."

echo "Using --no-unal:"
echo "  Do not write unmapped reads into the BAM."

echo "Not using --no-mixed:"
echo "  Keep possible single-mate alignment evidence when a pair cannot align together."

hisat2 \
  -p "${SLURM_CPUS_PER_TASK}" \
  --no-discordant \
  --no-unal \
  -x "${IDX}" \
  -1 "${R1}" \
  -2 "${R2}" \
  2> "${HISAT_LOG}" \
  | samtools sort \
      -@ "${SLURM_CPUS_PER_TASK}" \
      -o "${BAM}" \
      -

echo "Step 5: Index the sorted BAM"

samtools index "${BAM}"

echo "Step 6: Confirm BAM and BAM index exist"

ls -lh "${BAM}"
ls -lh "${BAM}.bai"

echo "Finished: HISAT2 alignment, sorted BAM, and BAM index."
