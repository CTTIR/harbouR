#' List views of a table
#'
#' @inheritParams hb_metadata
#' @param table Table name.
#'
#' @return A tibble with columns `name` (chr), `type` (chr) and `is_default`
#'   (lgl). Zero rows if no views exist.
#' @family views
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_list_views(client, "Samples")
#' @export
hb_list_views <- function(client, table, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  if (is.null(client$.metadata)) hb_metadata(client, call = call)
  tbls <- client$.metadata$tables
  idx <- match(table, vapply(tbls, function(t) t$name %||% NA_character_, character(1)))
  if (is.na(idx)) {
    cli::cli_abort("Table {.val {table}} not found.", call = call)
  }
  views <- tbls[[idx]]$views %||% list()
  if (length(views) == 0L) {
    return(tibble::tibble(name = character(), type = character(),
                          is_default = logical()))
  }
  tibble::tibble(
    name = vapply(views, function(v) as.character(v$name %||% NA_character_), character(1)),
    type = vapply(views, function(v) as.character(v$type %||% NA_character_), character(1)),
    is_default = vapply(views, function(v) isTRUE(v$is_default), logical(1))
  )
}

#' Get a view's settings
#' @inheritParams hb_list_views
#' @param view View name.
#' @return A 1-row tibble with the view's name, type and filters/sorts as
#'   list-columns.
#' @family views
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_get_view(client, "Samples", "Default")
#' @export
hb_get_view <- function(client, table, view, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(view, call = call)
  body <- .hb_request(client, "/dtable-server/api/v1/dtables/views/",
                      service = "dtable_server", auth = "base", method = "GET",
                      query = list(table_name = table, view_name = view))
  tibble::tibble(
    name = body$name %||% view,
    type = body$type %||% NA_character_,
    filters = list(body$filters %||% list()),
    sorts = list(body$sorts %||% list())
  )
}

#' Create a view
#' @inheritParams hb_list_views
#' @param view New view name.
#' @param settings Optional list of view settings.
#' @return Invisibly returns the client.
#' @family views
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_create_view(client, "Samples", "Active")
#' @export
hb_create_view <- function(client, table, view, settings = list(),
                           call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(view, call = call)
  body <- list(table_name = table, name = view)
  body <- c(body, settings)
  .hb_request(client, "/dtable-server/api/v1/dtables/views/",
              service = "dtable_server", auth = "base", method = "POST",
              body = body)
  client$.metadata <- NULL
  invisible(client)
}

#' Update a view
#' @inheritParams hb_create_view
#' @return Invisibly returns the client.
#' @family views
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_update_view(client, "Samples", "Active", list(filter_conjunction = "And"))
#' @export
hb_update_view <- function(client, table, view, settings,
                           call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(view, call = call)
  if (!is.list(settings)) {
    cli::cli_abort("{.arg settings} must be a list.", call = call)
  }
  body <- c(list(table_name = table, view_name = view), settings)
  .hb_request(client, "/dtable-server/api/v1/dtables/views/",
              service = "dtable_server", auth = "base", method = "PUT",
              body = body)
  client$.metadata <- NULL
  invisible(client)
}

#' Delete a view
#' @inheritParams hb_list_views
#' @param view View name.
#' @return Invisibly returns the client.
#' @family views
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_delete_view(client, "Samples", "Old")
#' @export
hb_delete_view <- function(client, table, view, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(view, call = call)
  .hb_request(client, "/dtable-server/api/v1/dtables/views/",
              service = "dtable_server", auth = "base", method = "DELETE",
              body = list(table_name = table, view_name = view))
  client$.metadata <- NULL
  invisible(client)
}
