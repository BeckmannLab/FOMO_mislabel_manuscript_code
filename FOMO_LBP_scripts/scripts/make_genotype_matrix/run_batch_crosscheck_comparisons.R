library(glue)
library(data.table)

batch_file <- commandArgs(trailingOnly=TRUE)[1]
crosscheck_outputs_dir <- "[PROJECT_DIR]/LBP/crosscheck_outputs"
fingerprint_vcfs_dir <- "[PROJECT_DIR]/LBP/fingerprint_vcfs"
H <- shQuote("[PROJECT_DIR]/GTEx/static_input_files/hg38_80_15_chr.map")

crosscheck_df <- fread(batch_file)

for (i in 1:nrow(crosscheck_df)) {
    indexA <- crosscheck_df[i, "sampleA"]
    indexB <- crosscheck_df[i, "sampleB"]
    O <- shQuote(glue("{crosscheck_outputs_dir}/{indexA}#{indexB}"))
    I1 <- shQuote(glue("{fingerprint_vcfs_dir}/{indexA}.fingerprint.vcf"))
    I2 <- shQuote(glue("{fingerprint_vcfs_dir}/{indexB}.fingerprint.vcf"))
    if (file.exists(O)) {next}
    print(glue("Running crosscheck between {indexA} and {indexB}"))
    crosscheck_command <- glue("java -jar $PICARD CrosscheckFingerprints I={I1} SI={I2} H={H} O={O} CROSSCHECK_MODE=CHECK_ALL_OTHERS CROSSCHECK_BY=SAMPLE")
    system(crosscheck_command)
}
