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
#' @param workspace_id,base_name Which base to work on. Required for a
#'   `username`/`password` client, because an account token is scoped to
#'   the user rather than to a base. Ignored when `api_token` is used,
#'   since an API token names its base implicitly.
#' @param timeout Per-request timeout in seconds. Default `30`.
#'
#' @param ... These dots are for future extensions and must be empty.
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
                      ...,
                      username = NULL,
                      password = NULL,
                      base_uuid = NULL,
                      workspace_id = NULL,
                      base_name = NULL,
                      timeout = 30) {
  rlang::check_dots_empty()
  server <- if (is.null(server) || !nzchar(server)) NULL else server
  api_token <- if (is.null(api_token) || !nzchar(api_token)) NULL else api_token

  .check_string(server)
  if (!grepl("^https?://", server)) {
    hb_abort(
      c("{.arg server} must begin with {.val http://} or {.val https://}.",
        "x" = "You supplied {.val {server}}."
      ),
      class = "harbour_error_bad_argument"
    )
  }
  server <- sub("/+$", "", server)

  has_api <- !is.null(api_token)
  has_acct <- !is.null(username) || !is.null(password)
  if (has_api && has_acct) {
    hb_abort(
      c("Supply either {.arg api_token} or {.arg username} and
         {.arg password}, not both."),
      class = "harbour_error_auth"
    )
  }
  if (!has_api && !has_acct) {
    hb_abort(
      c("No credentials supplied.",
        "i" = "Provide {.arg api_token}, or {.arg username} and
               {.arg password}, or set {.envvar SEATABLE_API_TOKEN}."
      ),
      class = "harbour_error_auth"
    )
  }
  if (has_acct) {
    .check_string(username)
    .check_string(password)
  }

  if (has_acct && (is.null(workspace_id) || is.null(base_name))) {
    cli::cli_warn(c(
      "A username/password client also needs {.arg workspace_id} and
       {.arg base_name} before it can reach a base.",
      "i" = "An {.arg api_token} is scoped to one base and needs neither."
    ))
  }
  cl <- new_harbour_client(
    server = server,
    api_token = api_token,
    username = username,
    password = password,
    base_uuid = base_uuid,
    workspace_id = workspace_id,
    base_name = base_name,
    timeout = timeout
  )
  validate_harbour_client(cl)
  cl
}

#' @keywords internal
#' @noRd
new_harbour_client <- function(server, api_token, username, password,
                               base_uuid, timeout,
                               workspace_id = NULL, base_name = NULL) {
  env <- new.env(parent = emptyenv())
  env$server <- server
  env$api_token <- api_token
  env$username <- username
  env$password <- password
  env$base_uuid <- base_uuid
  env$workspace_id <- workspace_id
  env$base_name <- base_name
  env$timeout <- timeout
  env$.account_token <- NULL
  env$.base_token <- NULL
  env$.base_token_expires <- NULL
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
    hb_abort("Object is not a {.cls harbour_client}.",
      call = call,
      class = "harbour_error_bad_argument"
    )
  }
  if (!is.environment(x)) {
    hb_abort("A {.cls harbour_client} must be environment-backed.",
      call = call,
      class = "harbour_error_bad_argument"
    )
  }
  if (is.null(x$server)) {
    hb_abort("A {.cls harbour_client} must have a {.field server}.",
      call = call,
      class = "harbour_error_bad_argument"
    )
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
  cli::cli_h1("<harbour_client>")
  lines <- format(x)
  names(lines) <- rep("*", length(lines))
  cli::cli_bullets(lines)
  invisible(x)
}

#' @param x A `harbour_client`.
#' @param ... Unused.
#' @rdname hb_client
#' @export
format.harbour_client <- function(x, ...) {
  rlang::check_dots_empty()
  auth_mode <- if (!is.null(x$api_token)) "api_token" else "username/password"
  c(
    sprintf("server   : %s", x$server),
    sprintf("auth     : %s", auth_mode),
    sprintf("token    : %s", .mask_token(x$api_token %||% x$.account_token)),
    sprintf("base     : %s", x$.base_name %||% x$base_name %||%
              "<not yet fetched>"),
    sprintf("base uuid: %s", x$base_uuid %||% "<unknown>"),
    sprintf("expires  : %s", .hb_format_expiry(x$.base_token_expires))
  )
}
