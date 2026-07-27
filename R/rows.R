#' Read a table as a tibble
#'
#' Reads all rows from `table` (optionally filtered by `view`) and returns
#' them as a typed tibble. Pagination is handled internally; the returned
#' tibble always has the table's columns in declared order plus an `_id`
#' column.
#'
#' @param x A `harbour_client` connected to a base, or a
#'   `harbour_dtable` read from a local file.
#' @param table Name of the table.
#' @param view Optional view name.
#' @param page_size Rows fetched per request. SeaTable caps this at 1000
#'   and harbouR clamps it, warning if you asked for more.
#' @param n_max Maximum number of rows to return. `Inf`, the default,
#'   reads the whole table.
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
#'
#' # just the first 10 rows
#' hb_read_table(client, "Samples", n_max = 10)
#' @export
hb_read_table <- function(x, table, ...) {
  UseMethod("hb_read_table")
}

#' @rdname hb_read_table
#' @method hb_read_table harbour_client
#' @export
hb_read_table.harbour_client <- function(x,
                                         table,
                                         ...,
                                         view = NULL,
                                         page_size = 1000L,
                                         n_max = Inf) {
  rlang::check_dots_empty()
  .check_client(x, arg = "x")
  .check_string(table)
  .check_string(view, allow_null = TRUE)
  page_size <- .hb_check_page_size(page_size)
  .hb_check_n_max(n_max)

  if (is.null(x$.metadata)) hb_metadata(x)
  cols <- .hb_columns_from_metadata(x$.metadata, table)

  start <- 0L
  rows <- list()
  # A server that keeps returning full pages must produce an error, not an
  # infinite loop. 1000 pages is 1e6 rows - far past any real base.
  max_pages <- 1000L
  for (page in seq_len(max_pages)) {
    want <- min(page_size, n_max - length(rows))
    if (want <= 0L) break
    q <- list(table_name = table, start = start, limit = as.integer(want))
    if (!is.null(view)) q$view_name <- view
    body <- .hb_request(x, .hb_base_path(x, "rows", ""),
      service = "gateway", auth = "base",
      method = "GET", query = q
    )
    chunk <- body$rows %||% list()
    rows <- c(rows, chunk)
    if (length(chunk) < want) break
    start <- start + length(chunk)
    if (page == max_pages) {
      hb_abort(
        c("Gave up after {max_pages} pages ({length(rows)} rows).",
          "i" = "Set {.arg n_max} to bound the read."),
        class = "harbour_error_http"
      )
    }
  }
  if (length(rows) > n_max) rows <- rows[seq_len(n_max)]
  .hb_rows_to_tibble(rows, cols)
}

#' Validate and clamp a page size against SeaTable's server maximum
#'
#' @param page_size The requested page size.
#' @param call The frame to blame for any error.
#' @return An integer, at most 1000.
#' @keywords internal
#' @noRd
.hb_check_page_size <- function(page_size, call = rlang::caller_env()) {
  ok <- is.numeric(page_size) && length(page_size) == 1L &&
    !is.na(page_size) && page_size >= 1
  if (!ok) {
    hb_abort("{.arg page_size} must be a positive integer.",
      class = "harbour_error_bad_argument", call = call
    )
  }
  # cli >= 3.4.0 reads a `{}` expression beginning with a dot as a style
  # name, so the constant has to be a plain local.
  cap <- .hb_max_page_size
  if (page_size > cap) {
    cli::cli_warn(c(
      "{.arg page_size} is capped at {.val {cap}} by SeaTable.",
      "i" = "Reading in pages of {.val {cap}} instead."
    ), call = call)
    return(cap)
  }
  as.integer(page_size)
}

#' Validate a row cap
#'
#' @param n_max The requested maximum.
#' @param call The frame to blame for any error.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_check_n_max <- function(n_max, call = rlang::caller_env()) {
  ok <- is.numeric(n_max) && length(n_max) == 1L &&
    !is.na(n_max) && n_max >= 1
  if (!ok) {
    hb_abort("{.arg n_max} must be a positive number or {.code Inf}.",
      class = "harbour_error_bad_argument", call = call
    )
  }
  invisible(NULL)
}

