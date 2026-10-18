#' Internal HTTP engine
#'
#' Every endpoint wrapper in harbouR routes through `.hb_request()`. It
#' resolves the right base URL for the target service, injects the correct
#' `Authorization` header, performs the request via `httr2`, transparently
#' refreshes the base token once on `401`, and translates non-2xx responses
#' into classed, `cli`-formatted errors that never include the token.
#'
#' @keywords internal
#' @noRd
.hb_user_agent <- function() {
  "harbouR (https://github.com/CTTIR/harbouR)"
}

#' @keywords internal
#' @noRd
.hb_base_url <- function(client, service = c("gateway", "web")) {
  service <- rlang::arg_match(service)
  # Both are served from the main host. Before 4.4 base operations lived on
  # separate dtable-server and dtable-db hosts; those were deprecated in 5.2
  # and removed in 5.3, and harbouR no longer addresses them.
  switch(service,
    gateway = client$server,
    web = client$server
  )
}

#' @keywords internal
#' @noRd
.hb_auth_header <- function(client,
                            auth = c("base", "account", "api", "none"),
                            call = rlang::caller_env()) {
  auth <- rlang::arg_match(auth)
  switch(auth,
    none = NULL,
    api = {
      tok <- client$api_token
      if (is.null(tok)) {
        hb_abort(
          c("This call requires an API token.",
            "i" = "Create the client with {.arg api_token}."
          ),
          class = "harbour_error_auth",
          call = call
        )
      }
      paste("Token", tok)
    },
    account = {
      tok <- client$.account_token %||%
        .hb_get_account_token(client, call = call)
      paste("Token", tok)
    },
    base = {
      tok <- client$.base_token %||% .hb_get_base_token(client, call = call)
      # The gateway expects Bearer for base tokens. `Token` is still right
      # for the web API's account and API tokens, handled above.
      paste("Bearer", tok)
    }
  )
}

