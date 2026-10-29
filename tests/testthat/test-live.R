# The only tests that talk to a real SeaTable server.
#
# Everything else in this suite replaces harbouR's request seam, which
# means it can prove that a wrapper builds the URL harbouR intends - but
# not that SeaTable agrees. These close that gap. The read checks compare
# harbouR with something it did not produce itself - the server's raw
# reply, or a second endpoint - because a read compared with the metadata
# it was built from passes whatever the server returned.
#
# They are skipped unless HARBOUR_TEST_SERVER and HARBOUR_TEST_TOKEN name
# a base you are willing to have written to and cleaned up:
#
#   Sys.setenv(HARBOUR_TEST_SERVER = "https://seatable.example.org")
#   Sys.setenv(HARBOUR_TEST_TOKEN  = "<an API token for a throwaway base>")
#
# They never run on CRAN.

live_client <- function() {
  testthat::skip_on_cran()
  server <- Sys.getenv("HARBOUR_TEST_SERVER")
  token <- Sys.getenv("HARBOUR_TEST_TOKEN")
  testthat::skip_if(
    !nzchar(server) || !nzchar(token),
    "HARBOUR_TEST_SERVER / HARBOUR_TEST_TOKEN not set"
  )
  hb_client(server = server, api_token = token)
}

# The first rows of a table exactly as the server sends them, before the
# coercion layer sees them.
live_raw_rows <- function(client, table, n = 5L) {
  body <- .hb_request(
    client, .hb_base_path(client, "rows", ""),
    service = "gateway", auth = "base", method = "GET",
    query = list(table_name = table, limit = n, convert_keys = "true")
  )
  body$rows %||% list()
}

test_that("the server is reachable and the credentials work", {
  client <- live_client()
  expect_identical(hb_ping(client), client)
  expect_identical(hb_check_credentials(client), client)
  info <- hb_server_info(client)
  expect_identical(nrow(info), 1L)
  expect_true(nzchar(info$version))
})

test_that("metadata comes back and names a base", {
  client <- live_client()
  meta <- hb_metadata(client)
  expect_s3_class(meta, "harbour_metadata")
  expect_true(nzchar(client$base_uuid))
  tables <- hb_list_tables(client)
  expect_named(tables, c("name", "n_columns", "n_views"))
  expect_gt(nrow(tables), 0L)
})

test_that("a table reads what the server sends", {
  client <- live_client()
  table <- hb_list_tables(client)$name[[1L]]
  # From the columns endpoint rather than the cached metadata that
  # hb_read_table() builds its tibble from.
  columns <- hb_list_columns(client, table, refresh = TRUE)
  data <- hb_read_table(client, table, n_max = 5L)
  expect_true("_id" %in% names(data))
  expect_true(all(columns$name %in% names(data)))

  raw <- live_raw_rows(client, table)
  skip_if(length(raw) == 0L, "the first table has no rows")
  # Every cell the server sends belongs to a declared column; the
  # underscore fields are SeaTable's own.
  sent <- unique(unlist(lapply(raw, names), use.names = FALSE))
  sent <- sent[!startsWith(sent, "_")]
  expect_identical(setdiff(sent, columns$name), character())

  ids <- vapply(
    raw,
    function(row) as.character(row[["_id"]] %||% NA_character_),
    character(1)
  )
  at <- match(ids, data[["_id"]])
  expect_false(anyNA(at))
  skip_if(anyNA(at), "the rows read are not the rows the server sent")

  # A cell the server filled in must not read as missing.
  lost <- character()
  for (r in seq_along(raw)) {
    for (name in intersect(names(raw[[r]]), columns$name)) {
      value <- raw[[r]][[name]]
      if (length(value) == 0L || identical(value, "")) next
      cell <- data[[name]][[at[[r]]]]
      if (length(cell) == 0L || all(is.na(cell))) {
        lost <- c(lost, paste(name, "in row", ids[[r]]))
      }
    }
  }
  expect_identical(lost, character())

  # A date-only cell arrives as the server's local midnight with its UTC
  # offset, so the calendar date it carries is the leading YYYY-MM-DD. It
  # must read as that date with a zero time component, as documented.
  # The formats are moment.js patterns, so a date-only one is one with no
  # time token: H, h, k, m or s.
  formats <- vapply(
    columns$data,
    function(info) as.character(info$format %||% NA_character_),
    character(1)
  )
  date_only <- columns$name[
    columns$type == "date" & !is.na(formats) & nzchar(formats) &
      !grepl("[Hhkms]", formats)
  ]
  shifted <- character()
  for (r in seq_along(raw)) {
    for (name in intersect(names(raw[[r]]), date_only)) {
      value <- raw[[r]][[name]]
      dated <- is.character(value) && length(value) == 1L &&
        grepl("^\\d{4}-\\d{2}-\\d{2}", value)
      if (!dated) next
      read <- format(data[[name]][[at[[r]]]], "%Y-%m-%d %H:%M:%S", tz = "UTC")
      if (!identical(read, paste(substr(value, 1L, 10L), "00:00:00"))) {
        shifted <- c(shifted, paste(name, value, "read as", read))
      }
    }
  }
  expect_identical(shifted, character())
})

