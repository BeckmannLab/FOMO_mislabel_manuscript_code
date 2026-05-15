library(glue)
library(dplyr)
library(stringr)

grids_dir <- "[PROJECT_DIR]/contamination_simulations/param_files"
grid_paths <- list.files(grids_dir, "\\.csv$", full.names=TRUE)

command_constructor <- data.frame(grid_path = grid_paths) %>%
    mutate(
        sim_name = tools::file_path_sans_ext(basename(grid_path)),
        output_path = file.path("[PROJECT_DIR]/contamination_simulations/solve_results", paste0(sim_name, ".csv")),
        file_exists = file.exists(output_path)) %>% 
    filter(!file_exists) %>% 
    mutate(
        job_name = glue("sim_name"),
        log_stdout_file = glue("[PROJECT_DIR]/contamination_simulations/solve_stdout/{sim_name}.txt"),
        log_stderr_file = glue("[PROJECT_DIR]/contamination_simulations/solve_stderr/{sim_name}.txt"),
        command = glue("Rscript [PROJECT_DIR]/contamination_simulations/scripts/simulate_and_run_solver.R {grid_path}"),
        bsub_command = str_c(sep = " ",
                             "bsub",
                             "-J", shQuote(job_name),
                             "-P", "acc_mscic1",
                             "-q", "premium",
                             "-n", "1",
                             "-R", shQuote("rusage[mem=25000]"),
                             "-W", shQuote("24:00"),
                             "-oo", shQuote(log_stdout_file),
                             "-eo", shQuote(log_stderr_file),
                             shQuote(command))
    )
for (my_bsub_command in command_constructor$bsub_command) {
    system(my_bsub_command)
}