#' @keywords internal
#' @noRd
.hb_get_account_token <- function(client, call = rlang::caller_env()) {
  if (is.null(client$username) || is.null(client$password)) {
    hb_abort(
      c("This call requires an account token.",
        "i" = "Create the client with {.arg username} and {.arg password}."
      ),
      class = "harbour_error_auth",
      call = call
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
  resp <- .hb_perform_raw(req, call = call)
  body <- .hb_resp_json(resp, call = call)
  tok <- body$token %||% body$auth_token
  if (is.null(tok)) {
    hb_abort(
      "Account-token response had no {.field token} field.",
      class = "harbour_error_auth",
      call = call
    )
  }
  client$.account_token <- tok
  tok
}

#' @keywords internal
#' @noRd
.hb_get_base_token <- function(client, call = rlang::caller_env()) {
  req <- if (!is.null(client$api_token)) {
    # An API token is issued for one base, so it names the base implicitly.
    httr2::request(client$server) |>
      httr2::req_url_path("/api/v2.1/dtable/app-access-token/") |>
      httr2::req_headers(Authorization = paste("Token", client$api_token))
  } else {
    # An account token is issued for the user, so the base must be named.
    .hb_check_account_base(client, call = call)
    httr2::request(sprintf(
      "%s/api/v2.1/workspace/%s/dtable/%s/access-token/",
      client$server,
      .hb_url_escape(client$workspace_id),
      .hb_url_escape(client$base_name)
    )) |>
      httr2::req_headers(
        Authorization = .hb_auth_header(client, "account", call = call)
      )
  }
  req <- req |>
    httr2::req_user_agent(.hb_user_agent()) |>
    httr2::req_timeout(client$timeout %||% 30)
  resp <- .hb_perform_raw(req, call = call)
  body <- .hb_resp_json(resp, call = call)
  tok <- body$access_token %||% body$dtable_access_token
  if (is.null(tok)) {
    # Without this check the next request would go out as "Bearer " and
    # fail with a 401 that blames the credentials rather than the reply.
    hb_abort(
      "Base-token response had no {.field access_token} field.",
      class = "harbour_error_auth",
      call = call
    )
  }
  client$.base_token <- tok
  client$.workspace_id <- body$workspace_id
  client$.base_uuid_seen <- body$dtable_uuid %||% body$base_uuid
  if (is.null(client$base_uuid)) client$base_uuid <- client$.base_uuid_seen
  client$.base_name <- body$dtable_name %||% body$name
  client$.base_token_expires <- as.POSIXct(Sys.time() + 3L * 24L * 60L * 60L)
  client$.base_token
}

#' @keywords internal
#' @noRd
.hb_refresh_base_token <- function(client, call = rlang::caller_env()) {
  client$.base_token <- NULL
  .hb_get_base_token(client, call = call)
}

#' @keywords internal
#' @noRd
.hb_req <- function(client,
                    path,
                    service = c("gateway", "web"),
                    auth = c("base", "account", "api", "none"),
                    query = NULL,
                    call = rlang::caller_env()) {
  service <- rlang::arg_match(service)
  auth <- rlang::arg_match(auth)
  base <- .hb_base_url(client, service)
  transient <- function(resp) {
    httr2::resp_status(resp) %in% c(429L, 500L, 502L, 503L, 504L)
  }
  # Build the full URL and hand it to request() rather than using
  # req_url_path(): that re-encodes, turning an already-escaped %20 into
  # %2520, and it leaves "/" alone, so a view named "a/b" would split into
  # two path segments. .hb_base_path() has already escaped every segment.
  req <- httr2::request(paste0(base, path)) |>
    httr2::req_user_agent(.hb_user_agent()) |>
    httr2::req_headers(
      # NULL drops the header, which is what `auth = "none"` wants: some
      # endpoints (ping, server-info) reject a token they did not expect.
      Authorization = .hb_auth_header(client, auth, call = call),
      Accept = "application/json"
    ) |>
    httr2::req_timeout(client$timeout %||% 30) |>
    httr2::req_retry(max_tries = 3, is_transient = transient)
  if (!is.null(query)) req <- httr2::req_url_query(req, !!!query)
  req
}

#' @keywords internal
#' @noRd
.hb_perform_raw <- function(req, path = NULL, call = rlang::caller_env()) {
  rlang::try_fetch(
    httr2::req_perform(req, path = path),
    httr2_http = function(cnd) .hb_translate_error(cnd, call = call)
  )
}

#' @keywords internal
#' @noRd
.hb_translate_error <- function(e, call = rlang::caller_env()) {
  resp <- e$resp
  status <- if (!is.null(resp)) httr2::resp_status(resp) else NA_integer_
  body <- .hb_error_body(resp)
  msg <- .hb_error_message(body)
  url <- tryCatch(resp$url, error = function(cnd) NULL) %||% NA_character_
  hint <- switch(as.character(status),
    "401" = "Check that the API token is valid for this base.",
    "403" = "Check that the token has permission for this endpoint.",
    "404" = "Verify the path and base UUID.",
    "429" = "Rate-limited - slow down or batch your requests.",
    NULL
  )
  hb_abort(
    c("SeaTable request failed (HTTP {status}).",
      "x" = "{msg}",
      if (!is.null(hint)) c("i" = hint) else NULL
    ),
    class = .hb_http_class(status),
    status = status,
    url = url,
    # Not `body`: rlang::abort() reserves that name for the message body,
    # and a parsed JSON list there aborts with an rlang error instead.
    response_body = body,
    call = call
  )
}

#' Read an error response's body without trusting its content type
#'
#' Some endpoints answer a 400 with a plain-text body - `Column ColA
#' exists.` - under an `application/json` content type, so
#' `resp_body_json()` fails and the server's explanation would be lost.
#'
#' @param resp An `httr2_response`, or `NULL`.
#' @return The parsed JSON, the body text when it is not JSON, or `NULL`.
#' @keywords internal
#' @noRd
.hb_error_body <- function(resp) {
  if (is.null(resp)) {
    return(NULL)
  }
  text <- tryCatch(httr2::resp_body_string(resp), error = function(cnd) NULL)
  if (is.null(text) || !nzchar(trimws(text))) {
    return(NULL)
  }
  tryCatch(
    jsonlite::fromJSON(text, simplifyVector = FALSE),
    error = function(cnd) trimws(text)
  )
}

#' Pull the server's explanation out of an error body
#'
#' @param body What `.hb_error_body()` returned.
#' @return A single string.
#' @keywords internal
#' @noRd
.hb_error_message <- function(body) {
  msg <- if (is.list(body)) {
    body$error_msg %||% body$error_message %||% body$detail %||%
      body$msg %||% body$message
  } else if (!grepl("^\\s*<", body %||% "<")) {
    # Plain text is shown; an HTML error page from a proxy is not.
    substr(body, 1L, 300L)
  }
  if (is.character(msg) && length(msg) == 1L && nzchar(msg)) {
    return(msg)
  }
  "SeaTable returned an error."
}

#' @keywords internal
#' @noRd
.hb_perform <- function(req, client, auth = "base",
                        call = rlang::caller_env()) {
  rlang::try_fetch(
    httr2::req_perform(req),
    httr2_http_401 = function(cnd) {
      # A 401 means the base token has expired. Refresh once and retry.
      # A 403 is NOT retried: the token is valid but lacks permission, and
      # retrying only doubles the request and misreports the cause.
      if (!identical(auth, "base")) {
        .hb_translate_error(cnd, call = call)
      }
      .hb_refresh_base_token(client, call = call)
      req2 <- httr2::req_headers(
        req,
        Authorization = .hb_auth_header(client, "base", call = call)
      )
      .hb_perform_raw(req2, call = call)
    },
    httr2_http = function(cnd) .hb_translate_error(cnd, call = call)
  )
}

#' @keywords internal
#' @noRd
.hb_resp_json <- function(resp, call = rlang::caller_env()) {
  body <- rlang::try_fetch(
    httr2::resp_body_json(resp, simplifyVector = FALSE),
    error = function(cnd) {
      hb_abort(
        c("Could not parse the server's JSON response.",
          "x" = "HTTP {httr2::resp_status(resp)}"
        ),
        class = "harbour_error_http",
        status = httr2::resp_status(resp),
        call = call,
        parent = cnd
      )
    }
  )
  body
}

#' @keywords internal
#' @noRd
.hb_request <- function(client, path, service = "gateway", auth = "base",
                        method = "GET", query = NULL, body = NULL,
                        call = rlang::caller_env()) {
  req <- .hb_req(
    client, path,
    service = service, auth = auth, query = query, call = call
  )
  req <- httr2::req_method(req, method)
  if (!is.null(body)) {
    # jsonlite writes a missing number as the *string* "NA" unless told
    # otherwise, so an empty numeric cell would reach SeaTable as text.
    req <- httr2::req_body_json(req, body, na = "null")
  }
  resp <- .hb_perform(req, client, auth = auth, call = call)
  if (identical(httr2::resp_status(resp), 204L)) {
    return(invisible(NULL))
  }
  .hb_resp_json(resp, call = call)
}

#' An account client must name the base it wants
#'
#' An API token is issued for one base, so it identifies the base by
#' itself. An account token is issued for the user, so the workspace and
#' base have to be named explicitly.
#'
#' @param client A `harbour_client`.
#' @param call The frame to blame for any error.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_check_account_base <- function(client, call = rlang::caller_env()) {
  absent <- c(
    if (is.null(client$workspace_id)) "workspace_id",
    if (is.null(client$base_name)) "base_name"
  )
  if (length(absent) > 0L) {
    hb_abort(
      c("A username/password client must name the base it works on.",
        "x" = "Missing: {.arg {absent}}.",
        "i" = "Pass them to {.fn hb_client}, or use an {.arg api_token},
               which is scoped to a single base."),
      class = "harbour_error_auth",
      call = call
    )
  }
  invisible(NULL)
}
