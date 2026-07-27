fixture <- function() {
  system.file("extdata", "example.dtable", package = "harbouR")
}

test_that("a .dtable reads into the documented structure", {
  base <- hb_read_dtable(fixture())
  expect_s3_class(base, "harbour_dtable")
  expect_true(is_harbour_dtable(base))
  # names() on a dtable gives its tables, not its internal slots.
  expect_identical(names(base), c("Samples", "Reference"))
  expect_setequal(
    names(unclass(base)),
    c("content", "path", "assets", "assets_dir", "base_name")
  )
  expect_identical(length(base), 2L)
})

test_that("the same verbs work on a file as on a live base", {
  base <- hb_read_dtable(fixture())
  tables <- hb_list_tables(base)
  expect_named(tables, c("name", "n_rows", "n_columns", "n_views"))
  # Unlike the server path, the row count is real: the rows are in the file.
  expect_identical(tables$n_rows, c(2L, 2L))

  columns <- hb_list_columns(base, "Samples")
  expect_named(columns, c("name", "type", "key", "editable", "data"))
  expect_true("digital-sign" %in% columns$type)

  views <- hb_list_views(base, "Samples")
  expect_identical(views$name, "Default View")
})

test_that("cells are read by column key, and types are right", {
  data <- hb_read_table(hb_read_dtable(fixture()), "Samples")
  expect_identical(nrow(data), 2L)
  expect_type(data$Name, "character")
  expect_type(data$Concentration, "double")
  expect_type(data$Consented, "logical")
  expect_s3_class(data$Collected, "POSIXct")
  expect_type(data$Tags, "list")
  expect_identical(data$Name, c("S-001", "S-002"))
})

test_that("select options are translated from ids to names", {
  base <- hb_read_dtable(fixture())
  # On disk the cell holds "opt2"; over the API it would hold "ready".
  labelled <- hb_read_table(base, "Samples")
  expect_identical(labelled$Status, c("ready", "draft"))
  expect_identical(labelled$Tags[[2L]], "urgent")

  raw <- hb_read_table(base, "Samples", option_labels = FALSE)
  expect_identical(raw$Status, c("opt2", "opt1"))
})

test_that("full-precision numbers survive the read", {
  data <- hb_read_table(hb_read_dtable(fixture()), "Samples")
  expect_identical(data$Concentration[[1L]], 0.00058747474747474751)
})

test_that("an absent cell reads as NA, not as an error", {
  data <- hb_read_table(hb_read_dtable(fixture()), "Samples")
  # Row 2 omits most keys entirely, which is how SeaTable writes an empty
  # cell - not as null, and not as "".
  expect_true(is.na(data$Homepage[[2L]]))
  expect_identical(data$Reports[[2L]], list())
})

test_that("a long-text cell reads whether it is a string or an object", {
  data <- hb_read_table(hb_read_dtable(fixture()), "Samples")
  expect_identical(data$Notes[[1L]], "A plain **markdown** string.")
  expect_identical(data$Notes[[2L]], "Rendered elsewhere.")
})

test_that("non-ASCII column names survive", {
  data <- hb_read_table(hb_read_dtable(fixture()), "Samples")
  expect_true("Temperatur (°C)" %in% names(data))
})

test_that("n_max bounds a local read", {
  data <- hb_read_table(hb_read_dtable(fixture()), "Samples", n_max = 1L)
  expect_identical(nrow(data), 1L)
})

test_that("reading and writing is a fixed point", {
  base <- hb_read_dtable(fixture())
  out <- withr::local_tempfile(fileext = ".dtable")
  expect_identical(hb_write_dtable(base, out), base)
  expect_identical(hb_read_dtable(out)$content, base$content)
})

test_that("the round trip preserves fields harbouR does not model", {
  base <- hb_read_dtable(fixture())
  out <- withr::local_tempfile(fileext = ".dtable")
  hb_write_dtable(base, out)
  again <- hb_read_dtable(out)
  # A future SeaTable release will add fields; keeping the parsed tree
  # verbatim is what stops them being silently dropped.
  expect_false(is.null(again$content$plugin_settings))
  expect_identical(again$content$version, base$content$version)
})

test_that("the writer keeps object slots as objects, not arrays", {
  base <- hb_read_dtable(fixture())
  json <- as.character(harbouR:::.hb_dtable_to_json(base$content))
  # jsonlite writes list() as []; SeaTable's importer needs {} here.
  expect_match(json, '"id_row_map":{}', fixed = TRUE)
  expect_match(json, '"summary_configs":{}', fixed = TRUE)
  expect_match(json, '"header_settings":{}', fixed = TRUE)
})

