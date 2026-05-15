library(jsonlite)
library(dplyr)
library(stringr)
library(glue)

output_dir <- "[PROJECT_DIR]/GTEx/bam_file_manifests"
manifest_json_filename <- "[PROJECT_DIR]/GTEx/raw_manifests/file-manifest_bam.json"
manifest_df <- fromJSON(manifest_json_filename) %>%
	mutate(
		sample_name = sub("\\.bam.*", "", file_name)
	) %>%
	arrange(sample_name)
sample_names <- unique(manifest_df$sample_name)

for (sample_name_i in sample_names) {
	sample_manifest_df <- manifest_df[manifest_df$sample_name == sample_name_i, ]
	sample_manifest_json <- toJSON(sample_manifest_df, pretty=TRUE)
	sample_manifest_filepath <- file.path(output_dir, glue("{sample_name_i}.json"))
	writeLines(sample_manifest_json, sample_manifest_filepath)
}
