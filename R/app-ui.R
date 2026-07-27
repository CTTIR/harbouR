#' The explorer's user interface
#'
#' The layout follows the job rather than the API: you are always looking
#' at one base, so the source and its tables live in a persistent rail,
#' and the main panel switches between what you want to do with the table
#' you picked.
#'
#' @return A `shiny` UI definition.
#' @keywords internal
#' @noRd
.hb_app_ui <- function() {
  shiny::tagList(
    .hb_styles(),
    shiny::tags$html(lang = "en"),
    .hb_masthead(),
    bslib::page_sidebar(
      window_title = "harbouR explorer",
      theme = .hb_theme(),
      sidebar = bslib::sidebar(
        width = 320,
        open = "always",
        .hb_source_ui(),
        shiny::tags$hr(),
        shiny::tags$div(
          class = "d-flex justify-content-between align-items-baseline",
          shiny::tags$strong("Tables"),
          shiny::textOutput("table_count", inline = TRUE)
        ),
        shiny::uiOutput("table_list")
      ),
      bslib::navset_card_underline(
        id = "panel",
        bslib::nav_panel("Data", .hb_data_ui()),
        bslib::nav_panel("Schema", .hb_schema_ui()),
        bslib::nav_panel("Query", .hb_query_ui()),
        bslib::nav_panel("Export", .hb_export_ui())
      )
    )
  )
}

#' @keywords internal
#' @noRd
.hb_masthead <- function() {
  pal <- .hb_palette()
  shiny::tags$header(
    class = "hb-masthead",
    role = "banner",
    shiny::HTML(sprintf(
      '<svg width="22" height="22" viewBox="0 0 24 24" aria-hidden="true">
         <path d="M12 2 L21 20 H3 Z" fill="%s"/>
         <path d="M12 8 L17 20 H7 Z" fill="%s"/>
         <circle cx="12" cy="16" r="2.2" fill="%s"/>
       </svg>', pal[["kelp"]], pal[["tide"]], pal[["beacon"]]
    )),
    shiny::tags$span(
      class = "hb-wordmark",
      shiny::HTML("harbou<span>R</span> explorer")
    ),
    shiny::tags$span(class = "flex-grow-1"),
    shiny::uiOutput("source_badge", inline = TRUE)
  )
}

#' @keywords internal
#' @noRd
.hb_source_ui <- function() {
  shiny::tagList(
    shiny::uiOutput("source_panel")
  )
}

#' @keywords internal
#' @noRd
.hb_source_fields <- function(open) {
  shiny::tags$details(
    open = if (open) NA else NULL,
    shiny::tags$summary(
      class = "fw-semibold",
      "Source"
    ),
    shiny::tags$div(
      class = "pt-2",
      shiny::fileInput(
        "dtable_file", "Open a .dtable file",
        accept = c(".dtable", ".zip"), buttonLabel = "Browse",
        width = "100%"
      ),
      shiny::actionButton(
        "use_demo", "Use the example base",
        class = "btn-sm btn-outline-secondary w-100 mb-3"
      ),
      shiny::tags$div(
        class = "pt-1",
        shiny::textInput(
          "server", "Server",
          value = Sys.getenv("SEATABLE_SERVER", "https://cloud.seatable.io"),
          width = "100%"
        ),
        # Never seeded from the environment: a value passed to
        # passwordInput() is serialised into the page HTML.
        shiny::passwordInput("token", "API token", width = "100%"),
        shiny::actionButton("connect", "Connect",
                            class = "btn-primary btn-sm")
      )
    )
  )
}

#' @keywords internal
#' @noRd
.hb_data_ui <- function() {
  shiny::tagList(
    shiny::tags$div(
      class = "d-flex gap-2 align-items-center mb-2 flex-wrap",
      shiny::uiOutput("data_title", inline = TRUE),
      shiny::tags$span(class = "flex-grow-1"),
      shiny::numericInput(
        "n_max", "Rows", value = 1000, min = 1, max = 100000,
        step = 500, width = "110px"
      )
    ),
    shiny::uiOutput("data_panel")
  )
}

#' @keywords internal
#' @noRd
.hb_schema_ui <- function() {
  shiny::tagList(
    shiny::tags$p(
      class = "text-muted small",
      "Every column, the SeaTable type it holds, and the R type harbouR
       reads it as."
    ),
    shiny::uiOutput("schema_legend"),
    shiny::uiOutput("schema_panel")
  )
}

#' @keywords internal
#' @noRd
.hb_query_ui <- function() {
  shiny::tagList(
    shiny::tags$p(
      class = "text-muted small",
      "SeaTable SQL. Needs a server connection; a local file has no
       query engine."
    ),
    shiny::textAreaInput(
      "sql", NULL, width = "100%", height = "110px",
      placeholder = "select * from Samples limit 100"
    ),
    shiny::uiOutput("run_sql_ui"),
    shiny::tags$hr(),
    shiny::uiOutput("query_panel")
  )
}

#' @keywords internal
#' @noRd
.hb_export_ui <- function() {
  shiny::tagList(
    shiny::tags$p(
      class = "text-muted small",
      "Download the whole base. A .dtable keeps everything; a spreadsheet
       flattens the columns a cell cannot hold."
    ),
    shiny::uiOutput("export_panel")
  )
}
