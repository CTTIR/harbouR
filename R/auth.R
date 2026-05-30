#' Ping the SeaTable server
#'
#' Issues a lightweight request against the server's ping endpoint to
#' verify connectivity and credentials. Returns `TRUE` on success and
#' errors informatively on failure.
#'
#' @inheritParams hb_metadata
#' @return A single `TRUE` on success; errors otherwise.
#' @family client
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_ping(client)
#' @export
hb_ping <- function(client, call = rlang::caller_env()) {
  .check_client(client, call = call)
  res <- tryCatch(
    .hb_request(client, "/api2/ping/", service = "web", auth = "api",
                method = "GET"),
    error = function(e) e
  )
  if (inherits(res, "error")) {
    cli::cli_abort(c("Could not reach {.url {client$server}}.",
                     "x" = conditionMessage(res)), call = call)
  }
  TRUE
}

#' Server information
#'
#' Returns the SeaTable server's reported version and basic info.
#'
#' @inheritParams hb_metadata
#' @return A one-row tibble with columns `server` (chr), `version` (chr) and
#'   `edition` (chr) where reported.
#' @family client
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_server_info(client)
#' @export
hb_server_info <- function(client, call = rlang::caller_env()) {
  .check_client(client, call = call)
  body <- .hb_request(client, "/server-info/", service = "web", auth = "api",
                      method = "GET")
  tibble::tibble(
    server = client$server,
    version = body$version %||% NA_character_,
    edition = body$edition %||% NA_character_
  )
}