test_that("a single-element array is not collapsed to a scalar", {
  base <- hb_read_dtable(fixture())
  json <- as.character(harbouR:::.hb_dtable_to_json(base$content))
  # auto_unbox would write "tag1" instead of ["tag1"], changing the type.
  expect_match(json, '["tag1"]', fixed = TRUE)
})

test_that("full precision survives the write", {
  base <- hb_read_dtable(fixture())
  json <- as.character(harbouR:::.hb_dtable_to_json(base$content))
  # The toJSON() default of digits = 4 writes 0.0006.
  expect_match(json, "0.00058747474747474751", fixed = TRUE)
})

test_that("a base can be built from data frames and written", {
  base <- hb_dtable(
    Samples = data.frame(
      Name = c("a", "b"),
      Value = c(1.5, 2.5),
      Ok = c(TRUE, FALSE),
      stringsAsFactors = FALSE
    ),
    base_name = "Built in R"
  )
  expect_s3_class(base, "harbour_dtable")
  expect_identical(names(base), "Samples")
  types <- hb_list_columns(base, "Samples")$type
  expect_identical(types, c("text", "number", "checkbox"))
  # The first column of a table always keys "0000".
  expect_identical(hb_list_columns(base, "Samples")$key[[1L]], "0000")

  out <- withr::local_tempfile(fileext = ".dtable")
  hb_write_dtable(base, out)
  expect_identical(hb_read_table(hb_read_dtable(out), "Samples")$Name,
                   c("a", "b"))
})

test_that("hb_dtable infers a single-select from a factor", {
  base <- hb_dtable(T1 = data.frame(g = factor(c("x", "y", "x"))))
  columns <- hb_list_columns(base, "T1")
  expect_identical(columns$type, "single-select")
  expect_length(columns$data[[1L]]$options, 2L)
})

test_that("hb_validate_dtable reports a clean base as clean", {
  problems <- hb_validate_dtable(hb_read_dtable(fixture()))
  expect_named(problems, c("location", "problem", "severity"))
  expect_identical(nrow(problems), 0L)
})

test_that("hb_validate_dtable catches duplicates and missing keys", {
  base <- hb_dtable(A = data.frame(x = 1), B = data.frame(x = 2))
  base$content$tables[[2L]]$name <- "A"
  base$content$version <- NULL
  problems <- hb_validate_dtable(base)
  expect_true(any(grepl("duplicate table name", problems$problem)))
  expect_true(any(grepl("version", problems$problem)))
})

test_that("the writer refuses a base that would not import", {
  base <- hb_dtable(A = data.frame(x = 1), B = data.frame(x = 2))
  base$content$tables[[2L]]$name <- "A"
  out <- withr::local_tempfile(fileext = ".dtable")
  expect_error(hb_write_dtable(base, out),
               class = "harbour_error_bad_argument")
})

test_that("assets are listed and can be extracted", {
  base <- hb_read_dtable(fixture())
  expect_gt(nrow(base$assets), 0L)
  expect_true(any(grepl("readme.txt", base$assets$filename)))
  # Without extraction there is nowhere for an asset path to point.
  expect_true(is.na(hb_asset_path(base, "file://dtable-bundle/asset/x")))

  extracted <- hb_read_dtable(fixture(), assets = "extract")
  path <- hb_asset_path(
    extracted, "file://dtable-bundle/asset/files/2026-07/readme.txt"
  )
  expect_true(file.exists(path))
  expect_identical(readLines(path, warn = FALSE), "hello world")
})

test_that("a non-dtable file is refused with a useful message", {
  not_zip <- withr::local_tempfile(fileext = ".dtable")
  writeLines("not a zip", not_zip)
  expect_error(hb_read_dtable(not_zip),
               class = "harbour_error_bad_argument")

  wrong_zip <- withr::local_tempfile(fileext = ".dtable")
  dir <- withr::local_tempdir()
  writeLines("x", file.path(dir, "other.txt"))
  zip::zip(wrong_zip, "other.txt", root = dir, mode = "cherry-pick")
  expect_error(hb_read_dtable(wrong_zip),
               class = "harbour_error_bad_argument")

  expect_error(hb_read_dtable(file.path(dir, "nope.dtable")),
               class = "harbour_error_not_found")
})

test_that("a newer format version warns but still reads", {
  base <- hb_read_dtable(fixture())
  base$content$format_version <- 99L
  out <- withr::local_tempfile(fileext = ".dtable")
  hb_write_dtable(base, out)
  expect_warning(hb_read_dtable(out), "format version 99")
})

