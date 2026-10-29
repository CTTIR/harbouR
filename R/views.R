#' List views of a table
#'
#' @param x A `harbour_client` connected to a base, or a
#'   `harbour_dtable` read from a local file.
#' @param table Table name.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @param refresh Logical. Ask the server rather than reusing the cached
#'   base metadata. Default `FALSE`.
#' @return A tibble with columns `name` (chr), `type` (chr) and `is_default`
#'   (lgl). Zero rows if no views exist.
#' @family views
#' @examples
#' # a .dtable file needs no server
#' path <- system.file("extdata", "example.dtable", package = "harbouR")
#' hb_list_views(hb_read_dtable(path), "Samples")
#'
#' # a live base needs a SeaTable server and an API token
#' \dontrun{
#' client <- hb_client()
#' hb_list_views(client, "Samples")
#' }
#' @order 1
#' @export
hb_list_views <- function(x, table, ...) {
  UseMethod("hb_list_views")
}

#' @rdname hb_list_views
#' @method hb_list_views harbour_client
#' @export
hb_list_views.harbour_client <- function(x, table, ...,
                                         refresh = FALSE) {
  rlang::check_dots_empty()
  .check_client(x, arg = "x")
  .check_string(table)
  .check_flag(refresh)
  views <- .hb_fetch_views(x, table, refresh = refresh)
  if (length(views) == 0L) {
    return(tibble::tibble(
      name = character(), type = character(),
      is_default = logical()
    ))
  }
  tibble::tibble(
    name = .hb_chr_field(views, "name"),
    type = .hb_chr_field(views, "type"),
    is_default = vapply(views, .hb_is_default_view, logical(1))
  )
}

#' Is this the table's default view?
#'
#' SeaTable does not report `is_default`; its default view is the one with
#' id `"0000"`, as in a `.dtable` file. The flag is still honoured if a
#' server or a test fixture sends it.
#'
#' @param view A view object.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_is_default_view <- function(view) {
  isTRUE(view$is_default) || identical(view[["_id"]], "0000")
}

#' Get a view's settings
#'
#' SeaTable's API addresses one view by its name in the URL, and its
#' server reads a slash in that name as a path separator and a name of one
#' or two dots as a folder. Such a view is looked up in the table's list of
#' views instead.
#' @inheritParams hb_metadata
#' @param table Table name.
#' @param view View name.
#' @param ... These dots are for future extensions and must be empty.
#' @return A one-row tibble with columns `name` (chr), `type` (chr),
#'   `is_default` (lgl), `filters` (list), `sorts` (list) and
#'   `hidden_columns` (list of chr).
#' @family views
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_get_view(client, "Samples", "Default")
#' }
#' @export
hb_get_view <- function(client, table, view, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(view)
  if (.hb_addressable_view(view)) {
    body <- .hb_request(client, .hb_base_path(client, "views", view, ""),
      service = "gateway", auth = "base", method = "GET",
      query = list(table_name = table)
    )
  } else {
    # Found in the table's list of views, which names none in its path.
    views <- .hb_fetch_views(client, table, refresh = TRUE)
    idx <- match(view, .hb_chr_field(views, "name"))
    if (is.na(idx)) {
      hb_abort(
        c("View {.val {view}} not found in table {.val {table}}."),
        class = "harbour_error_not_found"
      )
    }
    body <- views[[idx]]
  }
  tibble::tibble(
    name = as.character(body$name %||% view),
    type = as.character(body$type %||% NA_character_),
    is_default = .hb_is_default_view(body),
    filters = list(body$filters %||% list()),
    sorts = list(body$sorts %||% list()),
    hidden_columns = list(as.character(
      unlist(body$hidden_columns %||% list(), use.names = FALSE)
    ))
  )
}

