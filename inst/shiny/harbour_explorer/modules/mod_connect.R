mod_connect_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_columns(
    col_widths = c(6, 6),
    bslib::card(
      bslib::card_header("Connect to a base"),
      shiny::textInput(ns("server"), "Server URL",
                       value = Sys.getenv("SEATABLE_SERVER")),
      shiny::passwordInput(ns("token"), "API token",
                           value = Sys.getenv("SEATABLE_API_TOKEN")),
      shiny::actionButton(ns("connect"), "Connect",
                          class = "btn-primary"),
      shiny::tags$hr(),
      shiny::actionButton(ns("demo"), "Try demo (offline)"),
      shiny::tags$div(id = ns("msg"))
    ),
    bslib::card(
      bslib::card_header("About"),
      shiny::tags$p("harbouR is an unofficial, independent client. ",
                    "SeaTable is a trademark of SeaTable GmbH; this ",
                    "package is not affiliated with or endorsed by ",
                    "SeaTable GmbH.")
    )
  )
}

mod_connect_server <- function(id, state) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::observeEvent(input$connect, {
      result <- tryCatch({
        cl <- harbouR::hb_client(server = input$server,
                                 api_token = input$token)
        meta <- harbouR::hb_metadata(cl)
        list(ok = TRUE, client = cl, metadata = meta)
      }, error = function(e) list(ok = FALSE, message = conditionMessage(e)))
      if (isTRUE(result$ok)) {
        state$client <- result$client
        state$metadata <- result$metadata
        state$demo <- FALSE
        shiny::showNotification("Connected.", type = "message")
      } else {
        shiny::showNotification(
          paste("Could not connect:", result$message),
          type = "error"
        )
      }
    })

    shiny::observeEvent(input$demo, {
      state$client <- NULL
      state$metadata <- harbouR::hb_example_metadata()
      state$demo <- TRUE
      state$tables <- list(
        Samples = harbouR::hb_example_rows("Samples"),
        Patients = harbouR::hb_example_rows("Patients")
      )
      shiny::showNotification("Demo data loaded.", type = "message")
    })
  })
}
