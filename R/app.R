#' Launch the harbouR explorer
#'
#' Starts the bundled Shiny explorer app for inspecting a SeaTable base
#' interactively. Pass a connected `harbour_client` to skip the connect
#' screen, or run with no arguments to open the connect screen — which
#' also offers a fully offline demo mode powered by [hb_example_metadata()]
#' and [hb_example_rows()].
#'
#' The Shiny app and its UI dependencies (`shiny`, `bslib`, `DT`,
#' `reactable`, `ggplot2`) are in `Suggests`, not `Imports` — the core
#' client works headless. Missing dependencies produce a single informative
#' error rather than a stack trace.
#'
#' @param client Optional `harbour_client`. If `NULL`, the app opens its
#'   connect screen.
#' @param ... Forwarded to [shiny::runApp()].
#' @param host Host to bind. Default `"127.0.0.1"`.
#' @param port Port. Default `NULL` (let Shiny choose).
#'
#' @return Invisible `NULL`; launches a Shiny application.
#' @family shiny
#' @examplesIf interactive()
#' hb_run_explorer()
#' @export
hb_run_explorer <- function(client = NULL, ..., host = "127.0.0.1", port = NULL) {
  needed <- c("shiny", "bslib", "DT", "reactable", "ggplot2")
  missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "The harbouR explorer needs additional packages.",
      "x" = "Missing: {.pkg {missing}}.",
      "i" = "Install with: {.code install.packages(c({paste0('\"', missing, '\"', collapse = ', ')}))}."
    ))
  }
  if (!is.null(client)) .check_client(client)
  app_dir <- system.file("shiny", "harbour_explorer", package = "harbouR")
  if (!nzchar(app_dir)) {
    cli::cli_abort("Could not locate the bundled Shiny app directory.")
  }
  shiny::shinyOptions(harbouR_preset_client = client)
  shiny::runApp(app_dir, host = host, port = port, ...)
  invisible(NULL)
}
