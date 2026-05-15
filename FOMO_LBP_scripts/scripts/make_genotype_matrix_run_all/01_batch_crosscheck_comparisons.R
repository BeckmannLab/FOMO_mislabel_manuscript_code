library(data.table)
library(dplyr)
library(tools)

sample_metadata_df <- fread("[PROJECT_DIR]/LBP/all_files/sample_metadata_df.csv")

sample_metadata_df <- sample_metadata_df %>%
    filter(!grepl("EXO", ASSAYGROUP))

filtered_index <- sample_metadata_df %>% filter(!PHANTOM) %>% pull(INDEX)

n_comparisons <- as.integer(0.5 * length(filtered_index) * (length(filtered_index) - 1))

compared_files <- list.files("[PROJECT_DIR]/LBP/crosscheck_outputs")
compared_files <- file_path_sans_ext(basename(compared_files))

crosscheck_df <- expand.grid(
    index_a = filtered_index,
    index_b = filtered_index
) %>%
    mutate(
    index_a = as.character(index_a),
        index_b = as.character(index_b)
    ) %>%
    filter(index_a != index_b) %>%
    transmute(
    sampleA = pmin(index_a, index_b),
        sampleB = pmax(index_a, index_b)
    ) %>%
    distinct() %>%
    mutate(
        file_exists = paste0(sampleA, "#", sampleB) %in% compared_files
    )

fwrite(crosscheck_df, "[PROJECT_DIR]/LBP/all_files/all_crosscheck_comparisons.csv")

crosscheck_df <- fread("[PROJECT_DIR]/LBP/all_files/all_crosscheck_comparisons.csv")
n_batches <- 100
crosscheck_df <- crosscheck_df %>%
    filter(!file_exists) %>%
    mutate(
        batch_id = rep(1:n_batches, length.out=nrow(.))
    )

batch_dir <- "[PROJECT_DIR]/LBP/crosscheck_batches"
batch_id_vec <- unique(crosscheck_df$batch_id)
for (curr_batch_id in batch_id_vec) {
    fwrite(crosscheck_df %>% filter(batch_id == curr_batch_id),
           paste0(batch_dir, "/crosscheck_batch", curr_batch_id, ".csv"))
}
