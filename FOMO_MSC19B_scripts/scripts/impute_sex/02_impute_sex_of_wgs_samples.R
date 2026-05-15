library(ggplot2)
library(data.table)
allFiles=list.files("[PROJECT_DIR]/MSCBB/fingerprinted_bams", pattern=".*\\.vcf$")
allFiles=grep(".idx",allFiles,value=TRUE,invert=TRUE)
allFiles=data.frame(files=allFiles,sample=unlist(lapply(strsplit(allFiles,"_",fixed=TRUE),function(x){x[1]})))
allFiles$noX=FALSE
for(i in 1:nrow(allFiles)){
    cat("\r",i, "\t\t\t")
    data=fread(paste0("[PROJECT_DIR]/MSCBB/fingerprinted_bams/",allFiles$files[i]),data.table=FALSE)
    data=data[data$`#CHROM`=="chrX",]
    if(nrow(data)>0){
        data$AD=unlist(lapply(strsplit(data[,10],":",fixed=TRUE),function(x){x[1]}))
        data$AD1=as.numeric(unlist(lapply(strsplit(data[,11],",",fixed=TRUE),function(x){x[1]})))
        data$AD2=as.numeric(unlist(lapply(strsplit(data[,11],",",fixed=TRUE),function(x){x[2]})))
        data[,10]=NULL
        data$frac=data$AD1/data$AD2
        allFiles$frac[i]=length(which(data$frac[is.finite(data$frac)]>0))
    }else{
        allFiles$noX[i]=TRUE
    }
}
cat("\n")

allFiles$type=unlist(lapply(strsplit(allFiles$sample,"-",fixed=TRUE),function(x){x[1]}))

allFiles$sex=NA_character_
allFiles$sex[allFiles$type=="WGS" & allFiles$frac<200]="Male"
allFiles$sex[allFiles$type=="WGS" & allFiles$frac>=200]="Female"
allFiles$Subject_ID=unlist(lapply(strsplit(unlist(lapply(strsplit(allFiles$sample,"-",fixed=TRUE),function(x){x[2]})),"T",fixed=TRUE),function(x){x[1]}))

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
    select(Sample_ID = sample2, Subject_ID, Genotyped_Sex = sex, Labeled_Sex = Sex)
fwrite(wgs_sex_df, "[PROJECT_DIR]/MSCBB/all_files/wgs_sex_df.csv")
