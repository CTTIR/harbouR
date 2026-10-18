# Golden values for what harbouR returns without a server.
#
# Manuscripts rely on these outputs: reading the bundled example base, the
# example data, the column-type table, the files the .dtable and CSV
# writers produce, and what the CSV and Excel exports read back as. The
# other tests check properties of them; these pin the outputs themselves,
# so that a change to any of them - however small - has to be accepted as
# a new snapshot rather than slip through. As with the API lock, accepting
# one is a decision to change what a published analysis saw.
#
# Values are rendered to text before they are snapshotted. That makes the
# comparison exact rather than within a tolerance, and the same on every
# platform: doubles in the shortest form that reads back as the same
# number, date-times in UTC next to their exact seconds, and list cells as
# JSON that keeps each value's storage type.

golden_example <- function() {
  system.file("extdata", "example.dtable", package = "harbouR")
}

# The example base holds non-ASCII text, which a session that is not UTF-8
# cannot represent faithfully.
skip_if_not_utf8 <- function() {
  skip_if_not(isTRUE(l10n_info()[["UTF-8"]]), "the session is not UTF-8")
}

# The shortest of 15 to 17 significant digits that reads back as the same
# double. jsonlite parses with the C library's strtod(), which rounds
# correctly everywhere; R's own parser need not, which would let the number
# of digits shown depend on the platform.
golden_num <- function(x) {
  vapply(
    as.double(x),
    function(value) {
      if (is.na(value) && !is.nan(value)) {
        return(NA_character_)
      }
      if (!is.finite(value)) {
        return(format(value))
      }
      for (digits in 15:17) {
        text <- sprintf("%.*g", digits, value)
        if (identical(as.double(jsonlite::parse_json(text)), value)) break
      }
      text
    },
    character(1)
  )
}

# A date-time in UTC whatever the session's zone, with its exact seconds:
# the formatted time alone would hide a change below a second.
golden_time <- function(x) {
  if (length(x) == 0L) {
    return(character())
  }
  out <- paste0(
    format(x, "%Y-%m-%d %H:%M:%S", tz = "UTC"), " UTC (", golden_num(x), ")"
  )
  out[is.na(x)] <- NA_character_
  out
}

golden_type <- function(x) {
  if (is.object(x)) paste(class(x), collapse = "/") else typeof(x)
}

# Every value as a string, so the snapshot compares exactly.
golden_values <- function(x) {
  if (is.list(x)) {
    return(vapply(x, golden_json, character(1), USE.NAMES = FALSE))
  }
  if (inherits(x, "POSIXt")) {
    return(golden_time(x))
  }
  if (is.double(x) && !is.object(x)) {
    return(golden_num(x))
  }
  as.character(x)
}

# toJSON() writes list("a") and "a", or 12L and 12, the same way, so each
# vector becomes an object naming its storage type. An unnamed list stays
# an array and a named one an object, even when empty.
golden_tree <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  if (is.list(x)) {
    return(lapply(x, golden_tree))
  }
  node <- stats::setNames(list(golden_values(x)), golden_type(x))
  if (!is.null(names(x))) {
    node$names <- names(x)
  }
  node
}

golden_json <- function(x) {
  as.character(jsonlite::toJSON(
    golden_tree(x),
    auto_unbox = TRUE, null = "null", na = "null"
  ))
}

golden_column <- function(name, x) {
  class_line <- paste0("class: ", paste(class(x), collapse = " "))
  if (inherits(x, "POSIXt")) {
    tzone <- paste(attr(x, "tzone") %||% "<none>", collapse = " ")
    class_line <- paste0(class_line, ", tzone: ", tzone)
  }
  c(paste0("column: ", name), class_line, golden_values(x))
}

# A data frame as its class and size, then one entry per column, each
# naming itself so that a diff shows which column moved.
golden_table <- function(x, label) {
  header <- c(
    paste0("table: ", label),
    paste0("class: ", paste(class(x), collapse = " ")),
    paste0("rows: ", nrow(x))
  )
  c(list(header), unname(Map(golden_column, names(x), x)))
}

# Evaluate `expr`, keeping every message and warning it signals, so that a
# new or changed condition shows up in the snapshot as well.
golden_run <- function(expr) {
  seen <- new.env(parent = emptyenv())
  seen$conditions <- character()
  record <- function(cnd) {
    warning <- inherits(cnd, "warning")
    kind <- if (warning) "warning: " else "message: "
    seen$conditions <- c(
      seen$conditions, paste0(kind, trimws(conditionMessage(cnd)))
    )
    invokeRestart(if (warning) "muffleWarning" else "muffleMessage")
  }
  value <- withCallingHandlers(expr, warning = record, message = record)
  list(value = value, conditions = seen$conditions)
}

