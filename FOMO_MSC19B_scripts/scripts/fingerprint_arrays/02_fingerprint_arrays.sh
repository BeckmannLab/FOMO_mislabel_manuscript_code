#!/bin/bash
set -euo pipefail

CUSTOM_PICARD="[PROJECT_DIR]/MSCBB/all_files/picard.jar"
fingerprint_dir="[PROJECT_DIR]/MSCBB/fingerprinted_arrays"
map_file="[PROJECT_DIR]/GTEx/static_input_files/hg38_80_15_chr.map"
reference_file="[PROJECT_DIR]/GTEx/static_input_files/GRCh38.primary_assembly.genome_filtered.fa"
array_file='[PROJECT_DIR]/MSCBB/all_files/mscic_freeze1_all_merged.hg38.reheaded.vcf.gz'
input_index_file='[PROJECT_DIR]/MSCBB/all_files/mscic_freeze1_all_merged.hg38.reheaded.vcf.gz.tbi'

java -jar ${CUSTOM_PICARD} ExtractFingerprintVcf I="${array_file}" INPUT_INDEX_PATH=${input_index_file} R="${reference_file}" H="${map_file}" O="${fingerprint_dir}" CREATE_INDEX=true

