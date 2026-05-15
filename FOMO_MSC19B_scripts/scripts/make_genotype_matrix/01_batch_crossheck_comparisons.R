library(data.table)
library(dplyr)
library(tools)
library(assertthat)

sample_metadata_df <- fread("[PROJECT_DIR]/MSCBB/all_files/sample_metadata_df.csv", data.table=FALSE)

sample_id_vec <- sample_metadata_df %>% pull(Sample_ID)
n_comparisons <- as.integer(0.5 * length(sample_id_vec) * (length(sample_id_vec) - 1))

compared_files <- list.files("[PROJECT_DIR]/MSCBB/crosscheck_outputs")
compared_files <- file_path_sans_ext(basename(compared_files))

crosscheck_df <- expand.grid(
    sample_a = sample_id_vec,
    sample_b = sample_id_vec) %>%
    mutate(
        sample_a = as.character(sample_a),
        sample_b = as.character(sample_b)
    ) %>%
    filter(sample_a != sample_b) %>%
    transmute(
        sampleA = pmin(sample_a, sample_b),
        sampleB = pmax(sample_a, sample_b)
    ) %>%
    distinct() %>%
    mutate(
        file_exists = paste0(sampleA, "#", sampleB) %in% compared_files
    ) %>% 
    left_join(sample_metadata_df %>% select(Sample_ID, fingerprint_fileA = fingerprint_file), 
              by=c("sampleA" = "Sample_ID")) %>% 
    left_join(sample_metadata_df %>% select(Sample_ID, fingerprint_fileB = fingerprint_file),
              by=c("sampleB" = "Sample_ID"))

assert_that(n_comparisons == nrow(crosscheck_df))

fwrite(crosscheck_df, "[PROJECT_DIR]/MSCBB/all_files/all_crosscheck_comparisons.csv")

crosscheck_df <- fread("[PROJECT_DIR]/MSCBB/all_files/all_crosscheck_comparisons.csv")
n_batches <- 5000
crosscheck_df <- crosscheck_df %>%
    filter(!file_exists) %>%
    mutate(
        batch_id = rep(1:n_batches, length.out=nrow(.))
    )
batch_dir <- "[PROJECT_DIR]/MSCBB/crosscheck_batches"
batch_id_vec <- unique(crosscheck_df$batch_id)
for (curr_batch_id in batch_id_vec) {
    print(curr_batch_id)
    fwrite(crosscheck_df %>% filter(batch_id == curr_batch_id),
           paste0(batch_dir, "/crosscheck_batch", curr_batch_id, ".csv"))
}

