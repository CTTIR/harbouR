# The request engine under conditions the happy path never meets: a write
# the server may already have applied, a base token that has lapsed,
# credentials the server refuses, a server that cannot be reached, a
# server behind a path prefix, and reply bodies that are not JSON.
#
# Replies come from httr2::local_mocked_responses(), so every request goes
# through harbouR's real request code. Mocked replies bypass httr2's retry
# loop, which is why the retry policy is checked on the request itself.

# A reply as SeaTable sends it: JSON, under a JSON content type.
json_resp <- function(status, json, url = "https://demo.example.org/") {
  httr2::response(
    status_code = status,
    url = url,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw(json)
  )
}

# Answer every request with `respond(req)`, and keep each request seen.
local_replies <- function(respond, env = parent.frame()) {
  seen <- new.env(parent = emptyenv())
  seen$reqs <- list()
  httr2::local_mocked_responses(
    function(req) {
      seen$reqs[[length(seen$reqs) + 1L]] <- req
      respond(req)
    },
    env = env
  )
  seen
}

seen_urls <- function(seen) vapply(seen$reqs, function(r) r$url, "")

auth_of <- function(req) httr2::req_get_headers(req, "reveal")$Authorization

# A base token shaped like SeaTable's: a JWT whose payload carries `exp`.
# The payload includes characters base64url writes as "-" and "_", so
# reading it back exercises the alphabet swap as well as the padding.
fake_jwt <- function(exp) {
  b64url <- function(text) {
    chartr("+/", "-_", gsub("[\n=]", "", jsonlite::base64_enc(charToRaw(text))))
  }
  claims <- jsonlite::toJSON(
    list(exp = round(exp), dtable_uuid = "demo-uuid", note = "???>>>"),
    auto_unbox = TRUE, digits = NA
  )
  paste(
    b64url('{"alg":"HS256","typ":"JWT"}'), b64url(claims), "c2lnbmF0dXJl",
    sep = "."
  )
}

now <- function() as.numeric(Sys.time())

api_token_reply <- function(token) {
  sprintf(
    paste0(
      '{"app_name": "harbouR", "access_token": "%s",',
      ' "dtable_uuid": "demo-uuid", "dtable_server":',
      ' "https://demo.example.org/api-gateway/",',
      ' "workspace_id": 7, "use_api_gateway": true,',
      ' "dtable_name": "harbouR demo base"}'
    ),
    token
  )
}

account_client <- function(server = "https://demo.example.org",
                           password = "p", workspace_id = 7,
                           base_name = "My Base") {
  new_harbour_client(
    server = server, api_token = NULL, username = "u",
    password = password, base_uuid = NULL, timeout = 5,
    workspace_id = workspace_id, base_name = base_name
  )
}

api_client <- function(server = "https://demo.example.org",
                       api_token = "APITOKEN") {
  new_harbour_client(
    server = server, api_token = api_token, username = NULL,
    password = NULL, base_uuid = NULL, timeout = 5
  )
}

# How httr2 reports a request that got no answer: an `httr2_failure`
# around the transport error.
transport_failure <- function(reason = "Could not resolve host",
                              curl = "couldnt_resolve_host",
                              request = NULL) {
  # httr2's own condition carries the request it could not send.
  rlang::error_cnd(
    class = c("httr2_failure", "httr2_error"),
    message = "Failed to perform HTTP request.",
    request = request,
    parent = rlang::error_cnd(
      class = c(paste0("curl_error_", curl), "curl_error"),
      message = reason
    )
  )
}

# ---- Retries ---------------------------------------------------------------

test_that("only requests that change nothing are re-sent after a 5xx", {
  # A proxy can answer 502 or 504 after the server applied a write, so
  # re-sending an insert would store its rows twice. A 429 means the
  # server declined the request, so any request may be sent again.
  expect_identical(
    .hb_retry_statuses("GET"), c(429L, 500L, 502L, 503L, 504L)
  )
  expect_identical(
    .hb_retry_statuses("HEAD"), c(429L, 500L, 502L, 503L, 504L)
  )
  for (method in c("POST", "PUT", "DELETE", "post")) {
    expect_identical(.hb_retry_statuses(method), 429L, info = method)
  }
})

test_that("each request carries the retry policy of its own method", {
  cl <- mock_client()
  retried <- function(method, status) {
    req <- .hb_req(cl, "/x/", service = "web", auth = "api", method = method)
    req$policies$retry_is_transient(httr2::response(status_code = status))
  }
  expect_true(retried("GET", 503L))
  expect_true(retried("GET", 504L))
  expect_true(retried("POST", 429L))
  expect_false(retried("POST", 500L))
  expect_false(retried("POST", 502L))
  expect_false(retried("POST", 504L))
  expect_false(retried("PUT", 503L))
  expect_false(retried("DELETE", 500L))
})

