# hb_validate_dtable() promises to report each structural problem its
# documentation lists. The duplicate-name and missing-key cases are
# pinned in test-dtable.R; these pin the rest, on bases broken by hand
# the way a script that edits `content` might break them.

two_tables <- function() {
  hb_dtable(A = data.frame(x = 1:2), B = data.frame(y = c("a", "b")))
}

problems_at <- function(problems, location) {
  problems$problem[problems$location == location]
}

test_that("a table without an id, or sharing one, is reported", {
  base <- two_tables()
  base$content$tables[[1L]][["_id"]] <- NULL
  problems <- hb_validate_dtable(base)
  expect_identical(problems_at(problems, "tables[[1]]"), "table has no `_id`")
  expect_identical(unique(problems$severity), "error")

  base <- two_tables()
  shared <- base$content$tables[[1L]][["_id"]]
  base$content$tables[[2L]][["_id"]] <- shared
  problems <- hb_validate_dtable(base)
  expect_identical(
    problems_at(problems, "tables[[2]]"),
    sprintf("duplicate table id `%s`", shared)
  )
})

test_that("a table without a name is reported", {
  base <- two_tables()
  base$content$tables[[2L]]$name <- ""
  problems <- hb_validate_dtable(base)
  expect_identical(problems_at(problems, "tables[[2]]"), "table has no name")
})

test_that("a column without a key, a type or a name is reported", {
  base <- two_tables()
  base$content$tables[[1L]]$columns[[1L]]$key <- NULL
  base$content$tables[[2L]]$columns[[1L]]$type <- NULL
  problems <- hb_validate_dtable(base)
  expect_identical(
    problems_at(problems, "tables[[1]]$columns[[1]]"),
    "column has no key"
  )
  expect_identical(
    problems_at(problems, "tables[[2]]$columns[[1]]"),
    "column has no type"
  )

  base <- two_tables()
  base$content$tables[[1L]]$columns[[1L]]$name <- NULL
  problems <- hb_validate_dtable(base)
  expect_identical(
    problems_at(problems, "tables[[1]]$columns[[1]]"),
    "column has no name"
  )
})

test_that("repeated column keys and names and an _id column are reported", {
  base <- hb_dtable(A = data.frame(x = 1, y = 2))
  columns <- base$content$tables[[1L]]$columns
  base$content$tables[[1L]]$columns[[2L]]$key <- columns[[1L]]$key
  problems <- hb_validate_dtable(base)
  expect_identical(
    problems_at(problems, "tables[[1]]$columns"),
    "duplicate column keys"
  )

  base <- hb_dtable(A = data.frame(x = 1, y = 2))
  base$content$tables[[1L]]$columns[[2L]]$name <- "x"
  problems <- hb_validate_dtable(base)
  expect_identical(
    problems_at(problems, "tables[[1]]$columns"),
    "duplicate column names"
  )

  base <- hb_dtable(A = data.frame(x = 1, y = 2))
  base$content$tables[[1L]]$columns[[2L]]$name <- "_id"
  problems <- hb_validate_dtable(base)
  expect_identical(
    problems_at(problems, "tables[[1]]$columns[[2]]"),
    "a column named `_id` collides with the row identifier"
  )
})

test_that("an empty table setting that would be written as [] is a warning", {
  base <- two_tables()
  base$content$tables[[2L]]$header_settings <- list()
  problems <- hb_validate_dtable(base)
  hit <- problems[problems$location == "tables[[2]]$header_settings", ]
  expect_identical(nrow(hit), 1L)
  expect_identical(hit$severity, "warning")
})

test_that("rows without an id are counted, and repeated ids reported", {
  base <- two_tables()
  base$content$tables[[1L]]$rows[[1L]][["_id"]] <- NULL
  problems <- hb_validate_dtable(base)
  expect_identical(
    problems_at(problems, "tables[[1]]$rows"),
    "1 row without an `_id`"
  )

  base$content$tables[[1L]]$rows[[2L]][["_id"]] <- NULL
  problems <- hb_validate_dtable(base)
  expect_identical(
    problems_at(problems, "tables[[1]]$rows"),
    "2 rows without an `_id`"
  )

  base <- two_tables()
  rows <- base$content$tables[[2L]]$rows
  base$content$tables[[2L]]$rows[[2L]][["_id"]] <- rows[[1L]][["_id"]]
  problems <- hb_validate_dtable(base)
  expect_identical(
    problems_at(problems, "tables[[2]]$rows"),
    "duplicate row ids"
  )
})

