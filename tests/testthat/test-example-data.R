test_that("hb_example_rows defaults to Samples and validates the argument", {
  default <- hb_example_rows()
  expect_identical(default$Name, c("S-001", "S-002", "S-003"))
  expect_error(hb_example_rows("Nope"))
})

test_that("hb_example_rows Patients has the expected column types", {
  p <- hb_example_rows("Patients")
  expect_named(p, c("Patient ID", "Age", "Consented", "Last visit", "_id"))
  expect_true(is.logical(p$Consented))
  expect_s3_class(p$`Last visit`, "POSIXct")
})

test_that("new_harbour_metadata fills defaults from base_name and payload", {
  m1 <- harbouR:::new_harbour_metadata(list(tables = list()), base_name = "B")
  expect_identical(m1$base_name, "B")
  expect_identical(m1$version, NA_character_)

  m2 <- harbouR:::new_harbour_metadata(
    list(tables = list(), base_name = "fromPayload", version = 9))
  expect_identical(m2$base_name, "fromPayload")
  expect_identical(m2$version, "9")
})

test_that("example metadata round-trips through the listing tibble", {
  m <- hb_example_metadata()
  tbl <- tibble::as_tibble(m)
  expect_identical(tbl$n_columns, c(7L, 4L))
  expect_identical(tbl$n_views, c(1L, 1L))
})