test_that("a write goes out with the write policy", {
  cl <- mock_client()
  sent <- list()
  testthat::local_mocked_bindings(
    .hb_perform = function(req, client, auth = "base", call = NULL) {
      sent[[length(sent) + 1L]] <<- req
      make_resp(204L)
    },
    .package = "harbouR"
  )
  .hb_request(cl, "/rows/", method = "POST", body = list(rows = list()))
  .hb_request(cl, "/rows/")
  transient <- function(req, status) {
    req$policies$retry_is_transient(httr2::response(status_code = status))
  }
  expect_identical(sent[[1L]]$method, "POST")
  expect_false(transient(sent[[1L]], 502L))
  expect_true(transient(sent[[1L]], 429L))
  expect_true(transient(sent[[2L]], 502L))
})

# ---- Base-token renewal ----------------------------------------------------

test_that("a base token's expiry is read from the token itself", {
  exp <- round(now()) + 3600
  expect_identical(.hb_jwt_expiry(fake_jwt(exp)), .POSIXct(exp))
  # The payload really does use the base64url alphabet.
  expect_match(strsplit(fake_jwt(exp), ".", fixed = TRUE)[[1L]][[2L]], "[-_]")

  expect_null(.hb_jwt_expiry(NULL))
  expect_null(.hb_jwt_expiry(NA_character_))
  expect_null(.hb_jwt_expiry("BASETOKENSECRET"))
  expect_null(.hb_jwt_expiry("not.a.jwt"))
  no_exp <- sub("[.][^.]+[.]", ".e30.", fake_jwt(exp))
  expect_null(.hb_jwt_expiry(no_exp))
})

test_that("a lapsed base token is renewed before the request goes out", {
  cl <- mock_client()
  cl$.base_token <- fake_jwt(now() - 60)
  fresh <- fake_jwt(now() + 3 * 86400)
  seen <- local_replies(function(req) {
    if (grepl("/app-access-token/", req$url, fixed = TRUE)) {
      json_resp(200L, api_token_reply(fresh), req$url)
    } else {
      json_resp(200L, '{"metadata": {"tables": []}}', req$url)
    }
  })
  hb_metadata(cl)
  expect_identical(
    seen_urls(seen),
    c(
      "https://demo.example.org/api/v2.1/dtable/app-access-token/",
      "https://demo.example.org/api-gateway/api/v2/dtables/demo-uuid/metadata/"
    )
  )
  expect_identical(auth_of(seen$reqs[[2L]]), paste("Bearer", fresh))
  # The recorded expiry is the new token's own.
  expect_identical(cl$.base_token_expires, .hb_jwt_expiry(fresh))
})

test_that("a base token is renewed a few minutes before it lapses", {
  fresh <- fake_jwt(now() + 86400)
  renewals <- function(token, recorded = NULL) {
    cl <- mock_client()
    cl$.base_token <- token
    cl$.base_token_expires <- recorded
    seen <- local_replies(function(req) {
      json_resp(200L, api_token_reply(fresh), req$url)
    })
    .hb_auth_header(cl, "base")
    length(seen$reqs)
  }
  expect_identical(renewals(fake_jwt(now() + 120)), 1L)
  expect_identical(renewals(fake_jwt(now() + 3600)), 0L)
  # A token that cannot be decoded falls back on the recorded expiry.
  expect_identical(renewals("opaque", Sys.time() - 1), 1L)
  expect_identical(renewals("opaque", Sys.time() + 3600), 0L)
  # An unknown expiry is not a reason to renew.
  expect_identical(renewals("opaque", NULL), 0L)
})

test_that("a failed early renewal keeps a token that still works", {
  # Renewal starts minutes before the token lapses, so a moment's outage of
  # the exchange must not fail a call the cached token can still make.
  cl <- mock_client()
  valid <- fake_jwt(now() + 120)
  cl$.base_token <- valid
  seen <- local_replies(function(req) {
    if (grepl("/app-access-token/", req$url, fixed = TRUE)) {
      json_resp(502L, '{"error_msg": "bad gateway"}', req$url)
    } else {
      json_resp(200L, '{"tables": []}', req$url)
    }
  })
  expect_no_error(hb_metadata(cl))
  # One attempt to renew, then the call itself, with the cached token.
  expect_length(seen$reqs, 2L)
  expect_identical(auth_of(seen$reqs[[2L]]), paste("Bearer", valid))
  # A token already past its expiry has nothing to fall back on.
  cl <- mock_client()
  cl$.base_token <- fake_jwt(now() - 60)
  expect_error(hb_metadata(cl), class = "harbour_error_http")
})

