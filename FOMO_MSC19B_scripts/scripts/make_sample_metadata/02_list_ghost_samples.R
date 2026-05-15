library(dplyr)

wgs_ghosts <- stop("List of manually curated internal samples IDs redacted")

mscbb_data_file <- "[PROJECT_DIR]/MSCBB/all_files/full_C19_biobank_graph_data.RDS"
mscbb_object <- readRDS(mscbb_data_file)
mscbb_graph_vertex <- mscbb_object$vertex_table_incl_phantoms
rna_ghosts <- mscbb_graph_vertex %>% 
    filter(!is.na(Phantom)) %>% 
    pull(Sample)

all_ghosts <- c(wgs_ghosts, rna_ghosts)
writeLines(all_ghosts, "[PROJECT_DIR]/MSCBB/all_files/all_ghosts.txt")
