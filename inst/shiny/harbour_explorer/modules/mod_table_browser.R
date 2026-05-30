mod_table_browser_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      shiny::selectInput(ns("table"), "Table", choices = NULL),
      shiny::tags$h6("Schema"),
      DT::DTOutput(ns("schema_dt"))
    ),
    reactable::reactableOutput(ns("rows_tbl"))
  )
}

.hb_render_list_cell <- function(value) {
  if (is.null(value) || length(value) == 0L) return("")
  if (is.list(value[[1]])) {
    nms <- vapply(value, function(v) {
      nm <- v$name
      if (is.null(nm)) "<file>" else as.character(nm)
    }, character(1))
    return(paste(nms, collapse = ", "))
  }
  paste(as.character(unlist(value)), collapse = ", ")
}

mod_table_browser_server <- function(id, state) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::observe({
      shiny::req(state$metadata)
      tbls <- vapply(state$metadata$tables, function(t) t$name, character(1))
      sel <- if (!is.null(state$active_table)) state$active_table else tbls[[1]]
      shiny::updateSelectInput(session, "table", choices = tbls, selected = sel)
    })

    shiny::observeEvent(input$table, {
      shiny::req(input$table)
      state$active_table <- input$table
      if (!is.null(state$tables[[input$table]])) return()
      if (isTRUE(state$demo)) {
        state$tables[[input$table]] <- harbouR::hb_example_rows(input$table)
        return()
      }
      shiny::req(state$client)
      shiny::withProgress(message = "Reading table...", {
        state$tables[[input$table]] <-
          tryCatch(harbouR::hb_read_table(state$client, input$table),
                   error = function(e) tibble::tibble())
      })
    })

    output$schema_dt <- DT::renderDT({
      shiny::req(state$metadata, input$table)
      tbls <- state$metadata$tables
      idx <- match(input$table, vapply(tbls, function(t) t$name, character(1)))
      cols <- tbls[[idx]]$columns %||% list()
      tibble::tibble(
        column = vapply(cols, function(c) c$name %||% "?", character(1)),
        type = vapply(cols, function(c) c$type %||% "?", character(1))
      )
    }, options = list(dom = "t", pageLength = 30))

    output$rows_tbl <- reactable::renderReactable({
      shiny::req(input$table)
      df <- state$tables[[input$table]]
      shiny::req(df)
      list_cols <- vapply(df, is.list, logical(1))
      if (any(list_cols)) {
        for (cn in names(df)[list_cols]) {
          df[[cn]] <- vapply(df[[cn]], .hb_render_list_cell, character(1))
        }
      }
      reactable::reactable(df, searchable = TRUE, filterable = TRUE,
                           pagination = TRUE, defaultPageSize = 25)
    })
  })
}
