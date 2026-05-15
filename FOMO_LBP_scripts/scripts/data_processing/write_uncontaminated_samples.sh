#!/bin/bash
set -euo pipefail

bcftools query -l "[PROJECT_DIR]/LBP/lbp_wgs_qc2callset.vcf.gz" >> "[PROJECT_DIR]/LBP/all_files/all_uncontaminated_subjects.txt"
