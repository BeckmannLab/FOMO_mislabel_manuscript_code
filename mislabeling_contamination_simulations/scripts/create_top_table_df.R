library(data.table)
library(tools)
library(dplyr)

tt_files <- list.files("[PROJECT_DIR]/contamination_simulations/top_tables", pattern=".csv$", full.names=TRUE)
tt_files_list <- list()

i <- 1
for (my_tt_file in tt_files) {
    tt_row <- fread(my_tt_file, data.table=FALSE)
    tt_row$contaminated <- tt_row$contamination > 0
    i <- i + 1
    tt_files_list[[i]] <- tt_row
}

tt_df <- do.call(rbind, tt_files_list) %>% 
    filter(!(!contaminated & filtered)) %>% 
    mutate(
        group = case_when(
            !contaminated ~ "No contaminated samples",
            contaminated & !filtered ~ "1% of samples contaminated",
            contaminated & filtered ~ "1% of samples contaminated w/ filtering",
            TRUE ~ "There's an issue here"
        )
    )
fwrite(tt_df, "[PROJECT_DIR]/contamination_simulations/top_table_df.csv")
