#' Internal HTTP engine
#'
#' Every endpoint wrapper in harbouR routes through `.hb_request()`. It
#' resolves the right base URL for the target service, injects the correct
#' `Authorization` header, performs the request via `httr2`, renews the
#' base token before it lapses and once more if the server refuses it, and
#' translates non-2xx responses and transport failures into classed,
#' `cli`-formatted errors that never include the token.
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
      tok <- client$.base_token
      if (is.null(tok)) {
        tok <- .hb_get_base_token(client, call = call)
      } else if (.hb_base_token_lapsing(client)) {
        # Renewed early, so the cached token still works for a few minutes:
        # if the exchange fails for a moment - a server restarting, a rate
        # limit - the call goes ahead with it rather than failing. Refused
        # credentials, or a token already past its expiry, still fail.
        keep <- function(cnd) {
          expired <- .hb_base_token_lapsing(client, margin = 0)
          if (inherits(cnd, "harbour_error_auth") || expired) {
            return(rlang::zap())
          }
          tok
        }
        tok <- rlang::try_fetch(
          .hb_get_base_token(client, call = call),
          harbour_error_http = keep,
          harbour_error_rate_limit = keep
        )
      }
      # The gateway expects Bearer for base tokens. `Token` is still right
      # for the web API's account and API tokens, handled above.
      paste("Bearer", tok)
    }
  )
}

#' Is the cached base token about to lapse?
#'
#' A base token lives for three days by default, and the gateway refuses
#' an expired one with a 403 that reads like a missing permission, so it
#' is renewed a few minutes early instead. The token's own `exp` claim is
#' the authority; the expiry recorded when it was fetched stands in when
#' the token cannot be decoded. An unknown expiry does not count as
#' lapsing: such a token is used until the server refuses it.
#'
#' @param client A `harbour_client`.
#' @param margin Seconds before the expiry at which the token is renewed.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_base_token_lapsing <- function(client, margin = 300) {
  expiry <- .hb_jwt_expiry(client$.base_token) %||%
    client$.base_token_expires
  known <- inherits(expiry, "POSIXct") && length(expiry) == 1L &&
    !is.na(expiry)
  if (!known) {
    return(FALSE)
  }
  Sys.time() >= expiry - margin
}

