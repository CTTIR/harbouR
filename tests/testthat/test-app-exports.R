# The explorer's downloads. Most tests drive the handler a click reaches:
# shiny::testServer() returns a download output as the path of the file
# its content function wrote, so they read what the user would get.

skip_if_no_ui <- function() {
  needed <- c("shiny", "bslib", "reactable")
  present <- vapply(needed, requireNamespace, logical(1), quietly = TRUE)
  testthat::skip_if_not(all(present), "UI packages not installed")
  testthat::skip_if_not_installed("bslib", "0.6.0")
}

# testServer()'s mock session drops notifications, so without a record of
# them a test cannot tell a failure the app reported from a silent one.
# Whitespace is collapsed the way the browser shows it.
local_notifications <- function(.env = rlang::caller_env()) {
  seen <- new.env(parent = emptyenv())
  seen$text <- character()
  testthat::local_mocked_bindings(
    showNotification = function(ui, ...) {
      html <- paste(as.character(ui), collapse = " ")
      seen$text <- c(seen$text, gsub("\\s+", " ", html))
      invisible("notification")
    },
    .package = "shiny",
    .env = .env
  )
  seen
}

example_path <- function() {
  system.file("extdata", "example.dtable", package = "harbouR")
}

# What the Export panel says for a source, as the browser shows it.
export_note <- function(source) {
  seen <- new.env(parent = emptyenv())
  shiny::testServer(harbouR:::.hb_app_server(preset = source), {
    html <- as.character(htmltools::renderTags(output$export_panel$html)$html)
    seen$note <- gsub("\\s+", " ", html)
  })
  seen$note
}

# A live table of `n` rows, served a page at a time the way SeaTable does.
paged_rows <- function(n) {
  pool <- lapply(seq_len(n), function(i) {
    list(`_id` = sprintf("row%05d", i), Name = sprintf("S-%05d", i))
  })
  function(path, method, query, body) {
    if (!grepl("rows", path, fixed = TRUE)) {
      return(list())
    }
    from <- query$start + 1L
    to <- min(query$start + query$limit, length(pool))
    list(rows = if (from > to) list() else pool[from:to])
  }
}

test_that("This table as CSV holds every row, whatever the Rows setting", {
  skip_if_no_ui()
  big <- data.frame(id = seq_len(1001), label = paste0("row ", seq_len(1001)))
  base <- hb_dtable(Big = big, Small = data.frame(x = 1:3), base_name = "b")
  shiny::testServer(harbouR:::.hb_app_server(preset = base), {
    # The Data panel previews the first 1000 rows ...
    expect_identical(nrow(session$env$table_data()), 1000L)
    # ... but a file named after the table is the whole table.
    back <- utils::read.csv(output$dl_table_csv)
    expect_identical(nrow(back), 1001L)
    expect_identical(back$id, seq_len(1001))
    session$setInputs(n_max = 10)
    expect_identical(nrow(utils::read.csv(output$dl_table_csv)), 1001L)
  })
})

test_that("a live table's CSV is read in full, page by page", {
  skip_if_no_ui()
  with_mocked_request(
    shiny::testServer(harbouR:::.hb_app_server(preset = mock_client()), {
      session$setInputs(n_max = 10)
      expect_identical(nrow(session$env$table_data()), 10L)
      back <- utils::read.csv(output$dl_table_csv, check.names = FALSE)
      expect_identical(nrow(back), 1500L)
      expect_identical(back$Name[[1500L]], "S-01500")
    }),
    response = paged_rows(1500)
  )
})

test_that("the zipped CSVs include a table whose name starts with a dot", {
  base <- hb_dtable(
    Samples = data.frame(x = 1:3),
    .notes = data.frame(y = 4:6),
    base_name = "dots"
  )
  out <- withr::local_tempfile(fileext = ".zip")
  harbouR:::.hb_export(base, "csv-zip", out)
  expect_setequal(zip::zip_list(out)$filename, c("Samples.csv", ".notes.csv"))
  back <- withr::local_tempdir()
  zip::unzip(out, exdir = back)
  expect_identical(utils::read.csv(file.path(back, ".notes.csv"))$y, 4:6)
})

test_that("the zipped CSV download still reports what it flattened", {
  skip_if_no_ui()
  seen <- local_notifications()
  base <- hb_read_dtable(example_path())
  shiny::testServer(harbouR:::.hb_app_server(preset = base), {
    expect_setequal(zip::zip_list(output$dl_csv)$filename,
                    c("Samples.csv", "Reference.csv"))
  })
  expect_length(seen$text, 1L)
  expect_match(seen$text, "Some columns were flattened", fixed = TRUE)
})

