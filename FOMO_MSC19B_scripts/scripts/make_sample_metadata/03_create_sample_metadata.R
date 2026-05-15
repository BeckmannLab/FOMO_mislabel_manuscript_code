library(dplyr)
library(stringr)
library(rex)
library(data.table)

array_samples_vec <- readLines("[PROJECT_DIR]/MSCBB/all_files/raw_genotype_array_samples.txt")
array_metadata_df <- data.frame(Raw_Sample_ID = array_samples_vec) %>% 
    filter(!grepl("empty", Raw_Sample_ID, ignore.case=TRUE)) %>% 
    mutate(
        fingerprint_file = file.path("[PROJECT_DIR]/MSCBB/fingerprinted_arrays", paste0(Raw_Sample_ID, "fingerprint.vcf")),
        ## NOTE: The code below has been redacted since it refers
        ## internal detailsabout IDs that cannot be publicly released.
        Sample_ID = stop("Redacted code for extracting Sample_ID from Raw_Sample_ID"),
        Subject_ID = stop("Redacted code for extracting Subject_ID from Sample_ID"),
        SwapCat_ID = "Geno",
        Sample_ID = paste(SwapCat_ID, Sample_ID, sep="-"),
    ) %>% 
    select(Sample_ID, Subject_ID, SwapCat_ID, fingerprint_file)

bam_metadata_df <- readRDS("[PROJECT_DIR]/bam_sample_table.RDS") %>%
    mutate(
        fingerprint_file = file.path("[PROJECT_DIR]/MSCBB/fingerprinted_bams", paste0(sample_id, ".fingerprint.vcf")),
        Sample_ID = sample_id,
        ## Code redacted due to reference to internal ID details
        Subject_ID = stop("Redacted code for extracting Subject_ID from blood_sample_id"),
        SwapCat_ID = case_match(
            sample_type,
            c("RNASeq") ~ "RNA",
            .default = sample_type)
    ) %>% 
    select(Sample_ID, Subject_ID, SwapCat_ID, fingerprint_file)

sample_metadata_df <- bind_rows(array_metadata_df, bam_metadata_df)

ghost_samples <- readLines("[PROJECT_DIR]/MSCBB/all_files/all_ghosts.txt")
sample_metadata_df$Ghost <- FALSE
sample_metadata_df[sample_metadata_df$Sample_ID %in% ghost_samples, "Ghost"] <- TRUE

read_counts_df <- fread("[PROJECT_DIR]/MSCBB/all_files/read_counts_df.csv")
sample_metadata_df <- sample_metadata_df %>%
   left_join(read_counts_df, by="Sample_ID")

all_sex_df <- fread("[PROJECT_DIR]/MSCBB/all_files/all_sex_df.csv", na.strings = c(NA_character_, "")) %>%
    select(-Subject_ID)
sample_metadata_df <- sample_metadata_df %>%
   left_join(all_sex_df, by="Sample_ID")

fwrite(sample_metadata_df, "[PROJECT_DIR]/MSCBB/all_files/sample_metadata_df.csv")