#' Read the expiry out of a JWT
#'
#' A base token is a JWT whose payload carries its expiry as `exp`, in
#' seconds since the epoch. The payload is base64url, which swaps two
#' characters of base64 and drops the padding.
#'
#' @param token A base token.
#' @return A `POSIXct`, or `NULL` when `token` is not a JWT with a numeric
#'   `exp` claim.
#' @keywords internal
#' @noRd
.hb_jwt_expiry <- function(token) {
  if (!is.character(token) || length(token) != 1L || is.na(token)) {
    return(NULL)
  }
  parts <- strsplit(token, ".", fixed = TRUE)[[1L]]
  if (length(parts) != 3L) {
    return(NULL)
  }
  payload <- chartr("-_", "+/", parts[[2L]])
  payload <- paste0(payload, strrep("=", (4L - nchar(payload) %% 4L) %% 4L))
  claims <- tryCatch(
    jsonlite::parse_json(rawToChar(jsonlite::base64_dec(payload))),
    error = function(cnd) NULL
  )
  exp <- if (is.list(claims)) claims$exp
  if (!is.numeric(exp) || length(exp) != 1L || !is.finite(exp)) {
    return(NULL)
  }
  # jsonlite reads a whole number as an integer; a time is a double.
  .POSIXct(as.numeric(exp))
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
  # paste0() rather than req_url_path(), which would replace the path of a
  # server reached under a prefix such as https://example.org/seatable.
  req <- httr2::request(paste0(client$server, "/api2/auth-token/")) |>
    httr2::req_method("POST") |>
    httr2::req_user_agent(.hb_user_agent()) |>
    httr2::req_timeout(client$timeout %||% 30) |>
    httr2::req_body_json(list(
      username = client$username,
      password = client$password
    ))
  resp <- rlang::try_fetch(
    .hb_perform_raw(req, call = call),
    harbour_error = function(cnd) {
      # A wrong password is a 400 here, with the reason in
      # `non_field_errors`. A 400 that is not JSON comes from a proxy in
      # front of the server - plain HTTP sent to an HTTPS port, say - and
      # says nothing about the credentials.
      if (identical(cnd$status, 400L) && !is.list(cnd$response_body)) {
        return(rlang::zap())
      }
      .hb_rejected_credentials(
        cnd, c(400L, 401L, 403L),
        "SeaTable rejected the username and password (HTTP {status}).",
        "Check the {.arg username} and {.arg password} given to
         {.fn hb_client}.",
        call = call
      )
    }
  )
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
  # The workspace and base the client named, for a reply that leaves them
  # out. An API-token client names neither.
  named_workspace <- NULL
  named_base <- NULL
  if (!is.null(client$api_token)) {
    # An API token is issued for one base, so it names the base implicitly.
    req <- httr2::request(
      paste0(client$server, "/api/v2.1/dtable/app-access-token/")
    ) |>
      httr2::req_headers(Authorization = paste("Token", client$api_token))
    # An API token SeaTable does not know is refused with a 403.
    refused <- "SeaTable rejected the API token (HTTP {status})."
    hint <- "Check that {.arg api_token} is complete and has not been
             deleted from the base."
  } else {
    # An account token is issued for the user, so the base must be named.
    .hb_check_account_base(client, call = call)
    workspace <- .hb_format_id(client$workspace_id)
    base <- client$base_name
    req <- httr2::request(sprintf(
      "%s/api/v2.1/workspace/%s/dtable/%s/access-token/",
      client$server,
      .hb_url_escape(workspace),
      .hb_url_escape(base)
    )) |>
      httr2::req_headers(
        Authorization = .hb_auth_header(client, "account", call = call)
      )
    refused <- "SeaTable refused this account a token for base {.val {base}}
                (HTTP {status})."
    hint <- "Check that the account can open the base in workspace
             {workspace}, or call {.fn hb_check_credentials} to log in
             again."
    named_workspace <- workspace
    named_base <- base
  }
  req <- req |>
    httr2::req_user_agent(.hb_user_agent()) |>
    httr2::req_timeout(client$timeout %||% 30)
  # Neither exchange documents a 400, so only 401 and 403 are read as
  # refused credentials.
  resp <- rlang::try_fetch(
    .hb_perform_raw(req, call = call),
    harbour_error = function(cnd) {
      .hb_rejected_credentials(cnd, c(401L, 403L), refused, hint, call = call)
    }
  )
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
  # The account-token exchange replies with only the token and the UUID,
  # so an account client keeps the workspace and base it named itself.
  client$.workspace_id <- body$workspace_id %||% named_workspace
  client$.base_uuid_seen <- body$dtable_uuid %||% body$base_uuid
  if (is.null(client$base_uuid)) client$base_uuid <- client$.base_uuid_seen
  client$.base_name <- body$dtable_name %||% body$name %||% named_base
  client$.base_token_expires <- .hb_jwt_expiry(tok) %||%
    as.POSIXct(Sys.time() + 3L * 24L * 60L * 60L)
  client$.base_token
}

#' Report a refused token exchange as a credentials problem
#'
#' The token exchanges answer bad credentials with whichever status their
#' framework picks - a wrong password is a 400 at the login, an unknown
#' API token a 403 - so the status alone would not say what went wrong.
#' Both mean the credentials were refused, which is what
#' `harbour_error_auth` documents. The status's own class is kept as well,
#' so a handler written against it still matches.
#'
#' @param cnd The condition `.hb_perform_raw()` signalled.
#' @param statuses The statuses that mean the credentials were refused.
#' @param message,hint cli templates for the headline and the advice. They
#'   can use `status`, and the variables of the frame that called this.
#' @param call The frame to blame for the error.
#' @param .envir Where the templates' other variables live.
#' @return [rlang::zap()] for any other condition, which `try_fetch()`
#'   then lets through unchanged.
#' @keywords internal
#' @noRd
.hb_rejected_credentials <- function(cnd, statuses, message, hint,
                                     call = rlang::caller_env(),
                                     .envir = rlang::caller_env()) {
  status <- cnd$status
  if (length(status) != 1L || is.na(status) || !status %in% statuses) {
    return(rlang::zap())
  }
  env <- rlang::env(
    .envir,
    status = status,
    msg = .hb_error_message(cnd$response_body)
  )
  hb_abort(
    c(message, "x" = "{msg}", "i" = hint),
    class = unique(c("harbour_error_auth", .hb_http_class(status))),
    status = status,
    url = cnd$url,
    response_body = cnd$response_body,
    call = call,
    .envir = env
  )
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
                    method = "GET",
                    call = rlang::caller_env()) {
  service <- rlang::arg_match(service)
  auth <- rlang::arg_match(auth)
  base <- .hb_base_url(client, service)
  # Build the full URL and hand it to request() rather than using
  # req_url_path(): that re-encodes, turning an already-escaped %20 into
  # %2520, and it leaves "/" alone, so a view named "a/b" would split into
  # two path segments. .hb_base_path() has already escaped every segment.
  # The method is set here, with the retry policy chosen for it, so the two
  # cannot disagree.
  # Worked out once: req_headers() evaluates its arguments more than once,
  # which would fetch or renew a token twice.
  authorization <- .hb_auth_header(client, auth, call = call)
  req <- httr2::request(paste0(base, path)) |>
    httr2::req_method(method) |>
    httr2::req_user_agent(.hb_user_agent()) |>
    httr2::req_headers(
      # NULL drops the header, which is what `auth = "none"` wants: some
      # endpoints (ping, server-info) reject a token they did not expect.
      Authorization = authorization,
      Accept = "application/json"
    ) |>
    httr2::req_timeout(client$timeout %||% 30) |>
    httr2::req_retry(max_tries = 3, is_transient = .hb_retry_predicate(method))
  if (!is.null(query)) req <- httr2::req_url_query(req, !!!query)
  req
}

