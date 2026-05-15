library(readr)

AD_filepath <- "[PROJECT_DIR]/GTEx/merged_bam_vcf_output/all_merged_17350_AD_only_w_header.txt"
AD_matrix <- read_tsv(AD_filepath)
AD_matrix <- AD_matrix[5:17354]
colnames(AD_matrix) <- sub("\\[.*\\]", "", colnames(AD_matrix))
colnames(AD_matrix) <- sub(":AD$", "", colnames(AD_matrix))

allele_frac_func <- function(x) {
	split_values <- strsplit(x, split=",")
	numeric_values <- lapply(split_values, function(x) as.numeric(x))
	result <- sapply(numeric_values, \(x) x[1]/x[2])
	return(result)
}

allele_frac_matrix <- apply(AD_matrix, MARGIN = 2, FUN = allele_frac_func)
allele_frac_filepath <- "[PROJECT_DIR]/GTEx/merged_bam_vcf_output/all_merged_17350_allele_frac_w_header.tsv"
write.table(allele_frac_matrix, file = allele_frac_filepath, sep = "\t", col.names = TRUE, row.names = FALSE)


