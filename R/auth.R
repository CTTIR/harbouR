#' Check that a SeaTable server is reachable
#'
#' Issues a lightweight, unauthenticated request against the server's ping
#' endpoint. This tests *connectivity only* - use [hb_check_credentials()]
#' to test whether the client's credentials are accepted.
#'
#' Returns the client invisibly, so it composes:
#' `client |> hb_ping() |> hb_read_table("Samples")`.
#'
#' @inheritParams hb_metadata
#' @param ... These dots are for future extensions and must be empty.
#' @return The `client`, invisibly. Errors if the server is unreachable.
#' @family client
#' @seealso [hb_check_credentials()]
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_ping(client)
#' @export
hb_ping <- function(client, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  rlang::try_fetch(
    .hb_request(client, "/api2/ping/", service = "web", auth = "none",
                method = "GET"),
    error = function(cnd) {
      hb_abort(
        c("Could not reach {.url {client$server}}.",
          "i" = "Check the server URL and your network connection."),
        class = "harbour_error_http",
        parent = cnd
      )
    }
  )
  invisible(client)
}

#' Check that the client's credentials are accepted
#'
#' Exchanges the client's credentials for a token, which is the cheapest
#' way to find out whether they work. For an API-token client this fetches
#' a base token, and so also confirms the token is valid *for that base*;
#' for a username/password client it fetches an account token.
#'
#' Unlike [hb_ping()], which only proves the server is up, this proves the
#' credentials are usable.
#'
#' @inheritParams hb_metadata
#' @param ... These dots are for future extensions and must be empty.
#' @return The `client`, invisibly. Errors with a `harbour_error_auth`
#'   condition if the credentials are rejected.
#' @family client
#' @seealso [hb_ping()]
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_check_credentials(client)
#' @export
hb_check_credentials <- function(client, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  if (!is.null(client$api_token)) {
    .hb_refresh_base_token(client)
  } else {
    client$.account_token <- NULL
    .hb_get_account_token(client)
  }
  invisible(client)
}

#' Server information
#'
#' Returns the SeaTable server's reported version and basic info. This
#' endpoint is unauthenticated.
#'
#' @inheritParams hb_metadata
#' @param ... These dots are for future extensions and must be empty.
#' @return A one-row tibble with columns `server` (chr), `version` (chr) and
#'   `edition` (chr) where reported.
#' @family client
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_server_info(client)
#' @export
hb_server_info <- function(client, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  body <- .hb_request(client, "/server-info/", service = "web", auth = "none",
                      method = "GET")
  tibble::tibble(
    server = client$server,
    version = body$version %||% NA_character_,
    edition = body$edition %||% NA_character_
  )
}