test_that("generated identifiers match SeaTable's shapes", {
  ids <- replicate(1000L, harbouR:::.hb_new_row_id())
  expect_identical(length(unique(ids)), 1000L)
  expect_true(all(nchar(ids) == 22L))
  expect_true(all(grepl("^[A-Za-z0-9_-]{22}$", ids)))

  keys <- replicate(200L, harbouR:::.hb_new_short_id())
  expect_true(all(nchar(keys) == 4L))
  # A new table's first column and first view are always "0000".
  expect_identical(harbouR:::.hb_new_column_key(character()), "0000")
  expect_identical(harbouR:::.hb_new_view_id(character()), "0000")
  expect_false(harbouR:::.hb_new_column_key("0000") == "0000")
})

test_that("exporting to csv and xlsx flattens, and says so", {
  base <- hb_read_dtable(fixture())
  dir <- withr::local_tempdir()
  expect_message(hb_write_csv(base, dir), "flattened")
  expect_setequal(list.files(dir), c("Samples.csv", "Reference.csv"))
  back <- utils::read.csv(file.path(dir, "Samples.csv"), check.names = FALSE)
  expect_identical(nrow(back), 2L)
  expect_identical(back$Tags[[1L]], "urgent, blood")
})

test_that("hb_write_xlsx writes one sheet per table", {
  skip_if_not_installed("writexl")
  skip_if_not_installed("readxl")
  base <- hb_read_dtable(fixture())
  path <- withr::local_tempfile(fileext = ".xlsx")
  suppressMessages(hb_write_xlsx(base, path, tables = "Reference"))
  expect_identical(readxl::excel_sheets(path), "Reference")
  expect_identical(nrow(readxl::read_excel(path)), 2L)
})

test_that("exporting an unknown table names the ones that exist", {
  base <- hb_read_dtable(fixture())
  dir <- withr::local_tempdir()
  expect_error(hb_write_csv(base, dir, tables = "Nope"),
               class = "harbour_error_not_found")
})

test_that("hb_read_csv builds a new base rather than restoring one", {
  csv <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(data.frame(x = 1:2, y = c("a", "b")), csv,
                   row.names = FALSE)
  base <- hb_read_csv(c(Measurements = csv))
  expect_identical(names(base), "Measurements")
  expect_identical(nrow(hb_read_table(base, "Measurements")), 2L)
})

test_that("reading an unknown table lists the ones that exist", {
  base <- hb_read_dtable(fixture())
  expect_error(hb_read_table(base, "Nope"),
               class = "harbour_error_not_found")
  expect_error(hb_list_columns(base, "Nope"),
               class = "harbour_error_not_found")
})

test_that("print, format and summary describe the base", {
  base <- hb_read_dtable(fixture())
  expect_snapshot(print(base))
  expect_length(format(base), 2L)
  schema <- summary(base)
  expect_named(schema, c("table", "column", "type", "key"))
  expect_identical(nrow(schema), 29L)
})

test_that("hb_read_xlsx builds a base from a workbook", {
  skip_if_not_installed("writexl")
  skip_if_not_installed("readxl")
  path <- withr::local_tempfile(fileext = ".xlsx")
  writexl::write_xlsx(
    list(Alpha = data.frame(x = 1:2), Beta = data.frame(y = c("a", "b"))),
    path
  )
  base <- hb_read_xlsx(path)
  expect_setequal(names(base), c("Alpha", "Beta"))
  expect_identical(nrow(hb_read_table(base, "Alpha")), 2L)

  only <- hb_read_xlsx(path, sheets = "Beta")
  expect_identical(names(only), "Beta")
  expect_error(hb_read_xlsx(path, sheets = "Gamma"),
               class = "harbour_error_not_found")
})

test_that("hb_read_csv validates its inputs", {
  expect_error(hb_read_csv(1L), class = "harbour_error_bad_argument")
  expect_error(hb_read_csv("nope.csv"), class = "harbour_error_not_found")
})

test_that("hb_read_xlsx refuses a file that is not there", {
  skip_if_not_installed("readxl")
  expect_error(hb_read_xlsx("nope.xlsx"), class = "harbour_error_not_found")
})

test_that("hb_dtable refuses input it cannot turn into a base", {
  expect_error(hb_dtable(), class = "harbour_error_bad_argument")
  expect_error(hb_dtable(data.frame(x = 1)),
               class = "harbour_error_bad_argument")
  expect_error(hb_dtable(A = 1:3), class = "harbour_error_bad_argument")
})

test_that("hb_write_dtable refuses to clobber unless asked", {
  base <- hb_dtable(A = data.frame(x = 1))
  out <- withr::local_tempfile(fileext = ".dtable")
  hb_write_dtable(base, out)
  expect_error(hb_write_dtable(base, out, overwrite = FALSE),
               class = "harbour_error_bad_argument")
  expect_no_error(hb_write_dtable(base, out))
})

