#!/bin/bash
set -euo pipefail

array_file="[PROJECT_DIR]/MSCBB/all_files/mscic_freeze1_all_merged.hg38.reheaded.vcf.gz"
output_file="[PROJECT_DIR]/MSCBB/all_files/raw_genotype_array_samples.txt"
bcftools query -l "${array_file}" > "${output_file}"

