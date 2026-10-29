# Single cells on their way in from SeaTable and out to it: the shapes a
# live server sends, and the R values scripts hand to the write verbs.

# The JSON httr2's req_body_json() makes of a request body, with the
# `na = "null"` that .hb_request() adds.
wire_json <- function(x) {
  as.character(jsonlite::toJSON(
    x,
    auto_unbox = TRUE, digits = 22, null = "null", na = "null"
  ))
}

# Parsed one string at a time: as.POSIXct() picks a single format for a
# whole vector, which would drop the time from "2026-04-01 09:00:00"
# beside "2026-04-01".
utc <- function(x) {
  seconds <- vapply(
    x,
    function(s) if (is.na(s)) NA_real_ else unclass(as.POSIXct(s, tz = "UTC")),
    double(1),
    USE.NAMES = FALSE
  )
  .POSIXct(seconds, tz = "UTC")
}

date_column <- function(format = NULL, type = "date") {
  column <- list(name = "Due", type = type, key = "d001")
  if (!is.null(format)) {
    column$data <- list(format = format)
  }
  column
}

# Read one column from API-shaped rows, one value per row; a NULL value
# leaves the cell out, as the server does for an empty cell.
read_column <- function(values, column) {
  rows <- lapply(seq_along(values), function(i) {
    row <- list(`_id` = paste0("r", i))
    row[[column$name]] <- values[[i]]
    row
  })
  harbouR:::.hb_rows_to_tibble(rows, list(column))[[column$name]]
}

# A client whose Samples table also has the given columns.
client_with_columns <- function(...) {
  meta <- hb_example_metadata()
  meta$tables[[1L]]$columns <- c(meta$tables[[1L]]$columns, list(...))
  cl <- mock_client()
  cl$.metadata <- meta
  cl
}

file_object <- function(name = "report.pdf") {
  list(
    name = name, size = 12345, type = "file",
    url = paste0("https://x.org/files/", name)
  )
}

test_that("the type notes say what harbouR does with these cells", {
  types <- hb_column_types()
  notes <- stats::setNames(types$notes, types$seatable)
  # Nothing checks a select value against the options: the server adds an
  # unknown name as a new one.
  expect_match(notes[["single-select"]], "not validated")
  expect_match(notes[["checkbox"]], "unset box reads as FALSE")
  expect_match(notes[["digital-sign"]], "not written")
})

# Dates ----------------------------------------------------------------

test_that("a date-only cell from the API reads as the date SeaTable shows", {
  # A server east of UTC sends local midnight with its offset. Converting
  # that instant to UTC put every date on the previous day.
  got <- read_column(
    c(
      "2030-06-20T00:00:00+02:00", "2030-06-20T00:00:00-05:00",
      "2030-06-20T00:00:00Z", "2030-06-20T00:00:00.000+02:00"
    ),
    date_column("YYYY-MM-DD")
  )
  expect_identical(as.Date(got), rep(as.Date("2030-06-20"), 4L))
  expect_identical(got, utc(rep("2030-06-20", 4L)))
})

test_that("every date-only format reads the same way", {
  # The API sends the same ISO string whatever the display format is.
  for (format in c("YYYY-MM-DD", "M/D/YYYY", "DD/MM/YYYY", "DD.MM.YYYY")) {
    got <- read_column("2024-06-05T00:00:00+02:00", date_column(format))
    expect_identical(got, utc("2024-06-05"), info = format)
  }
})

test_that("the live read verbs return the calendar date of a date-only cell", {
  meta <- hb_example_metadata()
  columns <- meta$tables[[1L]]$columns
  at <- match("Collected", vapply(columns, function(col) col$name, ""))
  # The shape a real server reports: a date column carries its format.
  meta$tables[[1L]]$columns[[at]]$data <- list(format = "YYYY-MM-DD")
  cl <- mock_client()
  cl$.metadata <- meta
  row <- list(`_id` = "r1", Name = "a", Collected = "2030-06-20T00:00:00+02:00")

  with_mocked_request(
    read <- hb_read_table(cl, "Samples"),
    response = list(rows = list(row))
  )
  expect_identical(as.Date(read$Collected), as.Date("2030-06-20"))

  with_mocked_request(
    one <- hb_get_row(cl, "Samples", "r1"),
    response = row
  )
  expect_identical(as.Date(one$Collected), as.Date("2030-06-20"))

  with_mocked_request(
    queried <- hb_query(cl, "select Collected from Samples limit 1"),
    response = list(
      metadata = list(list(
        name = "Collected", type = "date", key = "k5",
        data = list(format = "YYYY-MM-DD")
      )),
      results = list(row[c("_id", "Collected")])
    )
  )
  expect_identical(as.Date(queried$Collected), as.Date("2030-06-20"))
})

