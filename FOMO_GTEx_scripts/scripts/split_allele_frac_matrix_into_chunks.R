allele_frac_matrix <- read_tsv(allele_frac_filepath)
for (i in 1:17) {
	start_idx <- (i-1)*1000 + 1
	end_idx <- i*1000
	split_allele_frac_filepath <- paste0("[PROJECT_DIR]/GTEx/merged_bam_vcf_output/split_allele_fracs/", i, ".tsv")
	split_allele_frac_matrix <- allele_frac_matrix[start_idx:end_idx]
	write.table(split_allele_frac_matrix, file=split_allele_frac_filepath, sep = "\t", col.names=TRUE, row.names = FALSE)
}
split_allele_frac_filepath <- paste0("[PROJECT_DIR]/GTEx/merged_bam_vcf_output/split_allele_fracs/18.tsv")
split_allele_frac_matrix <- allele_frac_matrix[17001:ncol(allele_frac_matrix)]
write.table(split_allele_frac_matrix, file=split_allele_frac_filepath, sep = "\t", col.names=TRUE, row.names = FALSE)

