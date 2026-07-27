# --- validation / guard branches -------------------------------------------

test_that("hb_read_table validates client, table, view and paging", {
  cl <- mock_client()
  expect_error(hb_read_table(1L, "Samples"), class = "harbour_error_bad_argument")
  expect_error(hb_read_table(cl, ""), regexp = "`table` must be a single non-empty string\\.")
  expect_error(hb_read_table(cl, "Samples", view = 1L), regexp = "`view` must be a single non-empty string\\.")
  expect_error(hb_read_table(cl, "Samples", page_size = 0L), "positive integer")
  expect_error(hb_read_table(cl, "Samples", page_size = NA), "positive integer")
  expect_error(hb_read_table(cl, "Samples", n_max = 0L), "positive number")
})

test_that("hb_read_table paginates and returns a typed tibble", {
  cl <- mock_client()
  page1 <- lapply(1:2, function(i) list(Name = paste0("S", i), `_id` = paste0("r", i)))
  state <- new.env(); state$n <- 0L
  resp <- function(path, method, query, body) {
    state$n <- state$n + 1L
    if (state$n == 1L) list(rows = page1) else list(rows = list())
  }
  rec <- with_mocked_request(
    out <- hb_read_table(cl, "Samples", page_size = 2L),
    response = resp
  )
  expect_s3_class(out, "tbl_df")
  expect_identical(out$Name, c("S1", "S2"))
  # Two requests: full page then the short final page.
  expect_identical(length(rec$calls), 2L)
  expect_identical(rec$calls[[1]]$query$table_name, "Samples")
})

test_that("hb_read_table forwards the view name", {
  cl <- mock_client()
  rec <- with_mocked_request(
    hb_read_table(cl, "Samples", view = "Default"),
    response = list(rows = list())
  )
  expect_identical(rec$calls[[1]]$query$view_name, "Default")
})

test_that("hb_query returns a tibble and handles empty results", {
  cl <- mock_client()
  rec <- with_mocked_request(
    out <- hb_query(cl, "select * from Samples"),
    response = list(results = list())
  )
  expect_s3_class(out, "tbl_df")
  expect_identical(nrow(out), 0L)
  expect_identical(rec$calls[[1]]$method, "POST")
  expect_identical(rec$calls[[1]]$body$sql, "select * from Samples")
})

test_that("hb_query assembles scalar and list columns", {
  cl <- mock_client()
  rows <- list(
    list(a = 1, b = list("x", "y")),
    list(a = 2, b = list("z"))
  )
  with_mocked_request(
    out <- hb_query(cl, "q"),
    response = list(results = rows)
  )
  expect_identical(out$a, c(1, 2))
  expect_true(is.list(out$b))
})

test_that("hb_query rejects non-string sql", {
  cl <- mock_client()
  expect_error(hb_query(cl, 1L), regexp = "`sql` must be a single non-empty string\\.")
})

test_that("hb_get_row returns a 1-row or 0-row tibble", {
  cl <- mock_client()
  with_mocked_request(
    one <- hb_get_row(cl, "Samples", "r1"),
    response = list(Name = "A", `_id` = "r1")
  )
  expect_identical(nrow(one), 1L)
  with_mocked_request(
    none <- hb_get_row(cl, "Samples", "missing"),
    response = list()
  )
  expect_identical(nrow(none), 0L)
})

test_that("hb_append_rows validates data and posts converted rows", {
  cl <- mock_client()
  expect_error(hb_append_rows(cl, "Samples", 1L), "data frame")
  data <- tibble::tibble(Name = "S-new", Concentration = 9.9)
  rec <- with_mocked_request(
    out <- hb_append_rows(cl, "Samples", data),
    response = function(path, method, query, body) list(rows = body$rows)
  )
  expect_s3_class(out, "tbl_df")
  expect_identical(rec$calls[[1]]$method, "POST")
  expect_identical(rec$calls[[1]]$body$table_name, "Samples")
})

test_that("hb_update_rows requires the id column and summarises updates", {
  cl <- mock_client()
  expect_error(hb_update_rows(cl, "Samples", 1L), "data frame")
  expect_error(
    hb_update_rows(cl, "Samples", tibble::tibble(Name = "x")),
    "not present"
  )
  data <- tibble::tibble(`_id` = c("r1", "r2"), Name = c("a", "b"))
  rec <- with_mocked_request(
    out <- hb_update_rows(cl, "Samples", data),
    response = list()
  )
  expect_identical(out$n_rows, 2L)
  expect_identical(out$n_requests, 1L)
  expect_identical(rec$calls[[1]]$method, "PUT")
})

