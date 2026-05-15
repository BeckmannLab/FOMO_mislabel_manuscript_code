library(devtools)
library(fomo)
library(data.table)
library(dplyr)
library(igraph)
library(withr)
library(assertthat)
library(tidyverse)
library(fs)
library(scales)
library(qs2)
library(readxl)
library(ggnewscale)
library(forcats)
library(glue)

pdfcrop <- function(fname) {
    for (fn in fname) {
        system2("pdfcrop", args = fn)
    }
}

pdfcrop_inplace <- function(fname) {
    for (fn in fname) {
        temp_file_name <- tempfile(fileext = ".pdf")
        out_file_name <- str_replace(temp_file_name, rex(".pdf", end), "-crop.pdf")
        assert_that(
            out_file_name != temp_file_name
        )
        file_copy(fn, temp_file_name)
        on.exit(file_delete(temp_file_name))
        assert_that(system2("pdfcrop", args = temp_file_name) == 0)
        assert_that(
            file_exists(out_file_name),
            file_size(out_file_name) > 0
        )
        file_move(out_file_name, fn)
    }
}

with_cropped_pdf <- function(new, ...) {
    with_pdf(new = new, ...)
    pdfcrop_inplace(new)
}

solver_pre <- qs_read("solver_pre_solve.qs2")

past_rna_mislabel_table <- as_tibble(read_excel("Mislabels-2020-10-13.xlsx", sheet = "Mislabeled RNA samples"))

current_mislabel_table <- read_excel("MSC19B_Mislabels.xlsx")

rna_sample_table <- readRDS("rna_sample_table.RDS")

rna_extraction_log_1 <- read_csv(
    "RNA_extraction_sample_log_8-31-20.csv",
    col_types = cols(
        `Elution Volume (_l)` = col_double(),
        `Total RNA Conc. (ng/_l)` = col_double(),
        `Total Yield (ng)` = col_double(),
        `DV200 (%)` = col_double(),
        RIN = col_double(),
        `Blood Sample Name` = col_character(),
        `RNA technician` = col_character(),
        `Date RNA extracted` = col_character(),
        `Extraction Shift` = col_character(),
        `Personal RNA Stock and Submission Plate Wells` = col_character(),
        `Submission Plate Number for Library Prep` = col_double(),
        `Submission Plate Well for Library Prep` = col_character(),
        Batch = col_character()
    ),
    na = c("", "NA", "#VALUE!", "Ctrl NA", "-", "EMPTY", "Empty", "empty")
)
names(rna_extraction_log_1) %<>%
    str_replace_all("_l", "ul")
extraction_excel_col_types <- c(
    `Elution Volume (μl)` = "numeric",
    `Total RNA Conc. (ng/μl)` = "numeric",
    `Total Yield (ng)` = "numeric",
    `DV200 (%)` = "numeric",
    RIN = "numeric",
    `Blood Sample Name` = "text",
    `RNA technician` = "text",
    `Date RNA extracted` = "text",
    `Extraction Shift` = "text",
    `Personal RNA Stock and Submission Plate Wells` = "text",
    `Submission Plate Number for Library Prep` = "numeric",
    `Submission Plate Well for Library Prep` = "text"
)
rna_extraction_log_2 <- lapply(
    1:3, read_excel,
    path = "TD01804_TD01806_TD01879_Batches7thru9_Plates14thru19_RNA_QC_08312020.xlsx",
    col_types = extraction_excel_col_types,
    na = c("", "NA", "#VALUE!", "Ctrl NA", "-", "EMPTY", "Empty", "empty")
) %>% bind_rows()

names(rna_extraction_log_2) %<>%
    str_replace_all("μl", "ul") %>%
    str_replace_all("Batch Submission Plate", "Submission Plate")
assert_that(all(names(rna_extraction_log_2) %in% names(rna_extraction_log_1)))
batch_map <- rna_extraction_log_1 %>%
    filter(!str_detect(Batch, "Peds_Subset")) %>%
    select(`Submission Plate Number for Library Prep`, Batch) %>%
    distinct() %>%
    filter(complete.cases(.))
rna_extraction_log_2 %<>%
    left_join(batch_map, by = "Submission Plate Number for Library Prep")
rna_extraction_log <- bind_rows(
    rna_extraction_log_1 %>% filter(!Batch %in% rna_extraction_log_2$Batch),
    rna_extraction_log_2
)

rna_plate_table <- rna_extraction_log %>%
    transmute(
        Uncorrected_Blood_Sample = `Blood Sample Name`,
        Plate = coalesce(
            str_c("Pediatric", str_extract(Batch, rex(digits %if_prev_is% "Peds_Subset_"))),
            as.character(`Submission Plate Number for Library Prep`)
        ),
        Plate_Well = `Submission Plate Well for Library Prep`,
        Row_And_Col = as_tibble(str_match(
            Plate_Well,
            rex(
                start,
                capture(alphas, name = "WellRow"),
                capture(digits, name = "WellCol"),
                end
            )
        )[, -1, drop = FALSE])
    ) %>%
    filter(!is.na(Uncorrected_Blood_Sample)) %>%
    unnest_wider(Row_And_Col) %>%
    mutate(
        WellRow = factor(WellRow, levels = rev(LETTERS)),
        WellCol = factor(WellCol, levels = as.character(sort(unique(as.numeric(WellCol)))))
    ) %>%
    droplevels()
