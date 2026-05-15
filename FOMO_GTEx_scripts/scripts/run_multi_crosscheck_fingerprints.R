library(readr)
library(dplyr)
library(glue)

crosscheck_bucket_file <- commandArgs(trailingOnly=TRUE)

command_constructor_df <- read_tsv(crosscheck_bucket_file, col_names=TRUE) %>%
	mutate(
		H=shQuote("[PROJECT_DIR]/CrossCheck/fingerprint_maps/map_files/hg38_80_15_chr.map"),
		O=shQuote(glue("[PROJECT_DIR]/GTEx/crosscheck_outputs/{SAMP1}#{SAMP2}")),
		crosscheck_command=glue("java -jar $PICARD CrosscheckFingerprints I={shQuote(I1)} SI={shQuote(I2)} H={H} O={O} CROSSCHECK_MODE=CHECK_ALL_OTHERS CROSSCHECK_BY=SAMPLE")
	)


start_time <- Sys.time()
for (curr_command in command_constructor_df$crosscheck_command) {
	try(system(curr_command))
}
end_time <- Sys.time()
print(start_time - end_time)

crosscheck_output_df <- data.frame()
for (output_file in command_constructor_df$O) {
	if (file.exists(output_file)) {
		curr_crosscheck_output <- read_tsv(output_file, comment="#")
		crosscheck_output_df <- rbind(crosscheck_output_df, curr_crosscheck_output)
	}
}
bucket_name <- tools::file_path_sans_ext(basename(crosscheck_bucket_file))
write_tsv(crosscheck_output_df, glue("[PROJECT_DIR]/GTEx/crosscheck_outputs/merged_outputs/merged_{bucket_name}.tsv"))

