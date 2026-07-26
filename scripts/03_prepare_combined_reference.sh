#!/bin/bash
#SBATCH --job-name=prep_combined_reference
#SBATCH --partition=tsl-medium
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --output=prep_refs_%j.out
#SBATCH --error=prep_refs_%j.err

# ============================================================
# CONFIGURATION — edit these before submitting
# ============================================================

# BASE_DIR override: BASE_DIR=/path/to/your/project sbatch 03_prepare_combined_reference.sh
BASE_DIR="${BASE_DIR:-$(pwd)}"

# Input — FOA (Fusarium oxysporum f. sp. albedinis, GCA_032206225.1)
FOA_GENOME="${BASE_DIR}/refs/GCA_032206225.1/GCA_032206225.1_FOAM13_A1_genomic.fna"
FOA_GTF="${BASE_DIR}/refs/GCA_032206225.1/genomic.gtf"

# Input — Palm (date palm, GCF_009389715.1)
PALM_GENOME="${BASE_DIR}/refs/GCF_009389715.1/GCF_009389715.1_palm_55x_up_171113_PBpolish2nd_filt_p_genomic.fna"
PALM_GTF="${BASE_DIR}/refs/GCF_009389715.1/genomic.gtf"

# Output directory
OUTDIR="${BASE_DIR}/refs/combined"

# ============================================================
# SETUP
# ============================================================

mkdir -p "${OUTDIR}"

# Output file names
FOA_GENOME_OUT="${OUTDIR}/FOA_prefixed.fna"
FOA_GTF_OUT="${OUTDIR}/FOA_prefixed.gtf"
PALM_GENOME_OUT="${OUTDIR}/PALM_prefixed.fna"
PALM_GTF_OUT="${OUTDIR}/PALM_prefixed.gtf"
COMBINED_OUT="${OUTDIR}/palm_foa_combined.fna"

echo "Job started: $(date)"
echo "Output directory: ${OUTDIR}"

# ============================================================
# STEP 1 — Prefix FOA genome chromosome names
# ============================================================

echo "Adding FOA_ prefix to FOA genome..."
sed "s/^>/>FOA_/" "${FOA_GENOME}" > "${FOA_GENOME_OUT}"

echo "Done. Verifying FOA genome:"
grep ">" "${FOA_GENOME_OUT}" | head -3

# ============================================================
# STEP 2 — Prefix FOA GTF chromosome names
# ============================================================

echo "Adding FOA_ prefix to FOA GTF..."
sed '/^#/! s/^/FOA_/' "${FOA_GTF}" > "${FOA_GTF_OUT}"

echo "Done. Verifying FOA GTF:"
awk '$1 !~ /^#/' "${FOA_GTF_OUT}" | cut -f1 | sort -u | head -3

# ============================================================
# STEP 3 — Prefix Palm genome chromosome names
# ============================================================

echo "Adding PALM_ prefix to Palm genome..."
sed "s/^>/>PALM_/" "${PALM_GENOME}" > "${PALM_GENOME_OUT}"

echo "Done. Verifying Palm genome:"
grep ">" "${PALM_GENOME_OUT}" | head -3

# ============================================================
# STEP 4 — Prefix Palm GTF chromosome names
# ============================================================

echo "Adding PALM_ prefix to Palm GTF..."
sed '/^#/! s/^/PALM_/' "${PALM_GTF}" > "${PALM_GTF_OUT}"

echo "Done. Verifying Palm GTF:"
awk '$1 !~ /^#/' "${PALM_GTF_OUT}" | cut -f1 | sort -u | head -3

# ============================================================
# STEP 5 — Combine prefixed genomes
# ============================================================

echo "Combining FOA and Palm genomes..."
cat "${FOA_GENOME_OUT}" "${PALM_GENOME_OUT}" > "${COMBINED_OUT}"

echo "Done. Verifying combined genome:"
grep ">" "${COMBINED_OUT}" | grep "FOA_" | head -3
grep ">" "${COMBINED_OUT}" | grep "PALM_" | head -3

# ============================================================
# FINAL VERIFICATION
# ============================================================

echo ""
echo "=== FINAL VERIFICATION ==="

echo "FOA genome chromosomes:"
grep -c ">" "${FOA_GENOME_OUT}"

echo "Palm genome chromosomes:"
grep -c ">" "${PALM_GENOME_OUT}"

echo "Combined genome chromosomes total:"
grep -c ">" "${COMBINED_OUT}"

echo "FOA GTF unique chromosomes:"
awk '$1 !~ /^#/' "${FOA_GTF_OUT}" | cut -f1 | sort -u | wc -l

echo "Palm GTF unique chromosomes:"
awk '$1 !~ /^#/' "${PALM_GTF_OUT}" | cut -f1 | sort -u | wc -l

echo ""
echo "Job finished: $(date)"
echo "All prefixed files saved in: ${OUTDIR}"