assert_that(!anyNA(rna_plate_table))

plate_levels <- unique(rna_plate_table$Plate)
# Put peds batches at the end
plate_levels <- unique(c(
    str_subset(plate_levels, "Pediatric", negate = TRUE),
    plate_levels
))

all_well_table <- expand_grid(
    Plate = plate_levels,
    WellRow = unique(rna_plate_table$WellRow),
    WellCol = unique(rna_plate_table$WellCol)
)

blood_mislabel_table <- past_rna_mislabel_table %>%
    transmute(
        ## Code redacted due to reference to internal ID details
        Uncorrected_Blood_Sample = stop("Redacted code for extracting Uncorrected_Blood_Sample from Original_Sample"),
        ## Convert to logical
        Blood_Mislabel = Blood_Mislabel == "TRUE"
    ) %>%
    filter(Blood_Mislabel) %>%
    distinct()

actual_mislabel_table <- current_mislabel_table %>%
    transmute(
        Uncorrected_Sample = Original_Sample,
        Uncorrected_Subject = Original_Subject,
        ## Code redacted due to reference to internal ID details
        Uncorrected_Blood_Sample = stop("Redacted code for extracting Uncorrected_Blood_Sample from Uncorrected_Sample"),
        Plate = str_extract(Uncorrected_Sample, rex(anything %if_prev_is% "Plate_", end)),
        Called_By_Manual_QC, Called_By_FOMO,
        Manual_QC_Correct, FOMO_Correct,
        FOMO_Unsolvable,
        Actually_Mislabeled,
        Final_Corrected_Sample_ID,
        Final_Corrected_Subject
    )

ghost_table <- solver_pre@sample_metadata %>%
    transmute(
        Uncorrected_Sample = Sample_ID,
        ## Code redacted due to reference to internal ID details
        Uncorrected_Blood_Sample = stop("Redacted code for extracting Uncorrected_Blood_Sample from Uncorrected_Sample"),
        Plate = str_extract(Uncorrected_Sample, rex(anything %if_prev_is% "Plate_", end)),
        Ghost = as.logical(Ghost)
    ) %>%
    filter(Ghost)

rna_fastq_table <- rna_sample_table %>%
    transmute(
        Uncorrected_Blood_Sample = sample_id,
        Plate = case_match(
            run_short,
            "Pediatrics_Batch2" ~ "Pediatric2",
            "Pediatrics" ~ "Pediatric1",
            .default = str_remove(run_short, "Plate_")
        ),
        R1_fastq, R2_fastq
    )

low_count_table <- past_rna_mislabel_table %>%
    transmute(
        ## Code redacted due to reference to internal ID details
        Uncorrected_Blood_Sample = stop("Redacted code for extracting Uncorrected_Blood_Sample from Original_Sample"),
        Low_Count = Error_Type == "low_count"
    ) %>%
    filter(Low_Count) %>%
    distinct()

rna_plate_plot_table_full <- all_well_table %>%
    full_join(rna_plate_table, by = join_by(Plate, WellRow, WellCol)) %>%
    left_join(ghost_table, by = join_by(Plate, Uncorrected_Blood_Sample)) %>%
    select(-Uncorrected_Sample) %>%
    left_join(actual_mislabel_table, by = join_by(Plate, Uncorrected_Blood_Sample)) %>%
    left_join(blood_mislabel_table, by = join_by(Uncorrected_Blood_Sample)) %>%
    left_join(low_count_table, by = join_by(Uncorrected_Blood_Sample)) %>%
    left_join(rna_fastq_table, by = join_by(Uncorrected_Blood_Sample, Plate)) %>%
    mutate(
        Plate = factor(Plate, plate_levels),
        Plate_Name = fct_relabel(Plate, \(x) str_c("Plate ", x)),
        Ghost = replace_na(Ghost, FALSE),
        Actually_Mislabeled = replace_na(Actually_Mislabeled, FALSE),
        # Must intersect with final call of mislabeled or not
        Blood_Mislabel = replace_na(Blood_Mislabel, FALSE) & Actually_Mislabeled,
        Plate = factor(Plate, plate_levels),
        Final_Status = case_when(
            !Actually_Mislabeled ~ "No mislabel",
            !is.na(Final_Corrected_Sample_ID) ~ "Corrected",
            !is.na(Final_Corrected_Subject) ~ "Subject corrected",
            .default = "Uncorrected"
        ),
        FOMO_Status = case_when(
            FOMO_Correct ~ "Correct",
            FOMO_Unsolvable ~ "Info needed",
            !FOMO_Correct ~ "Incorrect",
            .default = NA
        ),
        Mislabel_Category = case_when(
            is.na(Uncorrected_Blood_Sample) ~ "Empty well",
            # We let low count take precedence over no seq data, since if we
            # have a record of it being low count, that means we had seq data at
            # some point.
            Low_Count ~ "Ghost (low read depth)",
            is.na(R1_fastq) ~ "Ghost (no sequencing data)",
            Ghost ~ "Ghost (other)",
            !Actually_Mislabeled ~ "No mislabel",
            Blood_Mislabel ~ "Blood mislabel",
            Actually_Mislabeled ~ case_when(
                Final_Status == "Corrected" ~ "Corrected RNA mislabel",
                Final_Status == "Subject corrected" ~ "Subject corrected RNA mislabel",
                Final_Status == "Uncorrected" ~ "Uncorrected RNA mislabel",
                .default = "[UNKNOWN] RNA mislabel"
            ),
            .default = "[UNKNOWN]"
        ),
    )

