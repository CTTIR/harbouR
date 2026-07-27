#' Internal scalar validators
#'
#' These helpers are not exported and are intentionally undocumented in
#' `man/`. They produce informative `cli`-formatted errors whose `call`
#' points at the user-facing function that invoked them.
#'
#' @keywords internal
#' @noRd
.check_string <- function(x,
                          arg = rlang::caller_arg(x),
                          allow_null = FALSE,
                          call = rlang::caller_env()) {
  if (allow_null && is.null(x)) {
    return(invisible(NULL))
  }
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    hb_abort(
      c("{.arg {arg}} must be a single non-empty string.",
        "x" = "You supplied {.val {x}}."
      ),
      call = call,
      class = "harbour_error_bad_argument"
    )
  }
  invisible(NULL)
}

#' @keywords internal
#' @noRd
.check_flag <- function(x,
                        arg = rlang::caller_arg(x),
                        call = rlang::caller_env()) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    hb_abort(
      c("{.arg {arg}} must be a single `TRUE` or `FALSE`.",
        "x" = "You supplied {.val {x}}."
      ),
      call = call,
      class = "harbour_error_bad_argument"
    )
  }
  invisible(NULL)
}

#' @keywords internal
#' @noRd
.check_class <- function(x, cls,
                         arg = rlang::caller_arg(x),
                         call = rlang::caller_env()) {
  if (!inherits(x, cls)) {
    hb_abort(
      c("{.arg {arg}} must inherit from {.cls {cls}}.",
        "x" = "You supplied an object of class {.cls {class(x)}}."
      ),
      call = call,
      class = "harbour_error_bad_argument"
    )
  }
  invisible(NULL)
}

#' @keywords internal
#' @noRd
.check_client <- function(client,
                          arg = rlang::caller_arg(client),
                          call = rlang::caller_env()) {
  if (!inherits(client, "harbour_client")) {
    hb_abort(
      c("{.arg {arg}} must be a {.cls harbour_client}.",
        "i" = "Create one with {.fn harbouR::hb_client}."
      ),
      call = call,
      class = "harbour_error_bad_argument"
    )
  }
  invisible(NULL)
}

#' @keywords internal
#' @noRd
.check_table <- function(client, table,
                         arg = rlang::caller_arg(table),
                         call = rlang::caller_env()) {
  .check_string(table, arg = arg, call = call)
  if (!is.null(client$.metadata)) {
    available <- vapply(
      client$.metadata$tables, function(tbl) tbl$name, character(1)
    )
    if (!table %in% available) {
      hb_abort(
        c("Table {.val {table}} not found in this base.",
          "i" = "Available tables: {.val {available}}."
        ),
        call = call,
        class = "harbour_error_not_found"
      )
    }
  }
  invisible(NULL)
}

#' @keywords internal
#' @noRd
.mask_token <- function(x) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    return("<none>")
  }
  n <- nchar(x)
  if (n <= 8L) {
    return(strrep("*", n))
  }
  paste0(substr(x, 1L, 4L), "...", substr(x, n - 3L, n))
}


#' Pull one character field out of a list of SeaTable objects
#'
#' SeaTable's JSON gives back lists of tables, columns, views and users
#' that all share the same shape: a list of named lists. Extracting one
#' field as a character vector is the single most repeated operation in
#' the package.
#'
#' @param x A list of named lists.
#' @param field Name of the field to extract.
#' @param default Value used when the field is absent or `NULL`.
#' @return A character vector as long as `x`.
#' @keywords internal
#' @noRd
.hb_chr_field <- function(x, field, default = NA_character_) {
  vapply(
    x,
    function(item) as.character(item[[field]] %||% default),
    character(1)
  )
}

#' Drop the cached metadata after a schema change
#'
#' Every call that alters the base's structure invalidates the cached
#' metadata. Doing it through one function makes that contract greppable.
#'
#' @param client A `harbour_client`.
#' @return The client, invisibly.
#' @keywords internal
#' @noRd
.hb_invalidate_metadata <- function(client) {
  client$.metadata <- NULL
  invisible(client)
}

#' Count the elements of one list field across SeaTable objects
#'
#' @param x A list of named lists.
#' @param field Name of the list-valued field to measure.
#' @return An integer vector as long as `x`.
#' @keywords internal
#' @noRd
.hb_count_field <- function(x, field) {
  vapply(x, function(item) length(item[[field]] %||% list()), integer(1))
}

#' Take the first element of each coerced cell, with a typed fallback
#'
#' The coercion layer yields one value per cell, but an absent cell yields
#' a zero-length result. This collapses that to an atomic vector.
#'
#' @param x A list of coerced cell values.
#' @param empty Value used where the cell was absent.
#' @param cast Function applied to the first element.
#' @param template Prototype passed to [vapply()].
#' @return An atomic vector as long as `x`.
#' @keywords internal
#' @noRd
.hb_first <- function(x, empty, cast, template) {
  vapply(
    x,
    function(value) if (length(value) == 0L) empty else cast(value[[1L]]),
    template
  )
}

#' Render a base-token expiry for display
#'
#' `format()` on `NULL` gives `character(0)`, which would silently shorten
#' the vector the print method builds.
#'
#' @param x A `POSIXct` or `NULL`.
#' @return A single string.
#' @keywords internal
#' @noRd
.hb_format_expiry <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return("<not yet fetched>")
  }
  format(x, "%Y-%m-%d %H:%M:%S %Z")
}
