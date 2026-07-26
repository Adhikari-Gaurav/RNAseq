#!/bin/bash
#SBATCH --job-name=RNAseq_fastp_trim
#SBATCH --partition=tsl-medium
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=02-00:00
#SBATCH --output=fastp_%j.out
#SBATCH --error=fastp_%j.err

# ============================================================
# CONFIGURATION — edit these before submitting
# ============================================================

# BASE_DIR override: BASE_DIR=/path/to/your/project SAMPLE=SRR12345 sbatch 02_fastp.sh
BASE_DIR="${BASE_DIR:-$(pwd)}"

# Sample name — used for all output file naming
SAMPLE="${SAMPLE:-SRR37923508}"

# Input FASTQ files
R1="${BASE_DIR}/fastq/${SAMPLE}_1.fastq.gz"
R2="${BASE_DIR}/fastq/${SAMPLE}_2.fastq.gz"

# Output directory
OUTDIR="${BASE_DIR}/fastp_trim"
mkdir -p "${OUTDIR}"

# Trimming parameters
MIN_LENGTH=50
QUALITY_WINDOW=20
WINDOW_SIZE=4
AVG_QUAL=20
THREADS=${SLURM_CPUS_PER_TASK}

# ============================================================
# MODULES — check with: module avail fastp
# ============================================================

module load fastp/0.23.1

# ============================================================
# SETUP — do not edit below unless you know what you are doing
# ============================================================

# Derived output file names built from SAMPLE variable above
R1_TRIM="${OUTDIR}/${SAMPLE}_1.trim.fastq.gz"
R2_TRIM="${OUTDIR}/${SAMPLE}_2.trim.fastq.gz"
HTML="${OUTDIR}/${SAMPLE}.fastp.html"
JSON="${OUTDIR}/${SAMPLE}.fastp.json"
LOG="${OUTDIR}/${SAMPLE}.fastp.log"

# ============================================================
# RUN FASTP
# ============================================================

echo "Starting fastp for sample: ${SAMPLE}"
echo "Input R1: ${R1}"
echo "Input R2: ${R2}"
echo "Output directory: ${OUTDIR}"
echo "Job started: $(date)"

fastp \
  -i ${R1} \
  -I ${R2} \
  -o ${R1_TRIM} \
  -O ${R2_TRIM} \
  -h ${HTML} \
  -j ${JSON} \
  -R "${SAMPLE} fastp report" \
  --detect_adapter_for_pe \
  --trim_poly_g \
  --trim_poly_x \
  --cut_right \
  --cut_right_window_size ${WINDOW_SIZE} \
  --cut_right_mean_quality ${QUALITY_WINDOW} \
  --average_qual ${AVG_QUAL} \
  --correction \
  --length_required ${MIN_LENGTH} \
  --thread ${THREADS} \
  2> ${LOG}

echo "fastp finished: $(date)"
echo "Check HTML report: ${HTML}"
echo "Check log: ${LOG}"
