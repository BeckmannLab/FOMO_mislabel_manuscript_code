library(dplyr)
library(glue)

params_grid <- expand.grid(
    n_subjects = 1000,
    n_samples_per_subject = 5,
    n_swap_cats = 1,
    fraction_mislabel = c(seq.int(0.02, 0.20, by=0.02), 0.25, 0.30, 0.35, 0.40, 0.45, 0.50),
    fraction_contaminated = c(0, 0.01),
    seed = c(1997, 1998, 1999, 2000, 2001)) %>%
    mutate(
        sim_name = glue("{fraction_mislabel}-{fraction_contaminated}-{seed}"),
        param_path = file.path("[PROJECT_DIR]/contamination_simulations/param_files", glue("{sim_name}.csv")),
        output_path = file.path("[PROJECT_DIR]/contamination_simulations/solve_results", glue("{sim_name}.csv")),
        output_exists = file.exists(output_path)
    ) %>%
    filter(!output_exists) %>%
    select(-output_exists) %>%
    arrange(fraction_mislabel, fraction_contaminated, seed)  

for (i in 1:nrow(params_grid)) {
    param_path <- params_grid[i, "param_path"]
    write.csv(params_grid[i, ], param_path, row.names=FALSE)
}
