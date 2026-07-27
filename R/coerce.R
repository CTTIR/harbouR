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
  .hb_type_lookup()$list_types
}

#' Column types that cannot be written
#' @keywords internal
#' @noRd
.hb_readonly_types <- function() {
  .hb_type_lookup()$read_only
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

#' The R prototype each SeaTable column type reads as
#'
#' One table, consulted by both the empty-column and the empty-cell paths,
#' so the two can no longer disagree. They previously encoded the same
#' knowledge twice and had drifted: a `multiple-select` column produced a
#' `character` vector for a populated cell and a `list` for an empty one,
#' which breaks `tidyr::unnest()`, `purrr::map_chr()` and `vctrs`.
#'
#' @param type A SeaTable column type.
#' @return A zero-length vector of the right type.
#' @keywords internal
#' @noRd
.hb_prototype <- function(type) {
  type <- type %||% "text"
  if (type %in% .hb_list_types()) {
    return(list())
  }
  switch(
    .hb_r_type(type),
    double = double(),
    integer = integer(),
    logical = logical(),
    POSIXct = .POSIXct(double(), tz = "UTC"),
    character()
  )
}

#' Cached views of the column-type table
#'
#' `hb_column_types()` builds a tibble. Reading a base means one type
#' lookup per cell - the real example file is 330 columns x 839 rows - so
#' the derived vectors are computed once and reused.
#'
#' @keywords internal
#' @noRd
.hb_type_cache <- new.env(parent = emptyenv())

#' @keywords internal
#' @noRd
.hb_type_lookup <- function() {
  if (is.null(.hb_type_cache$r_type)) {
    types <- hb_column_types()
    .hb_type_cache$r_type <- stats::setNames(
      sub("<.*", "", types$r), types$seatable
    )
    .hb_type_cache$is_list <- stats::setNames(types$is_list, types$seatable)
    .hb_type_cache$read_only <- types$seatable[types$read_only]
    .hb_type_cache$list_types <- types$seatable[types$is_list]
  }
  .hb_type_cache
}

#' The R type name harbouR reads a SeaTable type as
#'
#' Derived from [hb_column_types()], so the mapping cannot drift from the
#' documentation.
#'
#' @param type A SeaTable column type.
#' @return A single string.
#' @keywords internal
#' @noRd
.hb_r_type <- function(type) {
  # An unrecognised type - a future SeaTable release, or a typo - reads as
  # text rather than erroring, so a new column type cannot break a read.
  hit <- .hb_type_lookup()$r_type[type %||% "text"]
  if (is.na(hit)) "character" else unname(hit)
}

#' @keywords internal
#' @noRd
.hb_empty_vector_for_type <- function(type) {
  .hb_prototype(type)
}

#' Parse a SeaTable date value
#'
#' SeaTable writes dates in several shapes depending on the column's own
#' format, and the system columns `_ctime` / `_mtime` use full ISO-8601
#' with a UTC offset - `2025-11-28T14:00:24.395+00:00`. The previous
#' `orders` list covered none of the offset-bearing forms, so every
#' creation and modification time read as `NA`.
#'
#' @param x A scalar date value: string, number, or `POSIXt`.
#' @param tz Time zone to interpret naive strings in. Values that carry an
#'   offset are converted from it.
#' @return A length-1 `POSIXct`, possibly `NA`.
#' @keywords internal
#' @noRd
.hb_parse_date_value <- function(x, tz = "UTC") {
  if (is.null(x) || length(x) == 0L) {
    return(.POSIXct(NA_real_, tz = tz))
  }
  if (inherits(x, "POSIXt")) {
    return(as.POSIXct(x))
  }
  if (inherits(x, "Date")) {
    return(as.POSIXct(format(x), tz = tz))
  }
  if (is.numeric(x)) {
    return(.POSIXct(as.double(x), tz = tz))
  }
  s <- as.character(x)
  if (!nzchar(s) || is.na(s)) {
    return(.POSIXct(NA_real_, tz = tz))
  }
  # ymd_hms handles the T separator, fractional seconds and offsets; the
  # fallbacks cover date-time without seconds and date-only columns.
  parsed <- suppressWarnings(lubridate::ymd_hms(s, tz = tz, quiet = TRUE))
  if (is.na(parsed)) {
    parsed <- suppressWarnings(lubridate::ymd_hm(s, tz = tz, quiet = TRUE))
  }
  if (is.na(parsed)) {
    day <- suppressWarnings(lubridate::ymd(s, tz = tz, quiet = TRUE))
    parsed <- if (is.na(day)) .POSIXct(NA_real_, tz = tz) else as.POSIXct(day)
  }
  as.POSIXct(parsed)
}

#' Coerce one SeaTable cell to its R representation
#'
#' @param value The raw JSON value, or `NULL` when the cell is absent.
#' @param type The SeaTable column type.
#' @param tz Time zone for date parsing.
#' @return A length-1 vector, or a list for list-typed columns. Empty and
#'   populated cells of the same column always agree in type.
#' @keywords internal
#' @noRd
.hb_coerce_cell <- function(value, type, tz = "UTC") {
  type <- type %||% "text"
  # An absent cell yields the column's prototype, so the empty and
  # populated branches cannot disagree about the resulting type.
  if (is.null(value) || length(value) == 0L) {
    # A list-column's *elements* are vectors, so an empty multiple-select
    # cell is character(0) - matching what a populated one yields - while
    # the column prototype used for a row-less table is list().
    if (type %in% c("multiple-select", "collaborator", "image")) {
      return(character())
    }
    if (type %in% .hb_list_types()) {
      return(list())
    }
    return(switch(
      .hb_r_type(type),
      double = NA_real_,
      integer = NA_integer_,
      logical = NA,
      POSIXct = .POSIXct(NA_real_, tz = tz),
      NA_character_
    ))
  }
  if (type %in% c("date", "ctime", "mtime")) {
    return(.hb_parse_date_value(value, tz = tz))
  }
  # long-text arrives either as a plain string or as an object carrying
  # the rendered text alongside its images, links and checklist.
  if (type == "long-text" && is.list(value)) {
    return(as.character(value$text %||% NA_character_))
  }
  if (type %in% c("multiple-select", "collaborator", "image")) {
    return(as.character(unlist(value, use.names = FALSE)))
  }
  if (type %in% .hb_list_types()) {
    return(if (is.list(value)) unname(value) else list(value))
  }
  switch(
    .hb_r_type(type),
    double = tryCatch(as.double(value),
      warning = function(cnd) NA_real_,
      error = function(cnd) NA_real_
    ),
    integer = tryCatch(as.integer(value),
      warning = function(cnd) NA_integer_,
      error = function(cnd) NA_integer_
    ),
    logical = isTRUE(as.logical(value)),
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
.hb_rows_to_tibble <- function(rows, columns, by = c("name", "key"),
                               tz = "UTC") {
  by <- rlang::arg_match(by)
  if (length(columns) == 0L) {
    # Documented to always carry _id, so a column-less table is 0 x 1,
    # not 0 x 0.
    return(tibble::tibble(`_id` = character()))
  }
  col_names <- .hb_chr_field(columns, "name")
  col_types <- .hb_chr_field(columns, "type", default = "text")
  # The API keys cells by display name; a .dtable file keys them by the
  # column's 4-character key. One lookup vector serves both.
  lookup <- if (by == "key") .hb_chr_field(columns, "key") else col_names

  out <- vector("list", length(columns))
  names(out) <- col_names
  for (i in seq_along(columns)) {
    type <- col_types[[i]]
    if (length(rows) == 0L) {
      out[[i]] <- .hb_prototype(type)
      next
    }
    field <- lookup[[i]]
    # A cell that was never filled in is absent from the row object
    # entirely, not present as null, so [[ ]] returning NULL is normal.
    raw <- lapply(rows, function(row) row[[field]])
    coerced <- lapply(raw, .hb_coerce_cell, type = type, tz = tz)
    out[[i]] <- .hb_collect_column(coerced, type, tz = tz)
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
  tibble::as_tibble(out, .name_repair = "minimal")
}

#' Assemble coerced cells into one column of the right type
#'
#' @param coerced A list of coerced cell values, one per row.
#' @param type The SeaTable column type.
#' @param tz Time zone for date columns.
#' @return An atomic vector, or a list for list-typed columns.
#' @keywords internal
#' @noRd
.hb_collect_column <- function(coerced, type, tz = "UTC") {
  if (type %in% .hb_list_types()) {
    return(coerced)
  }
  switch(
    .hb_r_type(type),
    double = .hb_first(coerced, NA_real_, as.double, double(1)),
    integer = .hb_first(coerced, NA_integer_, as.integer, integer(1)),
    logical = .hb_first(coerced, NA, isTRUE, logical(1)),
    POSIXct = {
      # One vectorised construction rather than a closure per cell: the
      # real example base is 330 columns x 839 rows.
      seconds <- vapply(
        coerced,
        function(value) {
          if (length(value) == 0L) NA_real_ else as.double(value[[1L]])
        },
        double(1)
      )
      .POSIXct(seconds, tz = tz)
    },
    .hb_first(coerced, NA_character_, as.character, character(1))
  )
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
      row[[cn]] <- .hb_serialise_cell(data[[cn]][[r]], col_types[[i]])
    }
    rows[[r]] <- row
  }
  rows
}

#' Serialise one R value into the JSON shape SeaTable expects
#'
#' The write path used to `unlist()` every list-valued cell. That is right
#' for a multiple-select column, whose value is a character vector, but it
#' destroys a `file` cell: a list of `{name, size, type, url}` objects
#' flattens to `c("report.pdf", "12345", "application/pdf", "https://...")`.
#' `geolocation` and `link` cells break the same way. The type decides.
#'
#' @param value One cell's value, taken from a data frame column.
#' @param type The SeaTable column type.
#' @return A value ready to be passed to `jsonlite`.
#' @keywords internal
#' @noRd
.hb_serialise_cell <- function(value, type) {
  if (inherits(value, c("Date", "POSIXt"))) {
    return(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }
  # Structured cells stay structured. Their elements are objects, and each
  # one must reach the server as an object.
  if (type %in% c("file", "image", "geolocation", "link", "digital-sign")) {
    if (is.null(value)) {
      return(list())
    }
    if (!is.list(value)) {
      return(as.list(value))
    }
    return(unname(value))
  }
  # Flat list-columns - multiple-select, collaborator - are vectors of
  # scalars, so flattening is exactly right.
  if (type %in% c("multiple-select", "collaborator")) {
    if (is.null(value)) {
      return(list())
    }
    return(as.list(unlist(value, use.names = FALSE)))
  }
  if (is.list(value)) {
    value <- unlist(value, use.names = FALSE)
  }
  value
}
