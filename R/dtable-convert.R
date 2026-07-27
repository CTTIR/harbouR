#' Export a base to an Excel workbook
#'
#' Writes one worksheet per table. This is deliberately **one-way**: a
#' spreadsheet cell holds a single value, so several SeaTable column types
#' have no faithful representation.
#'
#' @section What is lost:
#'
#' * `multiple-select`, `collaborator` and `image` cells are joined with
#'   `", "`.
#' * `file` cells are reduced to their file names.
#' * `link` and `link-formula` cells reference rows in other tables and
#'   are exported as their display values.
#' * `formula` columns export their computed value, not the formula.
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
  writexl::write_xlsx(sheets, path = path)
  invisible(path)
}

#' Export a base to CSV files
#'
#' Writes one `.csv` per table into `dir`. Subject to the same losses as
#' [hb_write_xlsx()]; see its documentation.
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
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  paths <- character(length(sheets))
  for (i in seq_along(sheets)) {
    name <- .hb_safe_filename(names(sheets)[[i]])
    file <- file.path(dir, paste0(name, ".csv"))
    utils::write.csv(
      sheets[[i]], file,
      row.names = FALSE, fileEncoding = "UTF-8"
    )
    paths[[i]] <- file
  }
  invisible(paths)
}

#' Read tables into a new base from CSV files
#'
#' Builds a fresh `harbour_dtable` from CSV files, one table per file.
#' This is **not** the inverse of [hb_write_csv()]: it produces a new base
#' with new identifiers, and only text, number, date and checkbox columns.
#' Nothing that a CSV cannot carry is recovered.
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
  frames <- lapply(files, function(file) {
    utils::read.csv(file, stringsAsFactors = FALSE, check.names = FALSE,
                    fileEncoding = "UTF-8")
  })
  rlang::exec(hb_dtable, !!!frames, base_name = base_name)
}

#' Read tables into a new base from an Excel workbook
#'
#' One table per worksheet. Like [hb_read_csv()], this produces a *new*
#' base rather than restoring one.
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
    as.data.frame(readxl::read_excel(path, sheet = sheet))
  })
  names(frames) <- wanted
  rlang::exec(hb_dtable, !!!frames, base_name = base_name)
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
    cli::cli_inform(c(
      "!" = "{length(flattened)} column{?s} {?was/were} flattened to text.",
      "*" = "{.field {flattened}}",
      "i" = "A spreadsheet cell holds one value. Use
             {.fn hb_write_dtable} to keep the structure."
    ))
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
