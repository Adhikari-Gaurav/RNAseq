# RNAseq

Scripts for a dual-genome RNA-seq alignment pipeline: raw reads from a host organism infected with a Fusarium pathogen are mapped against a single combined reference built from both genomes, so that reads can be sorted out by origin (host or pathogen) after alignment. This is the same general approach used for other host-pathogen or mixed-sample RNA-seq setups, applied here to date palm (Phoenix dactylifera) and Fusarium oxysporum f. sp. albedinis, the causal agent of Bayoud disease.

## Overview

The pipeline takes raw paired-end RNA-seq reads from the NCBI Sequence Read Archive (SRA) through to a sorted, indexed BAM alignment. Reads are first extracted from the SRA download and quality-trimmed, while separately the two reference genomes (host and pathogen) are prefixed and combined into one FASTA file so that a single HISAT2 index can be built and used for alignment. Every script in this repository was run on an HPC cluster through SLURM (`sbatch`); the `#SBATCH` directives at the top of each script (partition name, memory, time limit) reflect the cluster this was originally run on and should be adjusted to match your own cluster's configuration and queue names.

Each script also takes a `BASE_DIR` environment variable (and, where relevant, a `SAMPLE` variable) instead of hardcoding an absolute path, so the same scripts can be pointed at a different project directory without editing the file. Runs in this repository were tested with sra-tools 2.8.2, fastp 0.23.1, hisat2 2.2.2, and samtools 1.23, loaded as environment modules on the cluster; if your HPC uses a different module system or package manager, install matching versions of these four tools before running the scripts.

## Pipeline steps