#' Run a SeaTable SQL query
#'
#' @inheritParams hb_metadata
#' @param sql SeaTable SQL query string. SeaTable applies an implicit
#'   `LIMIT 100` when the query has none, and caps results at 10000 rows.
#'   harbouR warns if there is no `LIMIT` clause.
#' @param parameters Optional list of values for `?` placeholders in `sql`.
#' @param convert_keys Return column names rather than column keys.
#'   Default `TRUE`.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @return A tibble, typed from the result schema SeaTable reports
#'   alongside the rows, so the same table read via [hb_read_table()] and
#'   via `hb_query()` yields the same column types. Always a tibble, even
#'   when the query returns no rows.
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_query(client, "select * from Samples limit 5")
#' @export
hb_query <- function(client, sql, ..., parameters = NULL,
                     convert_keys = TRUE) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(sql)
  .check_flag(convert_keys)
  if (!grepl("\\blimit\\b", sql, ignore.case = TRUE)) {
    # SeaTable applies an implicit LIMIT 100. A query that looks like it
    # wants everything but silently gets a hundred rows is a wrong answer.
    cli::cli_warn(
      c("This query has no {.code LIMIT} clause.",
        "i" = "SeaTable applies an implicit {.code LIMIT 100}.",
        "i" = "Add one explicitly, up to the 10000-row ceiling."),
      .frequency = "regularly",
      .frequency_id = "harbour_query_limit"
    )
  }
  body <- list(sql = sql, convert_keys = convert_keys)
  if (!is.null(parameters)) body$parameters <- as.list(parameters)
  resp <- .hb_request(client, .hb_base_path(client, "sql", ""),
    service = "gateway", auth = "base",
    method = "POST", body = body
  )
  rows <- resp$results %||% resp$rows %||% list()
  # SeaTable reports the result schema alongside the rows. Using it is what
  # makes hb_query() and hb_read_table() agree on types: inferring from the
  # values instead means an all-NULL column comes back logical, and one
  # stray string turns a numeric column into character.
  columns <- resp$metadata %||% resp$columns %||% list()
  if (length(columns) > 0L) {
    return(.hb_rows_to_tibble(rows, columns))
  }
  if (length(rows) == 0L) {
    return(tibble::tibble())
  }
  .hb_untyped_rows_to_tibble(rows)
}

#' Build a tibble from rows whose schema the server did not report
#'
#' A fallback only. Types are inferred from the values, which is exactly
#' the guessing [hb_query()] avoids when metadata is available.
#'
#' @param rows A list of row objects.
#' @return A tibble.
#' @keywords internal
#' @noRd
.hb_untyped_rows_to_tibble <- function(rows) {
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  out <- lapply(cols, function(cn) {
    vals <- lapply(rows, function(row) row[[cn]])
    ragged <- vapply(
      vals,
      function(value) is.list(value) || length(value) > 1L,
      logical(1)
    )
    if (any(ragged)) {
      return(vals)
    }
    unlist(lapply(vals, function(value) value %||% NA), use.names = FALSE)
  })
  names(out) <- cols
  tibble::as_tibble(out, .name_repair = "minimal")
}

#' Get a single row by ID
#'
#' @inheritParams hb_metadata
#' @param table Table name.
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
#' @inheritParams hb_metadata
#' @param table Table name.
#' @param data A tibble or data frame whose columns match the table schema.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @param chunk_size Rows per request. SeaTable caps batch writes at
#'   1000 and harbouR clamps it, warning if you asked for more.
#' @return Invisibly, a one-row tibble with columns `table` (chr),
#'   `n_rows` (int) - the count the server confirmed - and
#'   `n_requests` (int). SeaTable does not return the created rows, so
#'   neither does harbouR; read the table back if you need their `_id`s.
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_append_rows(client, "Samples", tibble::tibble(Name = "S1"))
#' @export
hb_append_rows <- function(client, table, data, ...,
                           chunk_size = 1000L) {
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
  chunk_size <- .hb_check_chunk_size(chunk_size)
  rows <- .hb_tibble_to_rows(data, cols)
  chunks <- .hb_chunk(rows, chunk_size)
  inserted <- 0L
  for (i in seq_along(chunks)) {
    body <- .hb_request(
      client, .hb_base_path(client, "rows", ""),
      service = "gateway", auth = "base",
      method = "POST",
      body = list(table_name = table, rows = unname(chunks[[i]]))
    )
    # Report what the server confirmed. The previous implementation fell
    # back to the request payload, which has no server-assigned _id, and
    # then claimed in @return that it did.
    inserted <- inserted + as.integer(
      body$inserted_row_count %||% length(chunks[[i]])
    )
  }
  invisible(tibble::tibble(
    table = table,
    n_rows = inserted,
    n_requests = length(chunks)
  ))
}

