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
  if (allow_null && is.null(x)) return(invisible(NULL))
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    cli::cli_abort(
      c("{.arg {arg}} must be a single non-empty string.",
        "x" = "You supplied {.val {x}}."),
      call = call
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
    cli::cli_abort(
      c("{.arg {arg}} must be a single `TRUE` or `FALSE`.",
        "x" = "You supplied {.val {x}}."),
      call = call
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
    cli::cli_abort(
      c("{.arg {arg}} must inherit from {.cls {cls}}.",
        "x" = "You supplied an object of class {.cls {class(x)}}."),
      call = call
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
    cli::cli_abort(
      c("{.arg {arg}} must be a {.cls harbour_client}.",
        "i" = "Create one with {.fn harbouR::hb_client}."),
      call = call
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
      client$.metadata$tables, function(t) t$name, character(1)
    )
    if (!table %in% available) {
      cli::cli_abort(
        c("Table {.val {table}} not found in this base.",
          "i" = "Available tables: {.val {available}}."),
        call = call
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
  if (n <= 8L) return(strrep("*", n))
  paste0(substr(x, 1L, 4L), "...", substr(x, n - 3L, n))
}

#' @keywords internal
#' @noRd
.is_truthy <- function(x) {
  !is.null(x) && length(x) > 0L && !all(is.na(x)) &&
    (!is.character(x) || any(nzchar(x)))
}
