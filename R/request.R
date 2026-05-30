#' Internal HTTP engine
#'
#' Every endpoint wrapper in harbouR routes through `.hb_request()`. It
#' resolves the right base URL for the target service, injects the correct
#' `Authorization` header, performs the request via `httr2`, transparently
#' refreshes the base-token on `401`/`403` once, and translates non-2xx
#' responses into informative `cli`-formatted errors that never include
#' the token.
#'
#' @keywords internal
#' @noRd
.hb_user_agent <- function() {
  "harbouR (https://github.com/r-heller/harbouR)"
}

#' @keywords internal
#' @noRd
.hb_base_url <- function(client, service = c("web", "dtable_server", "dtable_db")) {
  service <- match.arg(service)
  switch(
    service,
    web = client$server,
    dtable_server = client$.dtable_server %||% client$server,
    dtable_db = client$.dtable_db %||% client$server
  )
}

#' @keywords internal
#' @noRd
.hb_auth_header <- function(client, auth = c("base", "account", "api")) {
  auth <- match.arg(auth)
  switch(
    auth,
    api = {
      tok <- client$api_token
      if (is.null(tok)) {
        cli::cli_abort("API token required but client has none.")
      }
      paste("Token", tok)
    },
    account = {
      tok <- client$.account_token %||% .hb_get_account_token(client)
      paste("Token", tok)
    },
    base = {
      tok <- client$.base_token %||% .hb_get_base_token(client)
      paste("Token", tok)
    }
  )
}

#' @keywords internal
#' @noRd
.hb_get_account_token <- function(client) {
  if (is.null(client$username) || is.null(client$password)) {
    cli::cli_abort(
      c("This call requires an account token.",
        "i" = "Create the client with {.arg username} and {.arg password}.")
    )
  }
  req <- httr2::request(client$server) |>
    httr2::req_url_path("/api2/auth-token/") |>
    httr2::req_method("POST") |>
    httr2::req_user_agent(.hb_user_agent()) |>
    httr2::req_timeout(client$timeout %||% 30) |>
    httr2::req_body_json(list(
      username = client$username,
      password = client$password
    ))
  resp <- .hb_perform_raw(req)
  body <- .hb_resp_json(resp)
  tok <- body$token %||% body$auth_token
  if (is.null(tok)) {
    cli::cli_abort("Account-token response had no {.field token} field.")
  }
  client$.account_token <- tok
  tok
}

#' @keywords internal
#' @noRd
.hb_get_base_token <- function(client) {
  if (!is.null(client$api_token)) {
    req <- httr2::request(client$server) |>
      httr2::req_url_path("/api/v2.1/dtable/app-access-token/") |>
      httr2::req_headers(Authorization = paste("Token", client$api_token)) |>
      httr2::req_user_agent(.hb_user_agent()) |>
      httr2::req_timeout(client$timeout %||% 30)
  } else {
    cli::cli_abort(
      c("Account-token base-access exchange is not implemented for this auth mode.",
        "i" = "Create the client with {.arg api_token}.")
    )
  }
  resp <- .hb_perform_raw(req)
  body <- .hb_resp_json(resp)
  client$.base_token <- body$access_token %||% body$dtable_access_token
  client$.dtable_server <- body$dtable_server %||% client$server
  client$.dtable_db <- body$dtable_db %||% body$dtable_server %||% client$server
  client$.workspace_id <- body$workspace_id
  client$.base_uuid_seen <- body$dtable_uuid %||% body$base_uuid
  if (is.null(client$base_uuid)) client$base_uuid <- client$.base_uuid_seen
  client$.base_name <- body$dtable_name %||% body$name
  client$.base_token_expires <- as.POSIXct(Sys.time() + 3L * 24L * 60L * 60L)
  client$.base_token
}

#' @keywords internal
#' @noRd
.hb_refresh_base_token <- function(client) {
  client$.base_token <- NULL
  .hb_get_base_token(client)
}

