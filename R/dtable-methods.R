#' Print a harbour dtable
#'
#' @param x A `harbour_dtable`.
#' @param ... Unused.
#' @return Invisibly returns `x`.
#' @family dtable
#' @examples
#' print(hb_dtable(Samples = data.frame(x = 1)))
#' @export
print.harbour_dtable <- function(x, ...) {
  rlang::check_dots_empty()
  tables <- x$content$tables %||% list()
  cli::cli_h1("<harbour_dtable>")
  cli::cli_bullets(c(
    "*" = "base   : {.val {x$base_name}}",
    "*" = "tables : {length(tables)}",
    "*" = "rows   : {sum(.hb_count_field(tables, 'rows'))}",
    "*" = "assets : {nrow(x$assets)}"
  ))
  if (length(tables) > 0L) {
    cli::cli_text("")
    lines <- format(x)
    shown <- lines[seq_len(min(10L, length(lines)))]
    for (line in shown) cli::cli_text("  - {line}")
    if (length(lines) > 10L) {
      cli::cli_text("  ... and {length(lines) - 10L} more.")
    }
  }
  invisible(x)
}

#' @param x A `harbour_dtable`.
#' @param ... Unused.
#' @return A character vector, one element per table.
#' @rdname print.harbour_dtable
#' @export
format.harbour_dtable <- function(x, ...) {
  rlang::check_dots_empty()
  tables <- x$content$tables %||% list()
  if (length(tables) == 0L) {
    return(character())
  }
  sprintf(
    "%s (%d cols, %d rows)",
    .hb_chr_field(tables, "name", default = "<unnamed>"),
    .hb_count_field(tables, "columns"),
    .hb_count_field(tables, "rows")
  )
}

#' Names of the tables in a dtable
#'
#' @param x A `harbour_dtable`.
#' @return A character vector of table names.
#' @family dtable
#' @examples
#' names(hb_dtable(Samples = data.frame(x = 1), Notes = data.frame(y = 2)))
#' @export
names.harbour_dtable <- function(x) {
  .hb_chr_field(x$content$tables %||% list(), "name")
}

#' Number of tables in a dtable
#'
#' @param x A `harbour_dtable`.
#' @return A single integer.
#' @family dtable
#' @examples
#' length(hb_dtable(Samples = data.frame(x = 1)))
#' @export
length.harbour_dtable <- function(x) {
  length(x$content$tables %||% list())
}

#' Coerce a dtable's table index to a tibble
#'
#' @param x A `harbour_dtable`.
#' @param ... Unused.
#' @return A tibble with one row per table and columns `name` (chr),
#'   `n_rows` (int), `n_columns` (int) and `n_views` (int). Unlike the
#'   server path, the row count is real: the rows are in the file.
#' @family dtable
#' @method as_tibble harbour_dtable
#' @examples
#' tibble::as_tibble(hb_dtable(Samples = data.frame(x = 1)))
#' @export
as_tibble.harbour_dtable <- function(x, ...) {
  rlang::check_dots_empty()
  tables <- x$content$tables %||% list()
  if (length(tables) == 0L) {
    return(tibble::tibble(
      name = character(), n_rows = integer(),
      n_columns = integer(), n_views = integer()
    ))
  }
  tibble::tibble(
    name = .hb_chr_field(tables, "name"),
    n_rows = .hb_count_field(tables, "rows"),
    n_columns = .hb_count_field(tables, "columns"),
    n_views = .hb_count_field(tables, "views")
  )
}

#' Summarise the schema of a dtable
#'
#' @param object A `harbour_dtable`.
#' @param ... Unused.
#' @return A tibble with one row per column across all tables: `table`
#'   (chr), `column` (chr), `type` (chr), `key` (chr).
#' @family dtable
#' @method summary harbour_dtable
#' @examples
#' summary(hb_dtable(Samples = data.frame(x = 1, y = "a")))
#' @export
summary.harbour_dtable <- function(object, ...) {
  rlang::check_dots_empty()
  tables <- object$content$tables %||% list()
  parts <- lapply(tables, function(tbl) {
    columns <- tbl$columns %||% list()
    if (length(columns) == 0L) {
      return(NULL)
    }
    tibble::tibble(
      table = rep(tbl$name %||% NA_character_, length(columns)),
      column = .hb_chr_field(columns, "name"),
      type = .hb_chr_field(columns, "type"),
      key = .hb_chr_field(columns, "key")
    )
  })
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (length(parts) == 0L) {
    return(tibble::tibble(
      table = character(), column = character(),
      type = character(), key = character()
    ))
  }
  do.call(rbind, parts)
}

