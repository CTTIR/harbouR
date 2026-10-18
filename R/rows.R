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
#' @param view Optional view name. A server returns only the columns a
#'   view shows, so a read through a view gives `NA` for the columns it
#'   hides, and harbouR warns naming them. A `.dtable` read keeps their
#'   values.
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
  n_read <- 0L
  # Pages are combined once at the end: growing one list a page at a time
  # copies it on every request.
  pages <- list()
  previous <- NULL
  # A server that keeps returning full pages must produce an error, not an
  # infinite loop. One request past the cap tells a table that ends exactly
  # there from a server that does not stop.
  max_pages <- .hb_max_pages(page_size)
  for (page in seq_len(max_pages + 1L)) {
    want <- min(page_size, n_max - n_read)
    if (want <= 0L) break
    # convert_keys defaults to false, which keys every cell by the column's
    # four-character key; the coercion layer looks cells up by name.
    q <- list(
      table_name = table, start = start, limit = as.integer(want),
      convert_keys = "true"
    )
    if (!is.null(view)) q$view_name <- view
    body <- .hb_request(x, .hb_base_path(x, "rows", ""),
      service = "gateway", auth = "base",
      method = "GET", query = q
    )
    chunk <- body$rows %||% list()
    if (page > max_pages && length(chunk) > 0L) {
      hb_abort(
        c("Gave up after {max_pages} pages ({n_read} rows).",
          "i" = "A read stops there in case the server never stops paging.",
          "i" = "Set {.arg n_max} to bound the read."),
        class = "harbour_error_http"
      )
    }
    # A cursor that does not advance hands back the same page for ever.
    # Stop at the first repeat rather than collect duplicates up to the cap,
    # or return them as rows when n_max ends the read first.
    # A last page that n_max shortens repeats only the start of the one
    # before it, so the new page is compared with that start.
    ids <- .hb_chr_field(chunk, "_id")
    repeated <- length(previous) >= length(ids) &&
      identical(ids, previous[seq_along(ids)])
    if (length(chunk) == want && !anyNA(ids) && repeated) {
      hb_abort(
        c("The server returned the same {length(ids)} rows for two pages
           in a row.",
          "x" = "Paging is not advancing, so the read was stopped."),
        class = "harbour_error_http"
      )
    }
    previous <- ids
    pages[[page]] <- chunk
    n_read <- n_read + length(chunk)
    if (length(chunk) < want) break
    start <- start + length(chunk)
  }
  rows <- do.call(c, c(list(list()), pages))
  if (length(rows) > n_max) rows <- rows[seq_len(n_max)]
  if (!is.null(view)) {
    .hb_warn_hidden_columns(x$.metadata, table, view, cols, rows)
  }
  .hb_rows_to_tibble(rows, cols)
}

#' How many pages a read may take before harbouR gives up
#'
#' The cap is set in rows - about ten million, far past any real base -
#' so that a small `page_size` does not cut a large table short. It only
#' has to stop a server that keeps returning new rows.
#'
#' @param page_size The page size in use.
#' @return A single integer.
#' @keywords internal
#' @noRd
.hb_max_pages <- function(page_size) {
  as.integer(max(1000, ceiling(1e7 / page_size)))
}

