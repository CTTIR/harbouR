mod_cell_detail_server <- function(id, state) {
  shiny::moduleServer(id, function(input, output, session) {
    # Placeholder for row detail; opened by mod_table_browser via state$selected_row.
    invisible(NULL)
  })
}