#' Find one table in a dtable
#'
#' @param x A `harbour_dtable`.
#' @param table Table name.
#' @param call The frame to blame for any error.
#' @return The table object, verbatim.
#' @keywords internal
#' @noRd
.hb_dtable_table <- function(x, table, call = rlang::caller_env()) {
  tables <- x$content$tables %||% list()
  known <- .hb_chr_field(tables, "name")
  idx <- match(table, known)
  if (is.na(idx)) {
    hb_abort(
      c("Table {.val {table}} not found in this base.",
        "i" = "Available tables: {.val {known}}."),
      class = "harbour_error_not_found",
      call = call
    )
  }
  tables[[idx]]
}

#' Build a lookup from select-option id to display name
#'
#' On disk a single- or multiple-select cell holds option *ids*; over the
#' API it holds option *names*. Without this translation a local read and
#' a server read of the same column disagree.
#'
#' @param column A column object.
#' @return A named character vector, or `NULL` when the column has no
#'   options.
#' @keywords internal
#' @noRd
.hb_select_lookup <- function(column) {
  options <- column$data$options %||% list()
  if (length(options) == 0L) {
    return(NULL)
  }
  stats::setNames(
    .hb_chr_field(options, "name"),
    .hb_chr_field(options, "id")
  )
}

#' Translate option ids to names in a coerced column
#'
#' @param values The coerced column.
#' @param lookup A named character vector from `.hb_select_lookup()`.
#' @return The column, with recognised ids replaced by names.
#' @keywords internal
#' @noRd
.hb_apply_select_lookup <- function(values, lookup) {
  if (is.null(lookup)) {
    return(values)
  }
  translate <- function(x) {
    hit <- unname(lookup[as.character(x)])
    # An id with no matching option is left as it is rather than becoming
    # NA: better to show the user something than to lose the value.
    ifelse(is.na(hit), as.character(x), hit)
  }
  if (is.list(values)) {
    return(lapply(values, translate))
  }
  translate(values)
}

#' @rdname hb_list_tables
#' @method hb_list_tables harbour_dtable
#' @export
hb_list_tables.harbour_dtable <- function(x, ...) {
  rlang::check_dots_empty()
  tibble::as_tibble(x)
}

#' @rdname hb_list_columns
#' @method hb_list_columns harbour_dtable
#' @export
hb_list_columns.harbour_dtable <- function(x, table, ...) {
  rlang::check_dots_empty()
  .check_string(table)
  columns <- .hb_dtable_table(x, table)$columns %||% list()
  if (length(columns) == 0L) {
    return(tibble::tibble(
      name = character(), type = character(),
      key = character(), editable = logical(), data = list()
    ))
  }
  types <- .hb_chr_field(columns, "type")
  tibble::tibble(
    name = .hb_chr_field(columns, "name"),
    type = types,
    key = .hb_chr_field(columns, "key"),
    editable = !types %in% .hb_readonly_types(),
    data = lapply(columns, function(column) column$data %||% list())
  )
}

#' @rdname hb_list_views
#' @method hb_list_views harbour_dtable
#' @export
hb_list_views.harbour_dtable <- function(x, table, ...) {
  rlang::check_dots_empty()
  .check_string(table)
  views <- .hb_dtable_table(x, table)$views %||% list()
  if (length(views) == 0L) {
    return(tibble::tibble(
      name = character(), type = character(), is_default = logical()
    ))
  }
  tibble::tibble(
    name = .hb_chr_field(views, "name"),
    type = .hb_chr_field(views, "type"),
    is_default = .hb_chr_field(views, "_id") == "0000"
  )
}

