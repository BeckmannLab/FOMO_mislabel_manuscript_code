library(magrittr)
library(tidyverse)
library(fs)
library(rex)
library(assertthat)
library(openxlsx)
library(qs2)

library(fomo)

sample_meta_table <- read_csv("[PROJECT_DIR]/MSCBB/all_files/sample_metadata_df.csv")
crosscheck_results_table <- read_csv("[PROJECT_DIR]/MSCBB/all_files/all_merged_non_ghost_crosscheck_output_df.csv")

estimate_n_mislabels(sample_meta_table$Labeled_Sex, sample_meta_table$Genotyped_Sex)

estimate_n_mislabels(sample_meta_table$Labeled_Sex, sample_meta_table$Genotyped_Sex, return_fraction = TRUE)


sample_meta_table %>%
    filter(!Ghost) %>%
    split(.$SwapCat_ID) %>%
    lapply(\(x) estimate_n_mislabels(x$Labeled_Sex, x$Genotyped_Sex, return_fraction = TRUE))

sample_meta_table %>%
    filter(!Ghost) %>%
    split(.$SwapCat_ID) %>%
    sapply(\(x) estimate_n_mislabels(x$Labeled_Sex, x$Genotyped_Sex, return_fraction = FALSE))

sample_meta_table %>%
    filter(!Ghost) %>%
    split(.$SwapCat_ID) %>%
    sapply(\(x) estimate_n_mislabels(x$Labeled_Sex, x$Genotyped_Sex, return_fraction = FALSE)) %>%
    sum

sample_meta_table %>%
    split(.$SwapCat_ID) %>%
    lapply(\(x) x %$% table(Labeled_Sex, Genotyped_Sex))

## Sample stats
x <- sample_meta_table %>%
    filter(!Ghost) %>%
    group_by(Subject_ID) %>%
    summarise(
        n = n(),
        n_pairs = n * (n-1) / 2
    )

x <- sample_meta_table %>%
    group_by(SwapCat_ID) %>%
    summarise(
        n_samples = n(),
        n_subjects = length(unique(Subject_ID)),
        mean_n_samples_per_subject = n_samples / n_subjects,
        median_samples_per_subject = median(table(Subject_ID))
    )

xg <- sample_meta_table %>%
    filter(!Ghost) %>%
    group_by(SwapCat_ID) %>%
    summarise(
        n_samples = n(),
        n_subjects = length(unique(Subject_ID)),
        mean_samples_per_subject = n_samples / n_subjects,
        median_samples_per_subject = median(table(Subject_ID))
    )


xgt <- sample_meta_table %>%
    filter(!Ghost) %>%
    summarise(
        n_samples = n(),
        n_subjects = length(unique(Subject_ID)),
        mean_samples_per_subject = n_samples / n_subjects,
        median_samples_per_subject = median(table(Subject_ID))
    )

crosscheck_results_table %>%
    mutate(
        ## Code redacted due to reference to internal ID details
        subjectA = stop("Redacted code for extracting subjectA from sampleA"),
        subjectB = stop("Redacted code for extracting subjectB from sampleB"),
        Expected_Match = subjectA == subjectB
    ) %>%
    split(.$Expected_Match) %>% lapply(\(x) summary(x$LOD_SCORE))

all_non_ghost_samples <- sample_meta_table %>%
    filter(!Ghost) %>%
    pull(Sample_ID) %>%
    sort
assert_that(!anyDuplicated(all_non_ghost_samples))

## Determined manually by choosing a threshold that gives
## approximately the right number of matches
lod_match_threshold <- 14.6

## Known pathological case, should be a mismatch but the LOD is
## greater than the above threshold. Increasing threshold to reject
## this match will break other matches, so instead we must flag one of
## the samples as contaminated sample, since it sends the
## contamination metric to 0.5 on the component.
all_non_ghost_samples <- setdiff(all_non_ghost_samples, "RNA-0c028410T1_Plate_13")

## Verify that the pair doesn't appear in the matches df any more
crosscheck_matches_df %>%
    filter(
        sampleA %in% pathological_pair,
        sampleB %in% pathological_pair
    )

genotype_matches_matrix <- table(crosscheck_matches_df$sampleA, crosscheck_matches_df$sampleB)
genotype_matches_matrix <- genotype_matches_matrix | t(genotype_matches_matrix)

output_dir <- "[PROJECT_DIR]/MSCBB/all_files/fomo_output"
dir_create(output_dir)

mislabel_solver <- MislabelSolver(
    sample_metadata = sample_meta_table %>% select(-SwapCat_ID),
    genotype_matrix=genotype_matches_matrix,
    swap_cats = sample_meta_table %>% select(Sample_ID, SwapCat_ID)
)
qs_save(mislabel_solver, path(output_dir, "solver_pre_solve.qs2"))

mislabel_solver_solved <- solveEnsemble(mislabel_solver)
qs_save(mislabel_solver_solved, path(output_dir, "solver_solved.qs2"))

## Currently this actually just returns the thing instead of writing
## it (which is arguably the correct behavior)
summary_list <- writeOutput(mislabel_solver_solved, output_dir)
write.xlsx(summary_list, file = path(output_dir, "corrections_summary.xlsx"))

relabel_table <- mislabel_solver_solved@.solve_state$relabel_data

full_relabel_table <- relabel_table %>%
    left_join(sample_meta_table, join_by(Init_Sample_ID == Sample_ID, Init_Subject_ID == Subject_ID, SwapCat_ID, Is_Ghost == Ghost)) %>%
    select(-fingerprint_file, -vertex_size_scalar, -SwapCat_Shape, -Is_Anchor) %>%
    as_tibble

relabeled_samples <- full_relabel_table %>%
    filter(Init_Subject_ID != Subject_ID) %>%
    as_tibble()
unsolved_samples <- full_relabel_table %>%
    filter(!Solved)


relabeled_samples %>% filter(SwapCat_ID == "WGS") %>%
    select(-Is_Ghost)

x <- full_relabel_table %>%
    filter(
        SwapCat_ID == "WGS",
        Labeled_Sex != Genotyped_Sex
    )

y <- full_relabel_table %>%
    filter(Subject_ID %in% x$Subject_ID) %>%
    mutate(Sex_Matched = Labeled_Sex == Genotyped_Sex)

x_bad_sex <- x %>%
    select(Subject_ID, WGS_Genotyped_Sex = Genotyped_Sex)

full_relabel_table %>%
    inner_join(x_bad_sex) %>%
    mutate(Matches_WGS_Sex = Genotyped_Sex == WGS_Genotyped_Sex) %>%
    group_by(Subject_ID) %>%
    drop_na(Matches_WGS_Sex) %>%
    summarise(n = n(), n_match = sum(Matches_WGS_Sex)) %>%
    print(n = Inf)

full_relabel_table %>%
    filter(Subject_ID %in% x$Subject_ID) %>%
    mutate(Sex_Matched = Labeled_Sex == Genotyped_Sex) %$%
    table(Subject_ID, Sex_Matched)

full_relabel_table %>%
    filter(Subject_ID %in% x$Subject_ID) %>%
    mutate(Sex_Matched = Labeled_Sex == Genotyped_Sex) %>%
    filter(!Sex_Matched)
