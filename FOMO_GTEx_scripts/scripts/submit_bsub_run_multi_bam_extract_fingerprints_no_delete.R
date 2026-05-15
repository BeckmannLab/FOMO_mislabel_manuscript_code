library(glue)
library(dplyr)
library(stringr)

groups_dir <- "[PROJECT_DIR]/GTEx/bam_file_groups"
group_ids <- tools::file_path_sans_ext(list.files(groups_dir, "\\.txt$"))
command_constructor <- data.frame(group_id = group_ids) %>%
	mutate(
		job_name = glue("{group_id}_run_multi_bam_extract_fingerprint"),
		log_stdout_file = glue("[PROJECT_DIR]/GTEx/log_stdout/{job_name}.txt"),
		log_stderr_file = glue("[PROJECT_DIR]/GTEx/log_stderr/{job_name}.txt"),
		command = glue("Rscript [PROJECT_DIR]/GTEx/scripts/run_multi_bam_extract_fingerprints_no_delete.R {group_id}"),
	    bsub_command = str_c(sep = " ",
	                 "bsub",
	                 "-J", shQuote(job_name),
	                 "-P", "acc_mscic1",
	                 "-q", "premium",
	                 "-n", "1",
	                 "-R", shQuote("rusage[mem=20000]"),
	                 "-W", shQuote("12:00"),
	                 "-oo", shQuote(log_stdout_file),
	                 "-eo", shQuote(log_stderr_file),
	                 shQuote(command))
	)
for (my_bsub_command in command_constructor$bsub_command) {
	system(my_bsub_command)
}
