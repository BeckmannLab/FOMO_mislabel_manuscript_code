library(readr)
library(dplyr)
library(igraph)
library(stringr)

crosscheck_comps <- read_tsv("[PROJECT_DIR]/GTEx/crosscheck_outputs/all_merged_crosscheck.tsv")
cutoff <- 2
crosscheck_matches <- as.matrix(crosscheck_comps %>% filter(LOD_SCORE >= cutoff) %>% select(LEFT_SAMPLE, RIGHT_SAMPLE))
genotype_graph <- graph_from_edgelist(crosscheck_matches, directed=FALSE)
cc_ids <- components(genotype_graph)$membership
sample_genotype_data <- data.frame(Sample_ID=names(cc_ids), Genotype_Group_ID=cc_ids) %>%
    mutate(
        Subject_ID = str_extract(Sample_ID, "GTEX-([^-]+)")
    ) %>%
    mutate(
        Subject_ID = case_when(
            Subject_ID == "GTEX-1F7RK0011 R5b" ~ "GTEX-1F7RK",
            Subject_ID == "GTEX-1F88E0011 R8a" ~ "GTEX-1F88E",
            TRUE ~ Subject_ID)
    )

write_tsv(sample_genotype_data, "[PROJECT_DIR]/GTEx/sample_genotype_datas/crosscheck_LOD_2.tsv")


