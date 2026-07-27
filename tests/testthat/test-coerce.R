test_that("hb_column_types is non-empty and well-shaped", {
  ct <- hb_column_types()
  expect_named(ct, c("seatable", "r", "is_list", "read_only", "notes"))
  expect_gt(nrow(ct), 15L)
  expect_false(anyDuplicated(ct$seatable) > 0L)
  expect_type(ct$is_list, "logical")
  expect_type(ct$read_only, "logical")
})

test_that("hb_column_types covers every type SeaTable documents", {
  # Anything missing here is a column harbouR would silently read as text.
  documented <- c(
    "text", "long-text", "email", "url", "number", "percent", "dollar",
    "euro", "duration", "rate", "checkbox", "date", "single-select",
    "multiple-select", "collaborator", "image", "file", "geolocation",
    "link", "link-formula", "formula", "auto-number", "button",
    "digital-sign", "creator", "last-modifier", "ctime", "mtime"
  )
  expect_setequal(hb_column_types()$seatable, documented)
})

test_that("the coercion layer derives its type sets from the mapping", {
  expect_setequal(harbouR:::.hb_list_types(),
                  hb_column_types()$seatable[hb_column_types()$is_list])
  expect_setequal(harbouR:::.hb_readonly_types(),
                  hb_column_types()$seatable[hb_column_types()$read_only])
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

test_that("a user column named _id is refused rather than silently dropped", {
  columns <- list(
    list(name = "Name", type = "text", key = "k1"),
    list(name = "_id", type = "text", key = "k2")
  )
  rows <- list(list(`_id` = "r1", Name = "a", `_id` = "clash"))
  expect_error(
    harbouR:::.hb_rows_to_tibble(rows, columns),
    class = "harbour_error_column_collision"
  )
})

test_that("structured cells are not flattened on write", {
  # The write path used to unlist() every list-valued cell, which turns a
  # file cell's {name,size,type,url} object into a bare character vector.
  file_cell <- list(list(
    name = "a.pdf", size = 1, type = "application/pdf", url = "/u"
  ))
  cols <- list(list(name = "Reports", type = "file"))
  out <- harbouR:::.hb_tibble_to_rows(
    tibble::tibble(Reports = list(file_cell)), cols
  )
  expect_type(out[[1L]]$Reports, "list")
  expect_named(
    out[[1L]]$Reports[[1L]], c("name", "size", "type", "url")
  )
  expect_identical(out[[1L]]$Reports[[1L]]$url, "/u")
})

test_that("writable structured cells keep their structure", {
  for (type in c("geolocation", "image")) {
    cell <- list(list(lat = 1.5, lng = 2.5))
    out <- harbouR:::.hb_tibble_to_rows(
      tibble::tibble(X = list(cell)),
      list(list(name = "X", type = type))
    )
    expect_type(out[[1L]]$X, "list")
    expect_type(out[[1L]]$X[[1L]], "list")
  }
})

test_that("read-only columns are dropped from the write payload", {
  # link, link-formula, button and digital-sign are maintained by SeaTable;
  # sending them back would at best be ignored and at worst rejected.
  for (type in .hb_readonly_types()) {
    out <- harbouR:::.hb_tibble_to_rows(
      tibble::tibble(X = list(list(a = 1))),
      list(list(name = "X", type = type))
    )
    expect_null(out[[1L]]$X, info = type)
  }
})

test_that("flat list-columns serialise as arrays even when length 1", {
  # A length-1 character vector would auto_unbox to a JSON scalar, silently
  # changing a multiple-select cell's type on the wire.
  for (type in c("multiple-select", "collaborator")) {
    out <- harbouR:::.hb_tibble_to_rows(
      tibble::tibble(X = list("only")),
      list(list(name = "X", type = type))
    )
    expect_identical(out[[1L]]$X, list("only"))
  }
})

test_that("an empty structured cell serialises as an empty array", {
  out <- harbouR:::.hb_tibble_to_rows(
    tibble::tibble(X = list(NULL)),
    list(list(name = "X", type = "file"))
  )
  expect_identical(out[[1L]]$X, list())
})
