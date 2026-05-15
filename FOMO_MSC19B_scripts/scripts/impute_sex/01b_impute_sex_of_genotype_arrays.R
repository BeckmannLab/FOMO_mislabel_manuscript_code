library(data.table)
library(ggplot2)
library(dplyr)
library(rex)
library(stringr)
library(withr)

setwd("[PROJECT_DIR]/MSCBB/all_files/imputed_sex")
array_sex_file <- "[PROJECT_DIR]/MSCBB/all_files/imputed_sex/mscic_freeze1_all_merged.hg38.vcf.gz_imputedSex.sexcheck"
array_sex_df <- fread(array_sex_file, data.table=FALSE)
array_sex_df <- array_sex_df %>% 
    filter(!grepl("empty", IID, ignore.case=TRUE)) %>% 
    mutate(
        Genotyped_Sex = case_when(
	    F > 0.8 ~ "Male",
	    F <= 0.2 ~ "Female",
	    TRUE ~ NA),
        ## NOTE: The code below has been redacted since it refers
        ## internal detailsabout IDs that cannot be publicly released.
        Sample_ID = stop("Redacted code for extracting Sample_ID from IID"),
        Subject_ID = stop("Redacted code for extracting Subject_ID from Sample_ID"),
        Sample_ID = paste("Geno", Sample_ID, sep="-"))

with_pdf("~/www/mislabeling/array_sex_inf.pdf", print(
    ggplot(array_sex_df,aes(x=F)) +
    geom_density()
))

subject_sex_table <- readRDS("[PROJECT_DIR]/MSCBB/all_files/Biobank_subject_sex_table_deidentified.RDS") %>%
    select(Subject_ID, Labeled_Sex = Sex) %>%
    distinct()

array_sex_df <- array_sex_df %>% 
    left_join(subject_sex_table, by="Subject_ID") %>% 
    select(Sample_ID, Subject_ID, Genotyped_Sex, Labeled_Sex)

fwrite(array_sex_df, "[PROJECT_DIR]/MSCBB/all_files/array_sex_df.csv")

