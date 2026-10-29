# The Query panel runs hb_query(), whose missing-LIMIT warning goes to the
# R console - which someone using the explorer cannot see - and is
# rate-limited, so it would not reach them even if it went to the browser.
# The panel tells them itself, every time it applies.

skip_if_no_query_ui <- function() {
  testthat::skip_if_not_installed("shiny")
  testthat::skip_if_not_installed("reactable")
}

capped_reply <- function() {
  list(
    metadata = list(list(key = "0000", name = "Name", type = "text")),
    results = lapply(1:3, function(i) {
      list(`_id` = paste0("r", i), Name = paste0("S", i))
    })
  )
}

# Replace shiny's notifications with a recorder, for the calling test.
record_notifications <- function(env = rlang::caller_env()) {
  shown <- new.env(parent = emptyenv())
  shown$notes <- list()
  testthat::local_mocked_bindings(
    showNotification = function(ui, ..., type = "default") {
      shown$notes[[length(shown$notes) + 1L]] <- list(
        text = as.character(ui), type = type
      )
      invisible("note")
    },
    .package = "shiny",
    .env = env
  )
  shown
}

test_that("a query without LIMIT is flagged in the browser every time", {
  skip_if_no_query_ui()
  shown <- record_notifications()
  # Verbose makes hb_query() raise its warning on every call, so this also
  # shows that the panel keeps it out of the console.
  withr::local_options(rlib_warning_verbosity = "verbose")
  cl <- mock_client()
  expect_no_warning(with_mocked_request(
    shiny::testServer(harbouR:::.hb_app_server(preset = cl), {
      session$setInputs(sql = "select * from Samples")
      session$setInputs(run_sql = 1)
      session$setInputs(run_sql = 2)
      expect_identical(nrow(session$env$state$query), 3L)
    }),
    response = capped_reply()
  ))
  expect_length(shown$notes, 2L)
  expect_identical(shown$notes[[1L]]$type, "warning")
  expect_match(shown$notes[[1L]]$text, "LIMIT", fixed = TRUE)
  expect_match(shown$notes[[1L]]$text, "100 rows", fixed = TRUE)
})

test_that("the notice does not wait on the console warning's rate limit", {
  skip_if_no_query_ui()
  shown <- record_notifications()
  # At rlang's default verbosity hb_query() warns about a query once in
  # eight hours. The query is unique to this run, so its first run warns.
  withr::local_options(rlib_warning_verbosity = "default")
  query <- sprintf(
    "select * from Samples where Name = '%s'", basename(tempfile("run"))
  )
  cl <- mock_client()
  with_mocked_request(
    shiny::testServer(harbouR:::.hb_app_server(preset = cl), {
      session$setInputs(sql = query)
      session$setInputs(run_sql = 1)
      session$setInputs(run_sql = 2)
    }),
    response = capped_reply()
  )
  expect_length(shown$notes, 2L)
})

test_that("a query with its own LIMIT runs without a notice", {
  skip_if_no_query_ui()
  shown <- record_notifications()
  withr::local_options(rlib_warning_verbosity = "verbose")
  cl <- mock_client()
  with_mocked_request(
    shiny::testServer(harbouR:::.hb_app_server(preset = cl), {
      session$setInputs(sql = "select * from Samples limit 3")
      session$setInputs(run_sql = 1)
      expect_identical(nrow(session$env$state$query), 3L)
    }),
    response = capped_reply()
  )
  expect_length(shown$notes, 0L)
})

test_that("a failed query is reported as a failure, not as a missing LIMIT", {
  skip_if_no_query_ui()
  shown <- record_notifications()
  withr::local_options(rlib_warning_verbosity = "verbose")
  cl <- mock_client()
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      stop(make_http_cond(400L, '{"error_message":"no such table: Nope"}'))
    },
    .package = "httr2"
  )
  expect_no_warning(
    shiny::testServer(harbouR:::.hb_app_server(preset = cl), {
      session$setInputs(sql = "select * from Nope")
      session$setInputs(run_sql = 1)
      expect_null(session$env$state$query)
    })
  )
  expect_length(shown$notes, 1L)
  expect_identical(shown$notes[[1L]]$type, "error")
  expect_match(shown$notes[[1L]]$text, "no such table", fixed = TRUE)
})

test_that("a statement that returns no columns says so, with no LIMIT notice", {
  # SeaTable answers an UPDATE with neither rows nor metadata: the panel
  # showed reactable's own error, and a notice about a LIMIT it does not
  # take.
  skip_if_no_query_ui()
  shown <- record_notifications()
  cl <- mock_client()
  reply <- list(
    error_message = "", success = TRUE, metadata = NULL,
    is_join_stmt = FALSE, results = NULL
  )
  with_mocked_request(
    shiny::testServer(harbouR:::.hb_app_server(preset = cl), {
      session$setInputs(sql = "UPDATE Samples SET Name = 'x' WHERE Name = 'y'")
      session$setInputs(run_sql = 1)
      panel <- as.character(htmltools::renderTags(output$query_panel$html)$html)
      expect_match(panel, "returned no columns", fixed = TRUE)
    }),
    response = reply
  )
  expect_length(shown$notes, 0L)
})

test_that("connecting opens the server's base and enables queries", {
  skip_if_no_query_ui()
  testthat::local_mocked_bindings(
    hb_metadata = function(client, ...) {
      client$.metadata <- hb_example_metadata()
      client$.metadata
    },
    .package = "harbouR"
  )
  shiny::testServer(harbouR:::.hb_app_server(), {
    session$setInputs(server = "https://seatable.example.org", token = "tok",
                      connect = 1)
    expect_true(is_harbour_client(session$env$state$source))
    expect_identical(session$env$state$kind, "server")
    expect_identical(session$env$state$table, "Samples")
    html <- as.character(htmltools::renderTags(output$run_sql_ui$html)$html)
    expect_no_match(html, "disabled", fixed = TRUE)
  })
})

test_that("a failed connection is shown to the user", {
  skip_if_no_query_ui()
  shown <- record_notifications()
  shiny::testServer(harbouR:::.hb_app_server(), {
    session$setInputs(server = "https://example.org", token = "", connect = 1)
    expect_null(session$env$state$source)
  })
  expect_length(shown$notes, 1L)
  expect_match(shown$notes[[1L]]$text, "Could not connect", fixed = TRUE)
})
