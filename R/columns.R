#' List columns of a table
#'
#' @inheritParams hb_metadata
#' @param table Table name.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @param refresh Logical. Ask the server rather than reusing the cached
#'   base metadata. Default `FALSE`.
#' @return A tibble with one row per column and columns `name` (chr),
#'   `type` (chr), `key` (chr), `editable` (lgl) and `data` (list). The
#'   `data` list-column holds the column's type-specific configuration -
#'   for a select column, its options.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_list_columns(client, "Samples")
#' @export
hb_list_columns <- function(client, table, ..., refresh = FALSE) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_flag(refresh)
  cols <- .hb_fetch_columns(client, table, refresh = refresh)
  if (length(cols) == 0L) {
    return(tibble::tibble(
      name = character(), type = character(),
      key = character(), editable = logical(), data = list()
    ))
  }
  types <- .hb_chr_field(cols, "type")
  tibble::tibble(
    name = .hb_chr_field(cols, "name"),
    type = types,
    key = .hb_chr_field(cols, "key"),
    editable = !types %in% .hb_readonly_types(),
    data = lapply(cols, function(col) col$data %||% list())
  )
}

#' Fetch a table's columns from the server
#'
#' The metadata endpoint carries columns too, but not always with the
#' full `data` payload, and it is cached. Reading the columns endpoint
#' directly is what makes select-option ids resolvable.
#'
#' @param client A `harbour_client`.
#' @param table Table name.
#' @param refresh Whether to bypass the cache.
#' @param call The frame to blame for any error.
#' @return A list of column objects, as SeaTable reports them.
#' @keywords internal
#' @noRd
.hb_fetch_columns <- function(client, table, refresh = FALSE,
                              call = rlang::caller_env()) {
  if (!refresh && !is.null(client$.metadata)) {
    return(.hb_columns_from_metadata(client$.metadata, table))
  }
  body <- .hb_request(client, .hb_base_path(client, "columns", ""),
    service = "gateway", auth = "base", method = "GET",
    query = list(table_name = table), call = call
  )
  body$columns %||% body$metadata %||% list()
}

