#' Conditions signalled by harbouR
#'
#' Every error harbouR raises carries the class `harbour_error`, plus a
#' more specific subclass, so callers can react to *what* went wrong
#' rather than matching on message text.
#'
#' @section Condition classes:
#'
#' \describe{
#'   \item{`harbour_error_auth`}{Credentials are missing, malformed, or
#'     were rejected by the server. Fields: none.}
#'   \item{`harbour_error_http`}{The server returned a non-2xx status that
#'     has no more specific subclass. Fields: `status`, `url`, `body`.}
#'   \item{`harbour_error_not_found`}{HTTP 404, or a named table, view or
#'     column that does not exist in the base. Fields: `status`, `url`,
#'     `body` for the HTTP case.}
#'   \item{`harbour_error_permission`}{HTTP 403. The token is valid but
#'     is not allowed to do this. Fields: `status`, `url`, `body`.}
#'   \item{`harbour_error_rate_limit`}{HTTP 429. Fields: `status`, `url`,
#'     `body`.}
#'   \item{`harbour_error_bad_argument`}{An argument failed validation
#'     before any request was made. Fields: none.}
#'   \item{`harbour_error_unsupported`}{The operation is not available -
#'     for example an auth mode that this endpoint does not accept.}
#'   \item{`harbour_error_column_collision`}{A column in the data would
#'     collide with a reserved SeaTable field name.}
#' }
#'
#' All of them also inherit from `harbour_error` and from `rlang_error`.
#'
#' @examples
#' res <- tryCatch(
#'   hb_client(server = "https://example.org"),
#'   harbour_error_auth = function(cnd) "no credentials"
#' )
#' res
#'
#' @name harbouR-conditions
NULL

#' Signal a harbouR error
#'
#' Thin wrapper around [cli::cli_abort()] that prepends the shared
#' `harbour_error` class. Every abort site in the package goes through it,
#' so no error escapes without a class.
#'
#' @param message A character vector, formatted by cli.
#' @param class Character. The specific subclass, without the
#'   `harbour_error_` prefix already applied - pass the full class name.
#' @param ... Named data fields stored on the condition.
#' @param call The execution environment to blame for the error.
#' @param parent An upstream condition to chain, or `NULL`.
#' @param .envir Environment in which the cli message is interpolated.
#'   Defaults to the caller's frame, which is where the values referenced
#'   by `{braces}` in `message` actually live.
#'
#' @return Never returns; throws a condition.
#' @keywords internal
#' @noRd
hb_abort <- function(message,
                     class = NULL,
                     ...,
                     call = rlang::caller_env(),
                     parent = NULL,
                     .envir = rlang::caller_env()) {
  cli::cli_abort(
    message,
    class = c(class, "harbour_error"),
    ...,
    call = call,
    parent = parent,
    .envir = .envir
  )
}

#' Map an HTTP status onto a harbouR condition class
#'
#' @param status Integer HTTP status code.
#' @return A single string naming the condition subclass.
#' @keywords internal
#' @noRd
.hb_http_class <- function(status) {
  if (is.na(status)) {
    return("harbour_error_http")
  }
  switch(
    as.character(status),
    "401" = "harbour_error_auth",
    "403" = "harbour_error_permission",
    "404" = "harbour_error_not_found",
    "429" = "harbour_error_rate_limit",
    "harbour_error_http"
  )
}