test_that("a base token the gateway calls invalid is renewed, then retried", {
  # The API gateway refuses a lapsed base token with 403 "invalid token",
  # not 401, so a client older than the token's lifetime never recovered.
  cl <- mock_client()
  fresh <- fake_jwt(now() + 86400)
  seen <- local_replies(function(req) {
    if (grepl("/app-access-token/", req$url, fixed = TRUE)) {
      json_resp(200L, api_token_reply(fresh), req$url)
    } else if (identical(auth_of(req), paste("Bearer", fresh))) {
      json_resp(200L, '{"metadata": {"tables": []}}', req$url)
    } else {
      json_resp(403L, '{"error_message": "invalid token"}', req$url)
    }
  })
  expect_s3_class(hb_metadata(cl), "harbour_metadata")
  expect_length(seen$reqs, 3L)
  expect_match(seen$reqs[[2L]]$url, "/app-access-token/", fixed = TRUE)
  expect_identical(cl$.base_token, fresh)
})

test_that("the invalid-token retry happens only once", {
  cl <- mock_client()
  seen <- local_replies(function(req) {
    if (grepl("/app-access-token/", req$url, fixed = TRUE)) {
      json_resp(200L, api_token_reply(fake_jwt(now() + 86400)), req$url)
    } else {
      json_resp(403L, '{"error_msg": "Invalid Token"}', req$url)
    }
  })
  expect_error(hb_metadata(cl), class = "harbour_error_permission")
  expect_length(seen$reqs, 3L)
})

test_that("any other 403 is reported without a retry", {
  cl <- mock_client()
  seen <- local_replies(function(req) {
    json_resp(403L, '{"error_msg": "Permission denied."}', req$url)
  })
  expect_error(hb_metadata(cl), class = "harbour_error_permission")
  expect_length(seen$reqs, 1L)

  # An API-token call is not a base call, whatever its 403 says.
  seen2 <- local_replies(function(req) {
    json_resp(403L, '{"error_message": "invalid token"}', req$url)
  })
  expect_error(
    .hb_request(
      cl, "/api/v2.1/dtable/app-upload-link/", service = "web", auth = "api"
    ),
    class = "harbour_error_permission"
  )
  expect_length(seen2$reqs, 1L)
})

test_that("hb_check_credentials also drops a password client's base token", {
  cl <- account_client()
  cl$.base_token <- "OLD"
  local_replies(function(req) json_resp(200L, '{"token": "ACCT"}', req$url))
  hb_check_credentials(cl)
  expect_identical(cl$.account_token, "ACCT")
  expect_null(cl$.base_token)
})

test_that("a failed credentials check leaves the cached base token alone", {
  # Only a login that works replaces what the old one gave.
  cl <- account_client(password = "wrong")
  cl$.base_token <- "OLD"
  local_replies(function(req) {
    json_resp(400L, '{"non_field_errors": ["No."]}', req$url)
  })
  expect_error(hb_check_credentials(cl), class = "harbour_error_auth")
  expect_identical(cl$.base_token, "OLD")
})

# ---- Refused credentials ---------------------------------------------------

test_that("a refused password is an auth error with the server's reason", {
  cl <- account_client(password = "wrong")
  local_replies(function(req) {
    json_resp(
      400L,
      '{"non_field_errors": ["Unable to login with provided credentials."]}',
      req$url
    )
  })
  err <- expect_error(hb_check_credentials(cl), class = "harbour_error_auth")
  # Still what a handler written against the status would expect.
  expect_s3_class(err, "harbour_error_http")
  expect_identical(err$status, 400L)
  expect_identical(err$url, "https://demo.example.org/api2/auth-token/")
  expect_identical(
    err$response_body,
    list(non_field_errors = list("Unable to login with provided credentials."))
  )
  expect_match(
    conditionMessage(err), "Unable to login with provided credentials.",
    fixed = TRUE
  )
  expect_match(conditionMessage(err), "username and password", fixed = TRUE)
})

test_that("a login 400 that is not JSON is not blamed on the password", {
  # SeaTable's own 400 is JSON; a web page comes from a proxy, as when
  # plain HTTP is sent to an HTTPS port.
  cl <- account_client()
  local_replies(function(req) {
    httr2::response(
      status_code = 400L, url = req$url,
      headers = list(`Content-Type` = "text/html"),
      body = charToRaw("<html><body>400 Bad Request</body></html>")
    )
  })
  err <- expect_error(hb_check_credentials(cl), class = "harbour_error_http")
  expect_false(inherits(err, "harbour_error_auth"))
})

