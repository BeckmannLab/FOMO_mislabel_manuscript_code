library(glue)
groups_dir <- "[PROJECT_DIR]/GTEx/bam_file_groups"
group_id <- commandArgs(trailingOnly = TRUE)[1]
group_id_file <- glue("{group_id}.txt")
samples <- readLines(file.path(groups_dir, group_id_file))
for (sample in samples) {
	bam_extract_fingerprints_command <- glue("[PROJECT_DIR]/GTEx/scripts/bam_extract_fingerprints_no_delete.sh {sample}")
	system(bam_extract_fingerprints_command)
}

