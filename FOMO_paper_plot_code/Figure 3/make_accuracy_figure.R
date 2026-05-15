#!/usr/bin/env Rscript

library(tidyverse)
library(ggplot2)
library(patchwork)
library(withr)
library(readr)

copy_ggplot <- function(p) unserialize(serialize(p, connection = NULL))

sim_results <- read_csv("merged_stats_df_20240401.csv.gz")

sim_param_names <- c(
    "n_subjects", "n_samples_per_subject", "n_swap_cats", "fraction_mislabel",
    "fraction_anchor", "fraction_ghost", "n_samples"
)

sim_results <- sim_results %>%
    mutate(
        net_genotyped_mislabels_fixed = n_genotyped_sample_mislabels_initial - n_genotyped_sample_mislabels_final,
        net_sample_accuracy = case_when(
            # We define net sample accuracy to be 1 when there are no initial
            # and no final mislabels.
            n_genotyped_sample_mislabels_initial == 0 & n_genotyped_sample_mislabels_final == 0 ~ 1,
            .default = net_genotyped_mislabels_fixed / n_genotyped_sample_mislabels_initial
        )
    )
summary(sim_results$net_sample_accuracy)

# No label domains (swapcats), ghosts, or anchors
sim_results_baseline <- sim_results %>%
    filter(
        fraction_ghost == 0,
        fraction_anchor == 0,
        n_swap_cats == 1
    )

sim_results_baseline_median <- sim_results_baseline %>%
    arrange(n_samples_per_subject) %>%
    mutate(n_samples_per_subject_plot = fct_inorder(if_else(
        n_samples_per_subject > 5,
        "6–10",
        as.character(n_samples_per_subject)
    ))) %>%
    group_by(fraction_mislabel, n_samples_per_subject_plot) %>%
    summarise(
        net_sample_accuracy = median(net_sample_accuracy, na.rm = TRUE),
        .groups = "drop"
    )

fig3a_data <- sim_results_baseline_median
fig3a <- ggplot(fig3a_data) +
    aes(
        x = fraction_mislabel,
        y = net_sample_accuracy,
        color = factor(n_samples_per_subject_plot),
        group = factor(n_samples_per_subject_plot)
    ) +
    geom_line(
        alpha = 0.3,
        position = position_dodge(width = 0.01),
    ) +
    geom_point(
        size = 1,
        position = position_dodge(width = 0.01)
    ) +
    labs(
        x = "Fraction of samples mislabeled",
        y = "Net sample accuracy (median)",
        color = "Samples per individual"
    ) +
    scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, length.out = 5)) +
    scale_color_hue() +
    scale_fill_hue() +
    theme(
        legend.position = "inside",
        legend.position.inside = c(0, 0),
        legend.justification = c(-0.05, -0.05)
    )

swap_cat_plot_data <- sim_results %>%
    filter(
        fraction_ghost == 0,
        fraction_anchor == 0,
        n_swap_cats %in% c(1, 3, 10)
    ) %>%
    group_by(fraction_mislabel, n_swap_cats) %>%
    summarise(net_sample_accuracy = median(net_sample_accuracy, na.rm = TRUE))

fig3b <- ggplot(swap_cat_plot_data) +
    aes(
        x = fraction_mislabel,
        y = net_sample_accuracy,
        color = factor(n_swap_cats),
        group = factor(n_swap_cats)
    ) +
    geom_line(
        alpha = 0.3,
        position = position_dodge(width = 0.01 / 2),
    ) +
    geom_point(
        size = 1,
        position = position_dodge(width = 0.01 / 2)
    ) +
    labs(
        x = "Fraction of samples mislabeled",
        y = "Net sample accuracy (median)",
        color = "Label domains"
    ) +
    scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, length.out = 5)) +
    scale_color_brewer(palette = "Dark2") +
    scale_fill_brewer(palette = "Dark2") +
    theme(
        legend.position = "inside",
        legend.position.inside = c(0, 0),
        legend.justification = c(-0.05, -0.05)
    )

figure3 <- (fig3a + fig3b) +
    plot_annotation(tag_levels = "a") +
    plot_layout(axes = "collect")
with_pdf(
    "Figure3_FOMO_accuracy.pdf",
    width = 8,
    height = 4,
    print(figure3)
)

# Numbers for paper text
sim_results_baseline %>%
    group_by(fraction_mislabel) %>%
    summarise(net_sample_accuracy = median(net_sample_accuracy, na.rm = TRUE))

sim_results %>%
    filter(
        n_swap_cats %in% c(1, 3, 10),
        fraction_anchor == 0,
        fraction_ghost == 0,
        fraction_mislabel == 0.4,
    ) %>%
    group_by(n_swap_cats) %>%
    summarise(net_sample_accuracy = median(net_sample_accuracy, na.rm = TRUE))