#' Warn about the columns a view leaves out of its rows
#'
#' SeaTable returns only a view's visible columns, but the tibble keeps the
#' table's full schema, so a hidden column reads as all `NA` - which looks
#' exactly like a column with no data in it. The view's hidden columns are
#' listed, by key, in the cached metadata. A view the cache does not know
#' is passed over: the read itself has succeeded.
#'
#' @param metadata The client's cached `harbour_metadata`.
#' @param table The table's name.
#' @param view The view's name.
#' @param columns The table's column objects.
#' @param rows The rows the server returned.
#' @param call The frame to report the warning from.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_warn_hidden_columns <- function(metadata, table, view, columns, rows,
                                    call = rlang::caller_env()) {
  if (length(rows) == 0L) {
    return(invisible(NULL))
  }
  tbls <- metadata$tables %||% list()
  views <- tbls[[match(table, .hb_chr_field(tbls, "name"))]]$views %||%
    list()
  idx <- match(view, .hb_chr_field(views, "name"))
  if (is.na(idx)) {
    return(invisible(NULL))
  }
  keys <- as.character(
    unlist(views[[idx]]$hidden_columns %||% list(), use.names = FALSE)
  )
  hidden <- .hb_chr_field(columns, "name")[
    .hb_chr_field(columns, "key") %in% keys
  ]
  # Only the columns that really did come back empty: a server that sends
  # a hidden column's values has nothing to warn about.
  empty <- vapply(
    hidden,
    function(name) {
      !any(vapply(rows, function(row) !is.null(row[[name]]), logical(1)))
    },
    logical(1)
  )
  hidden <- hidden[empty]
  if (length(hidden) > 0L) {
    cli::cli_warn(
      c("View {.val {view}} hides {length(hidden)} column{?s}, so
         {?it is/they are} {.code NA} in the result: {.field {hidden}}.",
        "i" = "SeaTable leaves a view's hidden columns out of its rows. Show
               them in the view, or read without {.arg view}, to get their
               values."),
      class = "harbour_warning_hidden_columns",
      call = call
    )
  }
  invisible(NULL)
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
#'   harbouR warns if there is no `LIMIT` clause - the word inside a quoted
#'   string or a back-ticked name does not count - at most once every
#'   eight hours for the same query, so a loop does not repeat it.
#' @param parameters Optional list of values for `?` placeholders in `sql`,
#'   in order. Names are ignored.
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
  if (.hb_sql_lacks_limit(sql)) {
    # SeaTable applies an implicit LIMIT 100. A query that looks like it
    # wants everything but silently gets a hundred rows is a wrong answer.
    # The rate limit is per query: a loop does not repeat the warning, but
    # one query does not silence the next. The query is hashed because
    # rlang stores the id as a variable name, which R caps at 10000 bytes.
    cli::cli_warn(
      c("This query has no {.code LIMIT} clause.",
        "i" = "SeaTable applies an implicit {.code LIMIT 100}.",
        "i" = "Add one explicitly, up to the 10000-row ceiling."),
      class = "harbour_warning_query_limit",
      .frequency = "regularly",
      .frequency_id = paste0("harbour_query_limit:", rlang::hash(sql))
    )
  }
  body <- list(sql = sql, convert_keys = convert_keys)
  # Placeholders are filled by position, and named values would be written
  # as a JSON object rather than the array the server reads.
  if (!is.null(parameters)) body$parameters <- as.list(unname(parameters))
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
  # The row identifier is appended from the rows themselves, so a schema
  # entry for it would only collide with that.
  columns <- Filter(function(col) !identical(col$name, "_id"), columns)
  by <- "name"
  if (!convert_keys) {
    # The cells are keyed by column key, so the columns must be too.
    columns <- lapply(columns, function(col) {
      col$name <- col$key %||% col$name
      col
    })
  } else if (.hb_cells_keyed_by_key(rows, columns, resp$is_join_stmt)) {
    # Reading by key keeps the reported names as the column names. A
    # column with no key is looked up by its name.
    columns <- lapply(columns, function(col) {
      col$key <- col$key %||% col$name
      col
    })
    by <- "key"
  }
  if (length(columns) > 0L) {
    return(.hb_rows_to_tibble(rows, columns, by = by))
  }
  if (length(rows) == 0L) {
    return(tibble::tibble())
  }
  .hb_untyped_rows_to_tibble(rows)
}

#' Does a query lack a LIMIT clause?
#'
#' Quoted strings and back-ticked names are blanked out first, so a column
#' called `Upper limit` or a value such as `'no limit'` is not taken for
#' the clause. A quote inside a string is written twice, as in SQL.
#'
#' @param sql A single SQL string.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_sql_lacks_limit <- function(sql) {
  # Byte by byte: everything the patterns look for is ASCII, and a string
  # that is not valid in its encoding must not make the check fail.
  bare <- gsub(
    "'(?:[^']|'')*'|\"(?:[^\"]|\"\")*\"|`[^`]*`", " ", sql,
    perl = TRUE, useBytes = TRUE
  )
  !grepl(
    "\\blimit\\b", bare,
    ignore.case = TRUE, perl = TRUE, useBytes = TRUE
  )
}

#' Are a query's result cells keyed by column key?
#'
#' SeaTable ignores `convert_keys` for a join - the only kind it supports,
#' `FROM a, b WHERE ...` - and keys every cell by the column's key, with
#' the names only in the metadata. It flags such a reply with
#' `is_join_stmt`. A join whose cells do carry the names, as they would
#' from a server that applied `convert_keys`, is still read by name. A
#' reply without the flag is read by key only when its cells carry none of
#' the reported names and some of the keys, so an ordinary result is never
#' affected.
#'
#' @param rows The result rows.
#' @param columns The result schema.
#' @param is_join The reply's `is_join_stmt` field.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_cells_keyed_by_key <- function(rows, columns, is_join) {
  fields <- unique(unlist(lapply(rows, names), use.names = FALSE))
  by_name <- any(.hb_chr_field(columns, "name") %in% fields)
  by_key <- any(.hb_chr_field(columns, "key") %in% fields)
  if (isTRUE(is_join)) by_key || !by_name else by_key && !by_name
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
    query = list(table_name = table, convert_keys = "true")
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
#'   `n_requests` (int). The server's reply also lists the new rows'
#'   `_id`s; harbouR's summary does not include them.
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
  # A misspelt column is dropped from every row. That has always been the
  # behaviour, and scripts may rely on it, so it is reported rather than
  # refused. `_id` and the other system fields pass without comment, so a
  # table read with hb_read_table() can be appended as it is.
  .hb_check_known_columns(
    setdiff(names(data), .hb_dtable_row_system_fields), cols, table,
    action = "warn"
  )
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