test_that("a login refused with 401 or 403 is an auth error too", {
  cl <- account_client()
  local_replies(function(req) {
    json_resp(403L, '{"detail": "Account is locked."}', req$url)
  })
  err <- expect_error(.hb_get_account_token(cl), class = "harbour_error_auth")
  expect_s3_class(err, "harbour_error_permission")
  expect_match(conditionMessage(err), "Account is locked.", fixed = TRUE)

  local_replies(function(req) {
    json_resp(401L, '{"detail": "Invalid username or password."}', req$url)
  })
  err2 <- expect_error(.hb_get_account_token(cl), class = "harbour_error_auth")
  expect_identical(err2$status, 401L)
  expect_match(conditionMessage(err2), "username and password", fixed = TRUE)
})

test_that("an unknown API token is an auth error as well as a 403", {
  cl <- api_client(api_token = "not-a-real-token")
  local_replies(function(req) {
    json_resp(403L, '{"error_msg": "Permission denied."}', req$url)
  })
  err <- expect_error(hb_check_credentials(cl), class = "harbour_error_auth")
  expect_s3_class(err, "harbour_error_permission")
  expect_identical(err$status, 403L)
  expect_identical(
    err$url, "https://demo.example.org/api/v2.1/dtable/app-access-token/"
  )
  expect_identical(err$response_body, list(error_msg = "Permission denied."))
  expect_match(conditionMessage(err), "Permission denied.", fixed = TRUE)
  expect_match(conditionMessage(err), "API token", fixed = TRUE)
})

test_that("a refused account token names the account, not an API token", {
  cl <- account_client()
  cl$.account_token <- "ACCT"
  local_replies(function(req) {
    json_resp(401L, '{"detail": "Invalid token"}', req$url)
  })
  err <- expect_error(.hb_get_base_token(cl), class = "harbour_error_auth")
  expect_identical(err$status, 401L)
  expect_match(conditionMessage(err), "Invalid token", fixed = TRUE)
  expect_false(grepl("API token", conditionMessage(err), fixed = TRUE))

  local_replies(function(req) {
    json_resp(
      403L, '{"detail": "Authentication credentials were not provided."}',
      req$url
    )
  })
  err2 <- expect_error(.hb_get_base_token(cl), class = "harbour_error_auth")
  expect_s3_class(err2, "harbour_error_permission")
})

test_that("a token exchange keeps other failures as they were", {
  cl <- account_client()
  cl$.account_token <- "ACCT"
  local_replies(function(req) {
    json_resp(404L, '{"error_msg": "dtable My Base not found."}', req$url)
  })
  err <- expect_error(.hb_get_base_token(cl), class = "harbour_error_not_found")
  expect_false(inherits(err, "harbour_error_auth"))

  # The base-token exchanges document no 400, so one is not read as
  # refused credentials.
  local_replies(function(req) json_resp(400L, '{"error_msg": "no"}', req$url))
  err2 <- expect_error(.hb_get_base_token(cl), class = "harbour_error_http")
  expect_false(inherits(err2, "harbour_error_auth"))

  login <- account_client()
  local_replies(function(req) json_resp(429L, "{}", req$url))
  err3 <- expect_error(
    .hb_get_account_token(login), class = "harbour_error_rate_limit"
  )
  expect_false(inherits(err3, "harbour_error_auth"))
  local_replies(function(req) json_resp(500L, "{}", req$url))
  err4 <- expect_error(
    .hb_get_account_token(login), class = "harbour_error_http"
  )
  expect_false(inherits(err4, "harbour_error_auth"))
})

test_that("every reason the login lists reaches the message", {
  expect_identical(
    .hb_error_message(list(non_field_errors = list("One.", "Two."))),
    "One. Two."
  )
  expect_identical(
    .hb_error_message(list(non_field_errors = list())),
    "SeaTable returned an error."
  )
})

test_that("a 401 hint names the credential the client uses", {
  cl <- account_client()
  cl$base_uuid <- "demo-uuid"
  cl$.account_token <- "ACCT"
  cl$.base_token <- "OLD"
  local_replies(function(req) {
    if (grepl("/access-token/$", req$url)) {
      json_resp(200L, '{"access_token": "NEW", "dtable_uuid": "demo-uuid"}')
    } else {
      json_resp(401L, '{"detail": "Invalid token"}', req$url)
    }
  })
  err <- expect_error(hb_metadata(cl), class = "harbour_error_auth")
  expect_match(conditionMessage(err), "username", fixed = TRUE)
  expect_false(grepl("API token", conditionMessage(err), fixed = TRUE))

  # An API-token client is still pointed at its token.
  api <- mock_client()
  local_replies(function(req) json_resp(401L, "{}", req$url))
  err2 <- expect_error(
    .hb_request(
      api, "/api/v2.1/dtable/app-upload-link/", service = "web", auth = "api"
    ),
    class = "harbour_error_auth"
  )
  expect_match(conditionMessage(err2), "API token", fixed = TRUE)
})