test_that("only the flattening report is shown as one", {
  skip_if_no_ui()
  seen <- local_notifications()
  expect_message(
    harbouR:::.hb_notify_flattening(NULL, message("Waiting to retry")),
    "Waiting to retry"
  )
  expect_length(seen$text, 0L)
})

test_that("the Export panel promises a lossless .dtable only for a file", {
  skip_if_no_ui()
  whole <- export_note(hb_read_dtable(example_path(), assets = "extract"))
  expect_match(whole, "A .dtable keeps everything", fixed = TRUE)

  # Read without its assets, a file's .dtable cannot carry them.
  bare <- export_note(hb_read_dtable(example_path()))
  expect_false(grepl("keeps everything", bare, fixed = TRUE))
  expect_match(bare, "opened without its attachments", fixed = TRUE)
  # A listing of folders alone holds no attachment to lose.
  folders <- hb_read_dtable(example_path())
  folders$assets <- folders$assets[endsWith(folders$assets$filename, "/"), ]
  expect_match(export_note(folders), "keeps everything", fixed = TRUE)

  live <- NULL
  with_mocked_request(
    live <- export_note(mock_client()),
    response = list(rows = list())
  )
  expect_false(grepl("keeps everything", live, fixed = TRUE))
  expect_match(live, "rebuilt from its rows", fixed = TRUE)
  expect_match(live, "attachments or views", fixed = TRUE)
})

test_that("a .dtable of a live base says what it does not keep", {
  skip_if_no_ui()
  seen <- local_notifications()
  with_mocked_request(
    shiny::testServer(harbouR:::.hb_app_server(preset = mock_client()), {
      out <- output$dl_dtable
      expect_setequal(names(hb_read_dtable(out)), c("Samples", "Patients"))
    }),
    response = list(rows = list())
  )
  expect_length(seen$text, 1L)
  expect_match(seen$text, "rebuilt from the rows", fixed = TRUE)
  expect_match(seen$text, "Select options, attachments and views are not",
               fixed = TRUE)
})

test_that("a live table keeps its name in a .dtable, whatever it is called", {
  # hb_dtable() has arguments called collaborators and base_name, and a
  # table passed under either name was taken for that argument: the first
  # vanished from the download, the second stopped it.
  cl <- mock_client()
  cl$.metadata$tables[[1L]]$name <- "collaborators"
  cl$.metadata$tables[[2L]]$name <- "base_name"
  base <- NULL
  tables <- cl$.metadata$tables
  # Both tables are sent a Name cell, which the second has no column for;
  # the read then asks for the metadata again, and gets the same tables.
  server <- function(path, method, query, body) {
    if (grepl("metadata", path, fixed = TRUE)) {
      return(list(metadata = list(tables = tables)))
    }
    list(rows = list(list(`_id` = "row1", Name = "S-1")))
  }
  with_mocked_request(
    base <- harbouR:::.hb_as_dtable(cl),
    response = server
  )
  expect_identical(names(base), c("collaborators", "base_name"))
  expect_length(base$content$collaborators, 0L)
  expect_identical(hb_read_table(base, "collaborators")$Name, "S-1")
  expect_identical(base$base_name, "harbouR demo base")
})

test_that("a .dtable of an opened file comes back unchanged, with no notice", {
  skip_if_no_ui()
  seen <- local_notifications()
  base <- hb_read_dtable(example_path(), assets = "extract")
  shiny::testServer(harbouR:::.hb_app_server(preset = base), {
    out <- output$dl_dtable
    expect_identical(hb_read_dtable(out)$content, base$content)
  })
  expect_length(seen$text, 0L)
})

test_that("what opening a file warns about is shown in the app", {
  # Of two attachments whose names differ only in case only one is
  # extracted, so a .dtable download lacks the other. hb_read_dtable()
  # warns, but at the console, where the explorer's user is not looking.
  skip_if_no_ui()
  skip_if_not("keys" %in% names(formals(zip::zip)), "zip is older than 3.0.0")
  src <- withr::local_tempdir()
  zip::unzip(example_path(), "content.json", exdir = src)
  writeLines("lower", file.path(src, "1"))
  writeLines("upper", file.path(src, "2"))
  archive <- withr::local_tempfile(fileext = ".dtable")
  zip::zip(
    archive, files = c("content.json", "1", "2"),
    keys = c("content.json", "asset/files/report.txt",
             "asset/files/Report.txt"),
    root = src, mode = "mirror"
  )
  upload <- function(path, name) {
    data.frame(name = name, datapath = path, size = file.size(path),
               type = "", stringsAsFactors = FALSE)
  }
  seen <- local_notifications()
  shiny::testServer(harbouR:::.hb_app_server(), {
    session$setInputs(dtable_file = upload(example_path(), "example.dtable"))
    expect_length(seen$text, 0L)
    expect_no_warning(
      session$setInputs(dtable_file = upload(archive, "clash.dtable"))
    )
    expect_true(is_harbour_dtable(session$env$state$source))
    expect_identical(session$env$state$source$base_name, "clash")
  })
  expect_length(seen$text, 1L)
  expect_match(seen$text, "While opening clash.dtable", fixed = TRUE)
  expect_match(seen$text, "differ only in case", fixed = TRUE)
  expect_match(seen$text, "asset/files/Report.txt", fixed = TRUE)
})

