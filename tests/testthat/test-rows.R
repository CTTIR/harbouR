# --- validation / guard branches -------------------------------------------

test_that("hb_read_table validates client, table, view and limit", {
  cl <- local_mock_client()
  expect_error(hb_read_table(1L, "Samples"), class = "rlang_error")
  expect_error(hb_read_table(cl, ""), class = "rlang_error")
  expect_error(hb_read_table(cl, "Samples", view = 1L), class = "rlang_error")
  expect_error(hb_read_table(cl, "Samples", limit = 0L), "positive integer")
  expect_error(hb_read_table(cl, "Samples", limit = NA), "positive integer")
})

test_that("hb_read_table paginates and returns a typed tibble", {
  cl <- local_mock_client()
  page1 <- lapply(1:2, function(i) list(Name = paste0("S", i), `_id` = paste0("r", i)))
  state <- new.env(); state$n <- 0L
  resp <- function(path, method, query, body) {
    state$n <- state$n + 1L
    if (state$n == 1L) list(rows = page1) else list(rows = list())
  }
  rec <- with_mocked_request(
    out <- hb_read_table(cl, "Samples", limit = 2L),
    response = resp
  )
  expect_s3_class(out, "tbl_df")
  expect_identical(out$Name, c("S1", "S2"))
  # Two requests: full page then the short final page.
  expect_identical(length(rec$calls), 2L)
  expect_identical(rec$calls[[1]]$query$table_name, "Samples")
})

test_that("hb_read_table forwards the view name", {
  cl <- local_mock_client()
  rec <- with_mocked_request(
    hb_read_table(cl, "Samples", view = "Default"),
    response = list(rows = list())
  )
  expect_identical(rec$calls[[1]]$query$view_name, "Default")
})

test_that("hb_query returns a tibble and handles empty results", {
  cl <- local_mock_client()
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
  cl <- local_mock_client()
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
  cl <- local_mock_client()
  expect_error(hb_query(cl, 1L), class = "rlang_error")
})

test_that("hb_get_row returns a 1-row or 0-row tibble", {
  cl <- local_mock_client()
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
  cl <- local_mock_client()
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
  cl <- local_mock_client()
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
  expect_identical(out$row_id, c("r1", "r2"))
  expect_true(all(out$updated))
  expect_identical(rec$calls[[1]]$method, "PUT")
})

test_that("hb_update_rows formats date cells and drops the id column", {
  cl <- local_mock_client()
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
  cl <- local_mock_client()
  expect_error(hb_delete_rows(cl, "Samples", character()), "non-empty")
  expect_error(hb_delete_rows(cl, "Samples", 1L), "non-empty")
  rec <- with_mocked_request(
    out <- hb_delete_rows(cl, "Samples", c("r1", "r2")),
    response = list()
  )
  expect_identical(out$row_id, c("r1", "r2"))
  expect_true(all(out$deleted))
  expect_identical(rec$calls[[1]]$method, "DELETE")
})

test_that("hb_lock_rows and hb_unlock_rows validate and return the client", {
  cl <- local_mock_client()
  expect_error(hb_lock_rows(cl, "Samples", character()), "non-empty")
  expect_error(hb_unlock_rows(cl, "Samples", 1L), "non-empty")
  rec <- with_mocked_request(
    res <- hb_lock_rows(cl, "Samples", "r1"),
    response = list()
  )
  expect_identical(res, cl)
  expect_identical(rec$calls[[1]]$path, "/dtable-server/api/v1/dtables/lock-rows/")
  rec2 <- with_mocked_request(
    res2 <- hb_unlock_rows(cl, "Samples", "r1"),
    response = list()
  )
  expect_identical(res2, cl)
  expect_match(rec2$calls[[1]]$path, "unlock-rows")
})