test_that("a dtable with no tables still behaves", {
  base <- hb_dtable(A = data.frame(x = 1))
  base$content$tables <- list()
  expect_identical(length(base), 0L)
  expect_identical(names(base), character())
  expect_identical(nrow(tibble::as_tibble(base)), 0L)
  expect_identical(nrow(summary(base)), 0L)
  expect_identical(format(base), character())
  expect_true(any(hb_validate_dtable(base)$severity == "warning"))
})

test_that("a view restricts the rows a local read returns", {
  base <- hb_read_dtable(
    system.file("extdata", "example.dtable", package = "harbouR")
  )
  # The default view lists no rows, which means "all of them".
  expect_identical(nrow(hb_read_table(base, "Samples", view = "Default View")),
                   2L)
  base$content$tables[[1L]]$views[[1L]]$rows <- list("CwD7tBAETtSXLQKQXhaR6A")
  expect_identical(nrow(hb_read_table(base, "Samples", view = "Default View")),
                   1L)
  expect_error(hb_read_table(base, "Samples", view = "Nope"),
               class = "harbour_error_not_found")
})

test_that("values beyond 2^53 warn about lost precision", {
  base <- hb_dtable(A = data.frame(big = 2^60))
  expect_warning(hb_read_table(base, "A"), "2\\^53")
})

test_that("empty and NA cells are omitted from a built base", {
  base <- hb_dtable(A = data.frame(
    x = c("a", NA), y = c(1, NA), stringsAsFactors = FALSE
  ))
  rows <- base$content$tables[[1L]]$rows
  # SeaTable records an empty cell by leaving the key out entirely.
  expect_false("0000" %in% names(rows[[2L]]))
  data <- hb_read_table(base, "A")
  expect_true(is.na(data$x[[2L]]))
})

test_that("dates survive a build and read", {
  base <- hb_dtable(A = data.frame(when = as.Date("2026-07-27")))
  expect_identical(hb_list_columns(base, "A")$type, "date")
  expect_identical(
    format(hb_read_table(base, "A")$when, "%Y-%m-%d"), "2026-07-27"
  )
})

test_that("a round trip through the app preserves bundled assets", {
  src <- system.file("extdata", "example.dtable", package = "harbouR")
  out <- withr::local_tempfile(fileext = ".dtable")
  hb_write_dtable(hb_read_dtable(src, assets = "extract"), out)
  expect_setequal(zip::zip_list(out)$filename, zip::zip_list(src)$filename)
})

test_that("writing a base whose assets were not extracted warns loudly", {
  # Reading with the default assets = "none" keeps the cells that point at
  # file://dtable-bundle/... but not the files, so writing it back would
  # otherwise silently produce an archive with dangling attachments.
  src <- system.file("extdata", "example.dtable", package = "harbouR")
  out <- withr::local_tempfile(fileext = ".dtable")
  expect_warning(hb_write_dtable(hb_read_dtable(src), out),
                 "bundled asset")
  expect_identical(nrow(zip::zip_list(out)), 1L)
})

test_that("a base with no assets writes without warning", {
  base <- hb_dtable(A = data.frame(x = 1))
  out <- withr::local_tempfile(fileext = ".dtable")
  expect_no_warning(hb_write_dtable(base, out))
})

test_that("assets = FALSE is an explicit choice, and says so", {
  src <- system.file("extdata", "example.dtable", package = "harbouR")
  out <- withr::local_tempfile(fileext = ".dtable")
  expect_warning(
    hb_write_dtable(hb_read_dtable(src, assets = "extract"), out,
                    assets = FALSE),
    "assets = FALSE"
  )
})

test_that("a value JSON cannot hold warns rather than vanishing", {
  # JSON has no Inf or NaN, so null is the only option - but a number
  # quietly becoming NA on the next read is the wrong way to learn that.
  expect_warning(hb_dtable(A = data.frame(x = c(1, Inf))), "cannot be")
  expect_warning(hb_dtable(A = data.frame(x = c(1, -Inf))), "cannot be")
  expect_no_warning(hb_dtable(A = data.frame(x = c(1, 2))))
  expect_no_warning(hb_dtable(A = data.frame(x = c(1, NA))))
})

test_that("the documented asset URL actually resolves in the fixture", {
  # The example in hb_asset_path.Rd demonstrated the failure path; assert
  # the documented URL so a future fixture rebuild fails here instead.
  base <- hb_read_dtable(
    system.file("extdata", "example.dtable", package = "harbouR"),
    assets = "extract"
  )
  path <- hb_asset_path(
    base, "file://dtable-bundle/asset/files/2026-07/readme.txt"
  )
  expect_false(is.na(path))
  expect_true(file.exists(path))
})

test_that("hb_read_dtable validates assets_dir", {
  src <- system.file("extdata", "example.dtable", package = "harbouR")
  expect_error(hb_read_dtable(src, assets = "extract", assets_dir = 42),
               class = "harbour_error_bad_argument")
})
