test_that(".hb_translate_error never includes the token", {
  cl <- local_mock_client(api_token = "supersecret-token-12345")
  # Build a fake httr2 condition by hand to test translation
  fake_resp <- structure(
    list(status_code = 401L, headers = list(),
         body = charToRaw('{"error_msg":"Bad credentials"}')),
    class = "httr2_response"
  )
  cond <- structure(
    list(message = "x", resp = fake_resp),
    class = c("httr2_http_401", "httr2_http", "rlang_error", "error", "condition")
  )
  msg <- tryCatch(
    harbouR:::.hb_translate_error(cond),
    error = function(e) conditionMessage(e)
  )
  expect_match(msg, "401")
  expect_false(grepl("supersecret-token-12345", msg, fixed = TRUE))
})

test_that("local_mock_client never prints the API token", {
  cl <- local_mock_client(api_token = "supersecret-token-abcdef")
  out <- paste(capture.output(print(cl)), collapse = "\n")
  expect_false(grepl("supersecret-token-abcdef", out, fixed = TRUE))
})
