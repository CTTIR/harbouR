test_that("hb_example_metadata returns a harbour_metadata", {
  m <- hb_example_metadata()
  expect_s3_class(m, "harbour_metadata")
  expect_true(is_harbour_metadata(m))
})

test_that("as_tibble.harbour_metadata yields the expected shape", {
  m <- hb_example_metadata()
  tbl <- tibble::as_tibble(m)
  expect_named(tbl, c("name", "n_rows", "n_columns", "n_views"))
  expect_identical(tbl$name, c("Samples", "Patients"))
})

test_that("summary.harbour_metadata lists every column once", {
  m <- hb_example_metadata()
  s <- summary(m)
  expect_named(s, c("table", "column", "type"))
  expect_identical(sort(unique(s$table)), c("Patients", "Samples"))
})

test_that("print.harbour_metadata returns invisibly", {
  m <- hb_example_metadata()
  expect_invisible(print(m))
})
