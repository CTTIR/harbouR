#' SeaTable column types and how harbouR maps them
#'
#' The single source of truth for the coercion layer. Every column type
#' SeaTable supports appears here exactly once, together with the R type
#' harbouR produces when reading, whether that R type is a list-column,
#' and whether the column is computed server-side and therefore cannot be
#' written. The coercion functions and the column-types vignette are both
#' derived from this table, so they cannot drift apart.
#'
#' @return A tibble with one row per SeaTable column type and columns:
#'   \describe{
#'     \item{`seatable`}{chr. The type name as SeaTable reports it.}
#'     \item{`r`}{chr. The R type harbouR reads it as.}
#'     \item{`is_list`}{lgl. Whether the result is a list-column.}
#'     \item{`read_only`}{lgl. Whether the value is computed server-side
#'       and is dropped on write.}
#'     \item{`notes`}{chr. Anything worth knowing.}
#'   }
#' @family metadata
#' @examples
#' hb_column_types()
#'
#' # the types you cannot write to
#' subset(hb_column_types(), read_only)
#' @export
hb_column_types <- function() {
  tibble::tribble(
    ~seatable, ~r, ~is_list, ~read_only, ~notes,
    "text", "character", FALSE, FALSE,
    "free text",
    "long-text", "character", FALSE, FALSE,
    "markdown blob",
    "email", "character", FALSE, FALSE,
    "validated as email server-side",
    "url", "character", FALSE, FALSE,
    "validated as URL server-side",
    "number", "double", FALSE, FALSE,
    "64-bit precision caveat applies",
    "percent", "double", FALSE, FALSE,
    "stored as a fraction, displayed as a percentage",
    "dollar", "double", FALSE, FALSE,
    "number with a currency format",
    "euro", "double", FALSE, FALSE,
    "number with a currency format",
    "duration", "double", FALSE, FALSE,
    "seconds",
    "rate", "integer", FALSE, FALSE,
    "0..N stars",
    "checkbox", "logical", FALSE, FALSE,
    "TRUE/FALSE",
    "date", "POSIXct", FALSE, FALSE,
    "UTC; date-only columns have a zero time component",
    "single-select", "character", FALSE, FALSE,
    "validated against the column's options on write",
    "multiple-select", "list<character>", TRUE, FALSE,
    "always a list-column",
    "collaborator", "list<character>", TRUE, FALSE,
    "list-column of email addresses",
    "image", "list<character>", TRUE, FALSE,
    "list-column of URLs",
    "file", "list<list>", TRUE, FALSE,
    "list-column of {name,size,type,url} lists",
    "geolocation", "list", TRUE, FALSE,
    "list-column with lat/lng/address",
    "link", "list", TRUE, TRUE,
    "managed via the link endpoints, not by writing the cell",
    "link-formula", "list", TRUE, TRUE,
    "mirrors a column in a linked table",
    "formula", "character", FALSE, TRUE,
    "computed server-side",
    "auto-number", "character", FALSE, TRUE,
    "server-generated identifier",
    "button", "list", TRUE, TRUE,
    "carries no data",
    "digital-sign", "list", TRUE, TRUE,
    "signature metadata",
    "creator", "character", FALSE, TRUE,
    "user email",
    "last-modifier", "character", FALSE, TRUE,
    "user email",
    "ctime", "POSIXct", FALSE, TRUE,
    "row creation time",
    "mtime", "POSIXct", FALSE, TRUE,
    "row modification time"
  )
}

#' Column types that are list-columns
#' @keywords internal
#' @noRd
.hb_list_types <- function() {
  types <- hb_column_types()
  types$seatable[types$is_list]
}

#' Column types that cannot be written
#' @keywords internal
#' @noRd
.hb_readonly_types <- function() {
  types <- hb_column_types()
  types$seatable[types$read_only]
}