test_that("hb_update_rows formats date cells and drops the id column", {
  cl <- mock_client()
  data <- tibble::tibble(`_id` = "r1",
                         Collected = as.POSIXct("2026-01-02", tz = "UTC"))
  rec <- with_mocked_request(
    hb_update_rows(cl, "Samples", data),
    response = list()
  )
  upd <- rec$calls[[1]]$body$updates[[1]]
  expect_identical(upd$row_id, "r1")
  expect_false("_id" %in% names(upd$row))
  expect_match(upd$row$Collected, "^2026-01-02")
})

test_that("hb_delete_rows validates ids and reports deletions", {
  cl <- mock_client()
  expect_error(hb_delete_rows(cl, "Samples", character()), "non-empty")
  expect_error(hb_delete_rows(cl, "Samples", 1L), "non-empty")
  rec <- with_mocked_request(
    out <- hb_delete_rows(cl, "Samples", c("r1", "r2")),
    response = list()
  )
  expect_identical(out$n_rows, 2L)
  expect_identical(out$n_requests, 1L)
  expect_identical(rec$calls[[1]]$method, "DELETE")
})

test_that("hb_lock_rows and hb_unlock_rows validate and return the client", {
  cl <- mock_client()
  expect_error(hb_lock_rows(cl, "Samples", character()), "non-empty")
  expect_error(hb_unlock_rows(cl, "Samples", 1L), "non-empty")
  rec <- with_mocked_request(
    res <- hb_lock_rows(cl, "Samples", "r1"),
    response = list()
  )
  expect_identical(res, cl)
  expect_match(rec$calls[[1]]$path, "lock-rows/$")
  rec2 <- with_mocked_request(
    res2 <- hb_unlock_rows(cl, "Samples", "r1"),
    response = list()
  )
  expect_identical(res2, cl)
  expect_match(rec2$calls[[1]]$path, "unlock-rows")
})

test_that("page_size above the server maximum warns and is clamped", {
  cl <- mock_client()
  # The old `limit` was documented as a page size but also used as the
  # stop condition, so limit = 5000 returned 1000 rows and stopped
  # silently. A wrong answer with no warning is the worst outcome.
  expect_warning(
    rec <- with_mocked_request(
      hb_read_table(cl, "Samples", page_size = 5000L),
      response = list(rows = list())
    ),
    "capped at"
  )
  expect_identical(rec$calls[[1]]$query$limit, 1000L)
})

test_that("n_max bounds the read and stops paging early", {
  cl <- mock_client()
  page <- lapply(1:1000, function(i) list(`_id` = paste0("r", i)))
  rec <- with_mocked_request(
    out <- hb_read_table(cl, "Samples", n_max = 10L),
    response = list(rows = page)
  )
  expect_identical(nrow(out), 10L)
  expect_identical(length(rec$calls), 1L)
  expect_identical(rec$calls[[1]]$query$limit, 10L)
})

test_that("reads page until the server returns a short page", {
  cl <- mock_client()
  responder <- function(path, method, query, body) {
    if (query$start == 0L) {
      list(rows = lapply(1:1000, function(i) list(`_id` = paste0("a", i))))
    } else {
      list(rows = lapply(1:7, function(i) list(`_id` = paste0("b", i))))
    }
  }
  rec <- with_mocked_request(
    out <- hb_read_table(cl, "Samples"),
    response = responder
  )
  expect_identical(nrow(out), 1007L)
  expect_identical(length(rec$calls), 2L)
  expect_identical(rec$calls[[2]]$query$start, 1000L)
})

test_that("writes are chunked at the server's batch limit", {
  cl <- mock_client()
  data <- tibble::tibble(Name = paste0("r", 1:2500))
  rec <- with_mocked_request(
    out <- hb_append_rows(cl, "Samples", data),
    response = list(inserted_row_count = 1000L)
  )
  expect_identical(length(rec$calls), 3L)
  expect_identical(out$n_requests, 3L)
  expect_identical(length(rec$calls[[1]]$body$rows), 1000L)
  expect_identical(length(rec$calls[[3]]$body$rows), 500L)
})

