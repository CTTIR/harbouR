test_that("column-less payloads retain every row and its identifier", {
  rows <- list(list(`_id` = "first"), list(), list(`_id` = "last"))
  for (by in c("name", "key")) {
    read <- .hb_rows_to_tibble(rows, list(), by = by)
    expect_identical(read, tibble::tibble(
      `_id` = c("first", NA_character_, "last")
    ))
  }
  expect_identical(
    .hb_rows_to_tibble(list(), list()), tibble::tibble(`_id` = character())
  )
})

test_that("column-less tables retain their rows through an archive", {
  base <- hb_dtable(Records = data.frame(row.names = seq_len(3L)))
  expected_ids <- vapply(
    base$content$tables[[1L]]$rows, `[[`, character(1), "_id"
  )
  expect_length(expected_ids, 3L)
  path <- withr::local_tempfile(fileext = ".dtable")
  hb_write_dtable(base, path)
  read <- hb_read_table(hb_read_dtable(path), "Records")
  expect_identical(read, tibble::tibble(`_id` = expected_ids))
})

test_that("ID-only CSV imports retain their rows with new identifiers", {
  path <- withr::local_tempfile(fileext = ".csv")
  ids <- c("AAAAAAAAAAAAAAAAAAAAAA", "BBBBBBBBBBBBBBBBBBBBBB")
  utils::write.csv(
    data.frame(`_id` = ids, check.names = FALSE), path, row.names = FALSE
  )
  base <- hb_read_csv(c(Records = path))
  read <- hb_read_table(base, "Records")
  expect_named(read, "_id")
  expect_identical(nrow(read), 2L)
  expect_length(unique(read$`_id`), 2L)
  # CSV import creates a new base, rather than restoring exported row IDs.
  expect_false(any(read$`_id` %in% ids))
})
