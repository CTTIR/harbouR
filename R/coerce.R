#' SeaTable column type mapping
#'
#' Returns the mapping between SeaTable column types and the R types
#' harbouR produces when reading rows. This is the single source of truth
#' for the coercion layer; the column-types vignette is derived from it.
#'
#' @return A tibble with columns `seatable` (chr), `r` (chr) and `notes` (chr).
#' @family metadata
#' @examples
#' hb_column_types()
#' @export
hb_column_types <- function() {
  tibble::tribble(
    ~seatable,           ~r,                 ~notes,
    "text",              "character",        "free text",
    "long-text",         "character",        "markdown blob",
    "email",             "character",        "validated as email server-side",
    "url",               "character",        "validated as URL server-side",
    "auto-number",       "character",        "server-generated identifier",
    "number",            "double",           "64-bit precision caveat applies",
    "rate",              "integer",          "0..N stars",
    "checkbox",          "logical",          "TRUE/FALSE",
    "date",              "Date or POSIXct",  "POSIXct when a time component is present",
    "single-select",     "character",        "validated against options on write",
    "multiple-select",   "list<character>",  "always a list-column",
    "collaborator",      "list<character>",  "list-column of email addresses",
    "image",             "list<character>",  "list-column of URLs",
    "file",              "list<list>",       "list-column of {name,size,type,url} lists",
    "link",              "list",             "managed via link endpoints, not direct write",
    "link-formula",      "list",             "read-only; mirrors a linked column",
    "formula",           "character",        "read-only computed value",
    "geolocation",       "list",             "list-column with lat/lng/address",
    "button",            "list",             "read-only metadata",
    "creator",           "character",        "read-only; user email",
    "last-modifier",     "character",        "read-only; user email",
    "ctime",             "POSIXct",          "read-only; row creation time",
    "mtime",             "POSIXct",          "read-only; row modification time"
  )
}

#' @keywords internal
#' @noRd
.hb_columns_from_metadata <- function(metadata, table) {
  if (!inherits(metadata, "harbour_metadata")) {
    cli::cli_abort("{.arg metadata} must be a {.cls harbour_metadata}.")
  }
  tbls <- metadata$tables
  names_ <- vapply(tbls, function(t) t$name %||% NA_character_, character(1))
  idx <- match(table, names_)
  if (is.na(idx)) {
    cli::cli_abort(
      c("Table {.val {table}} not found.",
        "i" = "Known tables: {.val {names_}}."),
      call = rlang::caller_env()
    )
  }
  cols <- tbls[[idx]]$columns %||% list()
  cols
}

#' @keywords internal
#' @noRd
.hb_empty_vector_for_type <- function(type) {
  switch(
    type %||% "text",
    "text" = ,
    "long-text" = ,
    "email" = ,
    "url" = ,
    "auto-number" = ,
    "single-select" = ,
    "formula" = ,
    "creator" = ,
    "last-modifier" = character(),
    "number" = double(),
    "rate" = integer(),
    "checkbox" = logical(),
    "date" = as.POSIXct(character(), tz = "UTC"),
    "ctime" = ,
    "mtime" = as.POSIXct(character(), tz = "UTC"),
    "multiple-select" = ,
    "collaborator" = ,
    "image" = ,
    "file" = ,
    "link" = ,
    "link-formula" = ,
    "geolocation" = ,
    "button" = list(),
    character()
  )
}

#' @keywords internal
#' @noRd
.hb_parse_date_value <- function(x) {
  if (is.null(x) || (is.character(x) && !nzchar(x))) {
    return(as.POSIXct(NA, tz = "UTC"))
  }
  if (inherits(x, "POSIXt")) return(as.POSIXct(x))
  if (is.numeric(x)) {
    return(as.POSIXct(x, origin = "1970-01-01", tz = "UTC"))
  }
  s <- as.character(x)
  parsed <- suppressWarnings(lubridate::parse_date_time(
    s,
    orders = c("Y-m-d H:M:S", "Y-m-d H:M", "Y-m-d", "Y/m/d"),
    tz = "UTC"
  ))
  if (is.na(parsed)) return(as.POSIXct(NA, tz = "UTC"))
  parsed
}

