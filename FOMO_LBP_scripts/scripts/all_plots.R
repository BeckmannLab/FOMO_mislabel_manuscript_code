library(data.table)
library(dplyr)
library(ggplot2)

crosscheck_output_df <- fread("[PROJECT_DIR]/LBP/all_files/crosscheck_output_df.csv", data.table=FALSE)
sample_metadata_df <- fread("[PROJECT_DIR]/LBP/all_files/sample_metadata_df.csv", data.table=FALSE)

crosscheck_output_df2 <- crosscheck_output_df %>%
    left_join(
        sample_metadata_df[, c("INDEX", "ASSAYGROUP", "N_READS", "IID")] %>%
            transmute(INDEX, LEFT_ASSAYGROUP = ASSAYGROUP, LEFT_N_READS = N_READS, LEFT_IID = IID),
        by=c("indexA"="INDEX")
    ) %>%
    left_join(
        sample_metadata_df[, c("INDEX", "ASSAYGROUP", "N_READS", "IID")] %>%
            transmute(INDEX, RIGHT_ASSAYGROUP = ASSAYGROUP, RIGHT_N_READS = N_READS, RIGHT_IID = IID),
        by=c("indexB"="INDEX")
    ) %>%
    mutate(
        MIN_N_READS = pmin(LEFT_N_READS, RIGHT_N_READS),
        ASSAYGROUPA = pmin(LEFT_ASSAYGROUP, RIGHT_ASSAYGROUP),
        ASSAYGROUPB = pmax(LEFT_ASSAYGROUP, RIGHT_ASSAYGROUP),
        ASSAYCOMP = paste(ASSAYGROUPA, ASSAYGROUPB, sep="#"),
        ASSAYGROUPA_SHORT = case_match(
            ASSAYGROUPA,
            c("WGSVUMC", "WGSISMMS") ~ "WGS",
            c("BULKRNASEQ779", "BULKRNASEQEXO") ~ "BULKRNA",
            c("EXORNASEQ") ~ "EXORNA",
            c("SCRNASEQ", "SCRNASEQFACS") ~ "SCRNA",
            .default = "OTHER"
        ),
        ASSAYGROUPB_SHORT = case_match(
            ASSAYGROUPB,
            c("WGSVUMC", "WGSISMMS") ~ "WGS",
            c("BULKRNASEQ779", "BULKRNASEQEXO") ~ "BULKRNA",
            c("EXORNASEQ") ~ "EXORNA",
            c("SCRNASEQ", "SCRNASEQFACS") ~ "SCRNA",
            .default = "OTHER"
        ),
        ASSAYCOMP_SHORT = paste(ASSAYGROUPA_SHORT, ASSAYGROUPB_SHORT, sep="#"),
        EXPECTED_MATCH = LEFT_IID == RIGHT_IID
    )

crosscheck_output_df2$MIN_N_READS <- as.numeric(crosscheck_output_df2$MIN_N_READS)
crosscheck_output_df2$LOD_SCORE <- as.numeric(crosscheck_output_df2$LOD_SCORE)

my_plot <- ggplot(crosscheck_output_df2, aes(x=LOD_SCORE, group=EXPECTED_MATCH, color=EXPECTED_MATCH, fill=EXPECTED_MATCH)) +
    facet_wrap("ASSAYCOMP_SHORT", scales="free_y") +
    geom_histogram(stat="bin", binwidth=10, position="stack") +
    xlim(-50, 50)
ggsave("~/www/LBP/LOD_histogram_zoom.png", my_plot, width=10, height=7)

my_plot <- ggplot(crosscheck_output_df2, aes(x=LOD_SCORE, group=EXPECTED_MATCH, color=EXPECTED_MATCH, fill=EXPECTED_MATCH)) +
    facet_wrap("ASSAYCOMP_SHORT", scales="free_y") +
    scale_y_log10() + 
    geom_histogram(stat="bin", binwidth=10, position="stack") 
ggsave("~/www/LBP/LOD_histogram_full.png", my_plot, width=10, height=7)

my_plot <- ggplot(crosscheck_output_df2, aes(x=MIN_N_READS/1e6, y=LOD_SCORE, color=EXPECTED_MATCH)) +
    facet_wrap("ASSAYCOMP_SHORT") +
    geom_point(size=0.75, alpha=0.5, shape=1) +
    labs(title = "LOD scores for pairwise Crosscheck comparisons (LBP)",
         x = "Number of Reads (lesser of two samples, in millions)",
         y = "LOD Score") +
    theme(plot.title = element_text(hjust = 0.5))
ggsave("~/www/LBP/LOD_vs_read_count_facet_by_comp_type.png", my_plot, width=10, height=7)

thresholds <- seq.int(-20,20,1)
counts <- integer(length=length(thresholds))
for (i in 1:length(thresholds)) {
    counts[i] <- crosscheck_output_df2 %>% 
        filter(LOD_SCORE > thresholds[i]) %>% 
        nrow()
}
data_df <- data.frame(LOD_SCORE=thresholds, counts=counts)
my_plot <- ggplot(data_df, aes(x=LOD_SCORE, y=counts)) +
    geom_point() +
    theme_bw() 
ggsave("~/www/LBP/LOD_cdf.png", my_plot, width=10, height=7)
