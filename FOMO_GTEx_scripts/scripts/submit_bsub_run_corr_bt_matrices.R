library(dplyr)
library(glue)
library(stringr)
command_constructor_df <- expand.grid(a=1:18, b=1:18) %>% 
    transmute(
        mat1_name = pmin(a, b),
        mat2_name = pmax(a, b)
    ) %>% 
    distinct() %>% 
    mutate(
        job_name = glue("{mat1_name}#{mat2_name}"),
        log_stdout_file = glue("[PROJECT_DIR]/GTEx/log_stdout/{job_name}.txt"),
        log_stderr_file = glue("[PROJECT_DIR]/GTEx/log_stderr/{job_name}.txt"),
        mat1_path = glue("[PROJECT_DIR]/GTEx/merged_bam_vcf_output/split_allele_fracs/{mat1_name}.tsv"),
        mat2_path = glue("[PROJECT_DIR]/GTEx/merged_bam_vcf_output/split_allele_fracs/{mat2_name}.tsv"),
        command = glue("Rscript [PROJECT_DIR]/GTEx/scripts/run_corr_bt_matrices.R {mat1_path} {mat2_path}"),
        bsub_command = str_c(sep = " ",
                             "bsub",
                             "-J", shQuote(job_name),
                             "-P", "acc_mscic1",
                             "-q", "premium",
                             "-n", "1",
                             "-R", shQuote("rusage[mem=5000]"),
                             "-W", shQuote("2:00"),
                             "-oo", shQuote(log_stdout_file),
                             "-eo", shQuote(log_stderr_file),
                             shQuote(command))
    )
    
for (my_bsub_command in command_constructor_df$bsub_command) {
    system(my_bsub_command)
}