#' Report data columns the table does not have
#'
#' @param names Column names from the data being written, already stripped
#'   of the ones the caller allows through.
#' @param columns The table's column objects.
#' @param table The table's name, for the message.
#' @param action `"abort"` to refuse the write, `"warn"` to report that the
#'   columns will not be written.
#' @param call The frame to blame for any error.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_check_known_columns <- function(names, columns, table,
                                    action = c("abort", "warn"),
                                    call = rlang::caller_env()) {
  action <- rlang::arg_match(action)
  known <- .hb_chr_field(columns, "name")
  unknown <- setdiff(names, known)
  if (length(unknown) == 0L) {
    return(invisible(NULL))
  }
  details <- c(
    "x" = "{.field {unknown}}",
    "i" = "Known columns: {.field {known}}."
  )
  if (identical(action, "warn")) {
    cli::cli_warn(
      c("{length(unknown)} column{?s} in {.arg data} {?is/are} not in
         {.val {table}} and will not be written.", details),
      class = "harbour_warning_unknown_column",
      call = call
    )
  } else {
    hb_abort(
      c("{length(unknown)} column{?s} in {.arg data} {?is/are} not in
         {.val {table}}.", details),
      class = "harbour_error_not_found",
      call = call
    )
  }
  invisible(NULL)
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
  ids <- as.character(data[[row_id_col]])
  n_missing <- sum(is.na(ids) | !nzchar(ids))
  if (n_missing > 0L) {
    hb_abort(
      c("Every row needs an id to be updated.",
        "x" = "{.field {row_id_col}} is missing in {n_missing} row{?s}."),
      class = "harbour_error_bad_argument"
    )
  }
  chunk_size <- .hb_check_chunk_size(chunk_size)
  if (is.null(client$.metadata)) hb_metadata(client)
  cols <- .hb_columns_from_metadata(client$.metadata, table)
  types <- .hb_chr_field(cols, "type", default = "text")
  names(types) <- .hb_chr_field(cols, "name")
  writable <- names(types)[!types %in% .hb_readonly_types()]
  .hb_check_known_columns(
    setdiff(names(data), c(row_id_col, .hb_dtable_row_system_fields)),
    cols, table
  )
  # Server-computed columns are dropped, matching hb_append_rows(), and the
  # cells go through the same serialiser: a file or geolocation cell keeps
  # its structure, a difftime column its units, a date-only column its
  # calendar date, and a cell that cannot be sent as it is is reported once
  # for the whole write.
  write <- setdiff(intersect(names(data), writable), row_id_col)
  cells <- .hb_serialise_rows(
    data, types[write],
    date_only = .hb_date_only_columns(cols)
  )
  updates <- lapply(seq_len(nrow(data)), function(r) {
    list(row_id = ids[[r]], row = cells[[r]])
  })
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
  .hb_check_row_ids(row_ids)
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

#' Validate a vector of row ids
#'
#' @param row_ids The ids to check.
#' @param call The frame to blame for any error.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_check_row_ids <- function(row_ids, call = rlang::caller_env()) {
  ok <- is.character(row_ids) && length(row_ids) > 0L &&
    !anyNA(row_ids) && all(nzchar(row_ids))
  if (!ok) {
    hb_abort(
      "{.arg row_ids} must be a non-empty character vector with no
       missing or empty ids.",
      class = "harbour_error_bad_argument", call = call
    )
  }
  invisible(NULL)
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
  .hb_check_row_ids(row_ids)
  # Unnamed, as hb_delete_rows() sends them: named ids would be written as
  # a JSON object rather than an array.
  .hb_request(client, .hb_base_path(client, "lock-rows", ""),
    service = "gateway", auth = "base", method = "PUT",
    body = list(table_name = table, row_ids = as.list(unname(row_ids)))
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
  .hb_check_row_ids(row_ids)
  .hb_request(client, .hb_base_path(client, "unlock-rows", ""),
    service = "gateway", auth = "base", method = "PUT",
    body = list(table_name = table, row_ids = as.list(unname(row_ids)))
  )
  invisible(client)
}
