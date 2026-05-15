library(data.table)
library(dplyr)
library(glue)
library(stringr)

sample_metadata_df <- fread("[PROJECT_DIR]/LBP/all_files/sample_metadata_df.csv", data.table=FALSE)
index_vec <- sample_metadata_df %>% filter(!PHANTOM) %>% pull(INDEX)
fingerprints_vec <- list.files("[PROJECT_DIR]/LBP/fingerprint_vcfs", pattern=".vcf$")
fingerprints_vec <- gsub("\\.fingerprint.vcf$", "", fingerprints_vec)
missing_index_vec <- setdiff(index_vec, fingerprints_vec)

print(paste0("missing ", length(missing_index_vec)))

command_constructor_df <- sample_metadata_df %>%
  filter(INDEX %in% missing_index_vec) %>%
  select(BAM, INDEX) %>%
  mutate(
    job_name = glue("fingerprint_{INDEX}"),
    log_stdout_file = glue("[PROJECT_DIR]/LBP/log_stdout/{job_name}.txt"),
    log_stderr_file = glue("[PROJECT_DIR]/LBP/log_stderr/{job_name}.txt"),
    command = glue("[PROJECT_DIR]/LBP/scripts/create_fingerprints/bam_extract_fingerprint.sh {INDEX} {BAM}"),
    bsub_command = str_c(sep = " ",
      "bsub",
      "-J", shQuote(job_name),
      "-P", "acc_mscic1",
      "-q", "premium",
      "-n", "1",
      "-R", shQuote("rusage[mem=10000]"),
      "-W", shQuote("24:00"),
      "-oo", shQuote(log_stdout_file),
      "-eo", shQuote(log_stderr_file),
      shQuote(command))
  )

for (my_bsub_command in command_constructor_df$bsub_command) {
        system(my_bsub_command)
}