1. [Extract FASTQ reads from SRA](#1-extract-fastq-reads-from-sra)
2. [Trim and quality-filter reads with fastp](#2-trim-and-quality-filter-reads-with-fastp)
3. [Prepare the combined reference genome](#3-prepare-the-combined-reference-genome)
4. [Build the HISAT2 index](#4-build-the-hisat2-index)
5. [Align reads with HISAT2](#5-align-reads-with-hisat2)

## 1. Extract FASTQ reads from SRA

Script: [`scripts/01_extract_fastq.sh`](scripts/01_extract_fastq.sh)

This step assumes an SRA run has already been downloaded onto the cluster (for example with `prefetch`) and starts from that local SRA file, converting it into the paired FASTQ files that every downstream step in this pipeline works from. The script first runs `vdb-validate` on the SRA file as a sanity check, confirming the download isn't corrupted before spending compute time on it. It then runs `fasterq-dump` with `--split-files`, which splits paired-end reads into separate R1 and R2 FASTQ files rather than leaving mates interleaved in a single file, since the downstream trimming and alignment steps both expect separate R1/R2 inputs. The resulting FASTQ files are gzip-compressed at the end to save disk space, since raw FASTQ output from `fasterq-dump` is uncompressed.

The `SAMPLE` variable at the top of the script (defaulting to the SRA accession used for this project, `SRR37923508`) controls which SRA file is processed and is used to build every input and output filename in the script, so a different accession can be run with `SAMPLE=SRR12345678 sbatch 01_extract_fastq.sh`.

## 2. Trim and quality-filter reads with fastp

Script: [`scripts/02_fastp.sh`](scripts/02_fastp.sh)

Raw sequencing reads always carry some amount of adapter contamination and lower-quality bases, usually concentrated toward the ends of reads, and aligning uncleaned reads directly against a reference tends to produce lower mapping rates and noisier alignments. This step runs fastp on the paired FASTQ files from step 1 to remove that noise before alignment. Specifically, the script uses `--detect_adapter_for_pe` to automatically detect and trim adapter sequence from paired-end reads without needing the adapter sequence supplied manually, `--trim_poly_g` and `--trim_poly_x` to remove poly-G and poly-X runs (poly-G tails in particular are a known artifact of Illumina two-channel chemistry rather than real biological sequence), and a sliding-window quality trim (`--cut_right` with a 4 bp window and mean-quality cutoff of Q20) that trims from the 3' end once average quality within the window drops below the threshold. Reads are additionally required to have an overall average quality of at least Q20 and a minimum post-trimming length of 50 bp, and `--correction` allows fastp to correct low-quality bases in overlapping regions of read pairs using the higher-quality base from the mate. fastp writes out an HTML/JSON quality report alongside the trimmed FASTQ files, which is worth checking after this step runs to confirm trimming behaved as expected before moving on to alignment.

## 3. Prepare the combined reference genome

Script: [`scripts/03_prepare_combined_reference.sh`](scripts/03_prepare_combined_reference.sh)

Because this project needs to distinguish host transcripts from pathogen transcripts after alignment, reads aren't mapped against either genome alone. Instead, both reference genomes are combined into a single FASTA file and reads are aligned against that combined reference in one pass; any read that came from the host will map to a host chromosome, and any read from the pathogen will map to a pathogen chromosome. The catch is that both genome assemblies use their own independent chromosome and scaffold naming, and it's entirely possible for a host contig and a pathogen contig to happen to share the same name, which would corrupt the combined reference and make it impossible to tell afterward which genome an alignment came from. This script avoids that by prefixing every chromosome name in both the FOA (pathogen) genome and the Palm (host) genome — `FOA_` and `PALM_` respectively — before concatenating the two FASTA files together, so origin is unambiguous from the sequence name alone even after combination. The same prefixing is applied to the two GTF annotation files for consistency, although only the combined FASTA file is used by the indexing step that follows; the prefixed GTFs are kept for any downstream annotation-aware analysis.

The genome and annotation files used here are the FOA genome assembly ([NCBI GCA_032206225.1](https://www.ncbi.nlm.nih.gov/datasets/genome/GCA_032206225.1/), *Fusarium oxysporum* f. sp. *albedinis*, assembly FOAM13_A1) and the date palm genome assembly ([NCBI GCF_009389715.1](https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_009389715.1/), *Phoenix dactylifera*). The script expects both the genomic FASTA and the GTF annotation for each to already be downloaded locally (see [step 1 of the effector dataset repository](https://github.com/Adhikari-Gaurav/Fusarium-Putative-Secreted-Protein-Dataset#1-data-acquisition) for one way to fetch NCBI genome assemblies with their annotations using the NCBI Datasets CLI).

## 4. Build the HISAT2 index

Script: [`scripts/04_hisat2_build_index.sh`](scripts/04_hisat2_build_index.sh)

With the combined host-pathogen FASTA in hand, this step builds a HISAT2 index from it using `hisat2-build`. This is a plain, sequence-only index built directly from the combined genome, without incorporating known splice sites or exon boundaries from the GTF annotations (HISAT2 supports building a splice-aware index using `hisat2_extract_splice_sites.py` and `hisat2_extract_exons.py` against a GTF, which can improve spliced-alignment accuracy, but that variant isn't used in this pipeline). Since indexing only needs the genome sequence, the GTF files prepared in step 3 aren't used here at all, only the combined FASTA. The output is a set of `.ht2` index files sharing a common prefix, which is what the alignment step in step 5 points HISAT2 at.

## 5. Align reads with HISAT2

Script: [`scripts/05_hisat2_align.sh`](scripts/05_hisat2_align.sh)

The final step aligns the trimmed paired-end reads from step 2 against the combined HISAT2 index from step 4, producing a coordinate-sorted, indexed BAM file. Two alignment flags are worth calling out specifically: `--no-discordant` suppresses discordant alignments (cases where both mates align but not in the expected orientation or distance apart, which are usually not informative for straightforward expression-level analysis), and `--no-unal` excludes unmapped reads from the output BAM entirely, keeping the file smaller and focused on reads that actually aligned somewhere in the combined genome. `--no-mixed` is deliberately not used, which means HISAT2 is still allowed to report a single-mate alignment for a pair when only one mate can be placed; that's kept on here so partial evidence isn't discarded outright. HISAT2's output is piped directly into `samtools sort` rather than being written to disk as an unsorted SAM/BAM first, and the resulting sorted BAM is indexed with `samtools index`, leaving a `.bam` and `.bam.bai` pair ready for downstream read counting or visualization.

## References

References are numbered in the order they are first cited above, in Vancouver style.

1. Leinonen R, Sugawara H, Shumway M; International Nucleotide Sequence Database Collaboration. The Sequence Read Archive. Nucleic Acids Res. 2011;39(Database issue):D19-D21. DOI: 10.1093/nar/gkq1019.
2. Chen S, Zhou Y, Chen Y, Gu J. fastp: an ultra-fast all-in-one FASTQ preprocessor. Bioinformatics. 2018;34(17):i884-i890. DOI: 10.1093/bioinformatics/bty560.
3. National Center for Biotechnology Information (NCBI). Fusarium oxysporum f. sp. albedinis genome assembly FOAM13_A1 [Internet]. Bethesda (MD): National Library of Medicine (US); [cited 2026 Jul 26]. Available from: https://www.ncbi.nlm.nih.gov/datasets/genome/GCA_032206225.1/.
4. National Center for Biotechnology Information (NCBI). Phoenix dactylifera genome assembly palm_55x_up_171113_PBpolish2nd_filt_p [Internet]. Bethesda (MD): National Library of Medicine (US); [cited 2026 Jul 26]. Available from: https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_009389715.1/.
5. Kim D, Paggi JM, Park C, Bennett C, Salzberg SL. Graph-based genome alignment and genotyping with HISAT2 and HISAT-genotype. Nat Biotechnol. 2019;37(8):907-915. DOI: 10.1038/s41587-019-0201-4.
6. Danecek P, Bonfield JK, Liddle J, Marshall J, Ohan V, Pollard MO, Whitwham A, Keane T, McCarthy SA, Davies RM, Li H. Twelve years of SAMtools and BCFtools. Gigascience. 2021;10(2):giab008. DOI: 10.1093/gigascience/giab008.

## License

See [LICENSE](LICENSE) for details (MIT).
