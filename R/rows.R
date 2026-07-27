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
#' @param ... These dots are for future extensions and must be empty.
#' @return A tibble with one row per SeaTable row and one column per
#'   SeaTable column, plus `_id` (chr). A 0-row tibble is returned for an
#'   empty table.
#'
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_read_table(client, "Samples")
#' @export
hb_read_table <- function(client, table, ..., view = NULL, limit = 1000L) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(view, allow_null = TRUE)
  bad_limit <- !is.numeric(limit) || length(limit) != 1L ||
    is.na(limit) || limit <= 0L
  if (bad_limit) {
    hb_abort("{.arg limit} must be a positive integer.",
      class = "harbour_error_bad_argument"
    )
  }

  if (is.null(client$.metadata)) hb_metadata(client)
  cols <- .hb_columns_from_metadata(client$.metadata, table)

  start <- 0L
  rows <- list()
  repeat {
    q <- list(table_name = table, start = start, limit = as.integer(limit))
    if (!is.null(view)) q$view_name <- view
    body <- .hb_request(client, .hb_base_path(client, "rows", ""),
      service = "gateway", auth = "base",
      method = "GET", query = q
    )
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
#' @param ... These dots are for future extensions and must be empty.
#' @return A tibble. Always a tibble, even when the query returns no rows.
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_query(client, "select * from Samples limit 5")
#' @export
hb_query <- function(client, sql, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(sql)
  body <- .hb_request(client, .hb_base_path(client, "sql", ""),
    service = "gateway", auth = "base",
    method = "POST",
    body = list(sql = sql, convert_keys = TRUE)
  )
  rows <- body$results %||% body$rows %||% list()
  if (length(rows) == 0L) {
    return(tibble::tibble())
  }
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  out <- lapply(cols, function(cn) {
    vals <- lapply(rows, function(r) r[[cn]])
    ragged <- vapply(
      vals,
      function(value) is.list(value) || length(value) > 1L,
      logical(1)
    )
    if (any(ragged)) {
      vals
    } else {
      filled <- lapply(vals, function(value) value %||% NA)
      v <- unlist(filled, use.names = FALSE)
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
#' @param ... These dots are for future extensions and must be empty.
#' @return A one-row tibble with one column per SeaTable column, plus
#'   `_id` (chr). An unknown `row_id` is an error - a
#'   `harbour_error_not_found` condition - not an empty result, because
#'   asking for a specific row that does not exist is a mistake worth
#'   surfacing.
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_get_row(client, "Samples", "abc123")
#' @export
hb_get_row <- function(client, table, row_id, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(row_id)
  if (is.null(client$.metadata)) hb_metadata(client)
  cols <- .hb_columns_from_metadata(client$.metadata, table)
  body <- .hb_request(client, .hb_base_path(client, "rows", row_id, ""),
    service = "gateway", auth = "base", method = "GET",
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
#' @param ... These dots are for future extensions and must be empty.
#' @return A tibble of the appended rows (with server-generated `_id`s).
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_append_rows(client, "Samples", tibble::tibble(Name = "S1"))
#' @export
hb_append_rows <- function(client, table, data, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  if (!is.data.frame(data)) {
    hb_abort("{.arg data} must be a data frame or tibble.",
      class = "harbour_error_bad_argument"
    )
  }
  if (is.null(client$.metadata)) hb_metadata(client)
  cols <- .hb_columns_from_metadata(client$.metadata, table)
  rows <- .hb_tibble_to_rows(data, cols)
  body <- .hb_request(
    client, .hb_base_path(client, "rows", ""),
    service = "gateway", auth = "base",
    method = "POST",
    body = list(table_name = table, rows = rows)
  )
  created <- body$rows %||% body$first_row %||% rows
  .hb_rows_to_tibble(created, cols)
}

#' Update rows in a table
#'
#' @inheritParams hb_append_rows
#' @param row_id_col Name of the column in `data` that holds row IDs.
#'   Default `"_id"`.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns a summary tibble with columns
#'   `row_id` (chr) and `updated` (lgl).
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_update_rows(
#'   client, "Samples",
#'   tibble::tibble(`_id` = "abc", Name = "renamed")
#' )
#' @export
hb_update_rows <- function(client, table, data, ..., row_id_col = "_id") {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(row_id_col)
  if (!is.data.frame(data)) {
    hb_abort("{.arg data} must be a data frame or tibble.",
      class = "harbour_error_bad_argument"
    )
  }
  if (!row_id_col %in% names(data)) {
    hb_abort(
      c("Column {.field {row_id_col}} not present in {.arg data}.",
        "i" = "Set {.arg row_id_col} to whichever column holds the row IDs."
      ),
      class = "harbour_error_bad_argument"
    )
  }
  if (is.null(client$.metadata)) hb_metadata(client)
  cols <- .hb_columns_from_metadata(client$.metadata, table)
  updates <- vector("list", nrow(data))
  for (r in seq_len(nrow(data))) {
    row <- list()
    for (cn in names(data)) {
      if (cn == row_id_col) next
      v <- data[[cn]][[r]]
      if (is.list(v)) v <- unlist(v, use.names = FALSE)
      if (inherits(v, c("Date", "POSIXt"))) {
        v <- format(v, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      }
      row[[cn]] <- v
    }
    updates[[r]] <- list(
      row_id = as.character(data[[row_id_col]][[r]]),
      row = row
    )
  }
  .hb_request(client, .hb_base_path(client, "rows", ""),
    service = "gateway", auth = "base", method = "PUT",
    body = list(table_name = table, updates = updates)
  )
  invisible(tibble::tibble(
    row_id = vapply(updates, function(update) update$row_id, character(1)),
    updated = rep(TRUE, length(updates))
  ))
}

#' Delete rows
#'
#' @inheritParams hb_read_table
#' @param row_ids A character vector of row IDs to delete.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns a tibble with `row_id` and `deleted` columns.
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_delete_rows(client, "Samples", c("abc", "def"))
#' @export
hb_delete_rows <- function(client, table, row_ids, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  if (!is.character(row_ids) || length(row_ids) == 0L) {
    hb_abort("{.arg row_ids} must be a non-empty character vector.",
      class = "harbour_error_bad_argument"
    )
  }
  .hb_request(client, .hb_base_path(client, "rows", ""),
    service = "gateway", auth = "base", method = "DELETE",
    body = list(table_name = table, row_ids = as.list(row_ids))
  )
  invisible(tibble::tibble(
    row_id = row_ids,
    deleted = rep(TRUE, length(row_ids))
  ))
}

#' Lock rows
#'
#' @inheritParams hb_delete_rows
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_lock_rows(client, "Samples", "abc")
#' @export
hb_lock_rows <- function(client, table, row_ids, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  if (!is.character(row_ids) || length(row_ids) == 0L) {
    hb_abort("{.arg row_ids} must be a non-empty character vector.",
      class = "harbour_error_bad_argument"
    )
  }
  .hb_request(client, .hb_base_path(client, "lock-rows", ""),
    service = "gateway", auth = "base", method = "PUT",
    body = list(table_name = table, row_ids = as.list(row_ids))
  )
  invisible(client)
}

#' Unlock rows
#' @inheritParams hb_lock_rows
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_unlock_rows(client, "Samples", "abc")
#' @export
hb_unlock_rows <- function(client, table, row_ids, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  if (!is.character(row_ids) || length(row_ids) == 0L) {
    hb_abort("{.arg row_ids} must be a non-empty character vector.",
      class = "harbour_error_bad_argument"
    )
  }
  .hb_request(client, .hb_base_path(client, "unlock-rows", ""),
    service = "gateway", auth = "base", method = "PUT",
    body = list(table_name = table, row_ids = as.list(row_ids))
  )
  invisible(client)
}