test_that("dates without an offset read exactly as before", {
  # This is how a .dtable stores a date.
  got <- read_column(
    list("2026-04-01", "2026-04-01 09:00:00", "2026/04/03", NULL),
    date_column("YYYY-MM-DD")
  )
  expect_identical(
    got,
    utc(c("2026-04-01", "2026-04-01 09:00:00", "2026-04-03", NA))
  )
})

test_that("date-time, creation and modification times keep their offset", {
  # These hold an instant, so the offset is part of the value.
  expect_identical(
    read_column("2030-06-20T23:55:00+02:00", date_column("YYYY-MM-DD HH:mm")),
    utc("2030-06-20 21:55:00")
  )
  for (type in c("ctime", "mtime")) {
    expect_identical(
      read_column(
        "2025-11-28T14:00:24+01:00",
        date_column("YYYY-MM-DD", type = type)
      ),
      utc("2025-11-28 13:00:24"),
      info = type
    )
  }
})

test_that("a date column without a format keeps the offset-aware parse", {
  # Nothing says such a column is date-only.
  for (column in list(date_column(), date_column(""))) {
    expect_identical(
      read_column("2030-06-20T00:00:00+02:00", column),
      utc("2030-06-19 22:00:00")
    )
  }
})

test_that("the bundled .dtable reads its dates and checkboxes as before", {
  base <- hb_read_dtable(
    system.file("extdata", "example.dtable", package = "harbouR")
  )
  samples <- hb_read_table(base, "Samples")
  expect_identical(samples$Collected, utc(c("2026-04-01", "2026-04-03")))
  expect_identical(samples$Created, utc(c("2026-07-27 12:00:00", NA)))
  expect_identical(samples$Changed, utc(c("2026-07-27 12:00:00", NA)))
  expect_identical(samples$Consented, c(TRUE, FALSE))
})

test_that("parsing each distinct date once gives the cell-by-cell result", {
  values <- list(
    "2030-06-20T00:00:00+02:00", NULL, "2026-04-01", 1.7e9,
    "2030-06-20T00:00:00+02:00", "", NA, "nonsense", "2026-04-01",
    "2025-11-28T14:00:24.395+00:00", "2026-04-01 09:00"
  )
  columns <- list(
    date_column("YYYY-MM-DD"), date_column("YYYY-MM-DD HH:mm"),
    date_column(), date_column(type = "ctime")
  )
  for (column in columns) {
    date_only <- identical(column$data$format, "YYYY-MM-DD")
    one_by_one <- vapply(
      values,
      function(value) {
        as.double(harbouR:::.hb_coerce_cell(
          value, column$type, date_only = date_only
        ))
      },
      double(1)
    )
    expect_identical(
      read_column(values, column), .POSIXct(one_by_one, tz = "UTC")
    )
  }
})

# Checkboxes -----------------------------------------------------------

test_that("an unset checkbox reads as FALSE, cell by cell and as a column", {
  expect_identical(harbouR:::.hb_coerce_cell(NULL, "checkbox"), FALSE)
  got <- read_column(
    list(TRUE, NULL, FALSE),
    list(name = "Done", type = "checkbox", key = "c001")
  )
  expect_identical(got, c(TRUE, FALSE, FALSE))
})

test_that("an NA checkbox written by hb_dtable() reads back as FALSE", {
  base <- hb_dtable(T1 = data.frame(Done = c(TRUE, NA, FALSE)))
  expect_identical(hb_read_table(base, "T1")$Done, c(TRUE, FALSE, FALSE))
})

