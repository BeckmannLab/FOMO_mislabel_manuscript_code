library(dplyr)
library(glue)
library(stringr)

command_constructor_df <- readRDS("[PROJECT_DIR]/bam_sample_table.RDS") %>%
    select(sample_id, bam_file) %>% 
    mutate(
        out_file = file.path("[PROJECT_DIR]/MSCBB/read_counts", sample_id),
        job_name = glue("readcount_{sample_id}"),
        log_stdout_file = glue("[PROJECT_DIR]/MSCBB/log_stdout/{job_name}.txt"),
        log_stderr_file = glue("[PROJECT_DIR]/MSCBB/log_stderr/{job_name}.txt"),
        command = glue("samtools view -c {bam_file} > {out_file}"),
        bsub_command = str_c(sep = " ",
                             "bsub",
                             "-J", shQuote(job_name),
                             "-P", "acc_mscic1",
                             "-q", "premium",
                             "-n", "10",
                             "-R", shQuote("rusage[mem=3000]"),
                             "-R", shQuote("span[hosts=1]"),
                             "-W", shQuote("1:00"),
                             "-oo", shQuote(log_stdout_file),
                             "-eo", shQuote(log_stderr_file),
                             shQuote(command))
    )

for (curr_bsub_command in command_constructor_df$bsub_command) {
    system(curr_bsub_command)
}