#' @keywords internal
#' @noRd
.hb_req <- function(client, path, service = c("web", "dtable_server", "dtable_db"),
                    auth = c("base", "account", "api"), query = NULL) {
  service <- match.arg(service)
  auth <- match.arg(auth)
  base <- .hb_base_url(client, service)
  req <- httr2::request(base) |>
    httr2::req_url_path(path) |>
    httr2::req_user_agent(.hb_user_agent()) |>
    httr2::req_headers(
      Authorization = .hb_auth_header(client, auth),
      Accept = "application/json"
    ) |>
    httr2::req_timeout(client$timeout %||% 30) |>
    httr2::req_retry(
      max_tries = 3,
      is_transient = function(resp) httr2::resp_status(resp) %in% c(429L, 500L, 502L, 503L, 504L)
    )
  if (!is.null(query)) req <- httr2::req_url_query(req, !!!query)
  req
}

#' @keywords internal
#' @noRd
.hb_perform_raw <- function(req) {
  tryCatch(
    httr2::req_perform(req),
    httr2_http_404 = function(e) {
      cli::cli_abort(c("Endpoint not found.",
                       "x" = "HTTP 404 at {.url {.hb_safe_url(req)}}"))
    },
    httr2_http = function(e) {
      .hb_translate_error(e)
    }
  )
}

#' @keywords internal
#' @noRd
.hb_safe_url <- function(req) {
  url <- tryCatch(req$url, error = function(e) "<unknown>")
  url
}

#' @keywords internal
#' @noRd
.hb_translate_error <- function(e) {
  resp <- e$resp
  status <- if (!is.null(resp)) httr2::resp_status(resp) else NA_integer_
  body <- tryCatch(httr2::resp_body_json(resp), error = function(.) NULL)
  msg <- body$error_msg %||% body$detail %||% body$msg %||% body$message %||%
    "SeaTable returned an error."
  hint <- switch(
    as.character(status),
    "401" = "Check that the API token is valid for this base.",
    "403" = "Check that the token has permission for this endpoint.",
    "404" = "Verify the path and base UUID.",
    "429" = "Rate-limited - slow down or batch your requests.",
    NULL
  )
  cli::cli_abort(c(
    "SeaTable request failed (HTTP {status}).",
    "x" = "{msg}",
    if (!is.null(hint)) c("i" = hint) else NULL
  ))
}

#' @keywords internal
#' @noRd
.hb_perform <- function(req, client, auth = "base") {
  resp <- tryCatch(
    httr2::req_perform(req),
    httr2_http = function(e) e
  )
  if (inherits(resp, "httr2_response")) return(resp)
  e <- resp
  status <- if (!is.null(e$resp)) httr2::resp_status(e$resp) else NA_integer_
  if (isTRUE(auth == "base") && !is.na(status) && status %in% c(401L, 403L)) {
    .hb_refresh_base_token(client)
    req2 <- httr2::req_headers(req,
      Authorization = .hb_auth_header(client, "base")
    )
    return(.hb_perform_raw(req2))
  }
  .hb_translate_error(e)
}

#' @keywords internal
#' @noRd
.hb_resp_json <- function(resp) {
  body <- tryCatch(
    httr2::resp_body_json(resp, simplifyVector = FALSE),
    error = function(e) {
      cli::cli_abort(c("Could not parse JSON response.",
                       "x" = "HTTP {httr2::resp_status(resp)}"))
    }
  )
  body
}

#' @keywords internal
#' @noRd
.hb_request <- function(client, path, service = "dtable_server", auth = "base",
                        method = "GET", query = NULL, body = NULL) {
  req <- .hb_req(client, path, service = service, auth = auth, query = query)
  req <- httr2::req_method(req, method)
  if (!is.null(body)) {
    req <- httr2::req_body_json(req, body)
  }
  resp <- .hb_perform(req, client, auth = auth)
  if (identical(httr2::resp_status(resp), 204L)) {
    return(invisible(NULL))
  }
  .hb_resp_json(resp)
}
