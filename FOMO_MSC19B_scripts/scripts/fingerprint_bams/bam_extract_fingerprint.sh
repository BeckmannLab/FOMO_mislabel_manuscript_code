#!/bin/bash
#exit 1
set -euo pipefail

index_id="${1}"
input_bam_file="${2}"

project_dir="[PROJECT_DIR]/MSCBB"

map_file="[PROJECT_DIR]/GTEx/static_input_files/hg38_80_15_chr.map"
reference_dict="[PROJECT_DIR]/GTEx/static_input_files/GRCh38.primary_assembly.genome_filtered_formatted.dict"
reference_file="[PROJECT_DIR]/GTEx/static_input_files/GRCh38.primary_assembly.genome_filtered.fa"
scratch_dir="${TEMPDIR}/${USER}"

copied_bam_file="${scratch_dir}/copied_bams/${index_id}.copied.bam"

if ! samtools view -H "${input_bam_file}" | grep -qE '^@SQ\sSN:chr1\s'; then
        if ! samtools view -H "${input_bam_file}" | grep -qE '^@SQ\sSN:1\s'; then
                echo "Human chromosomes not detected for ${index_id}. Aborting."
                exit 1
        fi
    echo "0. For ${index_id}, detected nochr chromosomes in header. Running ReplaceSamHeader and storing output to ${copied_bam_file}"
        copied_bam_file_init="${scratch_dir}/copied_bams/${index_id}.copied.init.bam"
        cp "${input_bam_file}" "${copied_bam_file_init}"
        new_header_file="${scratch_dir}/new_headers/${index_id}.header.sam"
        samtools view -H "${copied_bam_file_init}" | sed -e '/^@SQ/s/SN\:/SN\:chr/' -e '/^[^@]/s/\t/\tchr/2' > "${new_header_file}"
        java -jar $PICARD ReplaceSamHeader I="${copied_bam_file_init}" HEADER="${new_header_file}" O="${copied_bam_file}"
        rm "${copied_bam_file_init}"

else
        echo "0. For ${index_id}, chromosomes already in desired chr format. Creating symbolic link ${copied_bam_file}"
        ln -sf "${input_bam_file}" "${copied_bam_file}"
fi

if ! samtools view -H "${copied_bam_file}" | grep -q '^@RG'; then
        # Add dummy readgroups
        echo "0b. For ${index_id}, detected no read groups. Adding dummy readgroups"
        cp "${copied_bam_file}" "${copied_bam_file_init}"
        java -jar $PICARD AddOrReplaceReadGroups I="${copied_bam_file_init}" O="${copied_bam_file}" RGID=1 RGLB=lib1 RGPL=illumina RGPU=unit1 RGSM=sample1
        rm ${copied_bam_file_init}
fi

echo "1. For ${index_id}, running ReorderSam to filter unwanted chromosomes in BAM file ${copied_bam_file}"
filtered_bam_file="${scratch_dir}/filtered_bams/${index_id}.filtered.bam"
java -Xmx8g -jar $PICARD ReorderSam I="${copied_bam_file}" O="${filtered_bam_file}" SD="${reference_dict}" S=true TMP_DIR="${scratch_dir}/temp_dir" TMP_DIR="${project_dir}/temp_dir" MAX_RECORDS_IN_RAM=2000000
samtools index "${filtered_bam_file}"

echo "1b. For ${index_id}, removing temp file ${copied_bam_file}"
rm "${copied_bam_file}"

echo "2. For ${index_id}, S=sorting filtered BAM file ${filtered_bam_file}"
sorted_bam_file="${scratch_dir}/sorted_bams/${index_id}.filtered.sorted.bam"
samtools sort "${filtered_bam_file}" -o "${sorted_bam_file}" --threads 8 --write-index

echo "2b. For ${index_id}, removing temp file ${filtered_bam_file}"
rm "${filtered_bam_file}"

echo "3. For ${index_id}, extracting fingerprint from ${sorted_bam_file}"
fingerprint_vcf_file="${project_dir}/fingerprinted_bams/${index_id}.fingerprint.vcf"
java -jar $PICARD ExtractFingerprint I="${sorted_bam_file}" R="${reference_file}" H="${map_file}" O="${fingerprint_vcf_file}" CREATE_INDEX=true

echo "3b. For ${index_id}, removing temp file ${sorted_bam_file}"
rm "${sorted_bam_file}"

echo "Done fingerprinting for ${index_id}"
