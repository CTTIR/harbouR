#' Fetch base metadata
#'
#' Retrieves the structural metadata for a SeaTable base — the list of
#' tables, their columns (with SeaTable types) and views. The result is
#' cached on the client.
#'
#' @param client A `harbour_client`.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @return A `harbour_metadata` object — a list with components
#'   `base_name` (chr), `tables` (list), `version` (chr).
#'
#' @family metadata
#' @examplesIf interactive()
#' client <- hb_client()
#' meta <- hb_metadata(client)
#' as_tibble(meta)
#' @export
hb_metadata <- function(client, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  body <- .hb_request(client, .hb_base_path(client, "metadata", ""),
    service = "gateway", auth = "base", method = "GET"
  )
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
#' @param x A `harbour_client` connected to a base, or a
#'   `harbour_dtable` read from a local file.
#' @param refresh Logical; refetch metadata even if cached. Default `FALSE`.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @return A tibble with one row per table and columns `name` (chr),
#'   `n_columns` (int) and `n_views` (int).
#'
#'   The server path stops there: the metadata endpoint carries no row
#'   payloads, so there is no row count to report - use [hb_read_table()]
#'   if you need one. The `.dtable` path additionally returns `n_rows`
#'   (int), because in a file the rows are right there.
#'
#' @family metadata
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_list_tables(client)
#' @export
hb_list_tables <- function(x, ...) {
  UseMethod("hb_list_tables")
}

#' @rdname hb_list_tables
#' @method hb_list_tables harbour_client
#' @export
hb_list_tables.harbour_client <- function(x, ..., refresh = FALSE) {
  rlang::check_dots_empty()
  .check_client(x, arg = "x")
  .check_flag(refresh)
  meta <- if (!is.null(x$.metadata) && !refresh) {
    x$.metadata
  } else {
    hb_metadata(x)
  }
  tibble::as_tibble(meta)
}

#' List collaborators of the active base
#'
#' @inheritParams hb_metadata
#' @param ... These dots are for future extensions and must be empty.
#' @return A tibble with columns `email` (chr), `name` (chr) and
#'   `contact_email` (chr). Zero rows if none are reported.
#' @family metadata
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_list_collaborators(client)
#' @export
hb_list_collaborators <- function(client, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  body <- .hb_request(client, .hb_base_path(client, "related-users", ""),
    service = "gateway", auth = "base", method = "GET"
  )
  users <- body$user_list %||% body$collaborators %||% list()
  if (length(users) == 0L) {
    return(tibble::tibble(
      email = character(), name = character(),
      contact_email = character()
    ))
  }
  tibble::tibble(
    email = .hb_chr_field(users, "email"),
    name = .hb_chr_field(users, "name"),
    contact_email = vapply(
      users,
      function(user) {
        as.character(user$contact_email %||% user$email %||% NA_character_)
      },
      character(1)
    )
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
    overview <- format(x)
    cli::cli_text("")
    shown <- overview[seq_len(min(10L, length(overview)))]
    for (line in shown) cli::cli_text("  - {line}")
    if (length(overview) > 10L) {
      cli::cli_text("  ... and {length(overview) - 10L} more.")
    }
  }
  invisible(x)
}

#' @param x A `harbour_metadata` object.
#' @param ... Unused.
#' @return A character vector, one element per table.
#' @rdname print.harbour_metadata
#' @export
format.harbour_metadata <- function(x, ...) {
  rlang::check_dots_empty()
  tbls <- x$tables
  if (length(tbls) == 0L) {
    return(character())
  }
  sprintf(
    "%s (%d cols, %d views)",
    .hb_chr_field(tbls, "name", default = "<unnamed>"),
    .hb_count_field(tbls, "columns"),
    .hb_count_field(tbls, "views")
  )
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
      n_columns = integer(),
      n_views = integer()
    ))
  }
  tibble::tibble(
    name = .hb_chr_field(tbls, "name"),
    n_columns = .hb_count_field(tbls, "columns"),
    n_views = .hb_count_field(tbls, "views")
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
    tbl <- tbls[[i]]
    cols <- tbl$columns %||% list()
    if (length(cols) == 0L) next
    rows[[i]] <- tibble::tibble(
      table = rep(tbl$name %||% NA_character_, length(cols)),
      column = .hb_chr_field(cols, "name"),
      type = .hb_chr_field(cols, "type")
    )
  }
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0L) {
    return(tibble::tibble(
      table = character(), column = character(),
      type = character()
    ))
  }
  do.call(rbind, rows)
}
