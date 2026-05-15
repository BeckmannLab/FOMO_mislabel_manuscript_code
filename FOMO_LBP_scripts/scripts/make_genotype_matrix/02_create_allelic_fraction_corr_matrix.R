library(data.table)

merged_AF_df <- fread("[PROJECT_DIR]/LBP/all_files/merged_AF_df.csv")
AF_corr_df <-  cor(merged_AF_df, method="spearman", use="pairwise.complete.obs")

fwrite(AF_corr_df, "[PROJECT_DIR]/LBP/all_files/AF_corr_df.csv")
