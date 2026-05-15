library(data.table)
library(dplyr)
library(glue)
library(stringr)

bam_sample_df <- readRDS("[PROJECT_DIR]/bam_sample_table.RDS")
sample_id_vec <- bam_sample_df %>% pull(sample_id)
fingerprints_vec <- list.files("[PROJECT_DIR]/MSCBB/fingerprinted_bams", pattern=".vcf$")
fingerprints_vec <- gsub("\\.fingerprint.vcf$", "", fingerprints_vec)
missing_sample_id_vec <- setdiff(sample_id_vec, fingerprints_vec)

print(paste0("missing ", length(missing_sample_id_vec)))

set.seed(0)
command_constructor_df <- bam_sample_df %>%
    arrange(sample_type) %>%
    mutate(username = rep(c("dengc02", "thompr21", "beckmn01"), length.out=n())) %>%
    filter(sample_id %in% missing_sample_id_vec) %>%
    select(username, bam_file, sample_id) %>%
    mutate(
        job_name = glue("fingerprint_{sample_id}"),
        log_stdout_file = glue("[PROJECT_DIR]/MSCBB/log_stdout/{job_name}.txt"),
        log_stderr_file = glue("[PROJECT_DIR]/MSCBB/log_stderr/{job_name}.txt"),
        command = glue("[PROJECT_DIR]/MSCBB/scripts/fingerprint_bams/bam_extract_fingerprint3.sh {sample_id} {bam_file}"),
        bsub_command = str_c(sep = " ",
                             "bsub",
                             "-J", shQuote(job_name),
                             "-P", "acc_mscic1",
                             "-q", "premium",
                             "-n", "10",
                             "-R", shQuote("rusage[mem=3000]"),
         		     "-R", shQuote("span[hosts=1]"),
                             "-W", shQuote("12:00"),
                             "-oo", shQuote(log_stdout_file),
                             "-eo", shQuote(log_stderr_file),
                             shQuote(command))
    ) %>%
    filter(username == Sys.getenv("USER"))

print(table(command_constructor_df$username))

next_index <- 1
n_jobs <- nrow(command_constructor_df)
while (TRUE) {
    n_jobs_running <- as.numeric(processx::run("sh", c("-c", "bjobs | wc  -l"))$stdout)
    if (n_jobs_running < 25) {
        additional_jobs <- min(25 - n_jobs_running, n_jobs - next_index + 1)
        for (i in seq_len(additional_jobs)) {
            system(command_constructor_df$bsub_command[next_index])
            print(paste0("Submitted job for ", command_constructor_df$sample_id[next_index]))
            next_index <- next_index + 1
        }
    }
    if (next_index >= n_jobs) {break}
    Sys.sleep(5 * 60)
}
