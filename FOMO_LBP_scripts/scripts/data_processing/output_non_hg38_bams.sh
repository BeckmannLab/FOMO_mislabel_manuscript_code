#!/bin/bash
set -euo pipefail

bam_files="[PROJECT_DIR]/LBP/all_files/all_bam_files.txt"
non_hg38_list="[PROJECT_DIR]/LBP/all_files/non_hg38_bam_files.txt"

while IFS= read -r bam_file; do
	echo "${bam_file}"
	if [ -f "$bam_file" ]; then
		if ! samtools view -H "${bam_file}" | grep -q "248956422"; then
			echo "${bam_file}" >> "${non_hg38_list}"
		fi
	fi
done < "${bam_files}"
