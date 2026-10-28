#' Read a packaged branding asset
#'
#' Assets are local package files, independent of application data.
#' @keywords internal
#' @noRd
.hb_brand_text <- function(file) {
  path <- system.file("branding", file, package = "harbouR")
  if (!nzchar(path)) {
    hb_abort(
      "The packaged branding asset {.file {file}} is missing.",
      class = "harbour_error_package_asset", file = file
    )
  }
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

#' Encode a packaged logo for an image source
#' @keywords internal
#' @noRd
.hb_brand_uri <- function(file) {
  paste0("data:image/svg+xml,",
         utils::URLencode(.hb_brand_text(file), reserved = TRUE))
}

#' Add the browser icon and theme styles
#' @keywords internal
#' @noRd
.hb_brand_head <- function() {
  shiny::singleton(shiny::tags$head(
    shiny::tags$link(rel = "icon", type = "image/svg+xml",
                     href = .hb_brand_uri("favicon.svg")),
    shiny::tags$style(shiny::HTML(.hb_brand_text("branding.css")))
  ))
}

#' Build the named light and dark application artwork
#' @keywords internal
#' @noRd
.hb_brand_logo <- function(height = 64, mode = c("auto", "light", "dark")) {
  mode <- match.arg(mode)
  shiny::tagList(
    .hb_brand_head(),
    shiny::tags$span(
      class = "cttir-app-brand", `data-cttir-mode` = mode,
      style = sprintf("--cttir-brand-height:%spx;--cttir-brand-width:%spx;",
                      height, round(height * 432 / 498, 2)),
      shiny::tags$img(
        src = .hb_brand_uri("logo.svg"),
        class = "cttir-app-brand-light", alt = "harbouR logo"
      ),
      shiny::tags$img(
        src = .hb_brand_uri("logo-dark.svg"),
        class = "cttir-app-brand-dark", alt = "harbouR logo"
      )
    )
  )
}