# ---- Transport failures ----------------------------------------------------

test_that("a server that cannot be reached is a classed HTTP error", {
  cl <- mock_client()
  httr2::local_mocked_responses(function(req) transport_failure())
  err <- expect_error(hb_server_info(cl), class = "harbour_error_http")
  expect_s3_class(err, "harbour_error")
  # httr2's classes are kept, so a handler written for httr2 still matches.
  expect_s3_class(err, "httr2_failure")
  expect_s3_class(err, "httr2_error")
  expect_identical(err$status, NA_integer_)
  expect_identical(err$url, "https://demo.example.org/server-info/")
  expect_match(conditionMessage(err), "https://demo.example.org", fixed = TRUE)
  expect_s3_class(err$parent, "httr2_failure")

  # The same holds on a base call and on the token exchange before it.
  expect_error(hb_metadata(cl), class = "harbour_error_http")
  expect_error(hb_check_credentials(cl), class = "harbour_error_http")
})

test_that("a request that timed out is not reported as never sent", {
  # A timeout can come after the server received the request, and for a
  # write after it applied it, so the error does not say the server was
  # never reached, and a write says to check before sending it again.
  cl <- mock_client()
  cl$.metadata <- hb_example_metadata()
  httr2::local_mocked_responses(function(req) {
    transport_failure("Operation timed out", curl = "operation_timedout")
  })
  err <- expect_error(
    hb_append_rows(cl, "Samples", tibble::tibble(Name = "a")),
    class = "harbour_error_http"
  )
  expect_identical(err$status, NA_integer_)
  shown <- conditionMessage(err)
  expect_false(grepl("Could not reach", shown, fixed = TRUE))
  expect_match(shown, "did not complete", fixed = TRUE)
  expect_match(shown, "may have applied it", fixed = TRUE)
  expect_match(shown, "timeout", fixed = TRUE)
  # A read changes nothing, so it carries no such warning, and nor does a
  # login, though it goes out as a POST.
  err <- expect_error(hb_server_info(cl), class = "harbour_error_http")
  expect_false(grepl("may have applied", conditionMessage(err), fixed = TRUE))
  err <- expect_error(hb_check_credentials(account_client()),
                      class = "harbour_error_http")
  expect_false(grepl("may have applied", conditionMessage(err), fixed = TRUE))
})

test_that("a login that cannot reach the server never carries the password", {
  # httr2's condition keeps the whole request, and the login request's
  # body holds the password in clear text. The password is built at run
  # time, because a backtrace keeps the source of this file.
  secret <- paste0("pw-never-", "in-an-error")
  cl <- account_client(password = secret)
  httr2::local_mocked_responses(function(req) transport_failure())
  err <- expect_error(hb_check_credentials(cl), class = "harbour_error_http")
  expect_s3_class(err, "httr2_failure")
  expect_false(grepl(secret, conditionMessage(err), fixed = TRUE))
  expect_false(
    grepl(secret, rawToChar(serialize(err, NULL, ascii = TRUE)), fixed = TRUE)
  )
  # The transport error itself is still there to explain what happened.
  expect_match(conditionMessage(err), "Could not resolve host", fixed = TRUE)
})

test_that("an unreachable server's error does not carry the credentials", {
  # httr2's condition keeps the request, and the request keeps the
  # function that decides its retries. Saving the error saves both, so
  # nothing they hold may lead back to the client. The secrets are built
  # at run time, because a backtrace keeps the source of this file.
  token <- paste0("tok-never-", "in-an-error")
  password <- paste0("pw-never-", "in-an-error")
  base_token <- paste0("base-never-", "in-an-error")
  saved <- function(err) rawToChar(serialize(err, NULL, ascii = TRUE))
  httr2::local_mocked_responses(function(req) transport_failure())

  api <- mock_client(api_token = token)
  api$.base_token <- base_token
  for (verb in list(hb_metadata, hb_server_info, hb_ping)) {
    err <- expect_error(verb(api), class = "harbour_error_http")
    expect_false(grepl(token, saved(err), fixed = TRUE))
    expect_false(grepl(base_token, saved(err), fixed = TRUE))
  }

  account <- account_client(password = password)
  account$base_uuid <- "demo-uuid"
  account$.account_token <- token
  account$.base_token <- base_token
  err <- expect_error(hb_metadata(account), class = "harbour_error_http")
  for (secret in c(password, token, base_token)) {
    expect_false(grepl(secret, saved(err), fixed = TRUE))
  }
})