#' Validate a write chunk size against SeaTable's server maximum
#'
#' @param chunk_size The requested chunk size.
#' @param call The frame to blame for any error.
#' @return An integer, at most 1000.
#' @keywords internal
#' @noRd
.hb_check_chunk_size <- function(chunk_size, call = rlang::caller_env()) {
  ok <- is.numeric(chunk_size) && length(chunk_size) == 1L &&
    !is.na(chunk_size) && chunk_size >= 1
  if (!ok) {
    hb_abort("{.arg chunk_size} must be a positive integer.",
      class = "harbour_error_bad_argument", call = call
    )
  }
  cap <- .hb_max_batch_size
  if (chunk_size > cap) {
    cli::cli_warn(c(
      "{.arg chunk_size} is capped at {.val {cap}} by SeaTable.",
      "i" = "Writing in batches of {.val {cap}} instead."
    ), call = call)
    return(cap)
  }
  as.integer(chunk_size)
}

#' Update rows in a table
#'
#' @inheritParams hb_append_rows
#' @param row_id_col Name of the column in `data` that holds row IDs.
#'   Default `"_id"`.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @param chunk_size Rows per request. SeaTable caps batch writes at
#'   1000 and harbouR clamps it, warning if you asked for more.
#' @return Invisibly, a one-row tibble with columns `table` (chr),
#'   `n_rows` (int) and `n_requests` (int).
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_update_rows(
#'   client, "Samples",
#'   tibble::tibble(`_id` = "abc", Name = "renamed")
#' )
#' @export
hb_update_rows <- function(client, table, data, ..., row_id_col = "_id",
                           chunk_size = 1000L) {
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
  chunk_size <- .hb_check_chunk_size(chunk_size)
  if (is.null(client$.metadata)) hb_metadata(client)
  cols <- .hb_columns_from_metadata(client$.metadata, table)
  types <- .hb_chr_field(cols, "type", default = "text")
  names(types) <- .hb_chr_field(cols, "name")
  updates <- vector("list", nrow(data))
  for (r in seq_len(nrow(data))) {
    row <- list()
    for (cn in names(data)) {
      if (cn == row_id_col) next
      # Same type-aware serialisation the append path uses, so a file or
      # geolocation cell is not flattened into a bare character vector.
      row[[cn]] <- .hb_serialise_cell(
        data[[cn]][[r]],
        types[[cn]] %||% "text"
      )
    }
    updates[[r]] <- list(
      row_id = as.character(data[[row_id_col]][[r]]),
      row = row
    )
  }
  chunks <- .hb_chunk(updates, chunk_size)
  for (i in seq_along(chunks)) {
    .hb_request(client, .hb_base_path(client, "rows", ""),
      service = "gateway", auth = "base", method = "PUT",
      body = list(table_name = table, updates = unname(chunks[[i]]))
    )
  }
  invisible(tibble::tibble(
    table = table,
    n_rows = length(updates),
    n_requests = length(chunks)
  ))
}

#' Delete rows
#'
#' @inheritParams hb_metadata
#' @param table Table name.
#' @param row_ids A character vector of row IDs to delete.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @param chunk_size Rows per request. SeaTable caps batch writes at
#'   1000 and harbouR clamps it, warning if you asked for more.
#' @return Invisibly, a one-row tibble with columns `table` (chr),
#'   `n_rows` (int) and `n_requests` (int).
#' @family rows
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_delete_rows(client, "Samples", c("abc", "def"))
#' @export
hb_delete_rows <- function(client, table, row_ids, ...,
                           chunk_size = 1000L) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  if (!is.character(row_ids) || length(row_ids) == 0L) {
    hb_abort("{.arg row_ids} must be a non-empty character vector.",
      class = "harbour_error_bad_argument"
    )
  }
  chunk_size <- .hb_check_chunk_size(chunk_size)
  chunks <- .hb_chunk(row_ids, chunk_size)
  for (i in seq_along(chunks)) {
    .hb_request(client, .hb_base_path(client, "rows", ""),
      service = "gateway", auth = "base", method = "DELETE",
      body = list(table_name = table, row_ids = as.list(unname(chunks[[i]])))
    )
  }
  invisible(tibble::tibble(
    table = table,
    n_rows = length(row_ids),
    n_requests = length(chunks)
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
