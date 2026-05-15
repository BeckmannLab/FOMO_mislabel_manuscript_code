#!/bin/bash
set -euo pipefail

fingerprint_dir="[PROJECT_DIR]/GTEx/copied_fingerprint_vcfs"
merge_dir="[PROJECT_DIR]/GTEx/merged_bam_vcf_output"
split_files_dir="${merge_dir}/split_filelists"

find "${fingerprint_dir}" -name "*.vcf.gz" | split -n 20 > "${split_files_dir}"

for f in "${split_files_dir}"/*; do 
	O="${merge_dir}/$(basename "${f}")_merged.vcf.gz"
	echo "${O}"
	bcftools merge --file-list "${f}" | bgzip > "${O}" && tabix "${O}"
done

O="${merge_dir}/all_merged.vcf.gz"
find "${merge_dir}" -name "*.vcf.gz" > "${merge_dir}/final_mergelist"
bcftools merge --file-list "${merge_dir}/final_mergelist"| bgzip > "${O}" && tabix "${O}"

zcat "${merge_dir}/all_merged.vcf.gz" | bcftools query -l - | wc -l
