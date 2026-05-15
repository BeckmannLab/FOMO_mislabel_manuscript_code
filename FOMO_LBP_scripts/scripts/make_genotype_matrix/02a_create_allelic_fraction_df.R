library(data.table)

AD_files_vec <- list.files("[PROJECT_DIR]/LBP/allelic_depths", full.names=TRUE, pattern=".tsv$")
AF_list <- list()
i <- 1
for (AD_file in AD_files_vec) {
    if (i%%50 == 0) {print(i)}
    AD_vec <- fread(AD_file, data.table=FALSE)[, "V5"]
    index_name <- strsplit(basename(AD_file), "\\.")[[1]][1]
    AF_vec <- sapply(strsplit(AD_vec, split=","), \(x) as.numeric(x[1])/as.numeric(x[2]))
    AF_col <- data.frame(V1=AF_vec)
    colnames(AF_col) <- index_name
    AF_list[[i]] <- AF_col
    i <- i + 1
}

merged_AF_df <- do.call(cbind, AF_list)
fwrite(merged_AF_df, "[PROJECT_DIR]/LBP/all_files/merged_AF_df.csv")
