#' Create a table
#'
#' @inheritParams hb_metadata
#' @param table Name of the new table.
#' @param columns A list of column specifications: each element a named list
#'   with at least `name` and `type` (a SeaTable type string).
#'
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family tables
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_create_table(client, "NewTable", list(list(name = "Name", type = "text")))
#' @export
hb_create_table <- function(client, table, ..., columns = list()) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  if (!is.list(columns)) {
    hb_abort("{.arg columns} must be a list of column specs.",
      class = "harbour_error_bad_argument"
    )
  }
  .hb_request(client, .hb_base_path(client, "tables", ""),
    service = "gateway", auth = "base", method = "POST",
    body = list(table_name = table, columns = .hb_column_specs(columns))
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Rename a table
#' @inheritParams hb_metadata
#' @param table Current table name.
#' @param new_name New table name.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family tables
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_rename_table(client, "Old", "New")
#' @export
hb_rename_table <- function(client, table, new_name, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(new_name)
  .hb_request(client, .hb_base_path(client, "tables", ""),
    service = "gateway", auth = "base", method = "PUT",
    body = list(table_name = table, new_table_name = new_name)
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Delete a table
#' @inheritParams hb_metadata
#' @param table Name of the table to delete.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family tables
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_delete_table(client, "DropMe")
#' @export
hb_delete_table <- function(client, table, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .hb_request(client, .hb_base_path(client, "tables", ""),
    service = "gateway", auth = "base", method = "DELETE",
    body = list(table_name = table)
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Duplicate a table
#' @inheritParams hb_metadata
#' @param table Source table name.
#' @param duplicate_records Copy the rows as well as the structure.
#'   Default `TRUE`.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @section Naming:
#' SeaTable names the copy after the original with `(copy)` appended, and
#' offers no way to set the name in the same request. Follow with
#' [hb_rename_table()] if you need a particular name.
#' @family tables
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_duplicate_table(client, "Samples")
#' hb_rename_table(client, "Samples (copy)", "Samples_backup")
#' @export
hb_duplicate_table <- function(client, table, ..., duplicate_records = TRUE) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_flag(duplicate_records)
  .hb_request(client, .hb_base_path(client, "tables", "duplicate-table", ""),
    service = "gateway", auth = "base", method = "POST",
    body = list(
      table_name = table,
      is_duplicate_records = duplicate_records
    )
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Normalise user-facing column specs to the wire spelling
#'
#' harbouR exposes `name` and `type`, matching [hb_add_column()]'s
#' arguments; SeaTable's create-table model wants `column_name` and
#' `column_type`. Accept either, so following the documented example
#' produces a body the server understands.
#'
#' @param columns A list of column specifications.
#' @param call The frame to blame for any error.
#' @return A list of specs keyed as SeaTable expects.
#' @keywords internal
#' @noRd
.hb_column_specs <- function(columns, call = rlang::caller_env()) {
  lapply(seq_along(columns), function(i) {
    spec <- columns[[i]]
    if (!is.list(spec)) {
      hb_abort(
        c("Each column spec must be a named list.",
          "x" = "Element {i} is {.cls {class(spec)}}."),
        class = "harbour_error_bad_argument", call = call
      )
    }
    name <- spec$column_name %||% spec$name
    type <- spec$column_type %||% spec$type
    if (is.null(name) || is.null(type)) {
      hb_abort(
        c("Each column spec needs a name and a type.",
          "x" = "Element {i} has {.field {names(spec)}}.",
          "i" = "For example {.code list(name = \"Notes\", type = \"text\")}."),
        class = "harbour_error_bad_argument", call = call
      )
    }
    out <- list(column_name = as.character(name),
                column_type = as.character(type))
    data <- spec$column_data %||% spec$data
    if (!is.null(data)) out$column_data <- data
    out
  })
}
