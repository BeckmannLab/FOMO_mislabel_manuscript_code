library(magrittr)
library(dplyr)
library(ggplot2)
library(withr)
library(data.table)
allFiles=list.files("[PROJECT_DIR]/MSCBB/fingerprinted_bams", pattern=".*\\.vcf$")
allFiles=grep(".idx",allFiles,value=TRUE,invert=TRUE)
allFiles=data.frame(files=allFiles,sample=unlist(lapply(strsplit(allFiles,"_",fixed=TRUE),function(x){x[1]})))
allFiles$noX=FALSE
for(i in 1:nrow(allFiles)){
    cat("\r",i, "\t\t\t")
    data=fread(paste0("[PROJECT_DIR]/MSCBB/fingerprinted_bams/",allFiles$files[i]),data.table=FALSE)
    data=data[data$`#CHROM`=="chrX",]
    data$AD=as.character(unlist(lapply(strsplit(data[,10],":",fixed=TRUE),function(x){x[1]})))
    data$AD1=as.numeric(unlist(lapply(strsplit(data[,11],",",fixed=TRUE),function(x){x[1]})))
    data$AD2=as.numeric(unlist(lapply(strsplit(data[,11],",",fixed=TRUE),function(x){x[2]})))
    data$frac=data$AD1/(data$AD1 + data$AD2)
    data <- filter(data, is.finite(frac))
    allFiles$x_loci[i] <- nrow(data)
    ## Either exactly 0 or exactly 1 is homozygous
    allFiles$frac_homozygous[i] <- sum(pmin(data$frac, 1 - data$frac) <= 0.1) / nrow(data)
}
cat("\n")

allFiles$type=unlist(lapply(strsplit(allFiles$sample,"-",fixed=TRUE),function(x){x[1]}))

with_pdf("~/www/mislabeling/seq_sex_inf.pdf", print(
    ggplot(allFiles,aes(x=frac_homozygous)) +
    geom_density() +
    facet_wrap(~type, ncol = 1,  scales="free_y")
))

## Thresholds determined by examining plot
allFiles$sex <- NA_character_
allFiles$sex[allFiles$type=="WGS" & allFiles$frac_homozygous<0.68] <- "Female"
allFiles$sex[allFiles$type=="WGS" & allFiles$frac>=0.81] <- "Male"
allFiles$sex[allFiles$type=="WGS" & allFiles$x_loci<20] <- NA
allFiles$Subject_ID=unlist(lapply(strsplit(unlist(lapply(strsplit(allFiles$sample,"-",fixed=TRUE),function(x){x[2]})),"T",fixed=TRUE),function(x){x[1]}))
allFiles %$% table(type, sex, useNA = "ifany")

library(dplyr)
library(stringr)
subject_sex_table <- readRDS("[PROJECT_DIR]/MSCBB/all_files/Biobank_subject_sex_table_deidentified.RDS") %>%
    select(Subject_ID, Sex) %>%
    distinct()

allFiles=merge(allFiles,subject_sex_table,by="Subject_ID",all.x=TRUE)

wgs_sex_df <- allFiles %>%
    filter(type == "WGS") %>% 
    mutate(
        sample2 = sapply(files, \(x) str_split_1(x, pattern="\\.")[1])
    ) %>% 
    select(Sample_ID = sample2, Subject_ID, Genotyped_Sex = sex, Labeled_Sex = Sex, Fraction_X_Homozygous = frac_homozygous)
fwrite(wgs_sex_df, "[PROJECT_DIR]/MSCBB/all_files/wgs_sex_df.csv")
