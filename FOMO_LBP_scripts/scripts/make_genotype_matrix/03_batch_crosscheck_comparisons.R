library(data.table)
library(dplyr)
library(tidyr)

AF_corr_df <- fread("[PROJECT_DIR]/LBP/all_files/AF_corr_df.csv")
AF_corr_mat <- as.matrix(AF_corr_df)
rownames(AF_corr_mat) <- colnames(AF_corr_mat)

sample_metadata_df <- fread("[PROJECT_DIR]/LBP/all_files/sample_metadata_df.csv")
filtered_index <- sample_metadata_df %>% filter(!PHANTOM) %>% pull(INDEX)

AF_corr_mat <- AF_corr_mat[filtered_index, filtered_index]
fwrite(AF_corr_mat, "[PROJECT_DIR]/LBP/all_files/filtered_AF_corr_mat.csv")

n_comparisons <- 14 # 2 x largest number of samples per subject

crosscheck_bool_mat <- apply(AF_corr_mat, 2, \(x) rank(-x) <= n_comparisons + 1)
crosscheck_indices <- which(crosscheck_bool_mat, arr.ind=TRUE)
crosscheck_df <- data.frame(
    sample1 = rownames(AF_corr_mat)[crosscheck_indices[, 1]],
    sample2 = rownames(AF_corr_mat)[crosscheck_indices[, 2]]
) %>% 
    transmute(
        sampleA = pmin(sample1, sample2),
        sampleB = pmax(sample1, sample2)
    ) %>% 
    filter(sampleA != sampleB) %>% 
    distinct()

expected_matches_df <- sample_metadata_df %>% 
    filter(!PHANTOM) %>% 
    group_by(IID) %>%
    mutate(
        index_a = INDEX,
        index_b = list(INDEX)
    ) %>% 
    ungroup() %>% 
    unnest(index_b) %>%
    transmute(
        sampleA = pmin(index_a, index_b),
        sampleB = pmax(index_a, index_b)
    ) %>%
    filter(sampleA != sampleB) %>%
    distinct()

crosscheck_df <- rbind(crosscheck_df, expected_matches_df) %>% 
    distinct()

fwrite(crosscheck_df, "[PROJECT_DIR]/LBP/all_files/all_crosscheck_comparisons.csv")

batch_dir <- "[PROJECT_DIR]/LBP/crosscheck_batches"

crosscheck_df <- fread("[PROJECT_DIR]/LBP/all_files/all_crosscheck_comparisons.csv")
n_batches <- 500
crosscheck_df <- crosscheck_df %>% 
    mutate(
        batch_id = rep(1:n_batches, length.out=nrow(.))
    )

batch_id_vec <- unique(crosscheck_df$batch_id)
for (curr_batch_id in batch_id_vec) {
    fwrite(crosscheck_df %>% filter(batch_id == curr_batch_id),
           paste0(batch_dir, "/crosscheck_batch", curr_batch_id, ".csv"))
}
