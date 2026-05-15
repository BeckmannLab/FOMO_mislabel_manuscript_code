library(glue)
library(data.table)

batch_file <- commandArgs(trailingOnly=TRUE)[1]
crosscheck_outputs_dir <- "[PROJECT_DIR]/MSCBB/crosscheck_outputs"
H <- shQuote("[PROJECT_DIR]/GTEx/static_input_files/hg38_80_15_chr.map")

crosscheck_df <- fread(batch_file)

for (i in 1:nrow(crosscheck_df)) {
    sampleA <- crosscheck_df$sampleA[i]
    sampleB <- crosscheck_df$sampleB[i]
    I1 <- crosscheck_df$fingerprint_fileA[i]
    I2 <- crosscheck_df$fingerprint_fileB[i]
    O <- shQuote(glue("{crosscheck_outputs_dir}/{sampleA}#{sampleB}"))
    if (file.exists(O)) {next}
    print(glue("Running crosscheck between {sampleA} and {sampleB}"))
    crosscheck_command <- glue("java -jar $PICARD CrosscheckFingerprints I={I1} SI={I2} H={H} O={O} CROSSCHECK_MODE=CHECK_ALL_OTHERS CROSSCHECK_BY=SAMPLE")
    system(crosscheck_command)
}