#' Which statuses a request may be re-sent after
#'
#' A 429 means the server declined the request without acting on it, so
#' sending it again is always safe. A 5xx can come from a proxy that gave
#' up on a write the server went on to apply - re-sending an insert would
#' then store its rows twice - so only the methods that change nothing are
#' re-sent after one.
#'
#' @param method The request's HTTP method.
#' @return An integer vector of HTTP statuses.
#' @keywords internal
#' @noRd
.hb_retry_statuses <- function(method) {
  if (toupper(method) %in% c("GET", "HEAD")) {
    c(429L, 500L, 502L, 503L, 504L)
  } else {
    429L
  }
}

#' The function that tells `req_retry()` whether to send a request again
#'
#' Made here rather than inside `.hb_req()`. A function keeps the frame it
#' was created in, and `.hb_req()`'s frame holds the client; the request
#' keeps the function, and a condition about the request keeps the
#' request, so saving that condition would save the client's credentials
#' with it.
#'
#' @param method The request's HTTP method.
#' @return A function of an `httr2_response`, returning `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_retry_predicate <- function(method) {
  retry_on <- .hb_retry_statuses(method)
  function(resp) httr2::resp_status(resp) %in% retry_on
}

#' @keywords internal
#' @noRd
.hb_perform_raw <- function(req, path = NULL, call = rlang::caller_env(),
                            client = NULL) {
  rlang::try_fetch(
    httr2::req_perform(req, path = path),
    httr2_failure = function(cnd) .hb_transport_error(cnd, req, call = call),
    httr2_http = function(cnd) {
      .hb_translate_error(cnd, call = call, client = client)
    }
  )
}