#' @keywords internal
#' @noRd
.hb_coerce_cell <- function(value, type) {
  if (is.null(value)) {
    return(switch(type %||% "text",
      "number" = NA_real_,
      "rate" = NA_integer_,
      "checkbox" = NA,
      "date" = ,
      "ctime" = ,
      "mtime" = as.POSIXct(NA, tz = "UTC"),
      "multiple-select" = ,
      "collaborator" = ,
      "image" = ,
      "file" = ,
      "link" = ,
      "link-formula" = ,
      "geolocation" = ,
      "button" = list(),
      NA_character_
    ))
  }
  switch(type %||% "text",
    "text" = ,
    "long-text" = ,
    "email" = ,
    "url" = ,
    "auto-number" = ,
    "single-select" = ,
    "formula" = ,
    "creator" = ,
    "last-modifier" = as.character(value),
    "number" = tryCatch(as.double(value),
                        warning = function(w) NA_real_,
                        error = function(e) NA_real_),
    "rate" = tryCatch(as.integer(value),
                      warning = function(w) NA_integer_,
                      error = function(e) NA_integer_),
    "checkbox" = isTRUE(as.logical(value)),
    "date" = ,
    "ctime" = ,
    "mtime" = .hb_parse_date_value(value),
    "multiple-select" = ,
    "collaborator" = ,
    "image" = as.character(unlist(value, use.names = FALSE)),
    "file" = ,
    "link" = ,
    "link-formula" = ,
    "geolocation" = ,
    "button" = list(value),
    as.character(value)
  )
}

#' @keywords internal
#' @noRd
.hb_is_list_type <- function(type) {
  type %in% c("multiple-select", "collaborator", "image", "file",
              "link", "link-formula", "geolocation", "button")
}

#' Convert SeaTable row payloads to a typed tibble
#'
#' @keywords internal
#' @noRd
.hb_rows_to_tibble <- function(rows, columns) {
  if (length(columns) == 0L) {
    return(tibble::tibble())
  }
  out <- vector("list", length(columns))
  names(out) <- vapply(columns, function(c) as.character(c$name), character(1))
  for (i in seq_along(columns)) {
    col <- columns[[i]]
    type <- col$type %||% "text"
    name <- col$name
    if (length(rows) == 0L) {
      out[[i]] <- .hb_empty_vector_for_type(type)
      next
    }
    raw <- lapply(rows, function(r) r[[name]])
    coerced <- lapply(raw, .hb_coerce_cell, type = type)
    if (.hb_is_list_type(type)) {
      out[[i]] <- coerced
    } else if (type == "number") {
      out[[i]] <- vapply(coerced, function(v) if (length(v) == 0L) NA_real_ else as.double(v[[1L]]), double(1))
    } else if (type == "rate") {
      out[[i]] <- vapply(coerced, function(v) if (length(v) == 0L) NA_integer_ else as.integer(v[[1L]]), integer(1))
    } else if (type == "checkbox") {
      out[[i]] <- vapply(coerced, function(v) if (length(v) == 0L) NA else isTRUE(v[[1L]]), logical(1))
    } else if (type %in% c("date", "ctime", "mtime")) {
      out[[i]] <- do.call(c, lapply(coerced, function(v) if (length(v) == 0L) as.POSIXct(NA, tz = "UTC") else as.POSIXct(v, tz = "UTC")))
    } else {
      out[[i]] <- vapply(coerced, function(v) if (length(v) == 0L) NA_character_ else as.character(v[[1L]]), character(1))
    }
  }
  ids <- vapply(rows, function(r) as.character(r[["_id"]] %||% NA_character_), character(1))
  if (length(rows) > 0L) {
    out[["_id"]] <- ids
  } else {
    out[["_id"]] <- character()
  }
  tibble::as_tibble(out)
}

#' @keywords internal
#' @noRd
.hb_tibble_to_rows <- function(data, columns) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame or tibble.")
  }
  col_names <- vapply(columns, function(c) as.character(c$name), character(1))
  col_types <- vapply(columns, function(c) as.character(c$type %||% "text"), character(1))
  read_only <- c("formula", "auto-number", "creator", "last-modifier",
                 "ctime", "mtime", "link-formula", "button")

  rows <- vector("list", nrow(data))
  for (r in seq_len(nrow(data))) {
    row <- list()
    for (i in seq_along(col_names)) {
      cn <- col_names[[i]]
      if (!cn %in% names(data)) next
      if (col_types[[i]] %in% read_only) next
      v <- data[[cn]][[r]]
      if (is.list(v)) v <- unlist(v, use.names = FALSE)
      if (inherits(v, c("Date", "POSIXt"))) v <- format(v, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      row[[cn]] <- v
    }
    rows[[r]] <- row
  }
  rows
}
