test_that(".hb_columns_from_metadata validates and errors on unknown table", {
  m <- hb_example_metadata()
  cols <- harbouR:::.hb_columns_from_metadata(m, "Samples")
  expect_true(length(cols) > 0L)
  expect_error(harbouR:::.hb_columns_from_metadata(m, "Nope"), "not found")
  expect_error(harbouR:::.hb_columns_from_metadata(list(), "x"),
               "harbour_metadata")
})

test_that(".hb_empty_vector_for_type returns the right empty type", {
  expect_type(harbouR:::.hb_empty_vector_for_type("text"), "character")
  expect_type(harbouR:::.hb_empty_vector_for_type("number"), "double")
  expect_type(harbouR:::.hb_empty_vector_for_type("rate"), "integer")
  expect_type(harbouR:::.hb_empty_vector_for_type("checkbox"), "logical")
  expect_s3_class(harbouR:::.hb_empty_vector_for_type("date"), "POSIXct")
  expect_type(harbouR:::.hb_empty_vector_for_type("file"), "list")
  expect_type(harbouR:::.hb_empty_vector_for_type(NULL), "character")
  expect_type(harbouR:::.hb_empty_vector_for_type("mystery"), "character")
})

test_that(".hb_coerce_cell handles NULL across types", {
  expect_identical(harbouR:::.hb_coerce_cell(NULL, "number"), NA_real_)
  expect_identical(harbouR:::.hb_coerce_cell(NULL, "rate"), NA_integer_)
  expect_identical(harbouR:::.hb_coerce_cell(NULL, "checkbox"), NA)
  expect_true(is.na(harbouR:::.hb_coerce_cell(NULL, "date")))
  expect_identical(harbouR:::.hb_coerce_cell(NULL, "file"), list())
  expect_identical(harbouR:::.hb_coerce_cell(NULL, "text"), NA_character_)
  expect_identical(harbouR:::.hb_coerce_cell(NULL, NULL), NA_character_)
})

test_that(".hb_coerce_cell coerces by declared type", {
  expect_identical(harbouR:::.hb_coerce_cell("hi", "text"), "hi")
  expect_identical(harbouR:::.hb_coerce_cell("3.5", "number"), 3.5)
  expect_identical(harbouR:::.hb_coerce_cell("bad", "number"), NA_real_)
  expect_identical(harbouR:::.hb_coerce_cell("4", "rate"), 4L)
  expect_identical(harbouR:::.hb_coerce_cell("oops", "rate"), NA_integer_)
  expect_true(harbouR:::.hb_coerce_cell("TRUE", "checkbox"))
  expect_false(harbouR:::.hb_coerce_cell("no", "checkbox"))
  expect_identical(harbouR:::.hb_coerce_cell(list("a", "b"), "multiple-select"),
                   c("a", "b"))
  expect_type(harbouR:::.hb_coerce_cell("x", "button"), "list")
})

test_that(".hb_is_list_type classifies list-valued columns", {
  expect_true(harbouR:::.hb_is_list_type("file"))
  expect_true(harbouR:::.hb_is_list_type("multiple-select"))
  expect_false(harbouR:::.hb_is_list_type("text"))
  expect_false(harbouR:::.hb_is_list_type("number"))
})

test_that(".hb_parse_date_value covers each branch", {
  expect_true(is.na(harbouR:::.hb_parse_date_value(NULL)))
  expect_true(is.na(harbouR:::.hb_parse_date_value("")))
  expect_true(is.na(harbouR:::.hb_parse_date_value("nonsense")))
  expect_s3_class(harbouR:::.hb_parse_date_value("2026-04-01"), "POSIXct")
  expect_s3_class(harbouR:::.hb_parse_date_value("2026/04/01"), "POSIXct")
  expect_s3_class(harbouR:::.hb_parse_date_value(0), "POSIXct")
  expect_s3_class(
    harbouR:::.hb_parse_date_value(as.POSIXct("2026-01-01", tz = "UTC")),
    "POSIXct"
  )
})

test_that(".hb_tibble_to_rows drops read-only columns and formats dates", {
  m <- hb_example_metadata()
  cols <- harbouR:::.hb_columns_from_metadata(m, "Samples")
  data <- tibble::tibble(
    Name = "S1",
    Concentration = 1.0,
    Collected = as.POSIXct("2026-04-01", tz = "UTC"),
    Tags = list(c("a", "b"))
  )
  rows <- harbouR:::.hb_tibble_to_rows(data, cols)
  expect_length(rows, 1L)
  expect_identical(rows[[1]]$Name, "S1")
  expect_match(rows[[1]]$Collected, "^2026-04-01")
  expect_identical(rows[[1]]$Tags, c("a", "b"))
})

test_that(".hb_tibble_to_rows rejects non-data-frames", {
  m <- hb_example_metadata()
  cols <- harbouR:::.hb_columns_from_metadata(m, "Samples")
  expect_error(harbouR:::.hb_tibble_to_rows(1L, cols), "data frame")
})

test_that(".hb_rows_to_tibble parser output is a stable regression lock", {
  m <- hb_example_metadata()
  cols <- harbouR:::.hb_columns_from_metadata(m, "Samples")
  rows <- list(
    list(Name = "A", Concentration = 1.5, Status = "draft",
         Tags = c("x", "y"), Collected = "2026-04-01 09:00:00",
         Collaborators = c("a@b"), Reports = list(), `_id` = "r1")
  )
  tbl <- harbouR:::.hb_rows_to_tibble(rows, cols)
  expect_snapshot_value(
    lapply(tbl, function(col) if (inherits(col, "POSIXt")) format(col) else col),
    style = "json2"
  )
})