test_that("deletes and updates chunk too", {
  cl <- mock_client()
  ids <- paste0("r", 1:2001)
  rec <- with_mocked_request(
    out <- hb_delete_rows(cl, "Samples", ids),
    response = list()
  )
  expect_identical(length(rec$calls), 3L)
  expect_identical(out$n_rows, 2001L)

  updates <- tibble::tibble(`_id` = ids, Name = ids)
  rec2 <- with_mocked_request(
    out2 <- hb_update_rows(cl, "Samples", updates),
    response = list()
  )
  expect_identical(length(rec2$calls), 3L)
  expect_identical(out2$n_rows, 2001L)
})

test_that("hb_append_rows reports the count the server confirmed", {
  cl <- mock_client()
  rec <- with_mocked_request(
    out <- hb_append_rows(cl, "Samples", tibble::tibble(Name = c("a", "b"))),
    response = list(inserted_row_count = 2L)
  )
  expect_identical(out$n_rows, 2L)
  expect_identical(out$table, "Samples")
})

test_that("hb_query types its result from the schema the server reports", {
  cl <- mock_client()
  rec <- with_mocked_request(
    out <- hb_query(cl, "select n, d from Samples limit 5"),
    response = list(
      metadata = list(
        list(name = "n", type = "number", key = "a"),
        list(name = "d", type = "date", key = "b")
      ),
      results = list(
        list(n = 1, d = "2023-01-01T00:00:00+00:00"),
        list(n = NULL, d = NULL)
      )
    )
  )
  # Inferring from values instead would make an all-NULL column logical and
  # let one stray string turn a numeric column into character.
  expect_type(out$n, "double")
  expect_s3_class(out$d, "POSIXct")
  expect_true(is.na(out$n[[2L]]))
})

test_that("hb_query warns about SeaTable's implicit LIMIT 100", {
  cl <- mock_client()
  # The warning is rate-limited so a loop does not spam it; ask rlang to
  # emit it every time for the duration of this test.
  withr::local_options(rlib_warning_verbosity = "verbose")
  expect_warning(
    with_mocked_request(
      hb_query(cl, "select * from Samples"),
      response = list(metadata = list(), results = list())
    ),
    "LIMIT"
  )
})

test_that("hb_query stays quiet when the query has its own LIMIT", {
  cl <- mock_client()
  withr::local_options(rlib_warning_verbosity = "verbose")
  expect_no_warning(
    with_mocked_request(
      hb_query(cl, "select * from Samples LIMIT 10"),
      response = list(metadata = list(), results = list())
    )
  )
})

test_that("hb_query passes placeholders through as parameters", {
  cl <- mock_client()
  rec <- with_mocked_request(
    hb_query(cl, "select * from Samples where Name = ? limit 1",
             parameters = list("S-001")),
    response = list(metadata = list(), results = list())
  )
  expect_identical(rec$calls[[1]]$body$parameters, list("S-001"))
})

test_that("an out-of-schema column is a clear error, not a subscript crash", {
  cl <- mock_client()
  # types[[cn]] on a named vector errors for an absent name, so the
  # %||% "text" fallback beside it could never fire: the everyday
  # read |> mutate() |> update path crashed with a base R condition.
  expect_error(
    with_mocked_request(
      hb_update_rows(cl, "Samples", tibble::tibble(`_id` = "r1", ratio = 1.5)),
      response = list()
    ),
    class = "harbour_error_not_found"
  )
})

test_that("both write verbs drop server-computed columns", {
  meta <- hb_example_metadata()
  meta$tables[[1L]]$columns <- c(
    meta$tables[[1L]]$columns,
    list(list(name = "Serial", type = "auto-number", key = "z1"))
  )
  cl <- mock_client()
  cl$.metadata <- meta
  data <- tibble::tibble(`_id` = "r1", Name = "a", Serial = "0007")

  appended <- with_mocked_request(
    hb_append_rows(cl, "Samples", data), response = list()
  )
  updated <- with_mocked_request(
    hb_update_rows(cl, "Samples", data), response = list()
  )
  expect_false("Serial" %in% names(appended$calls[[1]]$body$rows[[1]]))
  expect_false("Serial" %in% names(updated$calls[[1]]$body$updates[[1]]$row))
})
