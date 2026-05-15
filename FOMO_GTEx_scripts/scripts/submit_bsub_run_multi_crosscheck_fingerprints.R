library(dplyr)
library(glue)
library(stringr)
library(tools)

crosscheck_bucket_files <- list.files("[PROJECT_DIR]/GTEx/crosscheck_comparisons", pattern="tsv", full.names=TRUE)

command_constructor_df <- data.frame(bucket_file=crosscheck_bucket_files) %>% 
    mutate(
        job_name = file_path_sans_ext(basename(bucket_file)),
        log_stdout_file = glue("[PROJECT_DIR]/GTEx/log_stdout/{job_name}.txt"),
        log_stderr_file = glue("[PROJECT_DIR]/GTEx/log_stderr/{job_name}.txt"),
        command = glue("Rscript [PROJECT_DIR]/GTEx/scripts/run_multi_crosscheck_fingerprints.R {bucket_file}"),
        bsub_command = str_c(sep = " ",
                             "bsub",
                             "-J", shQuote(job_name),
                             "-P", "acc_mscic1",
                             "-q", "premium",
                             "-n", "1",
                             "-R", shQuote("rusage[mem=5000]"),
                             "-W", shQuote("15:00"),
                             "-oo", shQuote(log_stdout_file),
                             "-eo", shQuote(log_stderr_file),
                             shQuote(command))
    )

for (my_bsub_command in command_constructor_df$bsub_command) {
    system(my_bsub_command)
}
