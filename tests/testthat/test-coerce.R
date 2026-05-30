test_that("hb_column_types is non-empty and well-shaped", {
  ct <- hb_column_types()
  expect_named(ct, c("seatable", "r", "notes"))
  expect_gt(nrow(ct), 15L)
})

test_that(".hb_rows_to_tibble returns a 0-row typed tibble for empty input", {
  meta <- hb_example_metadata()
  cols <- harbouR:::.hb_columns_from_metadata(meta, "Samples")
  tbl <- harbouR:::.hb_rows_to_tibble(list(), cols)
  expect_s3_class(tbl, "tbl_df")
  expect_identical(nrow(tbl), 0L)
  expect_true("Name" %in% names(tbl))
  expect_true("Tags" %in% names(tbl))
  expect_true(is.character(tbl$Name))
  expect_true(is.list(tbl$Tags))
  expect_true(is.list(tbl$Reports))
  expect_true(inherits(tbl$Collected, "POSIXt"))
})

test_that(".hb_rows_to_tibble preserves types across 1+ rows", {
  meta <- hb_example_metadata()
  cols <- harbouR:::.hb_columns_from_metadata(meta, "Samples")
  rows <- list(
    list(Name = "A", Concentration = 1.5, Status = "draft",
         Tags = c("x", "y"), Collected = "2026-04-01",
         Collaborators = c("a@b"), Reports = list(),
         `_id` = "r1"),
    list(Name = "B", Concentration = 2.5, Status = "ready",
         Tags = list(), Collected = "2026-04-02",
         Collaborators = list(), Reports = list(),
         `_id` = "r2")
  )
  tbl <- harbouR:::.hb_rows_to_tibble(rows, cols)
  expect_identical(nrow(tbl), 2L)
  expect_identical(tbl$Name, c("A", "B"))
  expect_identical(tbl$Concentration, c(1.5, 2.5))
  expect_true(is.list(tbl$Tags))
  expect_true(inherits(tbl$Collected, "POSIXt"))
})

test_that(".hb_rows_to_tibble degrades malformed numbers to NA", {
  meta <- hb_example_metadata()
  cols <- harbouR:::.hb_columns_from_metadata(meta, "Samples")
  rows <- list(list(Name = "x", Concentration = "not-a-number"))
  tbl <- harbouR:::.hb_rows_to_tibble(rows, cols)
  expect_true(is.na(tbl$Concentration[[1]]))
})