golden_conditions <- function(run) {
  if (length(run$conditions) == 0L) {
    return("conditions: none")
  }
  c("conditions:", run$conditions)
}

# Run `f` in a time zone either side of UTC and insist on one answer, so
# the snapshot cannot depend on where it was recorded.
golden_any_zone <- function(f) {
  east <- withr::with_timezone("Pacific/Auckland", f())
  west <- withr::with_timezone("America/Los_Angeles", f())
  expect_identical(west, east)
  east
}

# Row ids are generated afresh by every import, so only their shape is
# pinned.
golden_mask_ids <- function(data) {
  if ("_id" %in% names(data)) {
    ids <- data[["_id"]]
    shaped <- !is.na(ids) & grepl("^[A-Za-z0-9_-]{22}$", ids)
    ids[shaped] <- "<new 22-character row id>"
    data[["_id"]] <- ids
  }
  data
}

# A base built by hb_read_csv() or hb_read_xlsx(): its columns, the cells
# it stores and what reading each table gives. Column keys, row ids and
# timestamps are new on every import, so they are left out or masked.
golden_import <- function(base) {
  header <- c(
    paste0("class: ", paste(class(base), collapse = " ")),
    paste0("base_name: ", base$base_name),
    paste0("tables: ", paste(names(base), collapse = ", "))
  )
  per_table <- lapply(seq_along(names(base)), function(i) {
    table <- names(base)[[i]]
    rows <- base$content$tables[[i]]$rows %||% list()
    columns <- hb_list_columns(base, table)
    stored <- Map(
      function(name, key) {
        cells <- vapply(
          rows,
          function(row) {
            if (is.null(row[[key]])) NA_character_ else golden_json(row[[key]])
          },
          character(1)
        )
        c(paste0("stored: ", name), cells)
      },
      columns$name, columns$key
    )
    label <- paste0(table, ": hb_read_table()")
    read <- tryCatch(
      golden_table(golden_mask_ids(hb_read_table(base, table)), label),
      error = function(cnd) {
        list(c(
          paste0("table: ", label),
          paste0("error: ", class(cnd)[[1L]]),
          conditionMessage(cnd)
        ))
      }
    )
    c(
      golden_table(
        columns[setdiff(names(columns), "key")],
        paste0(table, ": hb_list_columns()")
      ),
      unname(stored),
      read
    )
  })
  c(list(header), unlist(per_table, recursive = FALSE))
}

test_that("the example base opens unchanged", {
  skip_if_not_utf8()
  golden <- golden_any_zone(function() {
    run <- golden_run(hb_read_dtable(golden_example()))
    base <- run$value
    # Names and sizes only. The rest of the listing comes from the zip
    # package, and its timestamps are wall-clock times without a zone.
    assets <- base$assets[
      c("filename", "compressed_size", "uncompressed_size")
    ]
    per_table <- lapply(names(base), function(table) {
      c(
        golden_table(
          hb_list_columns(base, table), paste0(table, ": hb_list_columns()")
        ),
        golden_table(
          hb_list_views(base, table), paste0(table, ": hb_list_views()")
        )
      )
    })
    c(
      list(
        golden_conditions(run),
        c(
          paste0("class: ", paste(class(base), collapse = " ")),
          paste0("base_name: ", base$base_name),
          paste0("file: ", basename(base$path)),
          paste0(
            "assets_dir: ",
            if (is.null(base$assets_dir)) "NULL" else "a directory"
          ),
          paste0("tables: ", paste(names(base), collapse = ", ")),
          paste0("length: ", length(base))
        )
      ),
      golden_table(assets, "assets"),
      golden_table(hb_list_tables(base), "hb_list_tables()"),
      golden_table(summary(base), "summary()"),
      unlist(per_table, recursive = FALSE)
    )
  })
  expect_snapshot_value(golden, style = "json2")
})

test_that("every table of the example base reads unchanged", {
  skip_if_not_utf8()
  base <- hb_read_dtable(golden_example())
  golden <- golden_any_zone(function() {
    per_table <- lapply(names(base), function(table) {
      run <- golden_run(hb_read_table(base, table))
      c(golden_table(run$value, table), list(golden_conditions(run)))
    })
    unlist(per_table, recursive = FALSE)
  })
  expect_snapshot_value(golden, style = "json2")
})

