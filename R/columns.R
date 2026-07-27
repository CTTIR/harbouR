#' List columns of a table
#'
#' @inheritParams hb_metadata
#' @param table Table name.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @return A tibble with columns `name` (chr), `type` (chr), `key` (chr) and
#'   `editable` (lgl).
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_list_columns(client, "Samples")
#' @export
hb_list_columns <- function(client, table, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  if (is.null(client$.metadata)) hb_metadata(client)
  cols <- .hb_columns_from_metadata(client$.metadata, table)
  if (length(cols) == 0L) {
    return(tibble::tibble(
      name = character(), type = character(),
      key = character(), editable = logical()
    ))
  }
  types <- .hb_chr_field(cols, "type")
  tibble::tibble(
    name = .hb_chr_field(cols, "name"),
    type = types,
    key = .hb_chr_field(cols, "key"),
    editable = !types %in% .hb_readonly_types()
  )
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
  .hb_request(client, "/dtable-server/api/v1/dtables/columns/",
    service = "dtable_server", auth = "base", method = "POST",
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
  .hb_request(client, "/dtable-server/api/v1/dtables/batch-append-columns/",
    service = "dtable_server", auth = "base", method = "POST",
    body = list(table_name = table, columns = columns)
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Update a column
#' @inheritParams hb_add_column
#' @param new_name Optional new column name.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_update_column(client, "Samples", "Notes", new_name = "Comments")
#' @export
hb_update_column <- function(client, table, name, ..., new_name = NULL,
                             column_data = NULL) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(name)
  .check_string(new_name, allow_null = TRUE)
  body <- list(table_name = table, column = name)
  if (!is.null(new_name)) body$new_column_name <- new_name
  if (!is.null(column_data)) body$column_data <- column_data
  .hb_request(client, "/dtable-server/api/v1/dtables/columns/",
    service = "dtable_server", auth = "base", method = "PUT",
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
  .hb_request(client, "/dtable-server/api/v1/dtables/columns/",
    service = "dtable_server", auth = "base", method = "DELETE",
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
  .hb_request(client, "/dtable-server/api/v1/dtables/column-options/",
    service = "dtable_server", auth = "base", method = "POST",
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
  .hb_request(client, "/dtable-server/api/v1/dtables/column-options/",
    service = "dtable_server", auth = "base", method = "PUT",
    body = list(
      table_name = table, column = name,
      option = option, new_option = new_option
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
  .hb_request(client, "/dtable-server/api/v1/dtables/column-options/",
    service = "dtable_server", auth = "base", method = "DELETE",
    body = list(table_name = table, column = name, option = option)
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}
