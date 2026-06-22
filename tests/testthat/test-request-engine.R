make_resp <- function(status = 200L, body = NULL) {
  structure(list(status_code = status, body = body),
            class = "httr2_response")
}

make_http_cond <- function(status, body_json = "{}") {
  resp <- structure(
    list(status_code = status, headers = list(),
         body = charToRaw(body_json)),
    class = "httr2_response")
  structure(list(message = "x", resp = resp),
            class = c(paste0("httr2_http_", status), "httr2_http",
                      "rlang_error", "error", "condition"))
}

test_that(".hb_base_url picks the right host per service", {
  cl <- local_mock_client()
  cl$.dtable_server <- "https://ds.example.org"
  cl$.dtable_db <- "https://db.example.org"
  expect_identical(harbouR:::.hb_base_url(cl, "web"), cl$server)
  expect_identical(harbouR:::.hb_base_url(cl, "dtable_server"), "https://ds.example.org")
  expect_identical(harbouR:::.hb_base_url(cl, "dtable_db"), "https://db.example.org")
})

test_that(".hb_auth_header builds api/account/base headers", {
  cl <- local_mock_client()
  expect_identical(harbouR:::.hb_auth_header(cl, "api"),
                   paste("Token", cl$api_token))
  cl$.account_token <- "ACCT"
  expect_identical(harbouR:::.hb_auth_header(cl, "account"), "Token ACCT")
  expect_identical(harbouR:::.hb_auth_header(cl, "base"),
                   paste("Token", cl$.base_token))
})

test_that(".hb_auth_header errors when api token is absent", {
  cl <- new_harbour_client(server = "https://x", api_token = NULL,
                           username = "u", password = "p",
                           base_uuid = NULL, timeout = 5)
  expect_error(harbouR:::.hb_auth_header(cl, "api"), "API token required")
})

test_that(".hb_get_account_token requires credentials and stores the token", {
  cl <- new_harbour_client(server = "https://x", api_token = NULL,
                           username = NULL, password = NULL,
                           base_uuid = NULL, timeout = 5)
  expect_error(harbouR:::.hb_get_account_token(cl), "requires an account token")

  cl2 <- new_harbour_client(server = "https://x", api_token = NULL,
                            username = "u", password = "p",
                            base_uuid = NULL, timeout = 5)
  testthat::local_mocked_bindings(
    .hb_perform_raw = function(req) make_resp(),
    .hb_resp_json = function(resp) list(token = "ACCT123"),
    .package = "harbouR"
  )
  tok <- harbouR:::.hb_get_account_token(cl2)
  expect_identical(tok, "ACCT123")
  expect_identical(cl2$.account_token, "ACCT123")
})

test_that(".hb_get_account_token errors when no token field returned", {
  cl <- new_harbour_client(server = "https://x", api_token = NULL,
                           username = "u", password = "p",
                           base_uuid = NULL, timeout = 5)
  testthat::local_mocked_bindings(
    .hb_perform_raw = function(req) make_resp(),
    .hb_resp_json = function(resp) list(),
    .package = "harbouR"
  )
  expect_error(harbouR:::.hb_get_account_token(cl), "no token field")
})

test_that(".hb_get_base_token populates client state from the response", {
  cl <- new_harbour_client(server = "https://x", api_token = "APITOK",
                           username = NULL, password = NULL,
                           base_uuid = NULL, timeout = 5)
  testthat::local_mocked_bindings(
    .hb_perform_raw = function(req) make_resp(),
    .hb_resp_json = function(resp) list(
      access_token = "BASETOK",
      dtable_server = "https://ds",
      dtable_db = "https://db",
      workspace_id = 42,
      dtable_uuid = "uuid-1",
      dtable_name = "MyBase"
    ),
    .package = "harbouR"
  )
  tok <- harbouR:::.hb_get_base_token(cl)
  expect_identical(tok, "BASETOK")
  expect_identical(cl$.dtable_server, "https://ds")
  expect_identical(cl$base_uuid, "uuid-1")
  expect_identical(cl$.base_name, "MyBase")
  expect_s3_class(cl$.base_token_expires, "POSIXct")
})