#' Create a view
#' @inheritParams hb_metadata
#' @param table Table name.
#' @param view New view name.
#' @param settings Optional named list of further fields for the new view,
#'   such as `type` (`"table"`, the default, or `"archive"`) or
#'   `is_locked`. SeaTable sets filters, sorts and hidden columns only on
#'   an existing view, so follow with [hb_update_view()] for those.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family views
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_create_view(client, "Samples", "Active")
#' }
#' @export
hb_create_view <- function(client, table, view, ..., settings = list()) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(view)
  .hb_check_settings(settings)
  # The table is named in the query string, not the body; the server
  # rejects a body-only table_name.
  body <- utils::modifyList(list(name = view, type = "table"), settings)
  .hb_request(client, .hb_base_path(client, "views", ""),
    service = "gateway", auth = "base", method = "POST",
    query = list(table_name = table), body = body
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Update a view
#'
#' SeaTable's API addresses one view by its name in the URL, and its
#' server reads a slash in that name as a path separator and a name of one
#' or two dots as a folder. Such a view cannot be changed through the API, and
#' harbouR says so before sending anything: rename it in SeaTable first.
#' @inheritParams hb_create_view
#' @param view Name of the view to update.
#' @param settings Named list of the fields to change: `name` to rename
#'   the view, `is_locked`, `filters`, `filter_conjunction`, `sorts`,
#'   `groupbys` or `hidden_columns`. Fields you leave out are unchanged.
#'   `hidden_columns` takes column keys - the `key` column of
#'   [hb_list_columns()] - not names.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family views
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_update_view(client, "Samples", "Active", list(filter_conjunction = "And"))
#' }
#' @export
hb_update_view <- function(client, table, view, settings, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(view)
  .hb_check_addressable_view(view, "change")
  .hb_check_settings(settings, allow_empty = FALSE)
  if (!is.null(settings[["hidden_columns"]])) {
    # The server reads an array of keys. One key on its own would be
    # unboxed to a bare string, and a named vector written as an object.
    settings[["hidden_columns"]] <- as.list(as.character(
      unlist(settings[["hidden_columns"]], use.names = FALSE)
    ))
  }
  .hb_request(client, .hb_base_path(client, "views", view, ""),
    service = "gateway", auth = "base", method = "PUT",
    query = list(table_name = table), body = settings
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Delete a view
#'
#' SeaTable's API addresses one view by its name in the URL, and its
#' server reads a slash in that name as a path separator and a name of one
#' or two dots as a folder. Such a view cannot be deleted through the API, and
#' harbouR says so before sending anything: rename it in SeaTable first.
#' @inheritParams hb_metadata
#' @param table Table name.
#' @param view View name.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family views
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_delete_view(client, "Samples", "Old")
#' }
#' @export
hb_delete_view <- function(client, table, view, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(view)
  .hb_check_addressable_view(view, "delete")
  .hb_request(client, .hb_base_path(client, "views", view, ""),
    service = "gateway", auth = "base", method = "DELETE",
    query = list(table_name = table)
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Can SeaTable's API address a view by this name?
#'
#' The endpoints for one view carry its name in the URL path. SeaTable's
#' proxy decodes an escaped slash back into a separator, and resolves a
#' segment of `.` or `..` away, so such a view can be created and read
#' through, but not fetched, changed or deleted by name.
#'
#' @param view A view name.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_addressable_view <- function(view) {
  !grepl("/", view, fixed = TRUE) && !view %in% c(".", "..")
}

#' Refuse a view the API cannot address, before asking the server
#'
#' The server's own answer is a 404 that reads like a wrong base.
#'
#' @param view A view name.
#' @param action The verb for the message: `"change"` or `"delete"`.
#' @param call The frame to blame for the error.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_check_addressable_view <- function(view, action,
                                       call = rlang::caller_env()) {
  if (.hb_addressable_view(view)) {
    return(invisible(NULL))
  }
  hb_abort(
    c("SeaTable's API cannot {action} a view called {.val {view}}.",
      "x" = "Its server reads a slash in a view name as a path separator,
             and a name of one or two dots as a folder.",
      "i" = "Rename the view in SeaTable itself, then use the new name."),
    class = "harbour_error_unsupported",
    call = call
  )
}

#' Fetch a table's views from the server
#'
#' @param client A `harbour_client`.
#' @param table Table name.
#' @param refresh Whether to bypass the cache.
#' @param call The frame to blame for any error.
#' @return A list of view objects, as SeaTable reports them.
#' @keywords internal
#' @noRd
.hb_fetch_views <- function(client, table, refresh = FALSE,
                            call = rlang::caller_env()) {
  if (!refresh && !is.null(client$.metadata)) {
    tbls <- client$.metadata$tables
    known <- .hb_chr_field(tbls, "name")
    idx <- match(table, known)
    if (is.na(idx)) {
      # `known` must be a local: cli >= 3.4.0 reads a `{}` expression
      # beginning with a dot as a style name, not as code.
      hb_abort(
        c("Table {.val {table}} not found.",
          "i" = "Known tables: {.val {known}}."),
        class = "harbour_error_not_found",
        call = call
      )
    }
    return(tbls[[idx]]$views %||% list())
  }
  body <- .hb_request(client, .hb_base_path(client, "views", ""),
    service = "gateway", auth = "base", method = "GET",
    query = list(table_name = table), call = call
  )
  body$views %||% list()
}

#' Validate a view-settings list
#'
#' An update needs at least one field: an empty list would also reach the
#' server as `[]`, which is not the object it expects.
#'
#' @param settings The settings to check.
#' @param allow_empty Whether an empty list is acceptable.
#' @param call The frame to blame for any error.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_check_settings <- function(settings, allow_empty = TRUE,
                               call = rlang::caller_env()) {
  empty <- is.list(settings) && length(settings) == 0L
  ok <- is.list(settings) && (empty || rlang::is_named(settings))
  if (!ok || (empty && !allow_empty)) {
    hb_abort(
      c("{.arg settings} must be a named list of view fields.",
        "i" = "For example {.code list(filter_conjunction = \"And\")}."),
      class = "harbour_error_bad_argument", call = call
    )
  }
  invisible(NULL)
}
