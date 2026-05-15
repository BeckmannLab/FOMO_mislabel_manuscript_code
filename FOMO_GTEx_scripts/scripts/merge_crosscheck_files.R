library(readr)

crosscheck_dir <- "[PROJECT_DIR]/GTEx/crosscheck_outputs/merged_bucket_outputs"
all_files <- list.files(crosscheck_dir, full.names=TRUE)

merged_output <- data.frame()
i <- 1
for (filepath in all_files) {
    i <- i + 1
    if (i %% 100 == 0) {
        print(i)
    }
    new_output <- read_tsv(filepath, comment="#", show_col_types = FALSE)
    merged_output <- rbind(merged_output, new_output)
}
write_tsv(merged_output, "[PROJECT_DIR]/GTEx/crosscheck_outputs/all_merged_crosscheck.tsv")

