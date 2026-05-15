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

# triangle vertex shape
mytriangle <- function(coords, v = NULL, params) {
    vertex.color <- params("vertex", "color")
    if (length(vertex.color) != 1 && !is.null(v)) {
        vertex.color <- vertex.color[v]
    }
    vertex.size <- params("vertex", "size")
    if (length(vertex.size) != 1 && !is.null(v)) {
        vertex.size <- vertex.size[v]
    }
    symbols(
        x = coords[, 1], y = coords[, 2], bg = vertex.color,
        stars = cbind(vertex.size, vertex.size, vertex.size),
        add = TRUE, inches = FALSE
    )
}
add_shape("triangle",
    clip = shape_noclip,
    plot = mytriangle
)

solver_pre <- qs_read("solver_pre_solve.qs2")
solver_post <- qs_read("solver_solved.qs2")
corrections_summary <- read_excel("corrections_summary.xlsx")

mislabeled_init_sample_ids <- corrections_summary %>%
    filter(Mislabeled) %>%
    pull(Initial_Sample_ID)

plot_attributes_table <- solver_pre@.solve_state$unsolved_relabel_data %>%
    select(Init_Sample_ID) %>%
    left_join(solver_pre@swap_cats, join_by(Init_Sample_ID == Sample_ID)) %>%
    mutate(
        color = case_when(
            Init_Sample_ID %in% solver_pre@.solve_state$unsolved_ghost_data$Init_Sample_ID ~
                muted("gray", c = 0, l = 80),
            Init_Sample_ID %in% mislabeled_init_sample_ids ~
                muted("red", c = 70, l = 80),
            .default = muted("green", c = 70, l = 80)
        ),
        SwapCat_Shape = case_match(
            SwapCat_ID,
            "Geno" ~ "triangle",
            "WGS" ~ "square",
            "RNA" ~ "circle",
            .default = "circle"
        ),
        vertex_size_scalar = 0.5 * case_match(
            SwapCat_Shape,
            "dot" ~ 1,
            "circle" ~ 1,
            "square" ~ 1,
            "triangle" ~ 1.5,
            .default = 1
        )
    )

relabel_data_for_graph <- solver_pre@.solve_state$unsolved_relabel_data %>%
    bind_rows(solver_pre@.solve_state$unsolved_ghost_data) %>%
    mutate(
        SwapCat_Shape = case_match(
            SwapCat_ID,
            "Geno" ~ "triangle",
            "WGS" ~ "square",
            "RNA" ~ "circle",
            .default = "circle"
        ),
        vertex_size_scalar = 0.5 * case_match(
            SwapCat_Shape,
            "dot" ~ 1,
            "circle" ~ 1,
            "square" ~ 1,
            "triangle" ~ 1.5,
            .default = 1
        )
    )

graph <- fomo:::.generate_graph(
    relabel_data_for_graph,
    graph_type = "combined",
    NULL,
    genotype_matrix = solver_pre@genotype_matrix,
    populate_plotting_attributes = TRUE,
    collapse_samples = FALSE
)
graph <- subgraph(graph, relabel_data_for_graph$Init_Sample_ID)
V(graph)$color <- case_when(
    names(V(graph)) %in% solver_pre@.solve_state$unsolved_ghost_data$Init_Sample_ID ~
        muted("gray", c = 0, l = 80),
    names(V(graph)) %in% mislabeled_init_sample_ids ~
        muted("red", c = 70, l = 80),
    .default = muted("green", c = 70, l = 80)
)

V(graph)$size <- relabel_data_for_graph$vertex_size_scalar * 1
component_graphs <- relabel_data_for_graph %>%
    split(.$Init_Component_ID) %>%
    map(\(x) subgraph(graph = graph, x$Init_Sample_ID))
with_cropped_pdf(
    "MSC19B_mislabel_network_components.pdf",
    for (gr in component_graphs) {
        with_seed(1986, {
            V(gr)$size <- V(gr)$size * 12
            gr$layout <- layout_with_kk
            plot(gr)
        })
    },
    height = 10,
    width = 10
)

# Big component
with_cropped_pdf(
    "MSC19B_mislabel_network_big_component.pdf",
    with_seed(1986, {
        gr <- component_graphs$Component_001
        V(gr)$size <- V(gr)$size * 12
        gr$layout <- layout_with_kk
        plot(gr, vertex.label = NA)
    }),
    height = 8,
    width = 8
)

# Fully mislabeled individual
with_cropped_pdf(
    "MSC19B_mislabel_network_fully_missed_individual.pdf",
    with_seed(1986, {
        gr <- component_graphs$Component_013
        V(gr)$size <- V(gr)$size * 12 * 2.25
        gr$layout <- layout_with_kk
        plot(gr, vertex.label = NA)
        # plot(gr)
    }),
    height = 5,
    width = 5
)
