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
                          allow_empty = FALSE,
                          secret = FALSE,
                          call = rlang::caller_env()) {
  if (allow_null && is.null(x)) {
    return(invisible(NULL))
  }
  bad <- !is.character(x) || length(x) != 1L || is.na(x) ||
    (!allow_empty && !nzchar(x))
  if (bad) {
    what <- if (allow_empty) {
      "{.arg {arg}} must be a single string."
    } else {
      "{.arg {arg}} must be a single non-empty string."
    }
    # A token or password in an error message ends up in consoles and
    # logs, so for those only the kind of value is described.
    supplied <- if (secret) {
      shape <- .hb_describe_value(x)
      "You supplied {shape}."
    } else {
      "You supplied {.val {x}}."
    }
    hb_abort(
      c(what, "x" = supplied),
      call = call,
      class = "harbour_error_bad_argument"
    )
  }
  invisible(NULL)
}

#' Describe a value without showing it
#'
#' @param x Any value.
#' @return A single string such as `"a number"` or `"a character vector
#'   of length 2"`.
#' @keywords internal
#' @noRd
.hb_describe_value <- function(x) {
  if (is.null(x)) {
    return("`NULL`")
  }
  if (is.atomic(x) && length(x) == 1L) {
    if (is.na(x)) {
      return("`NA`")
    }
    if (is.character(x)) {
      return(if (nzchar(x)) "a string" else "an empty string")
    }
    if (is.numeric(x)) {
      return("a number")
    }
  }
  kind <- if (is.character(x)) {
    "character vector"
  } else if (is.numeric(x)) {
    "numeric vector"
  } else if (is.logical(x)) {
    "logical vector"
  } else if (is.list(x)) {
    "list"
  }
  if (is.null(kind)) {
    return(paste0("an object of class <", class(x)[[1L]], ">"))
  }
  paste0("a ", kind, " of length ", length(x))
}

#' @keywords internal
#' @noRd
.check_workspace_id <- function(x,
                                arg = rlang::caller_arg(x),
                                call = rlang::caller_env()) {
  if (is.null(x)) {
    return(invisible(NULL))
  }
  ok <- length(x) == 1L && !is.na(x) && (
    (is.numeric(x) && is.finite(x) && x > 0 && x == round(x)) ||
      (is.character(x) && grepl("^[0-9]+$", x) && grepl("[1-9]", x))
  )
  if (!ok) {
    hb_abort(
      c("{.arg {arg}} must be a single positive whole number or a string of
         digits.",
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
.check_positive_number <- function(x,
                                   arg = rlang::caller_arg(x),
                                   allow_null = FALSE,
                                   min = 0,
                                   call = rlang::caller_env()) {
  if (allow_null && is.null(x)) {
    return(invisible(NULL))
  }
  # Inf passes: as a timeout it has always been handed on to curl as it is.
  ok <- is.numeric(x) && length(x) == 1L && !is.na(x) && x > 0 && x >= min
  if (!ok) {
    what <- if (min > 0) {
      "{.arg {arg}} must be a single number of at least {min}."
    } else {
      "{.arg {arg}} must be a single number greater than 0."
    }
    hb_abort(
      c(what, "x" = "You supplied {.val {x}}."),
      call = call,
      class = "harbour_error_bad_argument"
    )
  }
  invisible(NULL)
}

#' Take a value out of what usually wraps it
#'
#' A one-element list or a one-cell data frame - what a config reader or
#' single-bracket indexing gives - holds the value itself, and a factor
#' or a date reaches a URL as its text. Each reached the URL as that text,
#' so it is taken as it.
#'
#' @param x Any value.
#' @return `x`, unwrapped where it was wrapped.
#' @keywords internal
#' @noRd
.hb_unwrap_value <- function(x) {
  if (is.list(x) && length(x) == 1L && length(x[[1L]]) == 1L) {
    x <- x[[1L]]
  }
  if (is.factor(x) || inherits(x, "Date")) {
    x <- as.character(x)
  }
  x
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
