tt_dir <- "[PROJECT_DIR]/contamination_simulations/top_tables"
tt_paths <- list.files(tt_dir, "\\.csv$", full.names=TRUE)

tt_rows <- list()
i <- 1
for (tt_path in tt_paths) {
    tt_rows[[i]] <- read.csv(tt_path)
    i <- i + 1
}

tt_df <- do.call(rbind, tt_rows)
write.csv(tt_df, "[PROJECT_DIR]/contamination_simulations/merged_tt_df.csv", row.names=FALSE)