test_that("a retry that cannot reach the server is reported once", {
  # The retry after a refused base token goes out while the first
  # answer's handler is still running; its failure must not be wrapped
  # a second time on the way out.
  cl <- mock_client()
  seen <- local_replies(function(req) {
    if (grepl("/app-access-token/", req$url, fixed = TRUE)) {
      json_resp(200L, api_token_reply("NEW"), req$url)
    } else if (identical(auth_of(req), "Bearer NEW")) {
      transport_failure()
    } else {
      json_resp(401L, '{"detail": "Invalid token"}', req$url)
    }
  })
  err <- expect_error(hb_metadata(cl), class = "harbour_error_http")
  expect_length(seen$reqs, 3L)
  expect_s3_class(err, "httr2_failure")
  expect_false(inherits(err$parent, "harbour_error"))
  expect_s3_class(err$parent, "httr2_failure")
})

test_that("a refused connection is reported as a classed HTTP error", {
  skip_on_cran()
  cl <- hb_client(server = "http://127.0.0.1:1", api_token = "t", timeout = 2)
  err <- expect_error(hb_server_info(cl), class = "harbour_error_http")
  expect_s3_class(err, "httr2_failure")
  expect_identical(err$status, NA_integer_)
  expect_match(conditionMessage(err), "http://127.0.0.1:1", fixed = TRUE)
})

test_that("hb_ping still reports an unreachable server in its own words", {
  cl <- mock_client()
  httr2::local_mocked_responses(function(req) transport_failure())
  err <- expect_error(hb_ping(cl), class = "harbour_error_http")
  expect_match(conditionMessage(err), "Could not reach", fixed = TRUE)
  # With the status, URL and classes every other verb's error has.
  expect_identical(err$status, NA_integer_)
  expect_identical(err$url, "https://demo.example.org/api2/ping/")
  expect_s3_class(err, "httr2_failure")
  # Its cause is httr2's own condition, as it always was, not a second
  # harbouR error saying the same thing.
  expect_s3_class(err$parent, "httr2_failure")
  expect_false(inherits(err$parent, "harbour_error"))
})

# ---- Servers behind a path prefix ------------------------------------------

test_that("both token exchanges keep a path prefix in the server URL", {
  seen <- local_replies(function(req) {
    json_resp(
      200L, '{"token": "ACCT", "access_token": "BASE", "dtable_uuid": "u"}',
      req$url
    )
  })
  paths <- c("/api2/auth-token/", "/api/v2.1/dtable/app-access-token/")
  for (server in c("https://seatable.example.org",
                   "https://seatable.example.org:8443",
                   "https://gw.example.org/seatable")) {
    seen$reqs <- list()
    .hb_get_account_token(account_client(server = server))
    .hb_get_base_token(api_client(server = server))
    expect_identical(seen_urls(seen), paste0(server, paths), info = server)
  }
  # For a server at the root of its host the URLs are byte for byte what
  # httr2::req_url_path() built before.
  for (server in c("https://seatable.example.org",
                   "https://seatable.example.org:8443")) {
    old <- vapply(
      paths,
      function(path) httr2::req_url_path(httr2::request(server), path)$url,
      ""
    )
    expect_identical(unname(old), paste0(server, paths), info = server)
  }
})

# ---- What an account client remembers --------------------------------------

test_that("an account client keeps the base it named", {
  # The account-token exchange replies with only the token and the UUID.
  cl <- account_client()
  cl$.account_token <- "ACCT"
  local_replies(function(req) {
    if (grepl("/access-token/$", req$url)) {
      json_resp(200L, '{"access_token": "BASE", "dtable_uuid": "uuid-1"}')
    } else {
      json_resp(200L, '{"metadata": {"tables": []}}', req$url)
    }
  })
  meta <- hb_metadata(cl)
  expect_identical(meta$base_name, "My Base")
  expect_identical(cl$.base_name, "My Base")
  expect_identical(cl$.workspace_id, "7")
  expect_identical(cl$base_uuid, "uuid-1")
})

test_that("an API-token client takes its base only from the server", {
  # An API-token client ignores workspace_id and base_name, so they are
  # never checked, and they do not stand in for what a reply leaves out.
  cl <- api_client()
  cl$workspace_id <- c(1, 2)
  cl$base_name <- 42
  local_replies(function(req) {
    json_resp(200L, '{"access_token": "BASE", "dtable_uuid": "u"}', req$url)
  })
  .hb_get_base_token(cl)
  expect_null(cl$.workspace_id)
  expect_null(cl$.base_name)
})