#' @param option_labels Translate select-option ids to their display
#'   names. On disk a select cell holds an option id; over the API it
#'   holds the name, so this is what makes a local read and a server read
#'   of the same column agree. Set `FALSE` to see the raw ids.
#' @rdname hb_read_table
#' @method hb_read_table harbour_dtable
#' @export
hb_read_table.harbour_dtable <- function(x, table, ..., view = NULL,
                                         n_max = Inf,
                                         option_labels = TRUE) {
  rlang::check_dots_empty()
  .check_string(table)
  .check_string(view, allow_null = TRUE)
  .check_flag(option_labels)
  .hb_check_n_max(n_max)
  tbl <- .hb_dtable_table(x, table)
  columns <- tbl$columns %||% list()
  rows <- tbl$rows %||% list()
  if (!is.null(view)) {
    rows <- .hb_dtable_view_rows(tbl, view, rows)
  }
  if (length(rows) > n_max) {
    rows <- rows[seq_len(n_max)]
  }
  # Cells in a file are keyed by the column's 4-character key, not by its
  # display name as they are over the API.
  out <- .hb_rows_to_tibble(rows, columns, by = "key")
  if (option_labels) {
    for (i in seq_along(columns)) {
      type <- columns[[i]]$type %||% "text"
      if (!type %in% c("single-select", "multiple-select")) next
      lookup <- .hb_select_lookup(columns[[i]])
      name <- columns[[i]]$name
      out[[name]] <- .hb_apply_select_lookup(out[[name]], lookup)
    }
  }
  .hb_warn_large_numbers(out, table)
  out
}

#' Restrict rows to those a view shows
#'
#' A view's `rows` array, when non-empty, lists the row ids it displays.
#' Filters are not re-evaluated: harbouR reports what the file records.
#'
#' @param tbl A table object.
#' @param view A view name.
#' @param rows The table's rows.
#' @return The subset of `rows` the view shows.
#' @keywords internal
#' @noRd
.hb_dtable_view_rows <- function(tbl, view, rows,
                                 call = rlang::caller_env()) {
  views <- tbl$views %||% list()
  known <- .hb_chr_field(views, "name")
  idx <- match(view, known)
  if (is.na(idx)) {
    hb_abort(
      c("View {.val {view}} not found in table {.val {tbl$name}}.",
        "i" = "Available views: {.val {known}}."),
      class = "harbour_error_not_found",
      call = call
    )
  }
  shown <- unlist(views[[idx]]$rows %||% list(), use.names = FALSE)
  if (length(shown) == 0L) {
    return(rows)
  }
  ids <- vapply(
    rows,
    function(row) as.character(row[["_id"]] %||% NA_character_),
    character(1)
  )
  rows[ids %in% shown]
}

#' Warn about integers a double cannot represent exactly
#'
#' @param data A tibble read from a file.
#' @param table The table's name, for the message.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_warn_large_numbers <- function(data, table) {
  limit <- 2^53
  risky <- names(data)[vapply(
    data,
    function(col) {
      # is.double() is TRUE for POSIXct, which has no abs() method.
      is.double(col) && !inherits(col, c("POSIXt", "Date")) &&
        any(abs(col) > limit, na.rm = TRUE)
    },
    logical(1)
  )]
  if (length(risky) > 0L) {
    cli::cli_warn(c(
      "Some values in {.val {table}} exceed 2^53 and may have lost
       precision as doubles.",
      "i" = "Affected column{?s}: {.field {risky}}."
    ))
  }
  invisible(NULL)
}

#' Explain what the harbouR verbs accept
#'
#' Without these, passing something unsuitable to a generic produces R's
#' "no applicable method" message, which says nothing about what harbouR
#' wanted.
#'
#' @param x The offending object.
#' @param ... Unused.
#' @return Never returns; throws a `harbour_error_bad_argument`.
#' @name harbouR-default-methods
#' @keywords internal
#' @noRd
.hb_abort_no_method <- function(x, fn, call = rlang::caller_env()) {
  hb_abort(
    c("{.arg x} must be a {.cls harbour_client} or a
       {.cls harbour_dtable}.",
      "x" = "You supplied an object of class {.cls {class(x)}}.",
      "i" = "Connect with {.fn hb_client}, or open a file with
             {.fn hb_read_dtable}."),
    class = "harbour_error_bad_argument",
    call = call
  )
}

#' @rdname hb_list_tables
#' @method hb_list_tables default
#' @export
hb_list_tables.default <- function(x, ...) {
  .hb_abort_no_method(x, "hb_list_tables")
}

#' @rdname hb_list_columns
#' @method hb_list_columns default
#' @export
hb_list_columns.default <- function(x, table, ...) {
  .hb_abort_no_method(x, "hb_list_columns")
}

#' @rdname hb_list_views
#' @method hb_list_views default
#' @export
hb_list_views.default <- function(x, table, ...) {
  .hb_abort_no_method(x, "hb_list_views")
}

#' @rdname hb_read_table
#' @method hb_read_table default
#' @export
hb_read_table.default <- function(x, table, ...) {
  .hb_abort_no_method(x, "hb_read_table")
}
