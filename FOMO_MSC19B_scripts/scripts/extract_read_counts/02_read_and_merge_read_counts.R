library(dplyr)
library(data.table)

read_count_files <- list.files("[PROJECT_DIR]/MSCBB/read_counts", full.names=TRUE)
read_counts <- integer(length=length(read_count_files))
for (i in seq_along(read_count_files)) {
    read_counts[i] <- readLines(read_count_files[i])[1]
}

read_counts_df <- data.frame(
    Sample_ID = basename(read_count_files),
    read_count = read_counts
)

fwrite(read_counts_df, "[PROJECT_DIR]/MSCBB/all_files/read_counts_df.csv")
