library(readr)
library(dplyr)
library(glue)

crosscheck_bucket_file <- commandArgs(trailingOnly=TRUE)

command_constructor_df <- read_tsv(crosscheck_bucket_file, col_names=TRUE) %>%
        mutate(
                O=glue("[PROJECT_DIR]/GTEx/crosscheck_outputs/individual_outputs/{SAMP1}#{SAMP2}")
        )


crosscheck_output_df <- data.frame()
for (output_file in command_constructor_df$O) {
        if (file.exists(output_file)) {
                curr_crosscheck_output <- read_tsv(output_file, comment="#", show_col_types=FALSE)
                crosscheck_output_df <- rbind(crosscheck_output_df, curr_crosscheck_output)
        }
}
bucket_name <- tools::file_path_sans_ext(basename(crosscheck_bucket_file))
write_tsv(crosscheck_output_df, glue("[PROJECT_DIR]/GTEx/crosscheck_outputs/merged_bucket_outputs/merged_{bucket_name}.tsv"))

