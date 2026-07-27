#' Launch the harbouR explorer
#'
#' A Shiny app for working with a SeaTable base without writing code:
#' open a local `.dtable` export or connect to a server, browse the
#' tables, read the schema, run SQL, and download the result as
#' `.dtable`, Excel or CSV.
#'
#' Pass a connected [hb_client()] or a base read with [hb_read_dtable()]
#' to start there. With no argument the app opens on its source panel,
#' which offers a bundled example base that needs no credentials and no
#' network.
#'
#' The UI packages (`shiny`, `bslib`, `reactable`) are in `Suggests`, so
#' the client itself stays headless. A missing one produces a single
#' informative error rather than a stack trace.
#'
#' @param x Optional `harbour_client` or `harbour_dtable` to open with.
#' @param ... Passed to [shiny::runApp()].
#' @param host Host to bind. Default `"127.0.0.1"`.
#' @param port Port. Default `NULL`, letting Shiny choose.
#'
#' @return Invisible `NULL`; launches a Shiny application.
#' @family shiny
#' @examplesIf interactive()
#' # the bundled example base, no credentials needed
#' hb_run_explorer()
#'
#' # or start from a file
#' hb_run_explorer(hb_read_dtable("my-base.dtable"))
#' @export
hb_run_explorer <- function(x = NULL, ..., host = "127.0.0.1", port = NULL) {
  rlang::check_dots_used()
  needed <- c("shiny", "bslib", "reactable")
  present <- vapply(needed, requireNamespace, logical(1), quietly = TRUE)
  if (!all(present)) {
    absent <- needed[!present]
    hb_abort(
      c("The harbouR explorer needs additional packages.",
        "x" = "Missing: {.pkg {absent}}.",
        "i" = "Install them with {.code install.packages()}."),
      class = "harbour_error_unsupported"
    )
  }
  if (!is.null(x) && !is_harbour_client(x) && !is_harbour_dtable(x)) {
    hb_abort(
      c("{.arg x} must be a {.cls harbour_client} or a
         {.cls harbour_dtable}.",
        "x" = "You supplied an object of class {.cls {class(x)}}."),
      class = "harbour_error_bad_argument"
    )
  }
  app <- shiny::shinyApp(
    ui = .hb_app_ui(),
    server = .hb_app_server(preset = x)
  )
  shiny::runApp(app, host = host, port = port, ...)
  invisible(NULL)
}
