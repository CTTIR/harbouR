test_that("hb_example_rows is type-stable across tables", {
  s <- hb_example_rows("Samples")
  p <- hb_example_rows("Patients")
  expect_s3_class(s, "tbl_df")
  expect_s3_class(p, "tbl_df")
  expect_true(is.list(s$Tags))
  expect_true(is.list(s$Collaborators))
  expect_true(is.list(s$Reports))
  expect_true(inherits(s$Collected, "POSIXt"))
  expect_true(is.logical(p$Consented))
})

test_that("list_tables returns a 0-row tibble with the expected columns when no tables", {
  cl <- local_mock_client()
  cl$.metadata <- new_harbour_metadata(list(tables = list()),
                                       base_name = "empty")
  res <- hb_list_tables(cl)
  expect_named(res, c("name", "n_rows", "n_columns", "n_views"))
  expect_identical(nrow(res), 0L)
  expect_true(is.character(res$name))
})

test_that("hb_list_columns returns 0-row tibble with declared columns when no cols", {
  cl <- local_mock_client()
  cl$.metadata <- new_harbour_metadata(
    list(tables = list(list(name = "T", columns = list(), views = list()))),
    base_name = "empty"
  )
  res <- hb_list_columns(cl, "T")
  expect_named(res, c("name", "type", "key", "editable"))
  expect_identical(nrow(res), 0L)
})

test_that(".hb_rows_to_tibble keeps the same column types for 0, 1 and many rows", {
  meta <- hb_example_metadata()
  cols <- harbouR:::.hb_columns_from_metadata(meta, "Samples")
  empty <- harbouR:::.hb_rows_to_tibble(list(), cols)
  one <- harbouR:::.hb_rows_to_tibble(list(list(Name = "x", Concentration = 1)), cols)
  expect_true(is.list(empty$Tags) && is.list(one$Tags))
  expect_true(is.list(empty$Reports) && is.list(one$Reports))
  expect_true(inherits(empty$Collected, "POSIXt") && inherits(one$Collected, "POSIXt"))
})