test_that("checkbox values are sent as JSON booleans", {
  # SeaTable stores the number 1 in a checkbox as unticked; only a JSON
  # boolean is honoured.
  checkbox <- function(value) harbouR:::.hb_serialise_cell(value, "checkbox")
  expect_identical(checkbox(1), TRUE)
  expect_identical(checkbox(0), FALSE)
  expect_identical(checkbox(1L), TRUE)
  expect_identical(checkbox(0L), FALSE)
  expect_identical(checkbox(-2.5), TRUE)
  expect_identical(checkbox(TRUE), TRUE)
  expect_identical(checkbox(FALSE), FALSE)
  expect_identical(checkbox("TRUE"), TRUE)
  expect_identical(checkbox("false"), FALSE)
  expect_identical(checkbox("T"), TRUE)
  expect_identical(checkbox(factor("TRUE")), TRUE)
  expect_identical(checkbox(list(1)), TRUE)
  expect_identical(checkbox(NA), NA)
  expect_identical(checkbox(NA_real_), NA)
  # A blank or missing string is an empty cell, not a value to warn about.
  expect_no_warning(expect_identical(checkbox(NA_character_), NA))
  expect_no_warning(expect_identical(checkbox(""), NA))
  # An empty cell is left out of the row, as before.
  expect_null(checkbox(NULL))
  expect_null(checkbox(list()))
})

test_that("an unreadable checkbox string warns and is sent as null", {
  expect_warning(
    out <- harbouR:::.hb_serialise_cell("yes", "checkbox"),
    class = "harbour_warning_checkbox_value"
  )
  expect_identical(out, NA)
})

test_that("the write verbs send 0/1 checkboxes as booleans", {
  cl <- mock_client()
  data <- tibble::tibble(`_id` = c("r1", "r2", "r3"), Consented = c(1, 0, NA))

  appended <- with_mocked_request(
    hb_append_rows(cl, "Patients", data),
    response = list()
  )
  sent <- appended$calls[[1L]]$body$rows
  expect_identical(
    wire_json(sent),
    '[{"Consented":true},{"Consented":false},{"Consented":null}]'
  )

  updated <- with_mocked_request(
    hb_update_rows(cl, "Patients", data),
    response = list()
  )
  rows <- lapply(updated$calls[[1L]]$body$updates, function(u) u$row)
  expect_identical(
    wire_json(rows),
    '[{"Consented":true},{"Consented":false},{"Consented":null}]'
  )
})

test_that("the write verbs warn about a checkbox string they cannot read", {
  cl <- mock_client()
  data <- tibble::tibble(`_id` = c("r1", "r2"), Consented = c("TRUE", "yes"))
  for (verb in list(hb_append_rows, hb_update_rows)) {
    rec <- new_request_recorder()
    expect_warning(
      with_mocked_request(verb(cl, "Patients", data), recorder = rec),
      class = "harbour_warning_checkbox_value"
    )
    body <- rec$calls[[1L]]$body
    cells <- if (is.null(body$rows)) {
      lapply(body$updates, function(u) u$row$Consented)
    } else {
      lapply(body$rows, function(row) row$Consented)
    }
    expect_identical(cells, list(TRUE, NA))
  }
})

test_that("an append reports unreadable checkbox strings once", {
  cl <- mock_client()
  data <- tibble::tibble(
    `Patient ID` = c("p1", "p2", "p3"),
    Consented = c("yes", "no", "TRUE")
  )
  rec <- new_request_recorder()
  warnings <- list()
  withCallingHandlers(
    with_mocked_request(hb_append_rows(cl, "Patients", data), recorder = rec),
    warning = function(cnd) {
      warnings[[length(warnings) + 1L]] <<- cnd
      invokeRestart("muffleWarning")
    }
  )
  expect_length(warnings, 1L)
  expect_s3_class(warnings[[1L]], "harbour_warning_checkbox_value")
  expect_identical(warnings[[1L]]$columns, "Consented")
  expect_match(conditionMessage(warnings[[1L]]), "yes")
  expect_identical(
    lapply(rec$calls[[1L]]$body$rows, function(row) row$Consented),
    list(NA, NA, TRUE)
  )
})

