library(tidyverse)
library(readr)
library(assertthat)
library(ggplot2)
library(withr)
library(ggrastr)

setwd("~/Dropbox/Mislabeling_paper/Figures/Figure S3")

sample_table <- read_csv("sample_metadata_df.csv")
crosscheck_lod_table <- read_csv("crosscheck_output_df.csv")

match_table <- crosscheck_lod_table %>%
    inner_join(sample_table, join_by(LEFT_GROUP_VALUE == SID)) %>%
    inner_join(sample_table, join_by(RIGHT_GROUP_VALUE == SID), suffix = c("_LEFT", "_RIGHT")) %>%
    mutate(
        label_domains = if_else(
            ASSAYGROUP_SHORT_LEFT < ASSAYGROUP_SHORT_RIGHT,
            str_c(ASSAYGROUP_SHORT_LEFT, " vs. ", ASSAYGROUP_SHORT_RIGHT),
            str_c(ASSAYGROUP_SHORT_RIGHT, " vs. ", ASSAYGROUP_SHORT_LEFT),
        ),
        expected_match = IID_LEFT == IID_RIGHT,
        LOD_threshold = case_when(
            label_domains == "SCRNA|WGS" ~ -1700,
            .default = 10
        ),
        actual_match = LOD_SCORE >= LOD_threshold
    )

threshold_table <- match_table %>%
    select(label_domains, LOD_threshold) %>%
    distinct()

p <- ggplot(match_table) +
    facet_wrap(
        "label_domains",
        scales = "free"
    ) +
    aes(
        x = pmin(N_READS_LEFT, N_READS_RIGHT),
        y = LOD_SCORE,
        color = expected_match
    ) +
    geom_hline(
        aes(yintercept = LOD_threshold),
        data = threshold_table
    ) +
    rasterise(geom_point(size = 0.1), dpi = 1200) +
    geom_hline(
        aes(yintercept = LOD_threshold),
        data = threshold_table,
        alpha = 0.5
    ) +
    labs(
        x = "Minimum read count of sample pair",
        y = "LOD score",
        color = "Expected match based on individual label"
    ) +
    theme(
        legend.position = "top",
        axis.text.x = element_text(angle = 30, hjust = 1, vjust = 1),
    )
with_pdf(
    "FigureSX_LBP_LOD_Thresholds.pdf",
    width = 9,
    height = 7,
    print(p)
)