test_that("a round workspace id reaches the URL in full", {
  # as.character(1e5) is "1e+05", which no server reads as workspace 100000.
  cl <- account_client(workspace_id = 1e5, base_name = "B")
  cl$.account_token <- "ACCT"
  seen <- local_replies(function(req) {
    json_resp(200L, '{"access_token": "BASE", "dtable_uuid": "u"}', req$url)
  })
  .hb_get_base_token(cl)
  expect_identical(
    seen_urls(seen),
    "https://demo.example.org/api/v2.1/workspace/100000/dtable/B/access-token/"
  )
  expect_identical(cl$.workspace_id, "100000")
})

# ---- Reply bodies ----------------------------------------------------------

test_that("a JSON reply parses exactly as httr2 parsed it", {
  fixtures <- list.files(
    system.file("extdata", package = "harbouR"),
    pattern = "[.]json$", full.names = TRUE
  )
  expect_gt(length(fixtures), 0L)
  bodies <- c(
    vapply(fixtures, function(f) readChar(f, file.size(f), TRUE), ""),
    '{"rows": [{"a": 1, "b": null, "c": [1, 2.5], "d": {"e": "\\u00e9"}}]}',
    '{"error_msg": "no"}', '[]', '{}', '"text"', "12", "true",
    '{"big": 12345678901234567890, "neg": -0.5, "nested": [[], {}]}'
  )
  for (body in bodies) {
    resp <- json_resp(200L, body)
    expect_identical(
      .hb_resp_json(resp),
      httr2::resp_body_json(resp, simplifyVector = FALSE)
    )
  }
})

test_that("a reply's content type is checked as httr2 checks it", {
  for (type in c("application/json", "application/json; charset=utf-8",
                 "application/problem+json", "text/plain", "text/html", "")) {
    headers <- if (nzchar(type)) list(`Content-Type` = type) else list()
    resp <- httr2::response(200L, headers = headers, body = charToRaw("{}"))
    ours <- tryCatch(.hb_resp_json(resp), error = function(e) "refused")
    theirs <- tryCatch(
      httr2::resp_body_json(resp, simplifyVector = FALSE),
      error = function(e) "refused"
    )
    expect_identical(ours, theirs, info = type)
  }
  empty <- httr2::response(
    200L, headers = list(`Content-Type` = "application/json"), body = raw()
  )
  expect_error(.hb_resp_json(empty), class = "harbour_error_http")
  # The refusal is told beneath harbouR's own message, without naming an
  # internal function as its source.
  html <- httr2::response(
    200L, headers = list(`Content-Type` = "text/html"),
    body = charToRaw("<html></html>")
  )
  err <- expect_error(.hb_resp_json(html), class = "harbour_error_http")
  expect_match(conditionMessage(err), "Unexpected content type", fixed = TRUE)
  expect_false(grepl(".hb_resp_json", conditionMessage(err), fixed = TRUE))
})

test_that("a reply that names a local file is not read from that file", {
  # jsonlite::fromJSON() treats a short string that is not JSON as a path
  # and parses the file it names.
  path <- withr::local_tempfile(fileext = ".json")
  writeLines('{"error_msg": "read from the file"}', path)

  err <- tryCatch(
    .hb_translate_error(make_http_cond(400L, path)),
    error = function(e) e
  )
  expect_s3_class(err, "harbour_error_http")
  expect_identical(err$response_body, path)
  expect_match(conditionMessage(err), basename(path), fixed = TRUE)
  expect_false(grepl("read from the file", conditionMessage(err), fixed = TRUE))

  expect_error(
    .hb_resp_json(json_resp(200L, path)), class = "harbour_error_http"
  )
})

test_that("a reply that is a URL is not fetched", {
  skip_on_cran()
  # A listening socket nobody answers: had a body been fetched as a URL,
  # its connection would be left waiting here.
  listener <- NULL
  for (i in 0:19) {
    port <- 49152L + (Sys.getpid() * 37L + i * 211L) %% 15000L
    listener <- tryCatch(serverSocket(port), error = function(e) NULL)
    if (!is.null(listener)) break
  }
  if (is.null(listener)) skip("no free local port")
  withr::defer(close(listener))
  withr::local_options(timeout = 2)
  url <- sprintf("http://127.0.0.1:%d/reply.json", port)

  err <- tryCatch(
    .hb_translate_error(make_http_cond(400L, url)),
    error = function(e) e
  )
  expect_identical(err$response_body, url)
  expect_error(
    .hb_resp_json(json_resp(200L, url)), class = "harbour_error_http"
  )
  pending <- tryCatch(
    socketSelect(list(listener), timeout = 0),
    error = function(e) skip("cannot watch a listening socket here")
  )
  expect_false(pending)
})


# ---- Findings of the 2026-10-29 audit ----------------------------------------

