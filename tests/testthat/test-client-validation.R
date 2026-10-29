# What hb_client() accepts, what it refuses, and what the client prints.

test_that("print() shows braces in the base name and server as typed", {
  # The base name is chosen by whoever owns the base, and cli reads braces
  # in a message as code to run.
  withr::local_envvar(HARBOUR_PRINT_RAN = NA)
  cl <- mock_client(server = "https://{host}.example.org")
  cl$.base_name <- "Study {2024} {Sys.setenv(HARBOUR_PRINT_RAN = 'yes')}"
  out <- paste(cli::cli_fmt(print(cl)), collapse = "\n")
  expect_identical(Sys.getenv("HARBOUR_PRINT_RAN"), "")
  expect_match(
    out, "Study {2024} {Sys.setenv(HARBOUR_PRINT_RAN = 'yes')}", fixed = TRUE
  )
  expect_match(out, "https://{host}.example.org", fixed = TRUE)
  # format() hands back the text untouched.
  expect_true(
    "base     : Study {2024} {Sys.setenv(HARBOUR_PRINT_RAN = 'yes')}" %in%
      format(cl)
  )
})

test_that("a malformed API token or password is described, not echoed", {
  tokens <- list(271828182, c("tok-first-secret", "tok-second-secret"))
  for (token in tokens) {
    err <- expect_error(
      hb_client(server = "https://x.example.org", api_token = token),
      class = "harbour_error_bad_argument"
    )
    for (piece in as.character(token)) {
      expect_false(grepl(piece, conditionMessage(err), fixed = TRUE))
    }
  }
  passwords <- list(31415926, c("pw-first-secret", "pw-second-secret"))
  for (password in passwords) {
    err <- expect_error(
      hb_client(
        server = "https://x.example.org", username = "u", password = password
      ),
      class = "harbour_error_bad_argument"
    )
    for (piece in as.character(password)) {
      expect_false(grepl(piece, conditionMessage(err), fixed = TRUE))
    }
  }
  # What is said instead: the type, and the length when it is not one.
  expect_error(
    hb_client(server = "https://x.example.org", api_token = 271828182),
    "You supplied a number.", fixed = TRUE
  )
  expect_error(
    hb_client(server = "https://x.example.org", api_token = c("a", "b")),
    "You supplied a character vector of length 2.", fixed = TRUE
  )
  expect_error(
    hb_client(server = "https://x.example.org", username = "u",
              password = NA_character_),
    "You supplied `NA`.", fixed = TRUE
  )
  expect_error(
    hb_client(server = "https://x.example.org", username = "u",
              password = ""),
    "You supplied an empty string.", fixed = TRUE
  )
})

test_that("a malformed username or server is still shown", {
  expect_error(
    hb_client(server = "https://x.example.org", username = 42, password = "p"),
    "You supplied 42.", fixed = TRUE
  )
  expect_error(
    hb_client(server = 42, api_token = "t"), "You supplied 42.", fixed = TRUE
  )
})

test_that("an account client must name its base with usable values", {
  account <- function(...) {
    hb_client(
      server = "https://x.example.org", username = "u", password = "p", ...
    )
  }
  bad_ids <- list("abc", "0", "-7", -1, 0, 1.5, Inf, NA, c(1, 2), TRUE)
  for (id in bad_ids) {
    expect_error(
      account(workspace_id = id, base_name = "B"),
      class = "harbour_error_bad_argument"
    )
  }
  for (name in list(NA, NA_character_, "", c("A", "B"), Inf, TRUE)) {
    expect_error(
      account(workspace_id = 7, base_name = name),
      class = "harbour_error_bad_argument"
    )
  }
  for (id in list(7, 7L, "7", 1e5)) {
    expect_s3_class(account(workspace_id = id, base_name = "B"),
                    "harbour_client")
  }
  expect_error(
    account(workspace_id = "abc", base_name = "B"),
    paste(
      "`workspace_id` must be a single positive whole number or a string",
      "of digits."
    ),
    fixed = TRUE
  )
  expect_error(
    account(workspace_id = 7, base_name = NA),
    "`base_name` must be a single non-empty string.", fixed = TRUE
  )
})

test_that("a base named with a number can still be given as one", {
  # Passing 2024 for a base called "2024" has always worked: the name went
  # into the URL as text. A round number keeps its digits, as an id does.
  account <- function(name) {
    hb_client(
      server = "https://x.example.org", username = "u", password = "p",
      workspace_id = 7, base_name = name
    )
  }
  expect_identical(account(2024)$base_name, "2024")
  expect_identical(account(2024L)$base_name, "2024")
  expect_identical(account(1e5)$base_name, "100000")
  expect_identical(account("2024")$base_name, "2024")
})

