test_that("hb_client validates inputs", {
  expect_error(hb_client(server = ""), class = "rlang_error")
  expect_error(hb_client(server = "not-a-url", api_token = "x"))
  expect_error(hb_client(server = "https://x", api_token = "y",
                         username = "u", password = "p"))
})

test_that("hb_client builds a valid client from env vars", {
  withr::with_envvar(
    c(SEATABLE_SERVER = "https://demo.example.org",
      SEATABLE_API_TOKEN = "tok-abc-123"),
    {
      cl <- hb_client()
      expect_s3_class(cl, "harbour_client")
      expect_true(is_harbour_client(cl))
      expect_identical(cl$server, "https://demo.example.org")
    }
  )
})

test_that("print.harbour_client masks the token", {
  cl <- local_mock_client(api_token = "supersecret-token-1234567890")
  out <- capture.output(print(cl))
  expect_false(any(grepl("supersecret-token-1234567890", out, fixed = TRUE)))
})

test_that(".mask_token never reveals more than 8 chars", {
  expect_identical(harbouR:::.mask_token("abcd"), "****")
  expect_match(harbouR:::.mask_token("12345678901234567890"), "^1234\\.\\.\\.7890$")
})
