#' List columns of a table
#'
#' @param x A `harbour_client` connected to a base, or a
#'   `harbour_dtable` read from a local file.
#' @param table Table name.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @param refresh Logical. Ask the server rather than reusing the cached
#'   base metadata. Default `FALSE`.
#' @return A tibble with one row per column and columns `name` (chr),
#'   `type` (chr), `key` (chr), `editable` (lgl) and `data` (list).
#'   `editable` says whether harbouR writes the column: it is `FALSE` for
#'   the types [hb_column_types()] marks `read_only`. SeaTable's own
#'   `editable` flag is not used, since it is set for formula columns too.
#'   The
#'   `data` list-column holds the column's type-specific configuration -
#'   for a select column, its options.
#' @family columns
#' @examples
#' # a .dtable file needs no server
#' path <- system.file("extdata", "example.dtable", package = "harbouR")
#' hb_list_columns(hb_read_dtable(path), "Samples")
#'
#' # a live base needs a SeaTable server and an API token
#' \dontrun{
#' client <- hb_client()
#' hb_list_columns(client, "Samples")
#' }
#' @export
hb_list_columns <- function(x, table, ...) {
  UseMethod("hb_list_columns")
}

#' @rdname hb_list_columns
#' @method hb_list_columns harbour_client
#' @export
hb_list_columns.harbour_client <- function(x, table, ...,
                                           refresh = FALSE) {
  rlang::check_dots_empty()
  .check_client(x, arg = "x")
  .check_string(table)
  .check_flag(refresh)
  cols <- .hb_fetch_columns(x, table, refresh = refresh)
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
#' @inheritParams hb_metadata
#' @param table Table name.
#' @param name Column name.
#' @param type SeaTable column type, e.g. `"text"`, `"number"`, `"date"`.
#' @param column_data Optional list of column options, e.g. the choices
#'   for a select column. Named `column_data` rather than `data` because
#'   `data` means "the rows you are writing" everywhere else in harbouR.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_add_column(client, "Samples", "Notes", "text")
#' }
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
#'
#' The columns are sent in one request. SeaTable's batch endpoint skips
#' some column types without an error - a formula column among them - so
#' any column its reply leaves out is then created on its own.
#'
#' @inheritParams hb_add_column
#' @param columns A list of column specs, each a named list with `name`,
#'   `type` and optionally `data` - the same shape [hb_create_table()]
#'   takes. SeaTable's own spelling, `column_name`, `column_type` and
#'   `column_data`, is accepted too.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_add_columns(
#'   client, "Samples",
#'   list(
#'     list(name = "a", type = "text"),
#'     list(name = "b", type = "number")
#'   )
#' )
#' }
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
  specs <- .hb_column_specs(columns)
  reply <- .hb_request(client, .hb_base_path(client, "batch-append-columns", ""),
    service = "gateway", auth = "base", method = "POST",
    body = list(table_name = table, columns = specs)
  )
  # The reply lists the columns made. SeaTable 6.2 answers 200 and leaves
  # a formula column out, so each column the reply omits is created on its
  # own, where it is either made or refused with an error.
  if (!is.null(reply$columns)) {
    made <- .hb_chr_field(reply$columns, "name")
    for (spec in specs) {
      if (spec$column_name %in% made) next
      .hb_request(client, .hb_base_path(client, "columns", ""),
        service = "gateway", auth = "base", method = "POST",
        body = c(list(table_name = table), spec)
      )
    }
  }
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' The colours of a select option harbouR creates
#'
#' SeaTable needs both: a 6.2 server refuses an option that lacks either.
#' Amber under near-black text reads well on light and dark themes.
#'
#' @keywords internal
#' @noRd
.hb_option_colours <- list(color = "#EAA700", textColor = "#202428")

#' Update a column
#' @inheritParams hb_add_column
#' @param new_name Optional new column name. Sends `op_type =
#'   "rename_column"`.
#' @param new_type Optional new SeaTable column type. Sends `op_type =
#'   "modify_column_type"`. SeaTable performs one operation per request,
#'   so this cannot be combined with `new_name`.
#' @param column_data Optional list of column options, sent with the type
#'   change. Given without `new_type`, it reconfigures the column under its
#'   current type, which harbouR asks the server for - SeaTable requires
#'   the type to be named.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_update_column(client, "Samples", "Notes", new_name = "Comments")
#' }
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
  if (identical(op_type, "modify_column_type") && is.null(new_type)) {
    # From the server, not the cache: naming a type the column no longer
    # has would convert it back, which nobody asked for.
    new_type <- .hb_column_type(client, table, name, refresh = TRUE)
  }
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
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_delete_column(client, "Samples", "Old")
#' }
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
#'
#' The option is created in amber, with dark text: SeaTable requires both
#' colours. Change them in SeaTable if you prefer others.
#'
#' @inheritParams hb_add_column
#' @param option Option name to add.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_add_select_option(client, "Samples", "Status", "Done")
#' }
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
      options = list(c(list(name = option), .hb_option_colours))
    )
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Update a single-select option
#' @inheritParams hb_add_select_option
#' @param option Name of the option to rename.
#' @param new_option New option name.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_update_select_option(client, "Samples", "Status", "Done", "Complete")
#' }
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
#' @param option Name of the option to delete.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family columns
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_delete_select_option(client, "Samples", "Status", "Old")
#' }
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

#' Look up a column's current type
#'
#' @param client A `harbour_client`.
#' @param table Table name.
#' @param column Column name.
#' @param refresh Whether to ask the server rather than the cache.
#' @param call The frame to blame for any error.
#' @return A single string.
#' @keywords internal
#' @noRd
.hb_column_type <- function(client, table, column, refresh = FALSE,
                            call = rlang::caller_env()) {
  cols <- .hb_fetch_columns(client, table, refresh = refresh, call = call)
  idx <- match(column, .hb_chr_field(cols, "name"))
  if (is.na(idx)) {
    hb_abort(
      "Column {.val {column}} not found in table {.val {table}}.",
      class = "harbour_error_not_found",
      call = call
    )
  }
  as.character(cols[[idx]]$type)
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
