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
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_list_views(client, "Samples")
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
    is_default = vapply(
      views,
      function(view) isTRUE(view$is_default),
      logical(1)
    )
  )
}

#' Get a view's settings
#' @inheritParams hb_metadata
#' @param table Table name.
#' @param view View name.
#' @param ... These dots are for future extensions and must be empty.
#' @return A one-row tibble with columns `name` (chr), `type` (chr),
#'   `is_default` (lgl), `filters` (list), `sorts` (list) and
#'   `hidden_columns` (list of chr).
#' @family views
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_get_view(client, "Samples", "Default")
#' @export
hb_get_view <- function(client, table, view, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(view)
  body <- .hb_request(client, .hb_base_path(client, "views", view, ""),
    service = "gateway", auth = "base", method = "GET",
    query = list(table_name = table, view_name = view)
  )
  tibble::tibble(
    name = as.character(body$name %||% view),
    type = as.character(body$type %||% NA_character_),
    is_default = isTRUE(body$is_default),
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
#' @param settings Optional list of view settings.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family views
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_create_view(client, "Samples", "Active")
#' @export
hb_create_view <- function(client, table, view, ..., settings = list()) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(view)
  body <- list(table_name = table, name = view)
  body <- c(body, settings)
  .hb_request(client, .hb_base_path(client, "views", ""),
    service = "gateway", auth = "base", method = "POST",
    body = body
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Update a view
#' @inheritParams hb_create_view
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family views
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_update_view(client, "Samples", "Active", list(filter_conjunction = "And"))
#' @export
hb_update_view <- function(client, table, view, settings, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(view)
  if (!is.list(settings)) {
    hb_abort("{.arg settings} must be a list.",
      class = "harbour_error_bad_argument"
    )
  }
  body <- c(list(table_name = table, view_name = view), settings)
  .hb_request(client, .hb_base_path(client, "views", view, ""),
    service = "gateway", auth = "base", method = "PUT",
    body = body
  )
  .hb_invalidate_metadata(client)
  invisible(client)
}

#' Delete a view
#' @inheritParams hb_metadata
#' @param table Table name.
#' @param view View name.
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family views
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_delete_view(client, "Samples", "Old")
#' @export
hb_delete_view <- function(client, table, view, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(view)
  .hb_request(client, .hb_base_path(client, "views", view, ""),
    service = "gateway", auth = "base", method = "DELETE",
    body = list(table_name = table, view_name = view)
  )
  .hb_invalidate_metadata(client)
  invisible(client)
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