test_that("SQL and the read path agree on column classes", {
  client <- live_client()
  table <- hb_list_tables(client)$name[[1L]]
  read <- hb_read_table(client, table, n_max = 5L)
  skip_if(nrow(read) == 0L, "the first table has no rows")
  queried <- hb_query(client, sprintf("select * from `%s` limit 5", table))
  # More than `_id` alone, or the comparison below says nothing.
  shared <- intersect(names(read), names(queried))
  expect_gt(length(shared), 1L)
  class_of <- function(data) {
    vapply(data[shared], function(column) class(column)[[1L]], character(1))
  }
  expect_identical(class_of(queried), class_of(read))
})

test_that("a row round-trips: append, read, update, delete", {
  client <- live_client()
  table <- hb_list_tables(client)$name[[1L]]
  columns <- hb_list_columns(client, table)
  text_cols <- columns$name[columns$type == "text" & columns$editable]
  skip_if(length(text_cols) == 0L, "no writable text column in the base")
  text_col <- text_cols[[1L]]

  # Unique to this run, so no row the base already holds can match.
  marker <- paste0("harbouR-test-", Sys.getpid(), "-", as.integer(Sys.time()))
  updated <- paste0(marker, "-updated")
  payload <- tibble::tibble(x = marker)
  names(payload) <- text_col

  written <- hb_append_rows(client, table, payload)
  expect_identical(written$n_rows, 1L)
  # SeaTable does not return the new row, so it is found by its marker.
  # Cleanup deletes that row by its id and touches nothing else; if the
  # read below failed, it looks for the marker once more.
  created <- character()
  withr::defer({
    if (length(created) == 0L) {
      found <- hb_read_table(client, table)
      created <- found[["_id"]][found[[text_col]] %in% marker]
    }
    if (length(created) > 0L) hb_delete_rows(client, table, created)
  })
  found <- hb_read_table(client, table)
  created <- found[["_id"]][found[[text_col]] %in% marker]
  expect_length(created, 1L)
  skip_if(length(created) != 1L, "the appended row could not be found")

  update <- tibble::tibble(`_id` = created, x = updated)
  names(update)[2L] <- text_col
  expect_identical(hb_update_rows(client, table, update)$n_rows, 1L)
  expect_identical(hb_get_row(client, table, created)[[text_col]], updated)
})

test_that("a live base exports to a .dtable that reads back", {
  client <- live_client()
  base <- .hb_as_dtable(client)
  expect_true(is_harbour_dtable(base))
  out <- withr::local_tempfile(fileext = ".dtable")
  hb_write_dtable(base, out)
  again <- hb_read_dtable(out)
  # A whole number held as a double in R comes back from the JSON as an
  # integer, so the file's content is compared by value rather than by
  # storage type. Each table must then read back exactly as written.
  expect_equal(again$content, base$content)
  expect_identical(names(again), names(base))
  for (table in names(base)) {
    expect_identical(hb_read_table(again, table), hb_read_table(base, table))
  }
})

# ---- Server contracts a mocked test cannot see ----------------------------
#
# Each of these failed against a SeaTable 6.2.1 server while every mocked
# test passed: the mocks encoded what harbouR assumed the server does.

# A table of this run's own, deleted when the calling test ends. Letters,
# digits and underscores only, so SQL can name it without quoting.
live_table <- function(client, columns, env = parent.frame()) {
  name <- paste0(
    "harbouR_test_", Sys.getpid(), "_",
    gsub("[^0-9]", "", format(Sys.time(), "%H%M%OS3"))
  )
  hb_create_table(client, name, columns = columns)
  withr::defer(try(hb_delete_table(client, name), silent = TRUE), envir = env)
  name
}

