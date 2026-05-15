library(data.table)
library(dplyr)
library(tools)
library(glue)
library(stringr)

all_ghosts <- readLines("[PROJECT_DIR]/MSCBB/all_files//all_ghosts.txt")
crosscheck_output_dir <- "[PROJECT_DIR]/MSCBB/crosscheck_outputs"
temp_dir <- "[PROJECT_DIR]/MSCBB/temp_dir"
crosscheck_output_files <- list.files(crosscheck_output_dir, pattern="#", full.names=TRUE)

crosscheck_df <- fread("[PROJECT_DIR]/MSCBB/all_files/all_crosscheck_comparisons.csv", data.table=FALSE) %>% 
    ## Filter out comparisons that involved ghost samples
    filter(!(sampleA %in% all_ghosts), !(sampleB %in% all_ghosts)) %>% 
    mutate(
        crosscheck_output = paste0(sampleA, "#", sampleB),
        file_exists = crosscheck_output %in% basename(crosscheck_output_files)
    )

print(paste(sum(!crosscheck_df$file_exists), " expected outputs from crosscheck still missing"))

files_to_read <- file.path(crosscheck_output_dir, crosscheck_df %>% filter(file_exists) %>% pull(crosscheck_output))
n_batches <- 500
files_df <- data.frame(crosscheck_file=files_to_read) %>% 
    mutate(batch_id = rep(1:n_batches, length.out=n()))
batch_id_vec <- unique(files_df$batch_id)
for (curr_batch_id in batch_id_vec) {
    writeLines(files_df %>% filter(batch_id == curr_batch_id) %>% pull(crosscheck_file), file.path(temp_dir, paste0("crosscheck_batch_", curr_batch_id, ".txt")))
}


## Step 2: submit jobs to merge each crosscheck batch
all_batch_files <- file.path(temp_dir, paste0("crosscheck_batch_", batch_id_vec, ".txt"))

command_constructor_df <- data.frame(batch_file=all_batch_files) %>%
    mutate(
        batch_id = file_path_sans_ext(basename(batch_file)),
        job_name = glue("running_{batch_id}"),
        log_stdout_file = glue("[PROJECT_DIR]/MSCBB/log_stdout/crosscheck_comparisons/{job_name}.txt"),
        log_stderr_file = glue("[PROJECT_DIR]/MSCBB/log_stderr/crosscheck_comparisons/{job_name}.txt"),
        command = glue("Rscript [PROJECT_DIR]/MSCBB/scripts/make_genotype_matrix/merge_batched_crosscheck_outputs.R {batch_file}"),
        bsub_command = str_c(sep = " ",
                             "bsub",
                             "-J", shQuote(job_name),
                             "-P", "acc_mscic1",
                             "-q", "premium",
                             "-n", "1",
                             "-R", shQuote("rusage[mem=5000]"),
                             "-W", shQuote("4:00"),
                             "-oo", shQuote(log_stdout_file),
                             "-eo", shQuote(log_stderr_file),
                             shQuote(command))
    )

for (my_bsub_command in command_constructor_df$bsub_command) {
    system(my_bsub_command)
}

## Step 3: once all jobs are submitted, run this part
merged_crosscheck_output_files <- list.files("[PROJECT_DIR]/MSCBB/temp_dir/merged_crosscheck_batches", full.names=TRUE)
merged_crosscheck_list <- list(length=length(merged_crosscheck_output_files))
for (i in seq_along(merged_crosscheck_output_files)) {
    merged_crosscheck_list[[i]] <- fread(merged_crosscheck_output_files[i])
}
all_merged_non_ghost_crosscheck_output_df <- do.call(rbind, merged_crosscheck_list)
fwrite(all_merged_non_ghost_crosscheck_output_df, "[PROJECT_DIR]/MSCBB/all_files/all_merged_non_ghost_crosscheck_output_df.csv")

