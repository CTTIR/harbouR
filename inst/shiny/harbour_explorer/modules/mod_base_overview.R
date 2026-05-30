mod_base_overview_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::layout_columns(
      col_widths = c(4, 4, 4),
      bslib::value_box(title = "Base", value = shiny::textOutput(ns("base_name"))),
      bslib::value_box(title = "Tables", value = shiny::textOutput(ns("n_tables"))),
      bslib::value_box(title = "Rows (cached)", value = shiny::textOutput(ns("n_rows")))
    ),
    bslib::card(
      bslib::card_header("Tables overview"),
      DT::DTOutput(ns("tables_dt"))
    ),
    bslib::card(
      bslib::card_header("Rows per table"),
      shiny::plotOutput(ns("rows_plot"), height = "240px")
    )
  )
}

.hb_overview_plot <- function(df) {
  ggplot2::ggplot(df, ggplot2::aes(x = .data$name, y = .data$rows)) +
    ggplot2::geom_col(fill = "#5E2C8E") +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(x = NULL, y = "Rows", title = "Rows per table")
}

mod_base_overview_server <- function(id, state) {
  shiny::moduleServer(id, function(input, output, session) {
    output$base_name <- shiny::renderText({
      shiny::req(state$metadata)
      bn <- state$metadata$base_name
      if (is.null(bn) || is.na(bn)) "<unknown>" else bn
    })
    output$n_tables <- shiny::renderText({
      shiny::req(state$metadata)
      as.character(length(state$metadata$tables))
    })
    output$n_rows <- shiny::renderText({
      shiny::req(state$tables)
      as.character(sum(vapply(state$tables, nrow, integer(1))))
    })
    output$tables_dt <- DT::renderDT({
      shiny::req(state$metadata)
      tibble::as_tibble(state$metadata)
    }, options = list(dom = "tip", pageLength = 5))
    output$rows_plot <- shiny::renderPlot({
      shiny::req(state$tables)
      df <- data.frame(
        name = names(state$tables),
        rows = vapply(state$tables, nrow, integer(1)),
        stringsAsFactors = FALSE
      )
      .hb_overview_plot(df)
    })
  })
}

