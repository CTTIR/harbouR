# Every column type documented in hb_column_types() must behave the way the
# table says. Without this, the tribble and the three switch() statements
# that consume it can drift apart silently - which is how `duration`,
# `percent`, `dollar`, `euro` and `digital-sign` came to be missing, and how
# the empty and populated branches came to disagree about list-columns.

a_value_of_type <- function(type) {
  switch(type,
    "multiple-select" = , "collaborator" = , "image" = list("a", "b"),
    "file" = list(list(name = "a.pdf", size = 1L, type = "x", url = "/u")),
    "geolocation" = list(list(lat = 1.5, lng = 2.5)),
    "link" = , "link-formula" = list(list(row_id = "r1")),
    "button" = , "digital-sign" = list(list(username = "u")),
    "number" = , "percent" = , "dollar" = , "euro" = , "duration" = 12.5,
    "rate" = 3L,
    "checkbox" = TRUE,
    "date" = , "ctime" = , "mtime" = "2023-01-10T09:30:00+00:00",
    "some text"
  )
}

test_that("every documented type has a zero-length prototype", {
  for (type in hb_column_types()$seatable) {
    proto <- harbouR:::.hb_prototype(type)
    expect_identical(length(proto), 0L, info = type)
  }
})

test_that("empty and populated cells agree on type, for every type", {
  for (type in hb_column_types()$seatable) {
    empty <- harbouR:::.hb_coerce_cell(NULL, type)
    full <- harbouR:::.hb_coerce_cell(a_value_of_type(type), type)
    expect_identical(class(empty)[[1L]], class(full)[[1L]], info = type)
  }
})

test_that("a NULL cell never errors, for every type", {
  for (type in hb_column_types()$seatable) {
    expect_no_error(harbouR:::.hb_coerce_cell(NULL, type))
  }
})

test_that("a populated cell produces the R class the table promises", {
  expected <- c(
    character = "character", double = "numeric", integer = "integer",
    logical = "logical", POSIXct = "POSIXct", list = "list"
  )
  types <- hb_column_types()
  for (i in seq_len(nrow(types))) {
    type <- types$seatable[[i]]
    got <- harbouR:::.hb_coerce_cell(a_value_of_type(type), type)
    want <- if (types$is_list[[i]]) {
      # A list-column's elements are vectors of scalars for the flat types
      # and lists of objects for the structured ones.
      if (type %in% c("multiple-select", "collaborator", "image")) {
        "character"
      } else {
        "list"
      }
    } else {
      unname(expected[[harbouR:::.hb_r_type(type)]])
    }
    expect_identical(class(got)[[1L]], want, info = type)
  }
})

test_that("a whole column assembles to the promised type", {
  types <- hb_column_types()
  for (i in seq_len(nrow(types))) {
    type <- types$seatable[[i]]
    columns <- list(list(name = "X", type = type, key = "k1"))
    rows <- list(
      list(`_id` = "r1", X = a_value_of_type(type)),
      list(`_id` = "r2")
    )
    out <- harbouR:::.hb_rows_to_tibble(rows, columns)
    expect_identical(nrow(out), 2L, info = type)
    expect_named(out, c("X", "_id"), info = type)
    if (types$is_list[[i]]) {
      expect_type(out$X, "list")
    } else {
      expect_identical(length(out$X), 2L, info = type)
    }
  }
})

test_that("an unknown column type reads as text rather than erroring", {
  # A future SeaTable release must not break a read.
  expect_identical(harbouR:::.hb_r_type("brand-new-type"), "character")
  expect_identical(harbouR:::.hb_prototype("brand-new-type"), character())
  expect_identical(
    harbouR:::.hb_coerce_cell("x", "brand-new-type"), "x"
  )
})

test_that("ISO-8601 timestamps with offsets parse, including _ctime", {
  # This is the exact shape SeaTable writes for _ctime and _mtime; the
  # previous parser returned NA for all of them.
  expect_false(is.na(
    harbouR:::.hb_parse_date_value("2025-11-28T14:00:24.395+00:00")
  ))
  # An offset is honoured rather than ignored: 09:30+01:00 is 08:30 UTC.
  expect_identical(
    format(
      harbouR:::.hb_parse_date_value("2023-01-10T09:30:00+01:00"),
      "%H:%M"
    ),
    "08:30"
  )
  expect_true(is.na(harbouR:::.hb_parse_date_value("not a date")))
  expect_true(is.na(harbouR:::.hb_parse_date_value("")))
})

test_that("a column-less table still carries _id", {
  out <- harbouR:::.hb_rows_to_tibble(list(), list())
  expect_named(out, "_id")
  expect_identical(nrow(out), 0L)
})

test_that("cells can be looked up by column key as well as by name", {
  # The API keys rows by display name; a .dtable file keys them by the
  # column's 4-character key.
  columns <- list(list(name = "Regnr", type = "number", key = "0000"))
  rows <- list(list(`_id` = "r1", `0000` = 832))
  by_key <- harbouR:::.hb_rows_to_tibble(rows, columns, by = "key")
  expect_identical(by_key$Regnr, 832)
  by_name <- harbouR:::.hb_rows_to_tibble(rows, columns, by = "name")
  expect_true(is.na(by_name$Regnr))
})

test_that("non-syntactic and non-ASCII column names survive", {
  columns <- list(
    list(name = "Luftfeuchtigkeit (%])", type = "number", key = "a"),
    list(name = "Temperatur (°C)", type = "number", key = "b")
  )
  rows <- list(list(`_id` = "r1", a = 37.6, b = 20.7))
  out <- harbouR:::.hb_rows_to_tibble(rows, columns, by = "key")
  expect_named(out, c("Luftfeuchtigkeit (%])", "Temperatur (°C)", "_id"))
})
