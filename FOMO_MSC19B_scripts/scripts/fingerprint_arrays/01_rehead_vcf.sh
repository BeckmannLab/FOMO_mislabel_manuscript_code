#!/bin/bash
set -euo pipefail

array_file='[PROJECT_DIR]/MSCBB/all_files/mscic_freeze1_all_merged.hg38.vcf.gz'
new_array_file='[PROJECT_DIR]/MSCBB/all_files/mscic_freeze1_all_merged.hg38.reheaded.vcf'
file_with_working_header='[PROJECT_DIR]/ExtractFingerprintVcf/Subset3_Fixed_no_chrYM_reheaded_Samples.cohort.vcf.gz'

zcat $array_file | head -n3 > $new_array_file
zcat $file_with_working_header | head -n500 | grep contig >> $new_array_file
zcat $array_file | tail -n+$((1+$(zcat $array_file | head -n100 | grep -n contig | gawk '{print $1}' FS=":" | tail -n1))) | perl -lape 's/^23\b/X/g; $_="chr$_" if not m/^#/' >> $new_array_file
bgzip $new_array_file
tabix "${new_array_file}.gz"
