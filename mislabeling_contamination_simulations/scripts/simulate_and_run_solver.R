library(dplyr)
library(tidyr)
library(igraph)
library(devtools)
library(glue)

devtools::load_all("[PROJECT_DIR]/contamination_simulations/fomo")

source("[PROJECT_DIR]/contamination_simulations/scripts/sim_mislabeled_dataset.R")

cmd_args <- commandArgs(trailingOnly = TRUE)
params_grid_file <- cmd_args[1]
params_list <- as.list(read.csv(params_grid_file))

run_and_output_simulation <- function(
   n_subjects,
   n_samples_per_subject,
   n_swap_cats,
   fraction_mislabel,
   fraction_contaminated,
   seed,
   output_path
) {
    set.seed(seed)
    
    n_samples <- n_subjects * n_samples_per_subject
    my_data_list <- sim_mislabeled_sample_meta_data(n_subjects_per_group=as.integer(n_subjects/2), 
                                                    n_samples_per_group=as.integer(n_samples/2), 
                                                    n_swap_cats=n_swap_cats, 
                                                    n_mislabels=as.integer(fraction_mislabel * n_samples), 
                                                    seed=seed)
    sample_genotype_data <- my_data_list$sample_meta_data
    swap_cats <- my_data_list$swap_cats
    genotype_matrix <- matrix(0, nrow=nrow(sample_genotype_data), ncol=nrow(sample_genotype_data))
    rownames(genotype_matrix) <- sample_genotype_data$Sample_ID
    colnames(genotype_matrix) <- sample_genotype_data$Sample_ID
    genotype_group_ids <- unique(sample_genotype_data$Genotype_Group_ID)
    for (genotype_group_id in genotype_group_ids) {
        genotype_group_samples <- sample_genotype_data[sample_genotype_data$Genotype_Group_ID == genotype_group_id, "Sample_ID"]
        genotype_matrix[genotype_group_samples, genotype_group_samples] <- 1
    }
    diag(genotype_matrix) <- 0

    n_contaminated <- as.integer(fraction_contaminated * n_samples)
    
    sample_genotype_data$Contaminated <- FALSE
    sample_genotype_data$Contaminating_Subject <- NA
    sample_genotype_data[sample(1:n_samples, n_contaminated, replace = FALSE), "Contaminated"] <- TRUE
    
    contaminated_samples <- sample_genotype_data %>% filter(Contaminated) %>% pull(Sample_ID)
    
    for (contaminated_sample in contaminated_samples) {
        subject_id <- sample_genotype_data[sample_genotype_data$Sample_ID == contaminated_sample, "Subject_ID"]
        contaminating_subject <- sample_genotype_data %>% 
            filter(Subject_ID != subject_id) %>% 
            pull(Subject_ID) %>% 
            sample(1)
        sample_genotype_data[sample_genotype_data$Sample_ID == contaminated_sample, "Contaminating_Subject"] <- contaminating_subject
        contaminating_samples <- sample_genotype_data %>% 
            filter(E_Subject_ID == contaminating_subject) %>% 
            pull(Sample_ID)
        genotype_matrix[contaminated_sample, contaminating_samples] <- 1
        genotype_matrix[contaminating_samples, contaminated_sample] <- 1
    }
    
    sample_metadata <- sample_genotype_data %>% select(Sample_ID, Subject_ID)
    my_mislabel_solver <- MislabelSolver(sample_metadata, genotype_matrix, swap_cats)
    my_solver <- solveEnsemble(my_mislabel_solver)
    
    results_df <- sample_genotype_data %>% 
        select(Sample_ID, Subject_ID, E_Sample_ID, E_Subject_ID, 
               Mislabeled, Mislabeled_Subject, Contaminated, Contaminating_Subject) %>%
        left_join(swap_cats, by="Sample_ID") %>% 
        rename(Init_Sample_ID = Sample_ID,
               Init_Subject_ID = Subject_ID,
               True_Sample_ID = E_Sample_ID,
               True_Subject_ID = E_Subject_ID)
    
    sample_summary <- my_solver@.solve_state$relabel_data %>%
        group_by(Genotype_Group_ID, Init_Subject_ID) %>% 
        mutate(n_agree=n()) %>% 
        ungroup(Init_Subject_ID) %>%
        mutate(n_Genotype_Group=n()) %>% 
        ungroup(Genotype_Group_ID) %>% 
        left_join(
            my_solver@.solve_state$putative_subjects,
            by = "Genotype_Group_ID",
            suffix = c("", "_putative")
        ) %>% 
        transmute(
            Component_ID = Init_Component_ID,
            Genotype_Group_ID,
            Ghost = is.na(Genotype_Group_ID),
            Init_Subject_ID,
            Init_Sample_ID,
            Final_Subject_ID = Subject_ID,
            Final_Sample_ID = Sample_ID,
            Putative_Subject_ID = Subject_ID_putative,
            n_Genotype_Group = ifelse(!Ghost, n_Genotype_Group, NA_integer_),
            Init_Agreement = ifelse(!Ghost, paste0(n_agree-1, " out of ", n_Genotype_Group - 1), NA_character_),
            Status = case_when(
                Ghost ~ "ghost",
                is.na(Putative_Subject_ID) ~ "subject_unknown",
                grepl(LABEL_NOT_FOUND, Final_Sample_ID) ~ "deletion_or_duplication",
                Init_Sample_ID != Final_Sample_ID & (Final_Subject_ID != Putative_Subject_ID | n_Genotype_Group == 1) ~ "flagged",
                Init_Sample_ID != Final_Sample_ID ~ "corrected",
                n_Genotype_Group == 1 ~ "ignored_single-sample",
                n_agree < 2 ~ "ignored",
                TRUE ~ "validated"
            )
        ) %>% 
        arrange(Component_ID, Genotype_Group_ID, Final_Subject_ID, Final_Sample_ID)
    
    sample_summary$Neighbor_Connectedness <- NA
    sample_summary$Sample_Contamination_Flag <- FALSE
    for (sample_id in sample_summary$Init_Sample_ID) {
        neighbor_samples <- names(which(my_solver@genotype_matrix[sample_id, ] == 1))
        neighbor_matrix <- my_solver@genotype_matrix[neighbor_samples, neighbor_samples]
        existing_edges <- sum(neighbor_matrix[upper.tri(neighbor_matrix)])
        total_edges <- length(neighbor_matrix[upper.tri(neighbor_matrix)])
        sample_summary[sample_summary$Init_Sample_ID == sample_id, "Neighbor_Connectedness"] <- 
            paste0(existing_edges, " out of ", total_edges, " pairs of neighbors connected in genotype matrix")
        if (existing_edges < total_edges) {
            sample_summary[sample_summary$Init_Sample_ID == sample_id, "Sample_Contamination_Flag"] <- TRUE
        }
        
    }
    
    genotype_group_summary <- sample_summary %>% 
        group_by(Genotype_Group_ID) %>% 
        summarize(
            Inferred_Subject_ID = names(sort(table(Final_Subject_ID), decreasing = TRUE)[1]),
            n_Samples_validated = sum(Status == "validated"),
            n_Samples_corrected = sum(Status == "corrected"),
            n_Samples_deletion_or_duplication = sum(Status == "deletion_or_duplication"),
            n_Samples_ignored = sum(str_detect(Status, "^ignored")),
            n_Samples_total = n(),
            Init_Fraction_Match = paste0(n_Samples_validated + n_Samples_ignored, " out of ", n_Samples_total)
        ) %>% 
        ungroup() %>% 
        select(Genotype_Group_ID, Inferred_Subject_ID, Init_Fraction_Match, everything())
    
    genotype_group_summary$Genotype_Connectedness <- NA
    genotype_group_summary$Genotype_Contamination_Flag <- FALSE
    for (genotype_group_id in genotype_group_summary$Genotype_Group_ID) {
        genotype_group_init_samples <- sample_summary %>% 
            filter(Genotype_Group_ID == genotype_group_id) %>% 
            pull(Init_Sample_ID)
        genotype_group_matrix <- my_solver@genotype_matrix[genotype_group_init_samples, genotype_group_init_samples]
        existing_edges <- sum(genotype_group_matrix[upper.tri(genotype_group_matrix)])
        total_edges <- length(genotype_group_matrix[upper.tri(genotype_group_matrix)])
        genotype_group_summary[genotype_group_summary$Genotype_Group_ID == genotype_group_id, "Genotype_Connectedness"] <- 
            paste0(existing_edges, " out of ", total_edges, " edges")
	if (existing_edges < total_edges) {
	    genotype_group_summary[genotype_group_summary$Genotype_Group_ID == genotype_group_id, "Genotype_Contamination_Flag"] <- TRUE
	}
    }
    
    all_results_df <- results_df %>%
        left_join(sample_summary %>% select(Init_Sample_ID, Component_ID, Genotype_Group_ID, Final_Subject_ID, Final_Sample_ID, 
                                            Status, Neighbor_Connectedness, Sample_Contamination_Flag),
                  by="Init_Sample_ID") %>% 
        left_join(genotype_group_summary %>% select(Genotype_Group_ID, Genotype_Connectedness, Genotype_Contamination_Flag),
                  by="Genotype_Group_ID")
    
    write.csv(all_results_df, output_path, row.names=FALSE)
}

params_list$sim_name <- NULL
params_list$param_path <- NULL
do.call(run_and_output_simulation, params_list)