#' Add a column to a table
#' @inheritParams hb_list_columns
#' @param name Column name.
#' @param type SeaTable column type, e.g. `"text"`, `"number"`, `"date"`.
#' @param column_data Optional list of column options, e.g. the choices
#'   for a select column. Named `column_data` rather than `data` because
#'   `data` means "the rows you are writing" everywhere else in harbouR.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_add_column(client, "Samples", "Notes", "text")
#' @export
hb_add_column <- function(client, table, name, type, ..., column_data = NULL) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(name)
  .check_string(type)
  body <- list(table_name = table, column_name = name, column_type = type)
  if (!is.null(column_data)) body$column_data <- column_data
  .hb_request(client, .hb_base_path(client, "columns", ""),
    service = "gateway", auth = "base", method = "POST",
    body = body
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Add several columns at once
#' @inheritParams hb_add_column
#' @param columns A list of column specs (each a named list).
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_add_columns(
#'   client, "Samples",
#'   list(
#'     list(column_name = "a", column_type = "text"),
#'     list(column_name = "b", column_type = "number")
#'   )
#' )
#' @export
hb_add_columns <- function(client, table, columns, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  if (!is.list(columns) || length(columns) == 0L) {
    hb_abort("{.arg columns} must be a non-empty list of column specs.",
      class = "harbour_error_bad_argument"
    )
  }
  .hb_request(client, .hb_base_path(client, "batch-append-columns", ""),
    service = "gateway", auth = "base", method = "POST",
    body = list(table_name = table, columns = columns)
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Update a column
#' @inheritParams hb_add_column
#' @param new_name Optional new column name. Sends `op_type =
#'   "rename_column"`.
#' @param new_type Optional new SeaTable column type. Sends `op_type =
#'   "modify_column_type"`. SeaTable performs one operation per request,
#'   so this cannot be combined with `new_name`.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_update_column(client, "Samples", "Notes", new_name = "Comments")
#' @export
hb_update_column <- function(client, table, name, ..., new_name = NULL,
                             new_type = NULL, column_data = NULL) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(name)
  .check_string(new_name, allow_null = TRUE)
  .check_string(new_type, allow_null = TRUE)

  # SeaTable requires op_type and performs exactly one operation per call,
  # so asking for two at once is an error rather than something to guess at.
  wanted <- c(
    rename_column = !is.null(new_name),
    modify_column_type = !is.null(new_type) || !is.null(column_data)
  )
  if (sum(wanted) == 0L) {
    hb_abort(
      c("Nothing to update.",
        "i" = "Supply {.arg new_name}, {.arg new_type} or
               {.arg column_data}."),
      class = "harbour_error_bad_argument"
    )
  }
  if (sum(wanted) > 1L) {
    hb_abort(
      c("SeaTable updates one property per request.",
        "x" = "You asked to rename the column and change its type.",
        "i" = "Call {.fn hb_update_column} twice."),
      class = "harbour_error_bad_argument"
    )
  }

  op_type <- names(wanted)[wanted]
  body <- list(table_name = table, column = name, op_type = op_type)
  if (!is.null(new_name)) body$new_column_name <- new_name
  if (!is.null(new_type)) body$new_column_type <- new_type
  if (!is.null(column_data)) body$column_data <- column_data
  .hb_request(client, .hb_base_path(client, "columns", ""),
    service = "gateway", auth = "base", method = "PUT",
    body = body
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Delete a column
#' @inheritParams hb_add_column
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_delete_column(client, "Samples", "Old")
#' @export
hb_delete_column <- function(client, table, name, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(name)
  .hb_request(client, .hb_base_path(client, "columns", ""),
    service = "gateway", auth = "base", method = "DELETE",
    body = list(table_name = table, column = name)
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Add a single-select option
#' @inheritParams hb_add_column
#' @param option Option name to add.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_add_select_option(client, "Samples", "Status", "Done")
#' @export
hb_add_select_option <- function(client, table, name, option, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(name)
  .check_string(option)
  .hb_request(client, .hb_base_path(client, "column-options", ""),
    service = "gateway", auth = "base", method = "POST",
    body = list(
      table_name = table, column = name,
      options = list(list(name = option))
    )
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Update a single-select option
#' @inheritParams hb_add_select_option
#' @param new_option New option name.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_update_select_option(client, "Samples", "Status", "Done", "Complete")
#' @export
hb_update_select_option <- function(client,
                                    table,
                                    name,
                                    option,
                                    new_option,
                                    ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(name)
  .check_string(option)
  .check_string(new_option)
  # The API identifies the option to change by id, not by name, so the
  # current options have to be read before it can be updated.
  id <- .hb_select_option_id(client, table, name, option)
  .hb_request(client, .hb_base_path(client, "column-options", ""),
    service = "gateway", auth = "base", method = "PUT",
    body = list(
      table_name = table, column = name,
      options = list(list(id = id, name = new_option))
    )
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Delete a single-select option
#' @inheritParams hb_add_select_option
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_delete_select_option(client, "Samples", "Status", "Old")
#' @export
hb_delete_select_option <- function(client, table, name, option, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(name)
  .check_string(option)
  .hb_request(client, .hb_base_path(client, "column-options", ""),
    service = "gateway", auth = "base", method = "DELETE",
    body = list(
      table_name = table, column = name,
      option_names = as.list(option)
    )
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Resolve a select option's name to its SeaTable id
#'
#' Options are created by name but addressed by id. This reads the
#' column's current options and looks the name up.
#'
#' @param client A `harbour_client`.
#' @param table Table name.
#' @param column Column name.
#' @param option The option's display name.
#' @param call The frame to blame for any error.
#' @return A single string: the option's id.
#' @keywords internal
#' @noRd
.hb_select_option_id <- function(client, table, column, option,
                                 call = rlang::caller_env()) {
  cols <- .hb_fetch_columns(client, table, refresh = TRUE, call = call)
  idx <- match(column, .hb_chr_field(cols, "name"))
  if (is.na(idx)) {
    hb_abort(
      c("Column {.val {column}} not found in table {.val {table}}."),
      class = "harbour_error_not_found",
      call = call
    )
  }
  options <- cols[[idx]]$data$options %||% list()
  names_seen <- .hb_chr_field(options, "name")
  hit <- match(option, names_seen)
  if (is.na(hit)) {
    hb_abort(
      c("Option {.val {option}} not found in column {.val {column}}.",
        "i" = "Available options: {.val {names_seen}}."),
      class = "harbour_error_not_found",
      call = call
    )
  }
  as.character(options[[hit]]$id)
}
