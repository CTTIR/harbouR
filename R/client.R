#' Create a SeaTable client
#'
#' Builds a `harbour_client` object that holds the server URL, the user's
#' credentials and a lazily-fetched, transparently-refreshed base token.
#' The client is environment-backed, so internal token refreshes mutate
#' cached state in place without reassigning your variable.
#'
#' SeaTable uses a three-token model. `hb_client()` accepts either an
#' **API token** (per-base, long-lived, generated in the SeaTable UI) or
#' **username + password** (which yields an account token). In-base calls
#' transparently exchange these for a short-lived **base token**.
#'
#' Defaults for `server` and `api_token` are read from the environment
#' variables `SEATABLE_SERVER` and `SEATABLE_API_TOKEN`.
#'
#' @param server SeaTable server URL, e.g. `"https://cloud.seatable.io"`.
#'   Defaults to the `SEATABLE_SERVER` env var.
#' @param api_token Long-lived per-base API token. Defaults to the
#'   `SEATABLE_API_TOKEN` env var. Mutually exclusive with
#'   `username`/`password`.
#' @param username,password Account credentials. Used to acquire an account
#'   token. Mutually exclusive with `api_token`.
#' @param base_uuid Optional base UUID hint; usually discovered from the
#'   base-token exchange.
#' @param timeout Per-request timeout in seconds. Default `30`.
#' @param call Internal: error-propagation env. Not for direct use.
#'
#' @return A `harbour_client` object.
#'
#' @family client
#' @examplesIf interactive()
#' client <- hb_client(
#'   server = "https://cloud.seatable.io",
#'   api_token = Sys.getenv("SEATABLE_API_TOKEN")
#' )
#' print(client)
#' @export
hb_client <- function(server = Sys.getenv("SEATABLE_SERVER"),
                      api_token = Sys.getenv("SEATABLE_API_TOKEN"),
                      username = NULL,
                      password = NULL,
                      base_uuid = NULL,
                      timeout = 30,
                      call = rlang::caller_env()) {
  server <- if (is.null(server) || !nzchar(server)) NULL else server
  api_token <- if (is.null(api_token) || !nzchar(api_token)) NULL else api_token

  .check_string(server, call = call)
  if (!grepl("^https?://", server)) {
    cli::cli_abort(
      c("{.arg server} must begin with {.val http://} or {.val https://}.",
        "x" = "You supplied {.val {server}}."),
      call = call
    )
  }
  server <- sub("/+$", "", server)

  has_api <- !is.null(api_token)
  has_acct <- !is.null(username) || !is.null(password)
  if (has_api && has_acct) {
    cli::cli_abort(
      "Supply either {.arg api_token} or {.arg username}/{.arg password}, not both.",
      call = call
    )
  }
  if (!has_api && !has_acct) {
    cli::cli_abort(
      c("No credentials supplied.",
        "i" = "Provide {.arg api_token} or {.arg username} and {.arg password}, or set {.envvar SEATABLE_API_TOKEN}."),
      call = call
    )
  }
  if (has_acct) {
    .check_string(username, call = call)
    .check_string(password, call = call)
  }

  cl <- new_harbour_client(
    server = server,
    api_token = api_token,
    username = username,
    password = password,
    base_uuid = base_uuid,
    timeout = timeout
  )
  validate_harbour_client(cl, call = call)
  cl
}

#' @keywords internal
#' @noRd
new_harbour_client <- function(server, api_token, username, password,
                               base_uuid, timeout) {
  env <- new.env(parent = emptyenv())
  env$server <- server
  env$api_token <- api_token
  env$username <- username
  env$password <- password
  env$base_uuid <- base_uuid
  env$timeout <- timeout
  env$.account_token <- NULL
  env$.base_token <- NULL
  env$.base_token_expires <- NULL
  env$.dtable_server <- NULL
  env$.dtable_db <- NULL
  env$.workspace_id <- NULL
  env$.base_name <- NULL
  env$.metadata <- NULL
  class(env) <- c("harbour_client", "environment")
  env
}

#' @keywords internal
#' @noRd
validate_harbour_client <- function(x, call = rlang::caller_env()) {
  if (!inherits(x, "harbour_client")) {
    cli::cli_abort("Object is not a {.cls harbour_client}.", call = call)
  }
  if (!is.environment(x)) {
    cli::cli_abort("A {.cls harbour_client} must be environment-backed.", call = call)
  }
  if (is.null(x$server)) {
    cli::cli_abort("A {.cls harbour_client} must have a {.field server}.", call = call)
  }
  invisible(x)
}

#' Test whether an object is a harbour client
#'
#' @param x Object to test.
#' @return A single `TRUE` or `FALSE`.
#' @family client
#' @export
is_harbour_client <- function(x) inherits(x, "harbour_client")

#' @param x A `harbour_client`.
#' @param ... Unused.
#' @rdname hb_client
#' @export
print.harbour_client <- function(x, ...) {
  rlang::check_dots_empty()
  auth_mode <- if (!is.null(x$api_token)) "api_token" else "username/password"
  token_masked <- .mask_token(x$api_token %||% x$.account_token)
  base_name <- x$.base_name %||% "<not yet fetched>"
  base_uuid <- x$base_uuid %||% "<unknown>"
  expires <- format(x$.base_token_expires)
  cli::cli_h1("<harbour_client>")
  cli::cli_bullets(c(
    "*" = "server   : {.url {x$server}}",
    "*" = "auth     : {auth_mode}",
    "*" = "token    : {.val {token_masked}}",
    "*" = "base     : {.val {base_name}}",
    "*" = "base uuid: {.val {base_uuid}}",
    "*" = "expires  : {.val {expires}}"
  ))
  invisible(x)
}
