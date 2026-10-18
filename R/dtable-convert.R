#' Export a base to an Excel workbook
#'
#' Writes one worksheet per table. This is deliberately **one-way**: a
#' spreadsheet cell holds a single value, so several SeaTable column types
#' have no faithful representation.
#'
#' Each sheet is named after its table. `writexl` may adjust a name to fit
#' Excel's rules for sheet names: at most 31 characters, and none of
#' `/`, `\`, `?`, `*`, `:` or a square bracket. Excel compares sheet names
#' ignoring case, so table names that differ only in the case of the
#' letters A to Z, such as `Samples` and `samples`, are rejected before
#' anything is written.
#'
#' @section What is lost:
#'
#' * `multiple-select`, `collaborator` and `image` cells are joined with
#'   `", "`.
#' * `file` cells are reduced to their file names.
#' * `link` and `link-formula` cells reference rows in other tables and
#'   are exported as their display values.
#' * `formula` columns export their computed value, not the formula.
#' * `geolocation` cells are written as their values, in the order the
#'   source stores them, without the field names: `"11.5761, 48.1371"`
#'   does not say which number is the latitude.
#' * `digital-sign` cells are written as a placeholder, `"<object>"`, or
#'   as their bare values, depending on how the source stores them; the
#'   signature itself is not exported. `button` columns hold no value and
#'   are written as missing.
#' * A CSV stores numbers with 15 significant digits and a workbook with
#'   16, so a double that needs more, such as `0.1 + 0.2`, reads back very
#'   slightly different. In a CSV, date-times are written by
#'   `as.character()`, whose layout depends on the version of R. Use
#'   [hb_write_dtable()] for full precision.
#' * Views, filters, colours, column widths and every other piece of base
#'   configuration have no cell to live in.
#'
#' harbouR reports which columns were flattened. To keep everything, write
#' a `.dtable` with [hb_write_dtable()] instead.
#'
#' @param x A `harbour_dtable`, or a `harbour_client` to read from first.
#' @param path Destination `.xlsx` path.
#' @param ... These dots are for future extensions and must be empty.
#' @param tables Table names to export. Default: all of them.
#'
#' @return `path`, invisibly.
#'
#' @family dtable
#' @seealso [hb_write_csv()], [hb_write_dtable()]
#' @examplesIf rlang::is_installed("writexl")
#' base <- hb_read_dtable(
#'   system.file("extdata", "example.dtable", package = "harbouR")
#' )
#' out <- tempfile(fileext = ".xlsx")
#' hb_write_xlsx(base, out)
#' @export
hb_write_xlsx <- function(x, path, ..., tables = NULL) {
  rlang::check_dots_empty()
  rlang::check_installed("writexl", reason = "to write .xlsx files")
  .check_string(path)
  sheets <- .hb_flatten_tables(x, tables)
  # Excel compares sheet names ignoring case, and libxlsxwriter rejects
  # such a clash with an error that names neither table. Only A to Z are
  # folded: writexl writes names that differ in the case of other letters,
  # and renames exact repeats itself.
  distinct <- unique(names(sheets))
  folded <- chartr(
    paste(LETTERS, collapse = ""), paste(letters, collapse = ""), distinct
  )
  if (anyDuplicated(folded)) {
    clashing <- folded %in% folded[duplicated(folded)]
    # The names that would share a sheet are listed next to each other.
    clash <- distinct[clashing][order(match(folded[clashing], folded))]
    hb_abort(
      c("Table names that differ only in case cannot all be sheet names.",
        "x" = "Excel ignores case in sheet names, so these clash:
               {.val {clash}}.",
        "i" = "Export them to separate workbooks with {.arg tables}."),
      class = "harbour_error_bad_argument"
    )
  }
  # writexl shortens a long name and replaces the characters Excel does not
  # allow, which can make two names clash that the check above passed;
  # libxlsxwriter then fails with an error that names neither table.
  rlang::try_fetch(
    writexl::write_xlsx(sheets, path = path),
    error = function(cnd) {
      if (!grepl("already in use", conditionMessage(cnd), fixed = TRUE)) {
        return(rlang::zap())
      }
      hb_abort(
        c("Two table names give the same sheet name.",
          "i" = "Excel shortens sheet names to 31 characters, replaces
                 characters it does not allow and ignores case.",
          "i" = "Export the tables to separate workbooks with
                 {.arg tables}."),
        class = "harbour_error_bad_argument",
        parent = cnd
      )
    }
  )
  invisible(path)
}

#' Export a base to CSV files
#'
#' Writes one `.csv` per table into `dir`. Subject to the same losses as
#' [hb_write_xlsx()]; see its documentation. Table names that produce the
#' same filename (ignoring case) are rejected before any files are written.
#'
#' @param x A `harbour_dtable`, or a `harbour_client` to read from first.
#' @param dir Destination directory. Created if it does not exist.
#' @param ... These dots are for future extensions and must be empty.
#' @param tables Table names to export. Default: all of them.
#'
#' @return A character vector of the files written, invisibly.
#'
#' @family dtable
#' @seealso [hb_write_xlsx()], [hb_write_dtable()]
#' @examples
#' base <- hb_read_dtable(
#'   system.file("extdata", "example.dtable", package = "harbouR")
#' )
#' dir <- tempfile()
#' hb_write_csv(base, dir)
#' list.files(dir)
#' @export
hb_write_csv <- function(x, dir, ..., tables = NULL) {
  rlang::check_dots_empty()
  .check_string(dir)
  sheets <- .hb_flatten_tables(x, tables)
  filenames <- paste0(.hb_safe_filename(names(sheets)), ".csv")
  if (anyDuplicated(tolower(filenames))) {
    hb_abort(
      c("Table names produce duplicate CSV filenames.",
        "i" = "Export the tables separately to different directories."),
      class = "harbour_error_bad_argument"
    )
  }
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  paths <- character(length(sheets))
  for (i in seq_along(sheets)) {
    file <- file.path(dir, filenames[[i]])
    .hb_write_csv_file(sheets[[i]], file)
    paths[[i]] <- file
  }
  invisible(paths)
}

#' Read tables into a new base from CSV files
#'
#' Builds a fresh `harbour_dtable` from CSV files, one table per file.
#' This is **not** the inverse of [hb_write_csv()]: it produces a new base
#' with new identifiers, and only text, number and checkbox columns.
#' Nothing that a CSV cannot carry is recovered.
#'
#' Columns are typed the way [utils::read.csv()] types them, and quoting a
#' value does not change that:
#'
#' * A column of numbers becomes `number`, and one holding only `T`, `F`,
#'   `TRUE` or `FALSE` becomes `checkbox`.
#' * A value written `NA` is read as missing.
#' * Dates and date-times arrive as text.
#'
#' Two exceptions avoid losing data. A column holding an integer with a
#' leading zero, such as `"0001"`, or an integer of more than 15 digits
#' stays text, rather than losing the zeros or having its digits rounded.
#' A column with no values at all is text, not a checkbox column that
#' would read `FALSE` in every row.
#'
#' The files must be UTF-8, with or without a byte-order mark. A file in
#' another encoding is refused, naming the first line that is not valid
#' UTF-8. In a multibyte session that is not UTF-8, such as Shift-JIS or
#' GBK, the text goes through that session's encoding, so characters it
#' lacks are lost; read such files in a UTF-8 session. A column named
#' `_id`, such as the one [hb_write_csv()] writes,
#' is dropped: SeaTable keeps that name for the row identifier, and the new
#' base has identifiers of its own. One that holds anything but SeaTable
#' row ids, such as a database's keys, is dropped with a warning.
#'
#' @param files Paths to `.csv` files. Table names come from the file
#'   names unless `files` is named.
#' @param ... These dots are for future extensions and must be empty.
#' @param base_name Name recorded for the new base.
#'
#' @return A `harbour_dtable`.
#'
#' @family dtable
#' @examples
#' csv <- tempfile(fileext = ".csv")
#' utils::write.csv(data.frame(x = 1:2, y = c("a", "b")), csv,
#'                  row.names = FALSE)
#' hb_read_csv(c(Measurements = csv))
#' @export
hb_read_csv <- function(files, ..., base_name = "harbouR base") {
  rlang::check_dots_empty()
  if (!is.character(files) || length(files) == 0L) {
    hb_abort("{.arg files} must be a character vector of paths.",
      class = "harbour_error_bad_argument"
    )
  }
  absent <- files[!file.exists(files)]
  if (length(absent) > 0L) {
    hb_abort(
      c("{length(absent)} file{?s} not found.", "x" = "{.path {absent}}"),
      class = "harbour_error_not_found"
    )
  }
  names(files) <- names(files) %||%
    tools::file_path_sans_ext(basename(files))
  blank <- !nzchar(names(files))
  names(files)[blank] <- tools::file_path_sans_ext(basename(files[blank]))
  frames <- lapply(files, .hb_read_csv_file, call = rlang::current_env())
  .hb_import_base(frames, base_name, call = rlang::current_env())
}

#' Read tables into a new base from an Excel workbook
#'
#' One table per worksheet. Like [hb_read_csv()], this produces a *new*
#' base rather than restoring one.
#'
#' A column's type follows its cells, judged over every row of the sheet.
#' A column with no values at all is text. A column named `_id`, such as
#' the one [hb_write_xlsx()] writes, is dropped, with a warning when it
#' holds anything but SeaTable row ids.
#'
#' @param path Path to an `.xlsx` file.
#' @param ... These dots are for future extensions and must be empty.
#' @param sheets Worksheet names to read. Default: all of them.
#' @param base_name Name recorded for the new base.
#'
#' @return A `harbour_dtable`.
#'
#' @family dtable
#' @examplesIf rlang::is_installed(c("writexl", "readxl"))
#' path <- tempfile(fileext = ".xlsx")
#' writexl::write_xlsx(list(Samples = data.frame(x = 1:2)), path)
#' hb_read_xlsx(path)
#' @export
hb_read_xlsx <- function(path, ..., sheets = NULL,
                         base_name = "harbouR base") {
  rlang::check_dots_empty()
  rlang::check_installed("readxl", reason = "to read .xlsx files")
  .check_string(path)
  if (!file.exists(path)) {
    hb_abort(
      c("File not found.", "x" = "{.path {path}}"),
      class = "harbour_error_not_found"
    )
  }
  available <- readxl::excel_sheets(path)
  wanted <- sheets %||% available
  unknown <- setdiff(wanted, available)
  if (length(unknown) > 0L) {
    hb_abort(
      c("Worksheet{?s} not found: {.val {unknown}}.",
        "i" = "Available: {.val {available}}."),
      class = "harbour_error_not_found"
    )
  }
  frames <- lapply(wanted, function(sheet) {
    # readxl guesses a column's type from its first 1000 rows, and a later
    # value that does not fit the guess is lost. 1048576 is Excel's row
    # limit, so the guess sees the whole sheet.
    as.data.frame(
      readxl::read_excel(path, sheet = sheet, guess_max = 1048576L)
    )
  })
  names(frames) <- wanted
  .hb_import_base(frames, base_name, call = rlang::current_env())
}

#' Read one CSV file as read.csv() would, without losing text
#'
#' `read.csv()` converts a column after scanning it, and quoting does not
#' protect a value, so `"0001"` would become `1`. Every column is read as
#' text instead and converted here.
#'
#' @param path Path to a `.csv` file.
#' @param call The frame to blame for any error.
#' @return A data frame.
#' @keywords internal
#' @noRd
.hb_read_csv_file <- function(path, call = rlang::caller_env()) {
  # A pipe or a FIFO can be read only once, and the check reads it before
  # read.csv() would; such input is read into a file first. A regular file
  # is read where it is, so that read.csv()'s own warnings name it.
  source <- path
  if (grepl("^/(dev|proc)/", path) || !isTRUE(file.size(path) > 0)) {
    source <- tempfile("harbour-csv-")
    on.exit(unlink(source), add = TRUE)
    if (!isTRUE(file.copy(path, source))) {
      hb_abort(
        c("Could not read a CSV file.", "x" = "{.path {path}}"),
        class = "harbour_error_bad_argument",
        call = call
      )
    }
  }
  text <- .hb_check_csv_text(source, shown = path, call = call)
  frame <- rlang::try_fetch(
    .hb_read_csv_text(source, bom = text$bom),
    error = function(cnd) {
      # read.csv() gives up on a file of blank lines, with a message that
      # names no file.
      if (!text$blank) {
        return(rlang::zap())
      }
      hb_abort(
        c("A CSV file is empty.",
          "x" = "{.path {path}}",
          "i" = "A table needs at least a header line naming its columns."),
        class = "harbour_error_bad_argument",
        call = call,
        parent = cnd
      )
    }
  )
  frame[] <- lapply(frame, .hb_convert_csv_column)
  frame
}

#' Read checked UTF-8 bytes as a CSV
#'
#' In a UTF-8 session this is `read.csv(fileEncoding = "UTF-8")`, as it
#' always was. In a single-byte session, such as C or Latin-1, that
#' connection would re-encode the text into the session's encoding and
#' stop at the first character the encoding lacks, with only a generic
#' warning. The bytes are known to be UTF-8, so they are read as they are
#' and declared UTF-8 instead, and a byte-order mark, which `scan()` drops
#' only in a UTF-8 session, is dropped here. A multibyte session checks
#' text against its own encoding, so there the text is converted, as it
#' always was.
#'
#' @param path Path to a `.csv` file whose bytes are UTF-8.
#' @param bom Whether its first line starts with a byte-order mark.
#' @return A data frame of character columns.
#' @keywords internal
#' @noRd
.hb_read_csv_text <- function(path, bom = FALSE) {
  if (isTRUE(l10n_info()[["UTF-8"]])) {
    return(utils::read.csv(path, colClasses = "character",
                           check.names = FALSE, fileEncoding = "UTF-8"))
  }
  if (isTRUE(l10n_info()[["MBCS"]])) {
    return(utils::read.csv(path, colClasses = "character",
                           check.names = FALSE,
                           fileEncoding = if (bom) "UTF-8-BOM" else "UTF-8"))
  }
  con <- file(path, open = "rt", encoding = "native.enc")
  on.exit(close(con), add = TRUE)
  if (bom) {
    first <- readLines(con, n = 1L, warn = FALSE)
    pushBack(sub("^\ufeff", "", first, useBytes = TRUE), con,
             encoding = "bytes")
  }
  utils::read.csv(con, colClasses = "character", check.names = FALSE,
                  encoding = "UTF-8")
}

#' Write a data frame as a UTF-8 CSV file
#'
#' In a UTF-8 session this is `write.csv(fileEncoding = "UTF-8")`, as it
#' always was. In a single-byte session, such as C or Latin-1,
#' `write.csv()` first translates every string into the session's
#' encoding, writing a character it lacks as the literal text
#' `<U+00B0>`, so the strings are handed over as their UTF-8 bytes, which
#' it then writes unchanged. A multibyte session checks text against its
#' own encoding, so there it is written as it always was.
#'
#' @param frame A data frame.
#' @param file The path to write.
#' @return `file`, invisibly.
#' @keywords internal
#' @noRd
.hb_write_csv_file <- function(frame, file) {
  if (isTRUE(l10n_info()[["UTF-8"]]) || isTRUE(l10n_info()[["MBCS"]])) {
    utils::write.csv(frame, file, row.names = FALSE, fileEncoding = "UTF-8")
    return(invisible(file))
  }
  as_bytes <- function(x) {
    x <- enc2utf8(x)
    Encoding(x) <- "unknown"
    x
  }
  frame[] <- lapply(frame, function(col) {
    if (is.factor(col)) {
      levels(col) <- as_bytes(levels(col))
    } else if (is.character(col)) {
      col <- as_bytes(col)
    }
    col
  })
  names(frame) <- as_bytes(names(frame))
  con <- file(file, open = "w", encoding = "native.enc")
  on.exit(close(con), add = TRUE)
  utils::write.csv(frame, con, row.names = FALSE)
  invisible(file)
}

#' Convert one CSV column as read.csv() would, unless that loses text
#'
#' @param values A character vector, as `read.csv()` scanned it.
#' @return The converted vector, or `values` unchanged.
#' @keywords internal
#' @noRd
.hb_convert_csv_column <- function(values) {
  # A number cannot keep the zeros of "0001", nor the digits of an integer
  # longer than the 15 a double is sure to hold, so such a column stays
  # text.
  lossy <- grepl("^\\s*[-+]?(0[0-9]+|[0-9]{16,})\\s*$", values, perl = TRUE)
  if (any(lossy)) {
    return(values)
  }
  # The arguments read.table() itself passes, so that every other column
  # comes out exactly as read.csv() would have returned it.
  utils::type.convert(values, na.strings = character(), as.is = TRUE,
                      dec = ".", numerals = "allow.loss")
}

#' Refuse a CSV file that is not UTF-8 text, or holds nothing
#'
#' A connection that meets a byte it cannot decode stops reading, and
#' `read.csv()` returns the rows it had so far with only a generic warning:
#' a Windows-1252 file would lose everything after its first accented
#' letter.
#'
#' @param path Path to a `.csv` file.
#' @param shown The path to name in messages: the file the user gave,
#'   when `path` is a copy of it.
#' @param call The frame to blame for any error.
#' @return A list: `bom`, whether the first line starts with a byte-order
#'   mark, and `blank`, whether every line is blank.
#' @keywords internal
#' @noRd
.hb_check_csv_text <- function(path, shown = path,
                               call = rlang::caller_env()) {
  # "native.enc" hands the bytes over unconverted, whatever
  # options(encoding) says, and text mode still unpacks a compressed file
  # the way read.csv() does. Nuls are skipped rather than cutting a line
  # short, so the bytes after one are checked too; read.csv() deals with
  # nuls itself.
  con <- file(path, open = "rt", encoding = "native.enc")
  on.exit(close(con), add = TRUE)
  lines <- readLines(con, warn = FALSE, skipNul = TRUE)
  bad <- which(!validUTF8(lines))
  if (length(bad) > 0L) {
    line <- bad[[1L]]
    hb_abort(
      c("A CSV file is not UTF-8.",
        "x" = "{.path {shown}} has bytes that are not valid UTF-8 on line
               {line}.",
        "i" = "Re-save it as {.val CSV UTF-8} and read it again."),
      class = "harbour_error_bad_argument",
      call = call
    )
  }
  # read.csv() fails on a file with nothing in it, with messages such as
  # "no lines available in input" that do not say which file. A
  # byte-order mark is not content, and readLines() drops one only in a
  # UTF-8 locale.
  bom <- FALSE
  if (length(lines) > 0L) {
    first <- sub("^\ufeff", "", lines[[1L]], useBytes = TRUE)
    bom <- !identical(first, lines[[1L]])
    lines[[1L]] <- first
  }
  if (!any(nzchar(lines))) {
    hb_abort(
      c("A CSV file is empty.",
        "x" = "{.path {shown}}",
        "i" = "A table needs at least a header line naming its columns."),
      class = "harbour_error_bad_argument",
      call = call
    )
  }
  # On the bytes: in a multibyte session trimws() would check the text
  # against the session's encoding.
  list(bom = bom, blank = !any(grepl("[^ \t\r\n]", lines, useBytes = TRUE)))
}

#' Build a new base from imported data frames
#'
#' Shared by [hb_read_csv()] and [hb_read_xlsx()].
#'
#' @param frames A named list of data frames, one per table.
#' @param base_name Name recorded for the new base.
#' @return A `harbour_dtable`.
#' @keywords internal
#' @noRd
.hb_import_base <- function(frames, base_name,
                            call = rlang::caller_env()) {
  tables <- names(frames)
  frames <- lapply(seq_along(frames), function(k) {
    frame <- frames[[k]]
    # The exporters write the _id that hb_read_table() adds. Kept as an
    # ordinary column it collides with the row identifier, and no table of
    # the new base could be read. The other row fields collide with nothing
    # offline and have always imported, so they stay. Columns go one at a
    # time, because subsetting with `[` would rename repeated names.
    for (i in rev(which(names(frame) == "_id"))) {
      # An export's _id holds row ids; any other is data of the user's
      # own, such as a database's keys, and its loss is reported.
      if (!.hb_holds_row_ids(frame[[i]])) {
        table <- tables[[k]]
        cli::cli_warn(
          c("Dropped the {.field _id} column of table {.val {table}}.",
            "i" = "SeaTable keeps {.field _id} for its row identifier.
                   Rename the column in the file to keep its values."),
          class = "harbour_warning_id_column",
          call = call
        )
      }
      frame[[i]] <- NULL
    }
    # A column with no values gives read.csv() and readxl nothing to judge
    # by, and both call it logical. As a checkbox it would read back FALSE
    # in every row.
    for (i in seq_along(frame)) {
      if (is.logical(frame[[i]]) && all(is.na(frame[[i]]))) {
        frame[[i]] <- as.character(frame[[i]])
      }
    }
    frame
  })
  names(frames) <- tables
  .hb_dtable_from_frames(frames, base_name)
}

#' Does a column hold SeaTable row ids, and nothing else?
#'
#' @param x A column.
#' @return A single `TRUE` or `FALSE`; `TRUE` for a column with no values.
#' @keywords internal
#' @noRd
.hb_holds_row_ids <- function(x) {
  values <- as.character(x)
  values <- values[!is.na(values) & nzchar(values)]
  all(grepl("^[A-Za-z0-9_-]{22}$", values))
}

#' Build a base from a named list of data frames
#'
#' [hb_dtable()] takes its tables through `...`, so a table named
#' `collaborators` or `base_name` would bind to that argument instead of
#' becoming a table. The base is built under stand-in names, and the real
#' ones are put back afterwards; nothing else in it depends on the name.
#'
#' @param frames A named list of data frames, one per table.
#' @param base_name Name recorded for the new base.
#' @return A `harbour_dtable`.
#' @keywords internal
#' @noRd
.hb_dtable_from_frames <- function(frames, base_name) {
  real <- names(frames)
  alias <- real
  # A missing or empty name is passed on as it is and left as hb_dtable()
  # treats it: an empty one is refused, and a missing one becomes "NA".
  valid <- !is.na(real) & nzchar(real)
  alias[valid] <- paste0("table", seq_along(real))[valid]
  names(frames) <- alias
  base <- rlang::exec(hb_dtable, !!!frames, base_name = base_name)
  for (i in which(valid)) {
    base$content$tables[[i]]$name <- real[[i]]
  }
  base
}

#' Flatten a base's tables into spreadsheet-shaped data frames
#'
#' @param x A `harbour_dtable` or `harbour_client`.
#' @param tables Table names to include, or `NULL` for all.
#' @param call The frame to blame for any error.
#' @return A named list of data frames.
#' @keywords internal
#' @noRd
.hb_flatten_tables <- function(x, tables = NULL, call = rlang::caller_env()) {
  available <- if (is_harbour_dtable(x)) names(x) else hb_list_tables(x)$name
  wanted <- tables %||% available
  unknown <- setdiff(wanted, available)
  if (length(unknown) > 0L) {
    hb_abort(
      c("Table{?s} not found: {.val {unknown}}.",
        "i" = "Available: {.val {available}}."),
      class = "harbour_error_not_found",
      call = call
    )
  }
  flattened <- character()
  out <- lapply(wanted, function(table) {
    data <- hb_read_table(x, table)
    for (name in names(data)) {
      if (!is.list(data[[name]])) next
      flattened <<- c(flattened, paste0(table, "$", name))
      data[[name]] <- .hb_flatten_column(data[[name]])
    }
    as.data.frame(data, check.names = FALSE, stringsAsFactors = FALSE)
  })
  names(out) <- wanted
  if (length(flattened) > 0L) {
    # cli shortens an interpolated vector to 20 items, and a wide base can
    # flatten more; each one is a column the file no longer holds intact.
    shown <- cli::cli_vec(flattened, list("vec-trunc" = Inf))
    # The class lets the explorer show this report without taking every
    # other message for one.
    cli::cli_inform(
      c(
        "!" = "{length(flattened)} column{?s} {?was/were} flattened to text.",
        "*" = "{.field {shown}}",
        "i" = "A spreadsheet cell holds one value. Use
               {.fn hb_write_dtable} to keep the structure."
      ),
      class = "harbour_message_flattened"
    )
  }
  out
}

#' Reduce one list-column to a character vector
#'
#' @param column A list-column.
#' @return A character vector of the same length.
#' @keywords internal
#' @noRd
.hb_flatten_column <- function(column) {
  vapply(
    column,
    function(cell) {
      if (length(cell) == 0L) {
        return(NA_character_)
      }
      # A file or image cell is a list of objects; its name is the useful
      # part. Anything else is already a vector of scalars.
      if (is.list(cell)) {
        parts <- vapply(
          cell,
          function(item) {
            if (is.list(item)) {
              as.character(item$name %||% item$display_value %||%
                             item$url %||% "<object>")
            } else {
              as.character(item)
            }
          },
          character(1)
        )
        return(paste(parts, collapse = ", "))
      }
      paste(as.character(cell), collapse = ", ")
    },
    character(1)
  )
}

#' Make a table name safe to use as a file name
#'
#' @param x A table name.
#' @return A single string with path separators replaced.
#' @keywords internal
#' @noRd
.hb_safe_filename <- function(x) {
  gsub("[^A-Za-z0-9._-]+", "_", x)
}