rna_plate_plot_table_full %>%
    select(
        Actually_Mislabeled,
        Blood_Mislabel,
        Final_Status,
        FOMO_Status,
        Mislabel_Category
    ) %>%
    map(table) %>%
    map(as.data.frame)

sample_cat_colors <- c(
    "Empty well" = "white",
    "Ghost (no sequencing data)" = muted("gray", l = 90, c = 0),
    "Ghost (low read depth)" = muted("gray", l = 80, c = 0),
    "Ghost (other)" = muted("gray", l = 70, c = 0),
    "No mislabel" = muted("blue", l = 70, c = 70),
    "Blood mislabel" = muted("blue", l = 55, c = 80),
    "Corrected RNA mislabel" = muted("orange", l = 70),
    "Subject corrected RNA mislabel" = muted("orange", l = 50),
    "Uncorrected RNA mislabel" = muted("red", l = 40)
)

fomo_status_colors <- c(
    "Correct" = muted("green", l = 80),
    "Incorrect" = muted("purple4", l = 60),
    "Info needed" = muted("pink", c = 90, l = 50)
)

assert_that(all(rna_plate_plot_table_full$Mislabel_Category %in% names(sample_cat_colors)))
assert_that(all(na.omit(rna_plate_plot_table_full$FOMO_Status) %in% names(fomo_status_colors)))

rna_plate_plot_table_full$Mislabel_Category <- factor(rna_plate_plot_table_full$Mislabel_Category, levels = names(sample_cat_colors))
rna_plate_plot_table_full$FOMO_Status <- factor(rna_plate_plot_table_full$FOMO_Status, levels = names(fomo_status_colors))

p_full <- ggplot(rna_plate_plot_table_full) +
    facet_wrap(~Plate_Name) +
    aes(
        x = WellCol,
        y = WellRow,
    ) +
    geom_tile(
        aes(fill = Mislabel_Category),
        color = "black"
    ) +
    geom_point(
        data = rna_plate_plot_table_full %>%
            filter(Actually_Mislabeled) %>%
            drop_na(FOMO_Status),
        aes(color = FOMO_Status)
    ) +
    scale_x_discrete(expand = c(0, 0)) +
    scale_y_discrete(expand = c(0, 0)) +
    scale_fill_manual(values = sample_cat_colors, ) +
    scale_color_manual(values = fomo_status_colors) +
    guides(
        fill = guide_legend(order = 1),
        color = guide_legend(
            order = 2,
            override.aes = list(size = 3)
        )
    ) +
    labs(
        x = "Well column",
        y = "Well row",
        fill = "Well sample status",
        color = "FOMO relabel"
    ) +
    coord_fixed()

with_cropped_pdf(
    "MSC19B_RNA_Mislabels_All_Plates.pdf",
    print(p_full),
    width = 12,
    height = 8
)

rna_plate_plot_table_main <- rna_plate_plot_table_full %>%
    filter(Plate %in% c("2", "4", "9", "13", "18"))

p_main <- ggplot(rna_plate_plot_table_main) +
    facet_wrap(~Plate_Name) +
    aes(
        x = WellCol,
        y = WellRow,
    ) +
    geom_tile(
        aes(fill = Mislabel_Category),
        color = "black"
    ) +
    geom_point(
        data = rna_plate_plot_table_main %>%
            filter(Actually_Mislabeled) %>%
            drop_na(FOMO_Status),
        aes(color = FOMO_Status)
    ) +
    scale_x_discrete(expand = c(0, 0)) +
    scale_y_discrete(expand = c(0, 0)) +
    scale_fill_manual(values = sample_cat_colors, ) +
    scale_color_manual(values = fomo_status_colors) +
    labs(
        x = "Well column",
        y = "Well row",
        fill = "Well sample status",
        color = "FOMO relabel"
    ) +
    coord_fixed() +
    guides(
        fill = guide_legend(
            order = 1,
            ncol = 2
        ),
        color = guide_legend(
            order = 2,
            ncol = 1,
            override.aes = list(size = 3)
        )
    ) +
    theme(
        legend.position = "top",
        legend.direction = "vertical"
    )

with_cropped_pdf(
    "MSC19B_RNA_Mislabels_Selected_Plates.pdf",
    print(p_main),
    width = 15,
    height = 5.5
)
