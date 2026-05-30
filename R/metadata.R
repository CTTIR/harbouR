#' Fetch base metadata
#'
#' Retrieves the structural metadata for a SeaTable base — the list of
#' tables, their columns (with SeaTable types) and views. The result is
#' cached on the client.
#'
#' @param client A `harbour_client`.
#' @param call Internal: error-propagation env.
#'
#' @return A `harbour_metadata` object — a list with components
#'   `base_name` (chr), `tables` (list), `version` (chr).
#'
#' @family metadata
#' @examplesIf interactive()
#' client <- hb_client()
#' meta <- hb_metadata(client)
#' as_tibble(meta)
#' @export
hb_metadata <- function(client, call = rlang::caller_env()) {
  .check_client(client, call = call)
  body <- .hb_request(client, "/dtables/api/v1/dtables/metadata/",
                      service = "dtable_server", auth = "base", method = "GET")
  meta_raw <- body$metadata %||% body
  out <- new_harbour_metadata(meta_raw, base_name = client$.base_name)
  client$.metadata <- out
  out
}

#' @keywords internal
#' @noRd
new_harbour_metadata <- function(x, base_name = NULL) {
  tables <- x$tables %||% list()
  obj <- list(
    base_name = base_name %||% x$base_name %||% NA_character_,
    version = as.character(x$version %||% NA_character_),
    tables = tables
  )
  class(obj) <- c("harbour_metadata", "list")
  obj
}

#' Test whether an object is harbour metadata
#'
#' @param x Object to test.
#' @return A single `TRUE` or `FALSE`.
#' @family metadata
#' @export
is_harbour_metadata <- function(x) inherits(x, "harbour_metadata")

#' List the tables in a base
#'
#' @inheritParams hb_metadata
#' @param refresh Logical; refetch metadata even if cached. Default `FALSE`.
#'
#' @return A tibble with one row per table and columns
#'   `name` (chr), `n_rows` (int), `n_columns` (int), `n_views` (int).
#'
#' @family metadata
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_list_tables(client)
#' @export
hb_list_tables <- function(client, refresh = FALSE, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_flag(refresh, call = call)
  meta <- if (!is.null(client$.metadata) && !refresh) {
    client$.metadata
  } else {
    hb_metadata(client, call = call)
  }
  tables <- meta$tables
  if (length(tables) == 0L) {
    return(tibble::tibble(
      name = character(),
      n_rows = integer(),
      n_columns = integer(),
      n_views = integer()
    ))
  }
  tibble::tibble(
    name = vapply(tables, function(t) as.character(t$name %||% NA_character_), character(1)),
    n_rows = vapply(tables, function(t) length(t$rows %||% list()), integer(1)),
    n_columns = vapply(tables, function(t) length(t$columns %||% list()), integer(1)),
    n_views = vapply(tables, function(t) length(t$views %||% list()), integer(1))
  )
}

#' List collaborators of the active base
#'
#' @inheritParams hb_metadata
#' @return A tibble with columns `email` (chr), `name` (chr) and
#'   `contact_email` (chr). Zero rows if none are reported.
#' @family metadata
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_list_collaborators(client)
#' @export
hb_list_collaborators <- function(client, call = rlang::caller_env()) {
  .check_client(client, call = call)
  body <- .hb_request(client, "/api/v2.1/dtable/related-users/",
                      service = "web", auth = "api", method = "GET")
  users <- body$user_list %||% body$collaborators %||% list()
  if (length(users) == 0L) {
    return(tibble::tibble(email = character(), name = character(),
                          contact_email = character()))
  }
  tibble::tibble(
    email = vapply(users, function(u) as.character(u$email %||% NA_character_), character(1)),
    name = vapply(users, function(u) as.character(u$name %||% NA_character_), character(1)),
    contact_email = vapply(users, function(u) as.character(u$contact_email %||% u$email %||% NA_character_), character(1))
  )
}

#' Print method for harbour metadata
#' @param x A `harbour_metadata` object.
#' @param ... Unused.
#' @return Invisibly returns `x`.
#' @family metadata
#' @export
print.harbour_metadata <- function(x, ...) {
  rlang::check_dots_empty()
  tbls <- x$tables
  cli::cli_h1("<harbour_metadata>")
  cli::cli_bullets(c(
    "*" = "base   : {.val {x$base_name}}",
    "*" = "tables : {length(tbls)}"
  ))
  if (length(tbls) > 0L) {
    overview <- vapply(tbls, function(t) {
      sprintf("%s (%d cols, %d rows)",
              t$name %||% "<unnamed>",
              length(t$columns %||% list()),
              length(t$rows %||% list()))
    }, character(1))
    cli::cli_text("")
    for (line in utils::head(overview, 10L)) cli::cli_text("  - {line}")
    if (length(overview) > 10L) {
      cli::cli_text("  ... and {length(overview) - 10L} more.")
    }
  }
  invisible(x)
}

#' Coerce harbour metadata to a tibble
#'
#' @param x A `harbour_metadata` object.
#' @param ... Unused.
#' @return A tibble with one row per table; see [hb_list_tables()].
#' @family metadata
#' @method as_tibble harbour_metadata
#' @export
as_tibble.harbour_metadata <- function(x, ...) {
  rlang::check_dots_empty()
  tbls <- x$tables
  if (length(tbls) == 0L) {
    return(tibble::tibble(
      name = character(),
      n_rows = integer(),
      n_columns = integer(),
      n_views = integer()
    ))
  }
  tibble::tibble(
    name = vapply(tbls, function(t) as.character(t$name %||% NA_character_), character(1)),
    n_rows = vapply(tbls, function(t) length(t$rows %||% list()), integer(1)),
    n_columns = vapply(tbls, function(t) length(t$columns %||% list()), integer(1)),
    n_views = vapply(tbls, function(t) length(t$views %||% list()), integer(1))
  )
}

#' Summary of harbour metadata
#'
#' @param object A `harbour_metadata` object.
#' @param ... Unused.
#' @return A tibble with one row per column across all tables, suitable for
#'   inspecting the SeaTable schema. Columns: `table` (chr), `column` (chr),
#'   `type` (chr).
#' @family metadata
#' @method summary harbour_metadata
#' @export
summary.harbour_metadata <- function(object, ...) {
  rlang::check_dots_empty()
  tbls <- object$tables
  rows <- vector("list", length(tbls))
  for (i in seq_along(tbls)) {
    t <- tbls[[i]]
    cols <- t$columns %||% list()
    if (length(cols) == 0L) next
    rows[[i]] <- tibble::tibble(
      table = rep(t$name %||% NA_character_, length(cols)),
      column = vapply(cols, function(c) as.character(c$name %||% NA_character_), character(1)),
      type = vapply(cols, function(c) as.character(c$type %||% NA_character_), character(1))
    )
  }
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0L) {
    return(tibble::tibble(table = character(), column = character(),
                          type = character()))
  }
  do.call(rbind, rows)
}