test_that("logical checkbox values are written as they are", {
  cl <- mock_client()
  data <- tibble::tibble(Consented = c(TRUE, FALSE, NA))
  rec <- with_mocked_request(
    hb_append_rows(cl, "Patients", data),
    response = list()
  )
  expect_identical(
    lapply(rec$calls[[1L]]$body$rows, function(row) row$Consented),
    list(TRUE, FALSE, NA)
  )
})

# File and image cells -------------------------------------------------

test_that("a bare file object is written as a one-element array", {
  obj <- file_object()
  out <- harbouR:::.hb_serialise_cell(obj, "file")
  expect_identical(out, list(obj))
  expect_identical(
    wire_json(out),
    paste0(
      '[{"name":"report.pdf","size":12345,"type":"file",',
      '"url":"https://x.org/files/report.pdf"}]'
    )
  )
  # The shapes that were already right are left alone.
  two <- list(obj, file_object("b.pdf"))
  expect_identical(harbouR:::.hb_serialise_cell(list(obj), "file"), list(obj))
  expect_identical(harbouR:::.hb_serialise_cell(two, "file"), two)
  expect_identical(
    harbouR:::.hb_serialise_cell(stats::setNames(two, c("a", "b")), "file"),
    two
  )
})

test_that("the write verbs send an uploaded file object as an array", {
  # tibble(Reports = list(obj)) is the obvious way to write one back.
  cl <- mock_client()
  obj <- file_object()
  data <- tibble::tibble(`_id` = "r1", Reports = list(obj))
  appended <- with_mocked_request(
    hb_append_rows(cl, "Samples", data),
    response = list()
  )
  updated <- with_mocked_request(
    hb_update_rows(cl, "Samples", data),
    response = list()
  )
  expect_identical(appended$calls[[1L]]$body$rows[[1L]]$Reports, list(obj))
  expect_identical(
    updated$calls[[1L]]$body$updates[[1L]]$row$Reports,
    list(obj)
  )
})

test_that("an image cell is an array of URLs, whatever names it carries", {
  urls <- c(a = "https://x.org/a.png", b = "https://x.org/b.png")
  want <- '["https://x.org/a.png","https://x.org/b.png"]'
  expect_identical(
    wire_json(harbouR:::.hb_serialise_cell(urls, "image")), want
  )
  # A named list of URLs is not one object, so it is not wrapped.
  expect_identical(
    wire_json(harbouR:::.hb_serialise_cell(as.list(urls), "image")), want
  )

  cl <- client_with_columns(list(name = "Photos", type = "image", key = "k8"))
  rec <- with_mocked_request(
    hb_append_rows(cl, "Samples", tibble::tibble(Photos = list(urls))),
    response = list()
  )
  expect_identical(
    wire_json(rec$calls[[1L]]$body$rows[[1L]]$Photos), want
  )
})

# Numbers and durations ------------------------------------------------

test_that("non-finite numbers warn once per write, naming the columns", {
  cl <- client_with_columns(list(name = "Ratio", type = "number", key = "k8"))
  data <- tibble::tibble(
    Name = c("a", "b", "c"),
    Concentration = c(1, NaN, Inf),
    Ratio = c(-Inf, 2, 3)
  )
  rec <- new_request_recorder()
  warnings <- list()
  withCallingHandlers(
    with_mocked_request(hb_append_rows(cl, "Samples", data), recorder = rec),
    warning = function(cnd) {
      warnings[[length(warnings) + 1L]] <<- cnd
      invokeRestart("muffleWarning")
    }
  )
  expect_length(warnings, 1L)
  expect_s3_class(warnings[[1L]], "harbour_warning_non_finite")
  # In the table's order, although Ratio's bad cell comes first.
  expect_identical(warnings[[1L]]$columns, c("Concentration", "Ratio"))
  expect_match(conditionMessage(warnings[[1L]]), "Concentration")
  expect_match(conditionMessage(warnings[[1L]]), "Ratio")
  # They are still sent as null: JSON has no Inf or NaN.
  expect_identical(
    wire_json(rec$calls[[1L]]$body$rows),
    paste0(
      '[{"Name":"a","Concentration":1,"Ratio":null},',
      '{"Name":"b","Concentration":null,"Ratio":2},',
      '{"Name":"c","Concentration":null,"Ratio":3}]'
    )
  )
})

