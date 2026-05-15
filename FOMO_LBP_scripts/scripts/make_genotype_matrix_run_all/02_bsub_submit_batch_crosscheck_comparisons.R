library(dplyr)
library(tools)
library(glue)
library(stringr)

batch_files_vec <- list.files("[PROJECT_DIR]/LBP/crosscheck_batches", pattern=".csv$", full.names=TRUE)

command_constructor_df <- data.frame(batch_file=batch_files_vec) %>%
    mutate(
        batch_id = file_path_sans_ext(basename(batch_file)),
        job_name = glue("running_{batch_id}"),
        log_stdout_file = glue("[PROJECT_DIR]/LBP/log_stdout/crosscheck_comparisons/{job_name}.txt"),
        log_stderr_file = glue("[PROJECT_DIR]/LBP/log_stderr/crosscheck_comparisons/{job_name}.txt"),
        command = glue("Rscript [PROJECT_DIR]/LBP/scripts/make_genotype_matrix/run_batch_crosscheck_comparisons.R {batch_file}"),
        bsub_command = str_c(sep = " ",
                             "bsub",
                             "-J", shQuote(job_name),
                             "-P", "acc_mscic1",
                             "-q", "premium",
                             "-n", "1",
                             "-R", shQuote("rusage[mem=5000]"),
                             "-W", shQuote("24:00"),
                             "-oo", shQuote(log_stdout_file),
                             "-eo", shQuote(log_stderr_file),
                             shQuote(command))
    )

for (my_bsub_command in command_constructor_df$bsub_command) {
    system(my_bsub_command)
}
