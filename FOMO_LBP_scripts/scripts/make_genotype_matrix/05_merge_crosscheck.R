library(data.table)
library(dplyr)
library(tools)
library(glue)

crosscheck_df <- fread("[PROJECT_DIR]/LBP/all_files/all_crosscheck_comparisons.csv", data.table=FALSE) %>% 
    mutate(
        comp = paste0(sampleA, "#", sampleB)
    )
crosscheck_output_dir <- "[PROJECT_DIR]/LBP/crosscheck_outputs"
crosscheck_output_files <- list.files(crosscheck_output_dir, pattern="#", full.names=TRUE)

cols_to_keep <- c("LEFT_GROUP_VALUE", "RIGHT_GROUP_VALUE", "indexA", "indexB", "RESULT", "LOD_SCORE")
crosscheck_output_list <- list()

i <- 1
for (output_file in crosscheck_output_files) {
    if (!(basename(output_file) %in% crosscheck_df$comp)) {next}
    if (i %% 50 == 1) {print(i)}
    crosscheck_output_row <- fread(output_file)
    indices_compared <- strsplit(file_path_sans_ext(basename(output_file)), "#")[[1]]
    crosscheck_output_row$indexA <- indices_compared[1]
    crosscheck_output_row$indexB <- indices_compared[2]
    crosscheck_output_list[[i]] <- crosscheck_output_row[, ..cols_to_keep]
    i <- i + 1
}

crosscheck_output_df <- do.call(rbind, crosscheck_output_list)

fwrite(crosscheck_output_df, "[PROJECT_DIR]/LBP/all_files/crosscheck_output_df.csv")