test_that("an update with a non-finite number warns", {
  cl <- mock_client()
  rec <- new_request_recorder()
  expect_warning(
    with_mocked_request(
      hb_update_rows(
        cl, "Samples", tibble::tibble(`_id` = "r1", Concentration = Inf)
      ),
      recorder = rec
    ),
    class = "harbour_warning_non_finite"
  )
  expect_identical(
    wire_json(rec$calls[[1L]]$body$updates[[1L]]$row),
    '{"Concentration":null}'
  )
})

test_that("finite numbers and NA are written without a warning", {
  cl <- mock_client()
  expect_no_warning(
    with_mocked_request(
      hb_append_rows(
        cl, "Samples",
        tibble::tibble(Name = c("a", "b"), Concentration = c(1.5, NA))
      ),
      response = list()
    )
  )
})

test_that("a difftime is sent in seconds to a duration column", {
  # SeaTable stores a duration in seconds; a difftime carries its own
  # units, which subtracting two times in R picks automatically.
  cl <- client_with_columns(
    list(name = "Runtime", type = "duration", key = "k8")
  )
  data <- tibble::tibble(
    Name = "a",
    Concentration = as.difftime(1.5, units = "hours"),
    Runtime = as.difftime(90, units = "mins")
  )
  rec <- with_mocked_request(
    hb_append_rows(cl, "Samples", data),
    response = list()
  )
  row <- rec$calls[[1L]]$body$rows[[1L]]
  expect_identical(row$Runtime, 5400)
  # Any other numeric column gets the plain number, in its own units.
  expect_identical(row$Concentration, 1.5)
  expect_identical(
    wire_json(row), '{"Name":"a","Concentration":1.5,"Runtime":5400}'
  )
})

test_that("a difftime cell in a list-column is converted too", {
  minutes <- as.difftime(c(a = 2), units = "mins")
  expect_identical(harbouR:::.hb_serialise_cell(minutes, "duration"), 120)
  expect_identical(harbouR:::.hb_serialise_cell(minutes, "number"), 2)

  cl <- client_with_columns(
    list(name = "Runtime", type = "duration", key = "k8")
  )
  rec <- with_mocked_request(
    hb_update_rows(
      cl, "Samples", tibble::tibble(`_id` = "r1", Runtime = list(minutes))
    ),
    response = list()
  )
  expect_identical(rec$calls[[1L]]$body$updates[[1L]]$row$Runtime, 120)
})

test_that("an update sends difftimes in seconds and warns once per write", {
  cl <- client_with_columns(
    list(name = "Runtime", type = "duration", key = "k8")
  )
  data <- tibble::tibble(
    `_id` = c("r1", "r2"),
    Runtime = as.difftime(c(90, 2), units = "mins"),
    Concentration = c(Inf, NaN)
  )
  rec <- new_request_recorder()
  warnings <- list()
  withCallingHandlers(
    with_mocked_request(hb_update_rows(cl, "Samples", data), recorder = rec),
    warning = function(cnd) {
      warnings[[length(warnings) + 1L]] <<- cnd
      invokeRestart("muffleWarning")
    }
  )
  expect_length(warnings, 1L)
  expect_s3_class(warnings[[1L]], "harbour_warning_non_finite")
  expect_identical(warnings[[1L]]$columns, "Concentration")
  rows <- lapply(rec$calls[[1L]]$body$updates, function(u) u$row)
  expect_identical(vapply(rows, function(row) row$Runtime, 0), c(5400, 120))
})

# Dates on the way out ---------------------------------------------------

