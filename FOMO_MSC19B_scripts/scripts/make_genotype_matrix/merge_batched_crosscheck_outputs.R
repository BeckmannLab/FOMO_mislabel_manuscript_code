library(glue)
library(data.table)
library(tools)

batch_file <- commandArgs(trailingOnly=TRUE)[1]
merged_crosscheck_dir <- "[PROJECT_DIR]/MSCBB/temp_dir/merged_crosscheck_batches"

cols_to_keep <- c("LEFT_GROUP_VALUE", "RIGHT_GROUP_VALUE", "sampleA", "sampleB", "RESULT", "LOD_SCORE")

crosscheck_output_files <- readLines(batch_file)
crosscheck_output_list <- list(length=length(crosscheck_output_files))

for (i in seq_along(crosscheck_output_files)) {
    output_file <- crosscheck_output_files[i]
    crosscheck_output_row <- fread(output_file)
    samples_compared <- strsplit(file_path_sans_ext(basename(output_file)), "#")[[1]]
    crosscheck_output_row$sampleA <- samples_compared[1]
    crosscheck_output_row$sampleB <- samples_compared[2]
    crosscheck_output_list[[i]] <- crosscheck_output_row[, ..cols_to_keep]
}

crosscheck_output_df <- do.call(rbind, crosscheck_output_list)
merged_filename <- paste0(file_path_sans_ext(basename(batch_file)), ".csv")
merged_filepath <- file.path(merged_crosscheck_dir, merged_filename)
fwrite(crosscheck_output_df, merged_filepath)
