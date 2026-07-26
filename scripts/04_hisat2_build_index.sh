#!/bin/bash
#SBATCH --job-name=hisat2_build_index
#SBATCH --partition=tsl-medium
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=08:00:00
#SBATCH --output=hisat2_index_%j.out
#SBATCH --error=hisat2_index_%j.err

# ============================================================
# CONFIGURATION — edit these before submitting
# ============================================================

# BASE_DIR override: BASE_DIR=/path/to/your/project sbatch 04_hisat2_build_index.sh
BASE_DIR="${BASE_DIR:-$(pwd)}"

# Input — combined genome only, no GTFs needed
COMBINED_GENOME="${BASE_DIR}/refs/combined/palm_foa_combined.fna"

# Output directory
OUTDIR="${BASE_DIR}/hisat2_index"

# Index base name
INDEX_NAME="${OUTDIR}/palm_foa_hisat2_default"

# Threads
THREADS=${SLURM_CPUS_PER_TASK}

# ============================================================
# MODULES
# ============================================================

module load hisat2/2.2.2

# ============================================================
# SETUP
# ============================================================

mkdir -p "${OUTDIR}"

echo "Job started: $(date)"
echo "Output directory: ${OUTDIR}"
echo "Index name: ${INDEX_NAME}"

# ============================================================
# BUILD DEFAULT HISAT2 INDEX
# ============================================================

echo "Building default HISAT2 index — no splice sites, no exons..."

hisat2-build \
  -p ${THREADS} \
  "${COMBINED_GENOME}" \
  "${INDEX_NAME}"

# ============================================================
# VERIFY
# ============================================================

echo "=== INDEX FILES PRODUCED ==="
ls -lh "${OUTDIR}"/*.ht2

echo "Job finished: $(date)"
