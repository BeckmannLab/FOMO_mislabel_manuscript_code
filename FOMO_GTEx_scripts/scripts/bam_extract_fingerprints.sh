#!/bin/bash
# exit 1
set -euo pipefail

project_dir="[PROJECT_DIR]/GTEx"
temp_dir="${TEMPDIR}/${USER}"
export TMP_DIR="${temp_dir}"

sample_id="$1"

cd "${temp_dir}"

input_bam_file="${temp_dir}/${sample_id}.bam"
temp_bam_file="${temp_dir}/${sample_id}.temp.bam"
map_file="${project_dir}/static_input_files/hg38_80_15_chr.map"
reference_dict="${project_dir}/static_input_files/GRCh38.primary_assembly.genome_filtered_formatted.dict"
reference_file="${project_dir}/static_input_files/GRCh38.primary_assembly.genome_filtered.fa"
output_file="${project_dir}/fingerprint_vcfs/${sample_id}.fingerprint.vcf"

if [ -e "${input_bam_file}" ]; then
	echo "1. BAM file for sample ${sample_id} already downloaded"
else 
	echo "1. Downloading BAM file and index for sample ${sample_id}"
	${project_dir}/gen3-client download-multiple --profile=BECKMANNN --manifest="${project_dir}/bam_file_manifests/${sample_id}.json" --download-path="${temp_dir}" --protocol=s3 --no-prompt=true 
fi
echo "2. Running ReorderSam to filter unwanted chromosomes in BAM file for sample ${sample_id}"
java -jar $PICARD ReorderSam I="${input_bam_file}" O="${temp_bam_file}" SD="${reference_dict}" S=true TMP_DIR="${TMP_DIR}" MAX_RECORDS_IN_RAM=200000
rm "${input_bam_file}"
rm "${input_bam_file}.bai"
mv "${temp_bam_file}" "${input_bam_file}"
echo "3. Sorting filtered BAM file for sample ${sample_id}"
samtools sort ${input_bam_file} -o "${temp_bam_file}"
rm "${input_bam_file}"
mv "${temp_bam_file}" "${input_bam_file}"
echo "4. Reindexing filtered and sorted BAM file for sample ${sample_id}"
samtools index ${input_bam_file} 
echo "6. Finally, extracting fingerprint for ${sample_id}"
java -jar $PICARD ExtractFingerprint I="${input_bam_file}" R="${reference_file}" H="${map_file}" O="${output_file}"
echo "6. Done extracting fingerprint for ${sample_id}. Deleting bam, bam index, and header files from scratch directory"
rm "${input_bam_file}"
rm "${input_bam_file}.bai"