test_that("a factor workspace id or base name is taken as its label", {
  # A factor reached the URL as its label, so it has always worked.
  cl <- hb_client(
    server = "https://x.example.org", username = "u", password = "p",
    workspace_id = factor("7"), base_name = factor("My Base")
  )
  expect_identical(cl$workspace_id, "7")
  expect_identical(cl$base_name, "My Base")
  expect_error(
    hb_client(
      server = "https://x.example.org", username = "u", password = "p",
      workspace_id = factor("seven"), base_name = "B"
    ),
    class = "harbour_error_bad_argument"
  )
})

test_that("a wrapped workspace id or base name is taken as its value", {
  # A config reader or single-bracket indexing gives a one-element list or
  # a one-cell data frame, and a date reached the URL as its text.
  account <- function(workspace_id, base_name) {
    hb_client(
      server = "https://x.example.org", username = "u", password = "p",
      workspace_id = workspace_id, base_name = base_name
    )
  }
  cl <- account(list(7), list("B"))
  expect_identical(cl$workspace_id, 7)
  expect_identical(cl$base_name, "B")
  cl <- account(data.frame(id = 7L), data.frame(name = "B"))
  expect_identical(cl$workspace_id, 7L)
  expect_identical(cl$base_name, "B")
  expect_identical(account(7, as.Date("2024-01-02"))$base_name, "2024-01-02")
  # A number that is not whole keeps every digit as.character() gives it.
  expect_identical(account(7, 3.14159265)$base_name, "3.14159265")
})

test_that("a timeout httr2 would refuse is refused at once", {
  expect_error(
    hb_client(server = "https://x.example.org", api_token = "t",
              timeout = 0.0005),
    class = "harbour_error_bad_argument"
  )
})

test_that("an API-token client is not held to arguments it ignores", {
  # An API token names its base, so workspace_id and base_name are never
  # used for it and were never checked.
  cl <- hb_client(
    server = "https://x.example.org", api_token = "t",
    workspace_id = "not a number", base_name = 42
  )
  expect_s3_class(cl, "harbour_client")
})

test_that("the timeout must be a positive number of seconds", {
  client <- function(timeout) {
    hb_client(server = "https://x.example.org", api_token = "t",
              timeout = timeout)
  }
  for (bad in list("30", 0, -1, -Inf, NA, NA_real_, NaN, c(10, 20), TRUE)) {
    expect_error(client(bad), class = "harbour_error_bad_argument")
  }
  # Inf has always been handed on to curl, so it is not refused now.
  for (good in list(30, 60L, 0.5, Inf, NULL)) {
    expect_s3_class(client(good), "harbour_client")
  }
  expect_error(
    client("30"), "`timeout` must be a single number of at least 0.001.",
    fixed = TRUE
  )
})

test_that("a username and password are used even with SEATABLE_API_TOKEN set", {
  # The api_token default reads the variable, so the account client was
  # refused for holding both kinds of credentials.
  withr::local_envvar(SEATABLE_API_TOKEN = "from-the-environment")
  cl <- hb_client(
    server = "https://x.example.org", username = "u", password = "p",
    workspace_id = 1, base_name = "B"
  )
  expect_null(cl$api_token)
  expect_identical(cl$username, "u")
  # Passing both explicitly is still a mistake.
  expect_error(
    hb_client(server = "https://x.example.org", api_token = "t",
              username = "u", password = "p"),
    class = "harbour_error_auth"
  )
})

test_that("a finite timeout curl cannot take is refused", {
  expect_error(
    hb_client(server = "https://x.example.org", api_token = "t", timeout = 1e10),
    class = "harbour_error_bad_argument"
  )
  expect_s3_class(
    hb_client(server = "https://x.example.org", api_token = "t", timeout = 2147483),
    "harbour_client"
  )
})

test_that("base_uuid must be one string, and is escaped in the path", {
  client <- function(uuid) {
    hb_client(server = "https://x.example.org", api_token = "t", base_uuid = uuid)
  }
  for (bad in list(c("a", "b"), NA_character_, "", 1)) {
    expect_error(client(bad), class = "harbour_error_bad_argument")
  }
  cl <- client("a/b?c")
  expect_identical(
    harbouR:::.hb_base_path(cl, "rows", ""),
    "/api-gateway/api/v2/dtables/a%2Fb%3Fc/rows/"
  )
})