# SQL reads a copy of the base that can trail a write by a moment.
live_query <- function(client, sql, ok) {
  for (i in seq_len(20L)) {
    out <- hb_query(client, sql)
    if (isTRUE(ok(out))) break
    Sys.sleep(0.5)
  }
  out
}

test_that("a join's values come back, not NA", {
  client <- live_client()
  a <- live_table(client, list(list(name = "k", type = "text"),
                               list(name = "v", type = "number")))
  b <- live_table(client, list(list(name = "k", type = "text"),
                               list(name = "w", type = "text")))
  hb_append_rows(client, a, tibble::tibble(k = c("x", "y"), v = c(1, 2)))
  hb_append_rows(client, b, tibble::tibble(k = c("x", "y"), w = c("p", "q")))
  sql <- sprintf(
    "select %s.v, %s.w from %s, %s where %s.k = %s.k limit 10",
    a, b, a, b, a, b
  )
  out <- live_query(client, sql, function(x) nrow(x) == 2L)
  expect_setequal(out$v, c(1, 2))
  expect_setequal(out$w, c("p", "q"))
})

test_that("select options are added, renamed and deleted", {
  client <- live_client()
  table <- live_table(client, list(list(name = "Status", type = "single-select")))
  hb_add_select_option(client, table, "Status", "open")
  hb_append_rows(client, table, tibble::tibble(Status = "open"))
  hb_update_select_option(client, table, "Status", "open", "done")
  expect_identical(hb_read_table(client, table)$Status, "done")
  hb_delete_select_option(client, table, "Status", "done")
  options <- hb_list_columns(client, table, refresh = TRUE)$data[[1L]]$options
  expect_length(options, 0L)
})

test_that("writing back a view read keeps the columns it hides", {
  client <- live_client()
  table <- live_table(client, list(list(name = "T", type = "text"),
                                   list(name = "Keep", type = "text")))
  hb_append_rows(client, table, tibble::tibble(T = "a", Keep = "kept"))
  hb_create_view(client, table, "lean")
  keys <- hb_list_columns(client, table, refresh = TRUE)
  hb_update_view(client, table, "lean",
                 list(hidden_columns = keys$key[keys$name == "Keep"]))
  read <- suppressWarnings(hb_read_table(client, table, view = "lean"))
  read$T <- "changed"
  hb_update_rows(client, table, read)
  after <- hb_read_table(client, table)
  expect_identical(after$T, "changed")
  expect_identical(after$Keep, "kept")
})

test_that("NA in list columns is stored empty, and the base still exports", {
  client <- live_client()
  table <- live_table(client, list(
    list(name = "T", type = "text"), list(name = "G", type = "geolocation"),
    list(name = "C", type = "collaborator"), list(name = "I", type = "image")
  ))
  hb_append_rows(client, table, tibble::tibble(
    T = "x", G = NA, C = NA_character_, I = NA_character_
  ))
  raw <- live_raw_rows(client, table)[[1L]]
  expect_true(length(raw$G) == 0L)
  expect_true(length(raw$C) == 0L)
  read <- hb_read_table(client, table)
  expect_identical(read$G, list(list()))
  expect_s3_class(hb_dtable(T = read), "harbour_dtable")
})

test_that("a formula column added in a batch is created", {
  client <- live_client()
  table <- live_table(client, list(list(name = "N", type = "number")))
  hb_add_columns(client, table, list(
    list(name = "F", type = "formula", data = list(formula = "{N} * 2")),
    list(name = "T", type = "text")
  ))
  expect_true(all(c("F", "T") %in% hb_list_columns(client, table, refresh = TRUE)$name))
})

test_that("a date-time keeps its instant and a date its day", {
  client <- live_client()
  table <- live_table(client, list(
    list(name = "When", type = "date", data = list(format = "YYYY-MM-DD HH:mm")),
    list(name = "Day", type = "date", data = list(format = "YYYY-MM-DD"))
  ))
  instant <- as.POSIXct("2030-07-04 23:45:00", tz = "UTC")
  withr::with_timezone("Pacific/Auckland", {
    hb_append_rows(client, table, tibble::tibble(
      When = instant, Day = as.Date("2030-07-04")
    ))
  })
  read <- hb_read_table(client, table)
  expect_identical(as.numeric(read$When), as.numeric(instant))
  expect_identical(as.Date(read$Day), as.Date("2030-07-04"))
})
