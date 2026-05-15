library(data.table)
library(dplyr)

sample_metadata_df <- fread("[PROJECT_DIR]/LBP/all_files/sample_metadata_df.csv") 
index_vec <- sample_metadata_df %>% filter(!PHANTOM) %>% pull(INDEX)
genotype_matrix <- matrix(0, nrow=length(index_vec), ncol=length(index_vec))
rownames(genotype_matrix) <- colnames(genotype_matrix) <- index_vec

crosscheck_output_df <- fread("[PROJECT_DIR]/LBP/all_files/crosscheck_output_df.csv", data.table=FALSE)

crosscheck_output_df <- crosscheck_output_df %>%
    filter(indexA %in% index_vec, indexB %in% index_vec) %>% 
    left_join(
        sample_metadata_df[, c("INDEX", "ASSAYGROUP_SHORT", "N_READS", "IID")] %>%
            transmute(INDEX, LEFT_ASSAYGROUP = ASSAYGROUP_SHORT, LEFT_N_READS = N_READS, LEFT_IID = IID),
        by=c("indexA"="INDEX")
    ) %>%
    left_join(
        sample_metadata_df[, c("INDEX", "ASSAYGROUP_SHORT", "N_READS", "IID")] %>%
            transmute(INDEX, RIGHT_ASSAYGROUP = ASSAYGROUP_SHORT, RIGHT_N_READS = N_READS, RIGHT_IID = IID),
        by=c("indexB"="INDEX")
    ) %>%
    mutate(
        MIN_N_READS = pmin(LEFT_N_READS, RIGHT_N_READS),
        ASSAYGROUPA = pmin(LEFT_ASSAYGROUP, RIGHT_ASSAYGROUP),
        ASSAYGROUPB = pmax(LEFT_ASSAYGROUP, RIGHT_ASSAYGROUP),
        ASSAYCOMP = paste(ASSAYGROUPA, ASSAYGROUPB, sep="#"),
        EXPECTED_MATCH = LEFT_IID == RIGHT_IID
    )

crosscheck_cutoffs_df <- data.frame(ASSAYCOMP = unique(crosscheck_output_df$ASSAYCOMP), CUTOFF = 10)
crosscheck_cutoffs_df[crosscheck_cutoffs_df$ASSAYCOMP == "SCRNA#WGS", "CUTOFF"] <- -1700

crosscheck_output_df <- crosscheck_output_df %>% 
    left_join(crosscheck_cutoffs_df, by="ASSAYCOMP")
              
crosscheck_matches_df <- crosscheck_output_df %>% 
  filter(LOD_SCORE > CUTOFF) %>% 
  select(indexA, indexB)

genotype_matches_matrix <- table(crosscheck_matches_df$indexA, crosscheck_matches_df$indexB)

rowmatch <- match(rownames(genotype_matches_matrix), rownames(genotype_matrix))
colmatch <- match(colnames(genotype_matches_matrix), colnames(genotype_matrix))
genotype_matrix[rowmatch, colmatch] <- genotype_matches_matrix

genotype_matrix <- genotype_matrix | t(genotype_matrix)

index_uid_map <- sample_metadata_df$UID
names(index_uid_map) <- sample_metadata_df$INDEX
colnames(genotype_matrix) <- sapply(colnames(genotype_matrix), \(x) index_uid_map[x])
rownames(genotype_matrix) <- colnames(genotype_matrix)

fwrite(genotype_matrix, "[PROJECT_DIR]/LBP/all_files/genotype_matrix.csv")