test_that(".hb_get_base_token rejects account-only auth", {
  cl <- new_harbour_client(server = "https://x", api_token = NULL,
                           username = "u", password = "p",
                           base_uuid = NULL, timeout = 5)
  expect_error(harbouR:::.hb_get_base_token(cl), "not implemented")
})

test_that(".hb_refresh_base_token clears and refetches", {
  cl <- local_mock_client()
  testthat::local_mocked_bindings(
    .hb_perform_raw = function(req) make_resp(),
    .hb_resp_json = function(resp) list(access_token = "NEWTOK"),
    .package = "harbouR"
  )
  tok <- harbouR:::.hb_refresh_base_token(cl)
  expect_identical(tok, "NEWTOK")
})

test_that(".hb_perform_raw translates a 404 specially", {
  req <- list(url = "https://x/missing")
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop(make_http_cond(404)),
    .package = "httr2"
  )
  expect_error(harbouR:::.hb_perform_raw(req), "Endpoint not found")
})

test_that(".hb_perform_raw translates other HTTP errors", {
  req <- list(url = "https://x")
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) stop(make_http_cond(500, '{"msg":"oops"}')),
    .package = "httr2"
  )
  expect_error(harbouR:::.hb_perform_raw(req), "HTTP 500")
})

test_that(".hb_safe_url returns the url or a placeholder", {
  expect_identical(harbouR:::.hb_safe_url(list(url = "https://y")), "https://y")
})

test_that(".hb_translate_error maps known statuses to hints", {
  expect_error(harbouR:::.hb_translate_error(make_http_cond(401)), "401")
  expect_error(harbouR:::.hb_translate_error(make_http_cond(429)), "429")
})

test_that(".hb_resp_json errors on unparseable bodies", {
  testthat::local_mocked_bindings(
    resp_body_json = function(resp, ...) stop("bad"),
    resp_status = function(resp) 500L,
    .package = "httr2"
  )
  expect_error(harbouR:::.hb_resp_json(make_resp(500L)), "Could not parse JSON")
})

test_that(".hb_perform retries once on a 401 for base auth", {
  cl <- local_mock_client()
  attempts <- new.env(); attempts$n <- 0L
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      attempts$n <- attempts$n + 1L
      if (attempts$n == 1L) stop(make_http_cond(401)) else make_resp(200L)
    },
    req_headers = function(req, ...) req,
    .package = "httr2"
  )
  testthat::local_mocked_bindings(
    .hb_refresh_base_token = function(client) "REFRESHED",
    .hb_auth_header = function(client, auth) "Token X",
    .package = "harbouR"
  )
  resp <- harbouR:::.hb_perform(list(url = "u"), cl, auth = "base")
  expect_s3_class(resp, "httr2_response")
  expect_identical(attempts$n, 2L)
})

test_that(".hb_request returns NULL invisibly on 204", {
  cl <- local_mock_client()
  testthat::local_mocked_bindings(
    .hb_req = function(...) list(url = "u"),
    .hb_perform = function(req, client, auth = "base") make_resp(204L),
    .package = "harbouR"
  )
  testthat::local_mocked_bindings(
    req_method = function(req, method) req,
    resp_status = function(resp) resp$status_code,
    .package = "httr2"
  )
  expect_null(harbouR:::.hb_request(cl, "/x/"))
})

test_that(".hb_request parses JSON for non-204 responses", {
  cl <- local_mock_client()
  testthat::local_mocked_bindings(
    .hb_req = function(...) list(url = "u"),
    .hb_perform = function(req, client, auth = "base") make_resp(200L),
    .hb_resp_json = function(resp) list(ok = TRUE),
    .package = "harbouR"
  )
  testthat::local_mocked_bindings(
    req_method = function(req, method) req,
    req_body_json = function(req, body, ...) req,
    resp_status = function(resp) resp$status_code,
    .package = "httr2"
  )
  body <- harbouR:::.hb_request(cl, "/x/", body = list(a = 1), method = "POST")
  expect_true(body$ok)
})

test_that(".hb_req constructs a request object with a query", {
  cl <- local_mock_client()
  req <- harbouR:::.hb_req(cl, "/api2/ping/", service = "web", auth = "api",
                           query = list(table_name = "Samples"))
  expect_s3_class(req, "httr2_request")
})
