library(reshape2)
library(dplyr)
library(readr)
library(stringr)

matrix_file <- "[PROJECT_DIR]/GTEx/merged_bam_vcf_output/allele_fracs_corr_blocks/all_merged_17350_allele_frac_corr_crosscheck_boolean_mat.tsv"
crosscheck_matrix <- as.matrix(read.delim(matrix_file, header=TRUE, row.names=1, check.names=FALSE))

true_indices <- which(crosscheck_matrix, arr.ind=TRUE)

bam_data_map_file <- "[PROJECT_DIR]/GTEx/bam_data_map"
bam_data_map <- read.delim(bam_data_map_file, header=FALSE)
bam_data_map <- as.data.frame(bam_data_map) 
colnames(bam_data_map) <- c("File", "Sample")
bam_data_map$Sample_Fixed <- make.names(bam_data_map$Sample)
crosscheck_comps <- data.frame(S1=rownames(crosscheck_matrix)[true_indices[, 1]], S2=colnames(crosscheck_matrix)[true_indices[, 2]]) %>%
    transmute(
        SAMP1=pmin(S1, S2),
        SAMP2=pmax(S1, S2)) %>%
    distinct() %>%
    left_join(bam_data_map, by=c("SAMP1"="Sample_Fixed")) %>%
    rename(I1=File) %>%
    left_join(bam_data_map, by=c("SAMP2"="Sample_Fixed")) %>%
    rename(I2=File)

n_jobs <- 500
split_crosscheck_comps <- split(crosscheck_comps, seq.int(nrow(crosscheck_comps)) %% n_jobs)

for (i in seq_along(split_crosscheck_comps)) {
    save_file <- paste0("[PROJECT_DIR]/GTEx/crosscheck_comparisons/crosscheck_bucket_", i, ".tsv")
    write_tsv(split_crosscheck_comps[[i]], save_file)
}