test_that("a date-only column is written as the calendar date", {
  # SeaTable documents a date as YYYY-MM-DD. Sent with a time and a zone,
  # it could land on another day on a server that converts the instant to
  # its own zone, so only a column whose format shows a time gets one.
  cl <- client_with_columns(
    list(
      name = "Due", type = "date", key = "k8",
      data = list(format = "YYYY-MM-DD")
    ),
    list(
      name = "When", type = "date", key = "k9",
      data = list(format = "YYYY-MM-DD HH:mm")
    )
  )
  due <- as.POSIXct(c("2030-06-20", NA), tz = "UTC")
  when <- as.POSIXct("2030-06-20 15:30:00", tz = "UTC")
  rec <- with_mocked_request(
    hb_append_rows(
      cl, "Samples",
      tibble::tibble(Name = c("a", "b"), Due = due, When = when)
    ),
    response = list()
  )
  rows <- rec$calls[[1L]]$body$rows
  expect_identical(rows[[1L]]$Due, "2030-06-20")
  expect_identical(rows[[1L]]$When, "2030-06-20T15:30:00Z")
  expect_identical(wire_json(rows[[2L]]["Due"]), '{"Due":null}')

  rec <- with_mocked_request(
    hb_update_rows(
      cl, "Samples",
      tibble::tibble(`_id` = "r1", Due = as.Date("2030-06-21"), When = when)
    ),
    response = list()
  )
  row <- rec$calls[[1L]]$body$updates[[1L]]$row
  expect_identical(row$Due, "2030-06-21")
  expect_identical(row$When, "2030-06-20T15:30:00Z")
})

test_that("a date-only cell read from the API is written back unchanged", {
  # West of UTC the server sends the date as local midnight, a time that is
  # the next morning in UTC; read and written back, it must stay the day.
  column <- date_column("YYYY-MM-DD")
  value <- read_column(list("2030-06-20T00:00:00-05:00"), column)
  rows <- harbouR:::.hb_tibble_to_rows(
    tibble::tibble(Due = value), list(column)
  )
  expect_identical(rows[[1L]]$Due, "2030-06-20")
})

test_that("a date-time in a date-only column is written as the day it shows", {
  # Built as local midnight east of UTC, the instant falls on the day
  # before in UTC; the value still shows, and means, its own day.
  column <- date_column("YYYY-MM-DD")
  written <- function(value) {
    rows <- harbouR:::.hb_tibble_to_rows(
      tibble::tibble(Due = value), list(column)
    )
    rows[[1L]]$Due
  }
  expect_identical(
    written(as.POSIXct("2030-06-20", tz = "Europe/Berlin")), "2030-06-20"
  )
  expect_identical(
    written(as.POSIXct("2030-06-20 22:00", tz = "America/New_York")),
    "2030-06-20"
  )
  expect_identical(
    written(as.POSIXlt("2030-06-20 00:30", tz = "Pacific/Auckland")),
    "2030-06-20"
  )
  # A value harbouR read keeps its day after it is moved to another zone.
  read <- read_column(list("2030-06-20T00:00:00+02:00"), column)
  attr(read, "tzone") <- "America/New_York"
  expect_identical(written(read), "2030-06-20")
})

test_that("a POSIXlt in a date-time column is sent as its instant", {
  local <- as.POSIXlt("2030-06-20 22:00", tz = "America/New_York")
  expect_identical(
    harbouR:::.hb_serialise_cell(local, "date"), "2030-06-21T02:00:00Z"
  )
  expect_identical(
    harbouR:::.hb_serialise_cell(as.Date("2030-06-20"), "date"),
    "2030-06-20T00:00:00Z"
  )
})

test_that("a POSIXlt at midnight UTC keeps its UTC date, as a POSIXct does", {
  column <- date_column("YYYY-MM-DD")
  written <- function(value) {
    rows <- harbouR:::.hb_tibble_to_rows(
      tibble::tibble(Due = value), list(column)
    )
    vapply(rows, function(row) row$Due %||% NA_character_, "")
  }
  read <- read_column(list("2030-06-20T00:00:00-04:00"), column)
  expect_identical(written(as.POSIXlt(read, tz = "America/New_York")),
                   "2030-06-20")
  # An infinite date-time is no midnight, and does not stop the write.
  expect_identical(written(c(read, .POSIXct(-Inf, tz = "UTC"))),
                   c("2030-06-20", "-Inf"))
})