test_that("the column-type table is unchanged", {
  types <- hb_column_types()
  expect_s3_class(types, "tbl_df")
  expect_snapshot_value(as.data.frame(types), style = "json2")
})

test_that("the example rows and metadata are unchanged", {
  golden <- golden_any_zone(function() {
    meta <- hb_example_metadata()
    c(
      golden_table(hb_example_rows("Samples"), "hb_example_rows(\"Samples\")"),
      golden_table(
        hb_example_rows("Patients"), "hb_example_rows(\"Patients\")"
      ),
      list(c(
        paste0("class: ", paste(class(meta), collapse = " ")),
        paste0("components: ", paste(names(unclass(meta)), collapse = ", ")),
        paste0("base_name: ", golden_json(meta$base_name)),
        paste0("version: ", golden_json(meta$version)),
        paste0("table: ", vapply(meta$tables, golden_json, character(1)))
      ))
    )
  })
  expect_snapshot_value(golden, style = "json2")
})

test_that("the .dtable written from the example base is unchanged", {
  skip_if_not_utf8()
  golden <- golden_any_zone(function() {
    base <- hb_read_dtable(
      golden_example(),
      assets = "extract", assets_dir = withr::local_tempdir()
    )
    out <- withr::local_tempfile(fileext = ".dtable")
    run <- golden_run(hb_write_dtable(base, out))
    # Names and sizes only: timestamps, permissions and compressed sizes
    # come from the file system and the zlib build, not from harbouR.
    listing <- zip::zip_list(out)
    listing <- data.frame(
      filename = listing$filename,
      uncompressed_size = listing$uncompressed_size
    )
    listing <- listing[order(listing$filename, method = "radix"), ]
    rownames(listing) <- NULL
    json <- rawToChar(.hb_dtable_read_entry(out, "content.json"))
    Encoding(json) <- "UTF-8"
    # One entry per object, so that a diff points at the row, column or
    # view that changed; joined up again, the entries are the file.
    lines <- strsplit(
      gsub("},", "},\n", json, fixed = TRUE), "\n",
      fixed = TRUE
    )[[1L]]
    expect_identical(paste(lines, collapse = ""), json)
    c(
      list(golden_conditions(run)),
      golden_table(listing, "archive entries"),
      as.list(c("content.json:", lines))
    )
  })
  expect_snapshot_value(golden, style = "json2")
})

test_that("the CSV export of the example base is unchanged", {
  skip_if_not_utf8()
  # Before R 4.3, as.character() - which write.csv() applies to date-time
  # columns - formatted a column as a whole rather than cell by cell, so
  # the text of those cells can differ there.
  skip_if(getRversion() < "4.3.0", "R formats date-times differently")
  base <- hb_read_dtable(golden_example())
  golden <- golden_any_zone(function() {
    dir <- withr::local_tempdir()
    run <- golden_run(hb_write_csv(base, dir))
    # Lines rather than bytes: R ends the lines of a text file the way the
    # platform does. One entry per line, so a diff points at the row.
    files <- lapply(run$value, function(file) {
      as.list(c(
        paste0("file: ", basename(file)),
        readLines(file, encoding = "UTF-8", warn = FALSE)
      ))
    })
    c(list(golden_conditions(run)), unlist(files, recursive = FALSE))
  })
  expect_snapshot_value(golden, style = "json2")
})

test_that("re-importing the CSV export gives an unchanged base", {
  skip_if_not_utf8()
  skip_if(getRversion() < "4.3.0", "R formats date-times differently")
  base <- hb_read_dtable(golden_example())
  golden <- golden_any_zone(function() {
    dir <- withr::local_tempdir()
    files <- suppressMessages(hb_write_csv(base, dir))
    run <- golden_run(hb_read_csv(files))
    c(list(golden_conditions(run)), golden_import(run$value))
  })
  expect_snapshot_value(golden, style = "json2")
})

test_that("the Excel export and its re-import are unchanged", {
  skip_if_not_installed("writexl")
  skip_if_not_installed("readxl")
  skip_if_not_utf8()
  base <- hb_read_dtable(golden_example())
  golden <- golden_any_zone(function() {
    path <- withr::local_tempfile(fileext = ".xlsx")
    written <- golden_run(hb_write_xlsx(base, path))
    run <- golden_run(hb_read_xlsx(path))
    c(
      list(
        golden_conditions(written),
        c("sheets:", readxl::excel_sheets(path)),
        golden_conditions(run)
      ),
      golden_import(run$value)
    )
  })
  expect_snapshot_value(golden, style = "json2")
})
