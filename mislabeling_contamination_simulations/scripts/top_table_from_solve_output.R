library(dplyr)
library(tools)
library(glue)

solve_dir <- "[PROJECT_DIR]/contamination_simulations/solve_results"
solve_paths <- list.files(solve_dir, "\\.csv$", full.names=TRUE)

tt_dir <- "[PROJECT_DIR]/contamination_simulations/top_tables"

for (solve_path in solve_paths) {
    sim_name <- file_path_sans_ext(basename(solve_path))
    unfiltered_tt_path <- file.path(tt_dir, glue("{sim_name}-FALSE.csv"))
    filtered_tt_path <- file.path(tt_dir, glue("{sim_name}-TRUE.csv"))

    tt_list <- list()
    params_vec <- strsplit(sim_name, split="-")[[1]]
    tt_list$fraction_mislabel <- params_vec[1]
    tt_list$contamination <- params_vec[2]
    tt_list$seed <- params_vec[3]
    tt_filtered_list <- tt_list
    
    ## All output
    results_df <- read.csv(solve_path)
    tt_list$filtered <- FALSE
    tt_list$n_samples <- nrow(results_df)
    tt_list$n_init_sample_mislabels <- results_df %>% 
        filter(Init_Sample_ID != True_Sample_ID) %>% 
        nrow()
    tt_list$n_init_subject_mislabels <- results_df %>% 
        filter(Init_Subject_ID != True_Subject_ID) %>% 
        nrow()
    tt_list$n_fin_sample_mislabels <- results_df %>% 
        filter(Final_Sample_ID != True_Sample_ID) %>% 
        nrow()
    tt_list$n_fin_subject_mislabels <- results_df %>% 
        filter(Final_Subject_ID != True_Subject_ID) %>% 
        nrow()
    
    write.csv(as.data.frame(tt_list), unfiltered_tt_path, row.names=FALSE)
    
    ## Filtered output
    # I messed up the contamination flag
    results_df <- results_df %>% 
        mutate(
            existing_edges = sapply(Genotype_Connectedness, \(x) strsplit(x, split=" ")[[1]][1]),
            total_edges = sapply(Genotype_Connectedness, \(x) strsplit(x, split=" ")[[1]][4]),
            Genotype_Contamination_Flag = as.integer(existing_edges) < as.integer(total_edges)
        )
    results_wo_flag_df <- results_df %>% 
        filter(!Genotype_Contamination_Flag)
    tt_filtered_list$filtered <- TRUE
    tt_filtered_list$n_samples <- nrow(results_wo_flag_df)
    tt_filtered_list$n_init_sample_mislabels <- results_wo_flag_df %>% 
        filter(Init_Sample_ID != True_Sample_ID) %>% 
        nrow()
    tt_filtered_list$n_init_subject_mislabels <- results_wo_flag_df %>% 
        filter(Init_Subject_ID != True_Subject_ID) %>% 
        nrow()
    tt_filtered_list$n_fin_sample_mislabels <- results_wo_flag_df %>% 
        filter(Final_Sample_ID != True_Sample_ID) %>% 
        nrow()
    tt_filtered_list$n_fin_subject_mislabels <- results_wo_flag_df %>% 
        filter(Final_Subject_ID != True_Subject_ID) %>% 
        nrow()
    write.csv(as.data.frame(tt_filtered_list), filtered_tt_path, row.names=FALSE)
}
