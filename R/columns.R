#' List columns of a table
#'
#' @inheritParams hb_metadata
#' @param table Table name.
#'
#' @return A tibble with columns `name` (chr), `type` (chr), `key` (chr) and
#'   `editable` (lgl).
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_list_columns(client, "Samples")
#' @export
hb_list_columns <- function(client, table, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  if (is.null(client$.metadata)) hb_metadata(client, call = call)
  cols <- .hb_columns_from_metadata(client$.metadata, table)
  if (length(cols) == 0L) {
    return(tibble::tibble(name = character(), type = character(),
                          key = character(), editable = logical()))
  }
  tibble::tibble(
    name = vapply(cols, function(c) as.character(c$name %||% NA_character_), character(1)),
    type = vapply(cols, function(c) as.character(c$type %||% NA_character_), character(1)),
    key = vapply(cols, function(c) as.character(c$key %||% NA_character_), character(1)),
    editable = !vapply(cols, function(c) isTRUE(c$type %in% c("formula", "auto-number", "creator", "last-modifier", "ctime", "mtime", "link-formula", "button")), logical(1))
  )
}

#' Add a column to a table
#' @inheritParams hb_list_columns
#' @param name Column name.
#' @param type SeaTable column type, e.g. `"text"`, `"number"`, `"date"`.
#' @param data Optional list of column options (e.g. select options).
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_add_column(client, "Samples", "Notes", "text")
#' @export
hb_add_column <- function(client, table, name, type, data = NULL,
                          call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(name, call = call)
  .check_string(type, call = call)
  body <- list(table_name = table, column_name = name, column_type = type)
  if (!is.null(data)) body$column_data <- data
  .hb_request(client, "/dtable-server/api/v1/dtables/columns/",
              service = "dtable_server", auth = "base", method = "POST",
              body = body)
  client$.metadata <- NULL
  invisible(client)
}

#' Add several columns at once
#' @inheritParams hb_add_column
#' @param columns A list of column specs (each a named list).
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_add_columns(client, "Samples",
#'   list(list(column_name = "a", column_type = "text"),
#'        list(column_name = "b", column_type = "number")))
#' @export
hb_add_columns <- function(client, table, columns,
                           call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  if (!is.list(columns) || length(columns) == 0L) {
    cli::cli_abort("{.arg columns} must be a non-empty list of column specs.", call = call)
  }
  .hb_request(client, "/dtable-server/api/v1/dtables/batch-append-columns/",
              service = "dtable_server", auth = "base", method = "POST",
              body = list(table_name = table, columns = columns))
  client$.metadata <- NULL
  invisible(client)
}

#' Update a column
#' @inheritParams hb_add_column
#' @param new_name Optional new column name.
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_update_column(client, "Samples", "Notes", new_name = "Comments")
#' @export
hb_update_column <- function(client, table, name, new_name = NULL,
                             data = NULL, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(name, call = call)
  .check_string(new_name, allow_null = TRUE, call = call)
  body <- list(table_name = table, column = name)
  if (!is.null(new_name)) body$new_column_name <- new_name
  if (!is.null(data)) body$column_data <- data
  .hb_request(client, "/dtable-server/api/v1/dtables/columns/",
              service = "dtable_server", auth = "base", method = "PUT",
              body = body)
  client$.metadata <- NULL
  invisible(client)
}

#' Delete a column
#' @inheritParams hb_add_column
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_delete_column(client, "Samples", "Old")
#' @export
hb_delete_column <- function(client, table, name,
                             call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(name, call = call)
  .hb_request(client, "/dtable-server/api/v1/dtables/columns/",
              service = "dtable_server", auth = "base", method = "DELETE",
              body = list(table_name = table, column = name))
  client$.metadata <- NULL
  invisible(client)
}

#' Add a single-select option
#' @inheritParams hb_add_column
#' @param option Option name to add.
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_add_select_option(client, "Samples", "Status", "Done")
#' @export
hb_add_select_option <- function(client, table, name, option,
                                 call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(name, call = call)
  .check_string(option, call = call)
  .hb_request(client, "/dtable-server/api/v1/dtables/column-options/",
              service = "dtable_server", auth = "base", method = "POST",
              body = list(table_name = table, column = name,
                          options = list(list(name = option))))
  client$.metadata <- NULL
  invisible(client)
}

#' Update a single-select option
#' @inheritParams hb_add_select_option
#' @param new_option New option name.
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_update_select_option(client, "Samples", "Status", "Done", "Complete")
#' @export
hb_update_select_option <- function(client, table, name, option, new_option,
                                    call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(name, call = call)
  .check_string(option, call = call)
  .check_string(new_option, call = call)
  .hb_request(client, "/dtable-server/api/v1/dtables/column-options/",
              service = "dtable_server", auth = "base", method = "PUT",
              body = list(table_name = table, column = name,
                          option = option, new_option = new_option))
  client$.metadata <- NULL
  invisible(client)
}

#' Delete a single-select option
#' @inheritParams hb_add_select_option
#' @return Invisibly returns the client.
#' @family columns
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_delete_select_option(client, "Samples", "Status", "Old")
#' @export
hb_delete_select_option <- function(client, table, name, option,
                                    call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(name, call = call)
  .check_string(option, call = call)
  .hb_request(client, "/dtable-server/api/v1/dtables/column-options/",
              service = "dtable_server", auth = "base", method = "DELETE",
              body = list(table_name = table, column = name, option = option))
  client$.metadata <- NULL
  invisible(client)
}
