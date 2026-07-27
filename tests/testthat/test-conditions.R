test_that("every harbouR error carries the shared class", {
  expect_error(hb_client(server = ""), class = "harbour_error")
  expect_error(hb_client(server = "https://x.example.org"),
               class = "harbour_error")
  expect_error(hb_read_table(1L, "Samples"), class = "harbour_error")
})

test_that("argument failures are catchable as bad_argument", {
  cl <- mock_client()
  expect_error(hb_read_table(cl, ""), class = "harbour_error_bad_argument")
  expect_error(hb_list_tables(cl, refresh = "yes"),
               class = "harbour_error_bad_argument")
  expect_error(hb_query(cl, 1L), class = "harbour_error_bad_argument")
})

test_that("missing credentials are catchable as auth", {
  expect_error(hb_client(server = "https://x.example.org"),
               class = "harbour_error_auth")
})

test_that("an unknown table is catchable as not_found", {
  cl <- mock_client()
  expect_error(hb_read_table(cl, "Nope"), class = "harbour_error_not_found")
})

test_that("HTTP statuses map onto distinct condition classes", {
  expected <- c(
    "401" = "harbour_error_auth",
    "403" = "harbour_error_permission",
    "404" = "harbour_error_not_found",
    "429" = "harbour_error_rate_limit",
    "500" = "harbour_error_http"
  )
  for (status in names(expected)) {
    cnd <- make_http_cond(as.integer(status))
    err <- tryCatch(.hb_translate_error(cnd), error = function(e) e)
    expect_s3_class(err, expected[[status]])
    expect_s3_class(err, "harbour_error")
    expect_identical(err$status, as.integer(status))
  }
})

test_that(".hb_http_class falls back for unknown and missing statuses", {
  expect_identical(.hb_http_class(NA_integer_), "harbour_error_http")
  expect_identical(.hb_http_class(418L), "harbour_error_http")
})

test_that("a caller can react to the class rather than the message", {
  handled <- tryCatch(
    hb_client(server = "https://x.example.org"),
    harbour_error_auth = function(cnd) "asked for credentials"
  )
  expect_identical(handled, "asked for credentials")
})

test_that("HTTP conditions carry the status as a field", {
  cnd <- make_http_cond(429L, '{"error_msg": "slow down"}')
  err <- tryCatch(.hb_translate_error(cnd), error = function(e) e)
  expect_identical(err$status, 429L)
  expect_match(conditionMessage(err), "slow down")
})

test_that("a 403 is not retried as an expired base token", {
  # A 403 means the token is valid but lacks permission. Retrying it would
  # double the request and report a token-validity problem instead.
  cl <- mock_client()
  attempts <- 0L
  testthat::local_mocked_bindings(
    .hb_refresh_base_token = function(client, call = NULL) {
      attempts <<- attempts + 1L
      "NEWTOKEN"
    },
    .package = "harbouR"
  )
  req <- httr2::request("https://demo.example.org/x")
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) rlang::abort(
      "boom",
      class = c("httr2_http_403", "httr2_http", "rlang_error"),
      resp = structure(
        list(status_code = 403L, headers = list(), body = charToRaw("{}")),
        class = "httr2_response"
      )
    ),
    .package = "httr2"
  )
  expect_error(.hb_perform(req, cl, auth = "base"),
               class = "harbour_error_permission")
  expect_identical(attempts, 0L)
})
