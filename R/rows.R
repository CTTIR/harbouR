#' Read a table as a tibble
#'
#' Reads all rows from `table` (optionally filtered by `view`) and returns
#' them as a typed tibble. Pagination is handled internally; the returned
#' tibble always has the table's columns in declared order plus an `_id`
#' column.
#'
#' @inheritParams hb_metadata
#' @param table Name of the table.
#' @param view Optional view name.
#' @param limit Page size for paginated fetches. Default `1000`.
#'
#' @return A tibble with one row per SeaTable row and one column per
#'   SeaTable column, plus `_id` (chr). A 0-row tibble is returned for an
#'   empty table.
#'
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_read_table(client, "Samples")
#' @export
hb_read_table <- function(client, table, view = NULL, limit = 1000L,
                          call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(view, allow_null = TRUE, call = call)
  if (!is.numeric(limit) || length(limit) != 1L || is.na(limit) || limit <= 0L) {
    cli::cli_abort("{.arg limit} must be a positive integer.", call = call)
  }

  if (is.null(client$.metadata)) hb_metadata(client, call = call)
  cols <- .hb_columns_from_metadata(client$.metadata, table)

  start <- 0L
  rows <- list()
  repeat {
    q <- list(table_name = table, start = start, limit = as.integer(limit))
    if (!is.null(view)) q$view_name <- view
    body <- .hb_request(client, "/dtable-server/api/v1/dtables/rows/",
                        service = "dtable_server", auth = "base",
                        method = "GET", query = q)
    chunk <- body$rows %||% list()
    rows <- c(rows, chunk)
    if (length(chunk) < limit) break
    start <- start + length(chunk)
  }
  .hb_rows_to_tibble(rows, cols)
}

#' Run a SeaTable SQL query
#'
#' @inheritParams hb_metadata
#' @param sql SeaTable SQL query string.
#'
#' @return A tibble. Always a tibble, even when the query returns no rows.
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_query(client, "select * from Samples limit 5")
#' @export
hb_query <- function(client, sql, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(sql, call = call)
  body <- .hb_request(client, "/dtable-db/api/v1/query/",
                      service = "dtable_db", auth = "base",
                      method = "POST",
                      body = list(sql = sql, convert_keys = TRUE))
  rows <- body$results %||% body$rows %||% list()
  if (length(rows) == 0L) {
    return(tibble::tibble())
  }
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  out <- lapply(cols, function(cn) {
    vals <- lapply(rows, function(r) r[[cn]])
    if (any(vapply(vals, function(v) is.list(v) || length(v) > 1L, logical(1)))) {
      vals
    } else {
      v <- unlist(lapply(vals, function(x) if (is.null(x)) NA else x), use.names = FALSE)
      v
    }
  })
  names(out) <- cols
  tibble::as_tibble(out)
}

#' Get a single row by ID
#'
#' @inheritParams hb_read_table
#' @param row_id The SeaTable row identifier.
#'
#' @return A 1-row tibble, or a 0-row tibble if the row is not found.
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_get_row(client, "Samples", "abc123")
#' @export
hb_get_row <- function(client, table, row_id, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(row_id, call = call)
  if (is.null(client$.metadata)) hb_metadata(client, call = call)
  cols <- .hb_columns_from_metadata(client$.metadata, table)
  body <- .hb_request(client,
    paste0("/dtable-server/api/v1/dtables/rows/", row_id, "/"),
    service = "dtable_server", auth = "base", method = "GET",
    query = list(table_name = table)
  )
  if (is.null(body) || length(body) == 0L) {
    return(.hb_rows_to_tibble(list(), cols))
  }
  .hb_rows_to_tibble(list(body), cols)
}

#' Append rows to a table
#'
#' @inheritParams hb_read_table
#' @param data A tibble or data frame whose columns match the table schema.
#'
#' @return A tibble of the appended rows (with server-generated `_id`s).
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_append_rows(client, "Samples", tibble::tibble(Name = "S1"))
#' @export
hb_append_rows <- function(client, table, data, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame or tibble.", call = call)
  }
  if (is.null(client$.metadata)) hb_metadata(client, call = call)
  cols <- .hb_columns_from_metadata(client$.metadata, table)
  rows <- .hb_tibble_to_rows(data, cols)
  body <- .hb_request(client, "/dtable-server/api/v1/dtables/batch-append-rows/",
                      service = "dtable_server", auth = "base",
                      method = "POST",
                      body = list(table_name = table, rows = rows))
  created <- body$rows %||% body$first_row %||% rows
  .hb_rows_to_tibble(created, cols)
}

