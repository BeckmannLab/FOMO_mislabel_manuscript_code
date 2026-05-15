library(dplyr)
library(data.table)
library(magrittr)

rna_sex_df <- fread("[PROJECT_DIR]/MSCBB/all_files/RNA_sex_inference_table.tsv", data.table=FALSE) %>% 
    select(
        Sample_ID = Sample,
        Subject_ID,
        Genotyped_Sex = inferred_sex,
        Labeled_Sex = annotated_sex,
        Xist_UTY_logRatio = logRatio
    )
rna_sex_df$Sample_Type <- "RNA"
table(rna_sex_df$Genotyped_Sex, useNA = "ifany")

wgs_sex_df <- fread("[PROJECT_DIR]/MSCBB/all_files/wgs_sex_df.csv", data.table=FALSE, na.strings = c("NA", ""))
wgs_sex_df$Sample_Type <- "WGS"
table(wgs_sex_df$Genotyped_Sex, useNA = "ifany")

array_sex_df <- fread("[PROJECT_DIR]/MSCBB/all_files/array_sex_df.csv", data.table=FALSE, na.strings = c("NA", ""))
array_sex_df$Sample_Type <- "Geno"
table(array_sex_df$Genotyped_Sex, useNA = "ifany")

all_sex_df <- bind_rows(rna_sex_df, wgs_sex_df, array_sex_df) %>%
    mutate(
        Labeled_Sex = case_match(
            Labeled_Sex,
            c("Female") ~ "Female",
            c("Male") ~ "Male",
            .default = NA
        ),
        Genotyped_Sex = case_match(
            Genotyped_Sex,
            c("Female") ~ "Female",
            c("Male") ~ "Male",
            .default = NA
        )
    )
all_sex_df %$% table(Sample_Type, Genotyped_Sex, useNA = "ifany")

fwrite(all_sex_df, "[PROJECT_DIR]/MSCBB/all_files/all_sex_df.csv")