test_that("a saved transport error holds neither the request nor its data", {
  # httr2's condition holds the whole request: with httr2 before 1.2.0 its
  # Authorization header in clear text, and in every version the body - a
  # write's rows - so saving the error saved them.
  cl <- mock_client()
  httr2::local_mocked_responses(function(req) transport_failure(request = req))
  # Built at run time: the error's backtrace records this call, and a
  # literal written in it would be found there.
  payload <- paste0("PAY", "LOAD-", 77)
  err <- expect_error(
    .hb_request(cl, "/x/", method = "POST", body = list(cell = payload)),
    class = "harbour_error_http"
  )
  saved <- serialize(err, NULL)
  expect_length(grepRaw(payload, saved, fixed = TRUE), 0L)
  expect_null(err$parent$request)
  # The failure itself is still chained, with httr2's classes.
  expect_s3_class(err$parent, "httr2_failure")
})

test_that("an infinite timeout sets no limit rather than failing", {
  # curl refuses timeout_ms = Inf, so every request failed with an
  # unclassed curl error although hb_client() accepted Inf.
  cl <- hb_client(server = "https://x.example.org", api_token = "t",
                  timeout = Inf)
  req <- .hb_req(cl, "/x/", auth = "none")
  expect_null(req$options$timeout_ms)
  expect_identical(
    .hb_req(mock_client(), "/x/", auth = "none")$options$timeout_ms, 10000
  )
})

test_that("hb_ping keeps the class of an answer that was an error", {
  # Every failure became "Could not reach", a 404 or a 429 included.
  cl <- mock_client()
  httr2::local_mocked_responses(function(req) {
    httr2::response(status_code = 404L, url = req$url)
  })
  err <- expect_error(hb_ping(cl), class = "harbour_error_not_found")
  expect_identical(err$status, 404L)
  expect_no_match(conditionMessage(err), "Could not reach")
})

test_that("a reply that is not JSON names its URL and keeps its text", {
  cl <- mock_client()
  httr2::local_mocked_responses(function(req) {
    httr2::response(
      status_code = 200L, url = req$url,
      headers = list(`Content-Type` = "text/html"),
      body = charToRaw("<html>Log in</html>")
    )
  })
  err <- expect_error(hb_server_info(cl), class = "harbour_error_http")
  expect_identical(err$url, "https://demo.example.org/server-info/")
  expect_match(err$response_body, "Log in", fixed = TRUE)
})

test_that("a failed credentials check keeps the base token that worked", {
  cl <- mock_client()
  httr2::local_mocked_responses(function(req) transport_failure(request = req))
  expect_error(hb_check_credentials(cl), class = "harbour_error_http")
  expect_identical(cl$.base_token, "BASETOKENSECRET")
})

test_that("a Retry-After longer than a minute is not waited for", {
  # httr2 sleeps for whatever Retry-After says, so a 429 asking for an
  # hour blocked the session for an hour per retry. Such an answer is not
  # retried; a short wait still is. (Mocked responses skip httr2's retry
  # loop, so the policy is checked directly.)
  limited <- function(after) {
    httr2::response(
      status_code = 429L, url = "https://x.example.org/",
      headers = if (!is.null(after)) list(`Retry-After` = after) else list()
    )
  }
  retry <- .hb_retry_predicate("POST")
  expect_false(retry(limited("3600")))
  expect_true(retry(limited("5")))
  expect_true(retry(limited(NULL)))
  expect_false(.hb_retry_predicate("GET")(limited("61")))
})

test_that("a redirect is reported with where it points, not followed", {
  # curl drops the Authorization header on a redirect to another host or
  # scheme, so http:// redirected to https:// made a good token look
  # refused. The request now stops at the redirect and says where to go.
  cl <- mock_client()
  expect_false(.hb_req(cl, "/x/", auth = "none")$options$followlocation)
  httr2::local_mocked_responses(function(req) {
    httr2::response(
      status_code = 301L, url = req$url,
      headers = list(Location = "https://secure.example.org/server-info/")
    )
  })
  err <- expect_error(hb_server_info(cl), class = "harbour_error_http")
  expect_identical(err$status, 301L)
  expect_match(conditionMessage(err), "https://secure.example.org", fixed = TRUE)
})

test_that("a path segment of one or two dots is refused before sending", {
  # curl resolves such a segment away, so the request reached another
  # endpoint: hb_get_view(, ".") listed the views.
  cl <- mock_client()
  rec <- new_request_recorder()
  for (id in c(".", "..")) {
    expect_error(
      with_mocked_request(hb_get_row(cl, "Samples", id), recorder = rec),
      class = "harbour_error_bad_argument"
    )
  }
  expect_length(rec$calls, 0L)
})
