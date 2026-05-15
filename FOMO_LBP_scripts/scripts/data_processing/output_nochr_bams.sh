#!/bin/bash
set -euo pipefail

bam_files="[PROJECT_DIR]/LBP/all_files/all_bam_files.txt"
nochr_list="[PROJECT_DIR]/LBP/all_files/nochr_bam_files.txt"

while IFS= read -r bam_file; do
        echo "${bam_file}"
        if [ -f "$bam_file" ]; then
                if ! samtools view -H "${bam_file}" | grep -qE '^@SQ\sSN:chr1\s'; then
                        echo "${bam_file}" >> "${nochr_list}"
                fi
        fi
done < "${bam_files}"
