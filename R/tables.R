#' Create a table
#'
#' @inheritParams hb_metadata
#' @param table Name of the new table.
#' @param columns A list of column specifications: each element a named list
#'   with at least `name` and `type` (a SeaTable type string).
#'
#' @return Invisibly returns the client.
#' @family tables
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_create_table(client, "NewTable", list(list(name = "Name", type = "text")))
#' @export
hb_create_table <- function(client, table, columns = list(),
                            call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  if (!is.list(columns)) {
    cli::cli_abort("{.arg columns} must be a list of column specs.", call = call)
  }
  .hb_request(client, "/dtable-server/api/v1/dtables/tables/",
              service = "dtable_server", auth = "base", method = "POST",
              body = list(table_name = table, columns = columns))
  client$.metadata <- NULL
  invisible(client)
}

#' Rename a table
#' @inheritParams hb_metadata
#' @param table Current table name.
#' @param new_name New table name.
#' @return Invisibly returns the client.
#' @family tables
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_rename_table(client, "Old", "New")
#' @export
hb_rename_table <- function(client, table, new_name,
                            call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(new_name, call = call)
  .hb_request(client, "/dtable-server/api/v1/dtables/tables/",
              service = "dtable_server", auth = "base", method = "PUT",
              body = list(table_name = table, new_table_name = new_name))
  client$.metadata <- NULL
  invisible(client)
}

#' Delete a table
#' @inheritParams hb_metadata
#' @param table Name of the table to delete.
#' @return Invisibly returns the client.
#' @family tables
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_delete_table(client, "DropMe")
#' @export
hb_delete_table <- function(client, table, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .hb_request(client, "/dtable-server/api/v1/dtables/tables/",
              service = "dtable_server", auth = "base", method = "DELETE",
              body = list(table_name = table))
  client$.metadata <- NULL
  invisible(client)
}

#' Duplicate a table
#' @inheritParams hb_metadata
#' @param table Source table name.
#' @param new_name Optional new name. If `NULL` the server picks one.
#' @return Invisibly returns the client.
#' @family tables
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_duplicate_table(client, "Samples", "Samples_copy")
#' @export
hb_duplicate_table <- function(client, table, new_name = NULL,
                               call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(new_name, allow_null = TRUE, call = call)
  body <- list(table_name = table)
  if (!is.null(new_name)) body$new_table_name <- new_name
  .hb_request(client, "/dtable-server/api/v1/dtables/tables/duplicate/",
              service = "dtable_server", auth = "base", method = "POST",
              body = body)
  client$.metadata <- NULL
  invisible(client)
}
