library(glue)
library(stringr)
sample_names_file <- "[PROJECT_DIR]/GTEx/merged_bam_vcf_output/all_merged_17350_allele_frac_w_header.sample_list"
sample_names <- readLines(sample_names_file)
merged_mat <- matrix(NA_integer_, nrow=17350, ncol=17350)
colnames(merged_mat) <- sample_names
rownames(merged_mat) <- sample_names
for (i in 1:18) {
    for (j in i:18) {
        print(glue("{i}#{j}"))
        corr_block_file <- glue("[PROJECT_DIR]/GTEx/merged_bam_vcf_output/allele_fracs_corr_blocks/{i}#{j}.tsv")
        corr_block_mat <- as.matrix(read.table(corr_block_file, header=TRUE, row.names = 1, check.names=FALSE))
        merged_mat[rownames(corr_block_mat), colnames(corr_block_mat)] <- corr_block_mat
    }
}
fixed_names <- make.names(colnames(merged_mat))
colnames(merged_mat) <- fixed_names
rownames(merged_mat) <- fixed_names

merged_mat[lower.tri(merged_mat)] <- t(merged_mat)[lower.tri(merged_mat)]
library(assertthat)
assert_that(isSymmetric(merged_mat))

outpath <- "[PROJECT_DIR]/GTEx/merged_bam_vcf_output/allele_fracs_corr_blocks/all_merged_17350_allele_frac_corr_mat.tsv"
write.table(merged_mat, file=outpath, sep = "\t", col.names=TRUE, row.names = TRUE)