test_that("a Date with a fraction of a day is still sent as its midnight", {
  # mean() of two dates has one; a date-time column is sent the instant
  # of the date, as format() shows it, not a time of day.
  half <- mean(as.Date(c("2030-06-20", "2030-06-21")))
  expect_identical(
    harbouR:::.hb_serialise_cell(half, "date"), "2030-06-20T00:00:00Z"
  )
})

# --- shapes found on a live 6.2.1 server -------------------------------------

test_that("NA in a list-typed column is sent as an empty cell, not [null]", {
  # A live server stored [null] for each of these, and a [null]
  # geolocation then broke every export of the base.
  ser <- function(value, type) wire_json(harbouR:::.hb_serialise_cell(value, type))
  expect_identical(ser(NA, "geolocation"), "null")
  expect_identical(ser(NA_character_, "collaborator"), "[]")
  expect_identical(ser(NA_character_, "image"), "[]")
  expect_identical(ser(NA_character_, "multiple-select"), "[]")
  expect_identical(ser(c("a", NA), "multiple-select"), '["a"]')
  expect_identical(ser(list(NA), "file"), "[]")
  expect_identical(ser(list(list(lat = 1, lng = 2)), "geolocation"), '{"lat":1,"lng":2}')
})

test_that("a geolocation stored as [null] reads as an empty cell", {
  expect_identical(harbouR:::.hb_coerce_cell(list(NULL), "geolocation"), list())
  rows <- list(
    list(`_id` = "r1", G = list(NULL)),
    list(`_id` = "r2", G = list(lat = 48.4, lng = 9.99))
  )
  out <- harbouR:::.hb_rows_to_tibble(
    rows, list(list(name = "G", type = "geolocation", key = "g001"))
  )
  expect_identical(out$G[[1]], list())
  expect_identical(out$G[[2]], list(lng = 9.99, lat = 48.4))
})

test_that("geolocation fields read in one order, whichever the server sends", {
  # The list and get-row endpoints sent lat and lng in different orders,
  # so the same cell read from the two was not identical().
  a <- harbouR:::.hb_coerce_cell(list(lng = 9.99, lat = 48.4), "geolocation")
  b <- harbouR:::.hb_coerce_cell(list(lat = 48.4, lng = 9.99), "geolocation")
  expect_identical(a, b)
  c3 <- harbouR:::.hb_coerce_cell(
    list(address = "Ulm", lng = 9.99, lat = 48.4), "geolocation"
  )
  expect_identical(names(c3), c("lng", "lat", "address"))
})

test_that("a number read into a text column is written out in full", {
  # A formula cell with a numeric result read as "-2e-07" or "1.5e+10",
  # and an array result kept only its first element.
  cell <- function(value) harbouR:::.hb_coerce_cell(value, "formula")
  expect_identical(cell(15000000000), "15000000000")
  expect_identical(cell(-2e-07), "-0.0000002")
  expect_identical(cell(0.6), "0.6")
  expect_identical(cell(list("a", "b")), "a, b")
  expect_identical(cell(TRUE), "TRUE")
})

test_that("an empty string reads as NA, as SeaTable's API reports it", {
  # The API leaves an empty cell out of the row; a .dtable stores "".
  expect_identical(harbouR:::.hb_coerce_cell("", "text"), NA_character_)
  expect_identical(harbouR:::.hb_coerce_cell("", "single-select"), NA_character_)
  expect_identical(
    harbouR:::.hb_coerce_cell(list(text = "", preview = ""), "long-text"),
    NA_character_
  )
  expect_identical(harbouR:::.hb_coerce_cell(" ", "text"), " ")
})

test_that("a row with no writable cells is sent as an object", {
  rows <- harbouR:::.hb_serialise_rows(tibble::tibble(.rows = 2), character())
  expect_identical(wire_json(rows), "[{},{}]")
})

test_that("a number written to a text column is sent as text", {
  ser <- function(value) wire_json(harbouR:::.hb_serialise_cell(value, "text"))
  expect_identical(ser(123456789012), '"123456789012"')
  expect_identical(ser(0.1 + 0.2), '"0.3"')
  expect_identical(ser(NA_real_), "null")
  skip_if_not_installed("bit64")
  big <- bit64::as.integer64("9007199254740993")
  expect_identical(ser(big), '"9007199254740993"')
})
