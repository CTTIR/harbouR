test_that("hb_client trims trailing slashes from the server URL", {
  cl <- hb_client(server = "https://x.example.org///", api_token = "tok")
  expect_identical(cl$server, "https://x.example.org")
})

test_that("hb_client accepts username/password auth", {
  cl <- hb_client(server = "https://x", username = "u", password = "p")
  expect_s3_class(cl, "harbour_client")
  expect_identical(cl$username, "u")
  expect_null(cl$api_token)
})

test_that("hb_client errors when no credentials are supplied", {
  expect_error(
    hb_client(server = "https://x", api_token = "", username = NULL,
              password = NULL),
    "No credentials"
  )
})

test_that("hb_client rejects mixed credentials and bad usernames", {
  expect_error(
    hb_client(server = "https://x", api_token = "t", username = "u",
              password = "p"),
    "not both"
  )
  expect_error(
    hb_client(server = "https://x", username = "", password = "p"),
    "non-empty string"
  )
})

test_that("hb_client requires an http(s) server", {
  expect_error(hb_client(server = "ftp://x", api_token = "t"),
               "http")
})

test_that("validate_harbour_client checks structure", {
  cl <- local_mock_client()
  expect_invisible(harbouR:::validate_harbour_client(cl))
  expect_error(harbouR:::validate_harbour_client(1L), "not a")
  expect_error(
    harbouR:::validate_harbour_client(structure(list(), class = "harbour_client")),
    "environment-backed"
  )
})

test_that("print.harbour_client reports auth mode and masks tokens", {
  cl <- local_mock_client(api_token = "supersecret-token-1234567890")
  out <- cli::cli_fmt(print(cl))
  out <- paste(out, collapse = "\n")
  expect_match(out, "api_token")
  expect_false(grepl("supersecret-token-1234567890", out, fixed = TRUE))

  cl2 <- hb_client(server = "https://x", username = "u", password = "p")
  out2 <- paste(cli::cli_fmt(print(cl2)), collapse = "\n")
  expect_match(out2, "username/password")
})

test_that("is_harbour_client discriminates", {
  expect_true(is_harbour_client(local_mock_client()))
  expect_false(is_harbour_client(list()))
})