test_that("an empty view setting that would be written as [] is a warning", {
  base <- two_tables()
  expect_gt(length(base$content$tables[[1L]]$views), 0L)
  base$content$tables[[1L]]$views[[1L]]$colors <- list()
  problems <- hb_validate_dtable(base)
  hit <- problems[problems$location == "tables[[1]]$views[[1]]$colors", ]
  expect_identical(nrow(hit), 1L)
  expect_identical(hit$severity, "warning")
  expect_match(hit$problem, "SeaTable expects {}", fixed = TRUE)
})

test_that("a base that fails validation is not written", {
  base <- two_tables()
  base$content$tables[[1L]]$columns[[1L]]$key <- NULL
  out <- withr::local_tempfile(fileext = ".dtable")
  expect_error(
    hb_write_dtable(base, out),
    class = "harbour_error_bad_argument"
  )
  expect_false(file.exists(out))
})

# A table can lose its columns or its views the same way. Each listing
# then keeps its columns and their types, with no rows.

test_that("a table without columns or views lists as typed, empty tibbles", {
  base <- two_tables()
  base$content$tables[[1L]]$columns <- NULL
  base$content$tables[[1L]]$views <- NULL

  columns <- hb_list_columns(base, "A")
  expect_identical(nrow(columns), 0L)
  expect_identical(
    vapply(columns, function(col) class(col)[[1L]], character(1)),
    c(name = "character", type = "character", key = "character",
      editable = "logical", data = "list")
  )
  expect_identical(
    names(columns),
    names(hb_list_columns(base, "B"))
  )

  views <- hb_list_views(base, "A")
  expect_identical(nrow(views), 0L)
  expect_identical(
    vapply(views, function(col) class(col)[[1L]], character(1)),
    c(name = "character", type = "character", is_default = "logical")
  )
  expect_identical(names(views), names(hb_list_views(base, "B")))
})

test_that("summary() of metadata skips a table without columns", {
  meta <- hb_example_metadata()
  full <- summary(meta)
  meta$tables[[1L]]$columns <- NULL
  partial <- summary(meta)
  expect_identical(unique(partial$table), "Patients")
  expect_identical(partial, full[full$table == "Patients", ])

  meta$tables[[2L]]$columns <- list()
  empty <- summary(meta)
  expect_identical(nrow(empty), 0L)
  expect_identical(
    vapply(empty, function(col) class(col)[[1L]], character(1)),
    c(table = "character", column = "character", type = "character")
  )
})

# Two CSV files of the same name in different folders, as the help page
# of hb_read_csv() describes: unnamed, their tables share a name the
# validator reports; named, they do not.

test_that("CSV files sharing a file name need names to make a valid base", {
  dir_a <- withr::local_tempdir()
  dir_b <- withr::local_tempdir()
  files <- c(file.path(dir_a, "data.csv"), file.path(dir_b, "data.csv"))
  utils::write.csv(data.frame(x = 1), files[[1L]], row.names = FALSE)
  utils::write.csv(data.frame(y = 2), files[[2L]], row.names = FALSE)

  shared <- hb_read_csv(files)
  expect_identical(hb_list_tables(shared)$name, c("data", "data"))
  problems <- hb_validate_dtable(shared)
  expect_identical(
    problems_at(problems, "tables[[2]]"),
    "duplicate table name `data`"
  )

  named <- hb_read_csv(c(First = files[[1L]], Second = files[[2L]]))
  expect_identical(hb_list_tables(named)$name, c("First", "Second"))
  expect_identical(nrow(hb_validate_dtable(named)), 0L)
})
