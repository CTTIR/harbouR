# harbouR explorer — Shiny app
# UI packages are in Suggests; the launcher gates on requireNamespace().
# Do not call library() or require() here.

source(file.path("modules", "mod_connect.R"), local = TRUE)
source(file.path("modules", "mod_base_overview.R"), local = TRUE)
source(file.path("modules", "mod_table_browser.R"), local = TRUE)
source(file.path("modules", "mod_query.R"), local = TRUE)
source(file.path("modules", "mod_cell_detail.R"), local = TRUE)

.hb_theme <- function() {
  bslib::bs_theme(
    version = 5,
    bg = "#121212",
    fg = "#e8e8e8",
    primary = "#5E2C8E",
    base_font = "Inter, -apple-system, BlinkMacSystemFont, sans-serif",
    code_font = "JetBrains Mono, Menlo, monospace"
  )
}

ui <- bslib::page_navbar(
  title = shiny::tagList(
    shiny::HTML('<svg width="20" height="20" viewBox="0 0 24 24" style="vertical-align:-3px"><circle cx="12" cy="12" r="3" fill="#5E2C8E"/><path d="M2 18 H22" stroke="#5E2C8E" stroke-width="2"/></svg>'),
    " harbouR explorer"
  ),
  theme = .hb_theme(),
  id = "main",
  bg = "#121212",
  header = shiny::tags$head(
    shiny::includeCSS(file.path("www", "custom.css"))
  ),
  bslib::nav_panel(
    "Connect",
    mod_connect_ui("connect")
  ),
  bslib::nav_panel(
    "Overview",
    mod_base_overview_ui("overview")
  ),
  bslib::nav_panel(
    "Tables",
    mod_table_browser_ui("browser")
  ),
  bslib::nav_panel(
    "Query",
    mod_query_ui("query")
  ),
  bslib::nav_spacer(),
  bslib::nav_item(shiny::textOutput("status_badge", inline = TRUE))
)

server <- function(input, output, session) {
  state <- shiny::reactiveValues(
    client = NULL,
    metadata = NULL,
    demo = FALSE,
    tables = list(),
    active_table = NULL,
    selected_row = NULL
  )

  preset <- shiny::getShinyOption("harbouR_preset_client", default = NULL)
  if (!is.null(preset) && inherits(preset, "harbour_client")) {
    state$client <- preset
    state$metadata <- tryCatch(harbouR::hb_metadata(preset), error = function(e) NULL)
  }

  mod_connect_server("connect", state)
  mod_base_overview_server("overview", state)
  mod_table_browser_server("browser", state)
  mod_query_server("query", state)
  mod_cell_detail_server("cell_detail", state)

  output$status_badge <- shiny::renderText({
    if (isTRUE(state$demo)) "DEMO" else if (!is.null(state$client)) "LIVE" else ""
  })
}

shiny::shinyApp(ui, server)