#' @keywords internal
#' @noRd
.hb_columns_from_metadata <- function(metadata, table) {
  if (!inherits(metadata, "harbour_metadata")) {
    hb_abort("{.arg metadata} must be a {.cls harbour_metadata}.",
      class = "harbour_error_bad_argument"
    )
  }
  tbls <- metadata$tables
  names_ <- .hb_chr_field(tbls, "name")
  idx <- match(table, names_)
  if (is.na(idx)) {
    hb_abort(
      c("Table {.val {table}} not found.",
        "i" = "Known tables: {.val {names_}}."
      ),
      call = rlang::caller_env(),
      class = "harbour_error_not_found"
    )
  }
  cols <- tbls[[idx]]$columns %||% list()
  cols
}

#' @keywords internal
#' @noRd
.hb_empty_vector_for_type <- function(type) {
  switch(type %||% "text",
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
  if (inherits(x, "POSIXt")) {
    return(as.POSIXct(x))
  }
  if (is.numeric(x)) {
    return(as.POSIXct(x, origin = "1970-01-01", tz = "UTC"))
  }
  s <- as.character(x)
  parsed <- suppressWarnings(lubridate::parse_date_time(
    s,
    orders = c("Y-m-d H:M:S", "Y-m-d H:M", "Y-m-d", "Y/m/d"),
    tz = "UTC"
  ))
  if (is.na(parsed)) {
    return(as.POSIXct(NA, tz = "UTC"))
  }
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
      error = function(e) NA_real_
    ),
    "rate" = tryCatch(as.integer(value),
      warning = function(w) NA_integer_,
      error = function(e) NA_integer_
    ),
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
  type %in% .hb_list_types()
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
  names(out) <- .hb_chr_field(columns, "name")
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
      out[[i]] <- .hb_first(coerced, NA_real_, as.double, double(1))
    } else if (type == "rate") {
      out[[i]] <- .hb_first(coerced, NA_integer_, as.integer, integer(1))
    } else if (type == "checkbox") {
      out[[i]] <- .hb_first(coerced, NA, isTRUE, logical(1))
    } else if (type %in% c("date", "ctime", "mtime")) {
      out[[i]] <- do.call(c, lapply(coerced, function(value) {
        if (length(value) == 0L) {
          as.POSIXct(NA, tz = "UTC")
        } else {
          as.POSIXct(value, tz = "UTC")
        }
      }))
    } else {
      out[[i]] <- .hb_first(coerced, NA_character_, as.character, character(1))
    }
  }
  if ("_id" %in% names(out)) {
    hb_abort(
      c("A column in this table is named {.field _id}.",
        "x" = "harbouR uses {.field _id} for the SeaTable row identifier.",
        "i" = "Rename the column in SeaTable, or read it with
               {.fn hb_query} and alias it."
      ),
      class = "harbour_error_column_collision",
      call = rlang::caller_env()
    )
  }
  out[["_id"]] <- if (length(rows) > 0L) {
    vapply(
      rows,
      function(row) as.character(row[["_id"]] %||% NA_character_),
      character(1)
    )
  } else {
    character()
  }
  tibble::as_tibble(out)
}

#' @keywords internal
#' @noRd
.hb_tibble_to_rows <- function(data, columns) {
  if (!is.data.frame(data)) {
    hb_abort("{.arg data} must be a data frame or tibble.",
      class = "harbour_error_bad_argument"
    )
  }
  col_names <- .hb_chr_field(columns, "name")
  col_types <- .hb_chr_field(columns, "type", default = "text")
  read_only <- .hb_readonly_types()

  rows <- vector("list", nrow(data))
  for (r in seq_len(nrow(data))) {
    row <- list()
    for (i in seq_along(col_names)) {
      cn <- col_names[[i]]
      if (!cn %in% names(data)) next
      if (col_types[[i]] %in% read_only) next
      v <- data[[cn]][[r]]
      if (is.list(v)) v <- unlist(v, use.names = FALSE)
      if (inherits(v, c("Date", "POSIXt"))) {
        v <- format(v, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      }
      row[[cn]] <- v
    }
    rows[[r]] <- row
  }
  rows
}
