mod_query_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::card(
    bslib::card_header("SQL console"),
    shiny::textAreaInput(ns("sql"), "Query",
                         value = "select * from Samples limit 10",
                         width = "100%", height = "120px"),
    shiny::actionButton(ns("run"), "Run", class = "btn-primary"),
    shiny::tags$hr(),
    reactable::reactableOutput(ns("result"))
  )
}

mod_query_server <- function(id, state) {
  shiny::moduleServer(id, function(input, output, session) {
    result <- shiny::reactiveVal(NULL)
    shiny::observeEvent(input$run, {
      if (isTRUE(state$demo) || is.null(state$client)) {
        shiny::showNotification(
          "SQL requires a live connection. Connect first or use the Tables tab.",
          type = "warning"
        )
        return()
      }
      r <- tryCatch(harbouR::hb_query(state$client, input$sql),
                    error = function(e) {
                      shiny::showNotification(conditionMessage(e),
                                              type = "error")
                      NULL
                    })
      result(r)
    })
    output$result <- reactable::renderReactable({
      shiny::req(result())
      reactable::reactable(result(), searchable = TRUE, pagination = TRUE)
    })
  })
}