#' Report a request that never got an answer
#'
#' A refused connection, a DNS or TLS failure or a timeout reaches the
#' caller as httr2's `httr2_failure`, which carries no harbouR class. It is
#' re-signalled as `harbour_error_http` with no status, keeping httr2's
#' classes so a handler written for httr2 still matches.
#'
#' @param cnd The `httr2_failure` condition.
#' @param req The request that got no answer.
#' @param call The frame to blame for the error.
#' @return Never returns.
#' @keywords internal
#' @noRd
.hb_transport_error <- function(cnd, req, call = rlang::caller_env()) {
  url <- req$url %||% NA_character_
  server <- .hb_url_origin(url)
  # httr2's condition keeps the whole request, and the login request's body
  # holds the password in clear text. For that one, chain only the
  # transport error underneath, which says why without the request.
  login <- grepl("/api2/auth-token/", url, fixed = TRUE)
  cause <- cnd$parent
  # Only a failure before anything was sent means the server was never
  # reached. A timeout, a dropped connection or an empty reply can come
  # after the server received the request, and applied it.
  unreached <- inherits(cause, c(
    "curl_error_couldnt_resolve_host", "curl_error_couldnt_resolve_proxy",
    "curl_error_couldnt_connect", "curl_error_ssl_connect_error",
    "curl_error_peer_failed_verification"
  ))
  method <- toupper(req$method %||% if (is.null(req$body)) "GET" else "POST")
  message <- if (unreached) {
    c("Could not reach the SeaTable server at {.url {server}}.",
      "i" = "Check the server URL and your network connection.")
  } else {
    c("The request to the SeaTable server at {.url {server}} did not
       complete.",
      if (inherits(cause, "curl_error_operation_timedout")) {
        c("i" = "It took longer than the client's {.arg timeout} allows.")
      },
      if (!method %in% c("GET", "HEAD")) {
        c("!" = "The server may have applied this change; check before
                 sending it again.")
      })
  }
  hb_abort(
    message,
    class = c("harbour_error_http", "httr2_failure", "httr2_error"),
    status = NA_integer_,
    url = url,
    call = call,
    parent = if (login) cnd$parent else cnd
  )
}

#' The scheme, host and port of a URL
#'
#' @param url A single URL.
#' @return A single string; `url` itself if it cannot be parsed.
#' @keywords internal
#' @noRd
.hb_url_origin <- function(url) {
  parts <- tryCatch(httr2::url_parse(url), error = function(cnd) NULL)
  if (is.null(parts$scheme) || is.null(parts$hostname)) {
    return(url)
  }
  port <- if (!is.null(parts$port)) paste0(":", parts$port)
  paste0(parts$scheme, "://", parts$hostname, port)
}

#' @keywords internal
#' @noRd
.hb_translate_error <- function(e, call = rlang::caller_env(),
                                client = NULL) {
  resp <- e$resp
  status <- if (!is.null(resp)) httr2::resp_status(resp) else NA_integer_
  body <- .hb_error_body(resp)
  msg <- .hb_error_message(body)
  url <- tryCatch(resp$url, error = function(cnd) NULL) %||% NA_character_
  # A username/password client holds no API token, so do not send its
  # user looking for one.
  account <- !is.null(client) && is.null(client$api_token)
  hint <- switch(as.character(status),
    "401" = if (account) {
      "Check the {.arg username} and {.arg password}, and that the account
       can open this base."
    } else {
      "Check that the API token is valid for this base."
    },
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
#' The text is parsed with `jsonlite::parse_json()`, not `fromJSON()`:
#' the latter reads a short string that is not valid JSON as a file path
#' or a URL, and parses whatever it finds there instead.
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
    jsonlite::parse_json(text, simplifyVector = FALSE),
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
    # The login lists its reasons, a wrong password among them, as
    # `non_field_errors`.
    reasons <- unlist(body$non_field_errors, use.names = FALSE)
    body$error_msg %||% body$error_message %||% body$detail %||%
      body$msg %||% body$message %||%
      if (is.character(reasons) && length(reasons) > 0L) {
        paste(reasons, collapse = " ")
      }
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
  # Fetch a new base token and send the request again. This is done once:
  # .hb_perform_raw() reports whatever the second answer is.
  resend <- function() {
    .hb_refresh_base_token(client, call = call)
    authorization <- .hb_auth_header(client, "base", call = call)
    req2 <- httr2::req_headers(req, Authorization = authorization)
    .hb_perform_raw(req2, call = call, client = client)
  }
  rlang::try_fetch(
    httr2::req_perform(req),
    # try_fetch() keeps the handlers listed after a running handler
    # active, and a resend that fails to connect signals this class again,
    # already classed. Listing it first keeps it from being wrapped twice.
    httr2_failure = function(cnd) .hb_transport_error(cnd, req, call = call),
    httr2_http_401 = function(cnd) {
      # A base token that has lapsed or been revoked is refused: renew it
      # and retry.
      if (!identical(auth, "base")) {
        .hb_translate_error(cnd, call = call, client = client)
      }
      resend()
    },
    httr2_http_403 = function(cnd) {
      # The API gateway refuses a lapsed base token with 403 and "invalid
      # token". Any other 403 means the token is valid but lacks
      # permission, and retrying would only double the request and
      # misreport the cause.
      if (!identical(auth, "base") || !.hb_is_invalid_token(cnd$resp)) {
        .hb_translate_error(cnd, call = call, client = client)
      }
      resend()
    },
    httr2_http = function(cnd) {
      .hb_translate_error(cnd, call = call, client = client)
    }
  )
}

#' Did the gateway refuse the base token itself?
#'
#' The API gateway answers a base token it cannot verify, an expired one
#' included, with HTTP 403 and `invalid token` - the status it also uses
#' for a permission the token lacks. Only the message tells them apart.
#'
#' @param resp An `httr2_response`, or `NULL`.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_is_invalid_token <- function(resp) {
  body <- .hb_error_body(resp)
  msg <- if (is.list(body)) body$error_message %||% body$error_msg
  is.character(msg) && length(msg) == 1L && !is.na(msg) &&
    grepl("^\\s*invalid token\\.?\\s*$", msg, ignore.case = TRUE)
}

#' @keywords internal
#' @noRd
.hb_resp_json <- function(resp, call = rlang::caller_env()) {
  body <- rlang::try_fetch(
    {
      # The check resp_body_json() makes. Its error is chained beneath
      # harbouR's own, which names the function the user called, so it
      # names none itself.
      httr2::resp_check_content_type(
        resp,
        valid_types = "application/json",
        valid_suffix = "json",
        call = NULL
      )
      # resp_body_json() then hands the text to jsonlite::fromJSON(), which
      # reads a short string that is not valid JSON as a file path or a
      # URL and parses what it finds there; parse_json() only ever parses
      # the text it is given.
      jsonlite::parse_json(
        httr2::resp_body_string(resp, "UTF-8"),
        simplifyVector = FALSE
      )
    },
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
    service = service, auth = auth, query = query, method = method,
    call = call
  )
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
