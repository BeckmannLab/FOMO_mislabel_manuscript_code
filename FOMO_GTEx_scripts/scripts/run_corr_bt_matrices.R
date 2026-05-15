library(readr)
library(tools)
mat1_path <- commandArgs(trailingOnly=TRUE)[1]
mat2_path <- commandArgs(trailingOnly=TRUE)[2]

mat1 <- read_tsv(mat1_path)
mat2 <- read_tsv(mat2_path)

corr <- cor(mat1, mat2, use="pairwise.complete.obs", method="spearman")

mat1_name <- basename(file_path_sans_ext(mat1_path))
mat2_name <- basename(file_path_sans_ext(mat2_path))
outpath <- paste0("[PROJECT_DIR]/GTEx/merged_bam_vcf_output/allele_fracs_corr_blocks/", mat1_name, "#", mat2_name, ".tsv")

write.table(corr, file=outpath, sep = "\t", col.names=TRUE, row.names = TRUE)
