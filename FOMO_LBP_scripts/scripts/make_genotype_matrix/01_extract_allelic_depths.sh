#!/bin/bash
#exit 1
set -euo pipefail

fingerprint_dir="[PROJECT_DIR]/LBP/fingerprint_vcfs"
AD_dir="[PROJECT_DIR]/LBP/allelic_depths"

for fingerprint_vcf in "${fingerprint_dir}"/*.vcf; do
  filename=$(basename "${fingerprint_vcf}")
  filename_no_ext="${filename%.vcf}"
  AD_tsv="${AD_dir}/${filename_no_ext}.AD.tsv"
  bcftools query -f '%CHROM\t%POS\t%REF\t%ALT\t[%AD]\n' "${fingerprint_vcf}" > "${AD_tsv}"
done
