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
#' the client itself stays headless. A missing one, or a `bslib` older
#' than 0.6.0, produces a single informative error rather than a stack
#' trace. The Excel download also needs `writexl`; without it the app
#' says so when you ask for one.
#'
#' Shiny refuses uploads over 5 MB by default, and a `.dtable` with
#' attachments is often larger, so while the app runs it accepts files up
#' to 1 GB. To choose another limit, set the `shiny.maxRequestSize`
#' option, in bytes, before calling `hb_run_explorer()`; a value you have
#' set is left as it is.
#'
#' @param x Optional `harbour_client` or `harbour_dtable` to open with.
#' @param ... Passed to [shiny::runApp()].
#' @param host Host to bind. Default `"127.0.0.1"`, this computer only.
#'   The app has no login: bound to an address others can reach, it hands
#'   them a client passed to it - its token, and a SQL box that can change
#'   the base - and whatever file is open.
#' @param port Port. Default `NULL`, letting Shiny choose.
#'
#' @return Invisible `NULL`; launches a Shiny application.
#' @family shiny
#' @examplesIf interactive()
#' # the bundled example base, no credentials needed
#' hb_run_explorer()
#'
#' # or start from a file, with its attachments, so that a .dtable
#' # download keeps them
#' path <- system.file("extdata", "example.dtable", package = "harbouR")
#' hb_run_explorer(hb_read_dtable(path, assets = "extract"))
#' @export
hb_run_explorer <- function(x = NULL, ..., host = "127.0.0.1", port = NULL) {
  rlang::check_dots_used()
  needed <- c("shiny", "bslib", "reactable")
  present <- vapply(needed, requireNamespace, logical(1), quietly = TRUE)
  # requireNamespace() ignores the minimum version DESCRIPTION gives, and
  # a bslib before 0.6.0 has no navset_card_underline().
  old_bslib <- present[["bslib"]] &&
    package_version(getNamespaceVersion("bslib")) < "0.6.0"
  if (old_bslib) {
    present[["bslib"]] <- FALSE
    needed[[2L]] <- "bslib (>= 0.6.0)"
  }
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
  # Shiny refuses uploads over 5 MB, and a real export with attachments is
  # often larger. Lift the cap to 1 GB for as long as the app runs, but
  # leave a limit the user chose alone.
  if (is.null(getOption("shiny.maxRequestSize"))) {
    rlang::local_options(shiny.maxRequestSize = 1024^3)
  }
  shiny::runApp(app, host = host, port = port, ...)
  invisible(NULL)
}
