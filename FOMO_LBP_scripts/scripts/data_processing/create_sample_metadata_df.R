library(data.table)
library(dplyr)

sample_metadata_df <- fread("[PROJECT_DIR]/LBP/BAMPATHS_FOR_POSTWGS_IDCC_30AUG2022.tsv", data.table=FALSE)

sample_metadata_df <- sample_metadata_df %>%
    filter(!grepl("BOJAN", ASSAYGROUP))

# Filter out pilot run samples that aren't aligned to hg38
non_hg38_bams_vec <- readLines("[PROJECT_DIR]/LBP/all_files/non_hg38_bam_files.txt")
sample_metadata_df <- sample_metadata_df %>% filter(!(BAM %in% non_hg38_bams_vec))

# index1390 gives error no human chr detected
sample_metadata_df <- sample_metadata_df %>% filter(INDEX != "index1390")

# There's a non-unique UID
sample_metadata_df[sample_metadata_df$INDEX == "index1439", "UID"] <- "SCRNASEQ|T-4639|brain|postmortem|2"

nochr_bams_vec <- readLines("[PROJECT_DIR]/LBP/all_files/nochr_bam_files.txt")

read_count_dir <- "[PROJECT_DIR]/LBP/read_counts"

read_count_files <- list.files(read_count_dir, pattern=".txt$", full.names=TRUE)
read_count_list <- list()
i <- 1
for (read_count_file in read_count_files) {
    read_count_row <- fread(read_count_file)
    colnames(read_count_row) <- c("N_READS")
    read_count_row$INDEX <- strsplit(basename(read_count_file), "\\.")[[1]][1]
    read_count_list[[i]] <- read_count_row
    i <- i + 1
}

read_count_df <- do.call(rbind, read_count_list)

sample_metadata_df <- sample_metadata_df %>% 
    left_join(read_count_df, by="INDEX")

sample_metadata_df$PHANTOM <- sample_metadata_df$N_READS < 1e6

sample_metadata_df <- sample_metadata_df %>% 
    mutate(
        ASSAYGROUP_SHORT = case_match(
            ASSAYGROUP,
            c("WGSVUMC", "WGSISMMS") ~ "WGS",
            c("BULKRNASEQ779", "BULKRNASEQEXO") ~ "BULKRNA",
            c("EXORNASEQ") ~ "EXORNA",
            c("SCRNASEQ", "SCRNASEQFACS") ~ "SCRNA",
            .default = "OTHER"
        )
    )
uncontaminated_wgs_subjects <- readLines("[PROJECT_DIR]/LBP/all_files/all_uncontaminated_subjects.txt")
contaminated_wgs_subjects <- setdiff(sample_metadata_df %>% filter(ASSAYGROUP_SHORT == "WGS") %>% pull(IID),
                                     uncontaminated_wgs_subjects)
# Make sure we keep the samples that were removed because of duplication rather than contamination
contaminated_wgs_subjects <- setdiff(contaminated_wgs_subjects, c("PT-0122", "PT-0123", "PT-0214/15", "PT-0213", "PT-0237", "PT-0236", "S19010"))

sample_metadata_df[sample_metadata_df$ASSAYGROUP_SHORT == "WGS" & sample_metadata_df$IID %in% contaminated_wgs_subjects, "PHANTOM"] <- TRUE

# We dont want the exoseqs
sample_metadata_df <- sample_metadata_df %>% filter(ASSAYGROUP_SHORT != "EXORNA")

fwrite(sample_metadata_df, "[PROJECT_DIR]/LBP/all_files/sample_metadata_df.csv")
