# Does an httr2 request or response survive anywhere inside `x`, its
# parents and the calls of its backtrace included? Their headers carry the
# token: httr2 hides it when printing or saving, but it can still be
# revealed from the object.
holds_request <- function(x) {
  if (inherits(x, c("httr2_request", "httr2_response"))) {
    return(TRUE)
  }
  if (is.list(x) || is.call(x) || is.pairlist(x)) {
    parts <- if (is.list(x)) unclass(x) else as.list(x)
    return(any(vapply(
      parts, function(part) !missing(part) && holds_request(part), logical(1)
    )))
  }
  FALSE
}

test_that(".hb_translate_error never includes the token", {
  # Built at run time: a backtrace keeps the source of this file, so a
  # literal token would turn up in serialize() whatever the error held.
  secret <- paste0("supersecret-", "token-12345")
  cl <- mock_client(api_token = secret)
  # A real request, so the httr2 condition that reaches the translator
  # carries the token in its request headers.
  httr2::local_mocked_responses(function(req) {
    httr2::response(
      status_code = 401L,
      url = req$url,
      headers = list(`Content-Type` = "application/json"),
      body = charToRaw('{"error_msg":"Bad credentials"}')
    )
  })
  err <- tryCatch(
    harbouR:::.hb_request(
      cl, "/api/v2.1/dtable/app-upload-link/", service = "web", auth = "api"
    ),
    error = function(e) e
  )
  expect_s3_class(err, "harbour_error_auth")
  expect_match(conditionMessage(err), "401")
  expect_match(conditionMessage(err), "Bad credentials")
  expect_false(grepl(secret, conditionMessage(err), fixed = TRUE))
  expect_false(grepl(secret, paste(format(err), collapse = "\n"), fixed = TRUE))
  expect_false(
    grepl(secret, rawToChar(serialize(err, NULL, ascii = TRUE)), fixed = TRUE)
  )
  expect_false(holds_request(err))
})

test_that("mock_client never prints the API token", {
  cl <- mock_client(api_token = "supersecret-token-abcdef")
  # print() writes through cli, which capture.output() does not see.
  out <- paste(cli::cli_fmt(print(cl)), collapse = "\n")
  expect_match(out, "supe...cdef", fixed = TRUE)
  expect_false(grepl("supersecret-token-abcdef", out, fixed = TRUE))
})