#' Update rows in a table
#'
#' @inheritParams hb_append_rows
#' @param row_id_col Name of the column in `data` that holds row IDs.
#'   Default `"_id"`.
#'
#' @return Invisibly returns a summary tibble with columns
#'   `row_id` (chr) and `updated` (lgl).
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_update_rows(client, "Samples",
#'                tibble::tibble(`_id` = "abc", Name = "renamed"))
#' @export
hb_update_rows <- function(client, table, data, row_id_col = "_id",
                           call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(row_id_col, call = call)
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame or tibble.", call = call)
  }
  if (!row_id_col %in% names(data)) {
    cli::cli_abort(
      c("Column {.field {row_id_col}} not present in {.arg data}.",
        "i" = "Set {.arg row_id_col} to whichever column holds the row IDs."),
      call = call
    )
  }
  if (is.null(client$.metadata)) hb_metadata(client, call = call)
  cols <- .hb_columns_from_metadata(client$.metadata, table)
  updates <- vector("list", nrow(data))
  for (r in seq_len(nrow(data))) {
    row <- list()
    for (cn in names(data)) {
      if (cn == row_id_col) next
      v <- data[[cn]][[r]]
      if (is.list(v)) v <- unlist(v, use.names = FALSE)
      if (inherits(v, c("Date", "POSIXt"))) v <- format(v, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      row[[cn]] <- v
    }
    updates[[r]] <- list(row_id = as.character(data[[row_id_col]][[r]]), row = row)
  }
  .hb_request(client, "/dtable-server/api/v1/dtables/batch-update-rows/",
              service = "dtable_server", auth = "base", method = "PUT",
              body = list(table_name = table, updates = updates))
  invisible(tibble::tibble(
    row_id = vapply(updates, function(u) u$row_id, character(1)),
    updated = rep(TRUE, length(updates))
  ))
}

#' Delete rows
#'
#' @inheritParams hb_read_table
#' @param row_ids A character vector of row IDs to delete.
#'
#' @return Invisibly returns a tibble with `row_id` and `deleted` columns.
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_delete_rows(client, "Samples", c("abc", "def"))
#' @export
hb_delete_rows <- function(client, table, row_ids, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  if (!is.character(row_ids) || length(row_ids) == 0L) {
    cli::cli_abort("{.arg row_ids} must be a non-empty character vector.", call = call)
  }
  .hb_request(client, "/dtable-server/api/v1/dtables/batch-delete-rows/",
              service = "dtable_server", auth = "base", method = "DELETE",
              body = list(table_name = table, row_ids = as.list(row_ids)))
  invisible(tibble::tibble(row_id = row_ids, deleted = rep(TRUE, length(row_ids))))
}

#' Lock rows
#'
#' @inheritParams hb_delete_rows
#' @return Invisibly returns the client.
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_lock_rows(client, "Samples", "abc")
#' @export
hb_lock_rows <- function(client, table, row_ids, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  if (!is.character(row_ids) || length(row_ids) == 0L) {
    cli::cli_abort("{.arg row_ids} must be a non-empty character vector.", call = call)
  }
  .hb_request(client, "/dtable-server/api/v1/dtables/lock-rows/",
              service = "dtable_server", auth = "base", method = "PUT",
              body = list(table_name = table, row_ids = as.list(row_ids)))
  invisible(client)
}

#' Unlock rows
#' @inheritParams hb_lock_rows
#' @return Invisibly returns the client.
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_unlock_rows(client, "Samples", "abc")
#' @export
hb_unlock_rows <- function(client, table, row_ids, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  if (!is.character(row_ids) || length(row_ids) == 0L) {
    cli::cli_abort("{.arg row_ids} must be a non-empty character vector.", call = call)
  }
  .hb_request(client, "/dtable-server/api/v1/dtables/unlock-rows/",
              service = "dtable_server", auth = "base", method = "PUT",
              body = list(table_name = table, row_ids = as.list(row_ids)))
  invisible(client)
}