test_that("a failed download is reported in the app and serves no file", {
  skip_if_no_ui()
  seen <- local_notifications()
  written <- NULL
  testthat::local_mocked_bindings(
    hb_write_dtable = function(x, path, ...) {
      written <<- path
      writeLines("half an archive", path)
      hb_abort("The disk is full.", class = "harbour_error_bad_argument")
    }
  )
  base <- hb_read_dtable(example_path())
  shiny::testServer(harbouR:::.hb_app_server(preset = base), {
    # The mock session errors when a download leaves no file, where a
    # real one answers 404 rather than serve a truncated archive.
    expect_error(output$dl_dtable)
    # Checked before the session ends, which deletes its download folder.
    expect_false(file.exists(written))
  })
  # The reason reaches the browser instead of the console.
  expect_length(seen$text, 1L)
  expect_match(seen$text, "Could not write the .dtable", fixed = TRUE)
  expect_match(seen$text, "The disk is full.", fixed = TRUE)
})

test_that("an Excel export without writexl is refused with a reason", {
  # hb_write_xlsx() would offer to install writexl at the console, where
  # the explorer's user is not looking, and hold the app until answered.
  base <- hb_read_dtable(example_path())
  out <- withr::local_tempfile(fileext = ".xlsx")
  testthat::local_mocked_bindings(
    requireNamespace = function(package, ...) !identical(package, "writexl"),
    .package = "base"
  )
  cnd <- expect_error(
    harbouR:::.hb_export(base, "xlsx", out),
    class = "harbour_error_unsupported"
  )
  expect_match(harbouR:::.hb_plain_message(cnd), "writexl", fixed = TRUE)
  expect_false(file.exists(out))
})

test_that("the explorer accepts uploads past Shiny's 5 MB default", {
  skip_if_no_ui()
  withr::local_options(shiny.maxRequestSize = NULL)
  seen <- "runApp() was not called"
  testthat::local_mocked_bindings(
    runApp = function(...) seen <<- getOption("shiny.maxRequestSize"),
    .package = "shiny"
  )
  hb_run_explorer()
  expect_identical(seen, 1024^3)
  # only while it runs
  expect_null(getOption("shiny.maxRequestSize"))
})

test_that("an upload limit the user set is left alone", {
  skip_if_no_ui()
  withr::local_options(shiny.maxRequestSize = 30 * 1024^2)
  seen <- "runApp() was not called"
  testthat::local_mocked_bindings(
    runApp = function(...) seen <<- getOption("shiny.maxRequestSize"),
    .package = "shiny"
  )
  hb_run_explorer()
  expect_identical(seen, 30 * 1024^2)
  expect_identical(getOption("shiny.maxRequestSize"), 30 * 1024^2)
})

test_that("a failure opening the example base is reported, not thrown", {
  # It was the one action without error handling, so a full disk ended
  # the session with a grey screen.
  skip_if_no_ui()
  seen <- local_notifications()
  testthat::local_mocked_bindings(
    hb_read_dtable = function(...) stop("No space left on device"),
    .package = "harbouR"
  )
  shiny::testServer(harbouR:::.hb_app_server(), {
    session$setInputs(use_demo = 1)
    expect_null(session$env$state$source)
  })
  expect_match(seen$text, "example base", all = FALSE)
})

test_that("the attachments the app unpacked go when they are done with", {
  # Every opened base left its extracted attachments in the temporary
  # folder until R quit, and uploads may be 1 GB.
  skip_if_no_ui()
  last <- NULL
  shiny::testServer(harbouR:::.hb_app_server(), {
    session$setInputs(use_demo = 1)
    first <- session$env$state$source$assets_dir
    expect_true(dir.exists(first))
    session$setInputs(use_demo = 2)
    expect_false(dir.exists(first))
    last <<- session$env$state$source$assets_dir
    expect_true(dir.exists(last))
  })
  expect_false(dir.exists(last))
})

test_that("a preset's attachments are left where they were", {
  skip_if_no_ui()
  base <- hb_read_dtable(example_path(), assets = "extract")
  shiny::testServer(harbouR:::.hb_app_server(preset = base), {
    session$setInputs(use_demo = 1)
  })
  expect_true(dir.exists(base$assets_dir))
})
