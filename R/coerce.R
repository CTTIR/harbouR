#' SeaTable column types and how harbouR maps them
#'
#' The single source of truth for the coercion layer: one row per type
#' name, giving the R type harbouR produces when reading, whether that R
#' type is a list-column, and whether harbouR leaves the column out of
#' writes. The coercion functions and the column-types vignette are both
#' derived from this table, so they cannot drift apart.
#'
#' `percent`, `dollar` and `euro` are number formats rather than column
#' types: SeaTable reports such a column as type `"number"`, with the
#' format in its `data$format`. They are listed so that tables carrying
#' them as a type still coerce.
#'
#' A `date` column reads as `POSIXct` in UTC. When the column's format has
#' no time part, the cell holds a calendar date, and harbouR reads the date
#' SeaTable shows as midnight UTC, whatever UTC offset the server sends
#' with it, so [as.Date()] gives that date. A date-time read from a server
#' is an instant and is converted to UTC; a date-time stored without an
#' offset, as in a `.dtable` file, is read as UTC. A column that reports
#' no format is read as a date-time.
#'
#' Written to a date-only column, a `Date` is sent as itself and a
#' date-time as the date it shows in its own time zone, except one at
#' exactly midnight UTC, which keeps its UTC date: a cell read and written
#' back keeps its day. A date-time column is sent the instant, in UTC.
#'
#' @return A tibble with one row per type and columns:
#'   \describe{
#'     \item{`seatable`}{chr. The type name as SeaTable reports it, or one
#'       of the number formats above.}
#'     \item{`r`}{chr. The R type harbouR reads it as.}
#'     \item{`is_list`}{lgl. Whether the result is a list-column.}
#'     \item{`read_only`}{lgl. Whether harbouR leaves the column out of
#'       writes. Most of these are computed or maintained by SeaTable; a
#'       `digital-sign` cell is left out because a signature should come
#'       from the signer.}
#'     \item{`notes`}{chr. Anything worth knowing.}
#'   }
#' @family metadata
#' @examples
#' hb_column_types()
#'
#' # the types harbouR does not write
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
    "TRUE/FALSE; an unset box reads as FALSE",
    "date", "POSIXct", FALSE, FALSE,
    "UTC; date-only columns have a zero time component",
    "single-select", "character", FALSE, FALSE,
    "not validated on write: SeaTable adds an unknown name as a new option",
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
    "signature metadata; not written, since it should come from the signer",
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

#' The display format a column reports, if any
#'
#' @param column A column object.
#' @return A single string, or `NULL`.
#' @keywords internal
#' @noRd
.hb_column_format <- function(column) {
  data <- column[["data"]]
  if (!is.list(data)) {
    return(NULL)
  }
  format <- data[["format"]]
  if (!is.character(format) || length(format) != 1L || is.na(format)) {
    return(NULL)
  }
  format
}

#' Does a date format show a calendar date with no time?
#'
#' SeaTable's date formats are moment.js patterns - `YYYY-MM-DD`,
#' `M/D/YYYY`, `DD/MM/YYYY` and `DD.MM.YYYY`, each optionally followed by
#' ` HH:mm` - and only the time tokens use `H`, `h`, `k`, `m` or `s`. A
#' missing or empty format says nothing either way, so it is not taken
#' as date-only.
#'
#' @param format A single string, or `NULL`.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_date_only_format <- function(format) {
  !is.null(format) && nzchar(format) && !grepl("[Hhkms]", format)
}

# A timestamp that carries a UTC offset, the shape the API sends:
# 2030-06-20T00:00:00+02:00, or with a Z. A .dtable stores dates without
# one.
.hb_offset_timestamp <- paste0(
  "^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}",
  "(:[0-9]{2}([.,][0-9]+)?)? ?(Z|[+-][0-9]{2}(:?[0-9]{2})?)$"
)

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
#' @param date_only Whether the column shows a calendar date with no time.
#'   The API sends such a cell as local midnight with the server's UTC
#'   offset; converting that instant to UTC put it on the previous day
#'   on any server east of UTC. The written date is kept instead.
#' @return A length-1 `POSIXct`, possibly `NA`.
#' @keywords internal
#' @noRd
.hb_parse_date_value <- function(x, tz = "UTC", date_only = FALSE) {
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
  if (date_only && grepl(.hb_offset_timestamp, s)) {
    # The leading YYYY-MM-DD is the date SeaTable shows. It is read with
    # the same call as a naive date-only string below: midnight in `tz`.
    day <- suppressWarnings(
      lubridate::ymd(substr(s, 1L, 10L), tz = tz, quiet = TRUE)
    )
    parsed <- if (is.na(day)) .POSIXct(NA_real_, tz = tz) else as.POSIXct(day)
    return(as.POSIXct(parsed))
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
#' @param date_only For a `date` column, whether its format has no time
#'   part; see `.hb_parse_date_value()`.
#' @return A length-1 vector, or a list for list-typed columns. Empty and
#'   populated cells of the same column always agree in type.
#' @keywords internal
#' @noRd
.hb_coerce_cell <- function(value, type, tz = "UTC", date_only = FALSE) {
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
      # SeaTable shows a box that was never ticked as unticked, and a whole
      # column has always read it as FALSE, so a single cell does too.
      logical = FALSE,
      POSIXct = .POSIXct(NA_real_, tz = tz),
      NA_character_
    ))
  }
  if (type %in% c("date", "ctime", "mtime")) {
    # Creation and modification times are instants, whatever their format.
    return(.hb_parse_date_value(
      value,
      tz = tz, date_only = date_only && identical(type, "date")
    ))
  }
  # long-text arrives either as a plain string or as an object carrying
  # the rendered text alongside its images, links and checklist.
  if (type == "long-text" && is.list(value)) {
    return(.hb_cell_text(value$text))
  }
  if (type %in% c("multiple-select", "collaborator", "image")) {
    return(as.character(unlist(value, use.names = FALSE)))
  }
  if (identical(type, "geolocation")) {
    # One object. A stored [null], or anything else without field names,
    # holds no position. lng and lat come first, in that order - the one a
    # .dtable stores and SeaTable's "lng_lat" format names - because its
    # endpoints send them in different orders.
    if (!is.list(value) || is.null(names(value))) {
      return(list())
    }
    first <- intersect(c("lng", "lat"), names(value))
    return(value[c(first, setdiff(names(value), first))])
  }
  if (type %in% .hb_list_types()) {
    # Names are kept: a geolocation or digital-sign cell is one JSON object,
    # and stripping its names would leave c(50, 8.23) with no way to tell
    # latitude from longitude.
    return(if (is.list(value)) value else list(value))
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
    .hb_cell_text(value)
  )
}

#' Read a cell as text
#'
#' The API leaves an empty cell out of the row, while a `.dtable` stores
#' it as `""`; both read as `NA`. A number - a formula's result, say - is
#' written in full rather than as `1.5e+10`, and an array result keeps
#' every element.
#'
#' @param value One raw cell value.
#' @return A single string, possibly `NA`.
#' @keywords internal
#' @noRd
.hb_cell_text <- function(value) {
  if (is.list(value)) {
    value <- unlist(value, use.names = FALSE)
  }
  text <- if (is.numeric(value)) .hb_number_text(value) else as.character(value)
  text <- text[!is.na(text)]
  if (length(text) == 0L) {
    return(NA_character_)
  }
  text <- paste(text, collapse = ", ")
  if (nzchar(text)) text else NA_character_
}

#' Write numbers as text, in full and without an exponent
#'
#' @param value A numeric or `integer64` vector.
#' @return A character vector as long as `value`, `NA` where it is missing.
#' @keywords internal
#' @noRd
.hb_number_text <- function(value) {
  out <- if (inherits(value, "integer64")) {
    as.character(value)
  } else {
    vapply(
      value,
      function(number) format(number, digits = 15, scientific = FALSE, trim = TRUE),
      character(1)
    )
  }
  out[is.na(value)] <- NA_character_
  unname(out)
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
    coerced <- if (type %in% c("date", "ctime", "mtime")) {
      date_only <- identical(type, "date") &&
        .hb_date_only_format(.hb_column_format(columns[[i]]))
      .hb_coerce_dates(raw, type, tz = tz, date_only = date_only)
    } else {
      lapply(raw, .hb_coerce_cell, type = type, tz = tz)
    }
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

#' Coerce a column of date cells, parsing each distinct string once
#'
#' Date parsing is the slowest step of a read - up to three lubridate
#' calls per cell - and a column's dates often repeat. Each distinct string
#' is coerced once and the result is mapped back to every cell holding it,
#' so a cell gets exactly what coercing it on its own gives.
#'
#' @param raw A list of raw cell values, one per row.
#' @param type `"date"`, `"ctime"` or `"mtime"`.
#' @param tz,date_only Passed to `.hb_coerce_cell()`.
#' @return A list of coerced cells, as long as `raw`.
#' @keywords internal
#' @noRd
.hb_coerce_dates <- function(raw, type, tz = "UTC", date_only = FALSE) {
  plain <- vapply(
    raw,
    function(value) {
      is.character(value) && length(value) == 1L && is.null(attributes(value))
    },
    logical(1)
  )
  out <- vector("list", length(raw))
  out[!plain] <- lapply(
    raw[!plain], .hb_coerce_cell,
    type = type, tz = tz, date_only = date_only
  )
  strings <- as.character(unlist(raw[plain], use.names = FALSE))
  distinct <- unique(strings)
  parsed <- lapply(
    distinct, .hb_coerce_cell,
    type = type, tz = tz, date_only = date_only
  )
  out[plain] <- parsed[match(strings, distinct)]
  out
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
    logical = .hb_first(coerced, FALSE, isTRUE, logical(1)),
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
.hb_tibble_to_rows <- function(data, columns, call = rlang::caller_env()) {
  if (!is.data.frame(data)) {
    hb_abort("{.arg data} must be a data frame or tibble.",
      class = "harbour_error_bad_argument"
    )
  }
  col_names <- .hb_chr_field(columns, "name")
  col_types <- .hb_chr_field(columns, "type", default = "text")
  write <- col_names %in% names(data) & !col_types %in% .hb_readonly_types()
  .hb_serialise_rows(
    data, stats::setNames(col_types[write], col_names[write]),
    date_only = .hb_date_only_columns(columns),
    call = call
  )
}

#' The date columns whose format shows a calendar date with no time
#'
#' @param columns Column objects.
#' @return A character vector of column names.
#' @keywords internal
#' @noRd
.hb_date_only_columns <- function(columns) {
  keep <- vapply(
    columns,
    function(col) {
      identical(col[["type"]], "date") &&
        .hb_date_only_format(.hb_column_format(col))
    },
    logical(1)
  )
  .hb_chr_field(columns[keep], "name")
}

#' Serialise the cells of a data frame, one named list per row
#'
#' A cell that cannot be sent as it is - a number JSON cannot represent,
#' or a checkbox string that is neither TRUE nor FALSE - is reported once
#' for the whole write, naming the columns, rather than once per cell.
#'
#' @param data A data frame.
#' @param types The SeaTable type of each column to write, named by
#'   column. Each row object lists its cells in this order.
#' @param date_only The names of the date columns whose format has no
#'   time part.
#' @param call The frame to blame in a warning.
#' @return A list with one named list per row of `data`.
#' @keywords internal
#' @noRd
.hb_serialise_rows <- function(data, types, date_only = character(),
                               call = rlang::caller_env()) {
  names_ <- names(types)
  # A difftime column is converted while it is whole: taking one cell out
  # with [[ ]] drops its units.
  vectors <- lapply(seq_along(types), function(j) {
    values <- data[[names_[[j]]]]
    if (inherits(values, "difftime")) {
      values <- .hb_difftime_value(values, types[[j]])
    }
    # A date-only cell is sent as the calendar date, the form SeaTable
    # documents for it. With a time and a zone attached, a server that
    # converts the instant to its own zone could store another day.
    if (names_[[j]] %in% date_only && inherits(values, c("Date", "POSIXt"))) {
      values <- .hb_calendar_date(values)
    }
    values
  })
  # An environment rather than <<-, as in hb_validate_dtable(): each cell
  # reports into it, against the column being serialised.
  state <- new.env(parent = emptyenv())
  state$column <- NA_character_
  state$non_finite <- character()
  state$checkbox <- character()
  state$checkbox_values <- character()
  report <- function(problem, values) {
    state[[problem]] <- union(state[[problem]], state$column)
    if (identical(problem, "checkbox")) {
      state$checkbox_values <- union(state$checkbox_values, values)
    }
  }
  rows <- vector("list", nrow(data))
  for (r in seq_len(nrow(data))) {
    # An object even when no cell is written: an empty list would go out
    # as [], which is no row.
    row <- .hb_empty_object()
    for (j in seq_along(types)) {
      state$column <- names_[[j]]
      row[[names_[[j]]]] <- .hb_serialise_cell(
        vectors[[j]][[r]], types[[j]],
        report = report
      )
    }
    rows[[r]] <- row
  }
  # Name the columns in the order they were written, not found.
  state$non_finite <- intersect(names_, state$non_finite)
  state$checkbox <- intersect(names_, state$checkbox)
  .hb_warn_unsendable(state, call = call)
  rows
}

#' The calendar date a date-only cell is written as
#'
#' A `Date` is its own date. A date-time is the date it shows in its own
#' time zone, so a value built as local midnight keeps its day. One at
#' exactly midnight UTC - how harbouR reads a date-only cell - keeps its
#' UTC date instead, even after it has been moved to another zone.
#'
#' @param values A `Date` or `POSIXt` vector.
#' @return A character vector of `YYYY-MM-DD` dates, `NA` where `values`
#'   is missing.
#' @keywords internal
#' @noRd
.hb_calendar_date <- function(values) {
  out <- format(values, "%Y-%m-%d")
  if (inherits(values, "POSIXt")) {
    # The instant, whatever the class, so that a POSIXlt and a POSIXct of
    # the same moment get the same day; an infinite one is no midnight.
    instants <- as.POSIXct(values)
    seconds <- unclass(instants)
    midnight <- is.finite(seconds) & seconds %% 86400 == 0
    out[midnight] <- format(instants[midnight], "%Y-%m-%d", tz = "UTC")
  }
  out
}

#' Warn, once per write, about cells that could not be sent as they were
#'
#' @param state The environment `.hb_serialise_rows()` collects into: the
#'   columns by problem, and the checkbox values that were not understood.
#' @param call The frame to blame.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_warn_unsendable <- function(state, call) {
  non_finite <- state$non_finite
  if (length(non_finite) > 0L) {
    cli::cli_warn(
      c("{length(non_finite)} column{?s} hold{?s/} Inf, -Inf or NaN, which
         JSON cannot represent: {.field {non_finite}}.",
        "i" = "Those cells are sent as {.code null} and will read back as
               {.val {NA_real_}}."),
      class = "harbour_warning_non_finite",
      columns = non_finite,
      call = call
    )
  }
  checkbox <- state$checkbox
  checkbox_values <- state$checkbox_values
  if (length(checkbox) > 0L) {
    cli::cli_warn(
      c("{length(checkbox)} checkbox column{?s} hold{?s/} values that are
         neither TRUE nor FALSE: {.field {checkbox}}.",
        "i" = "{.val {checkbox_values}} {?is/are} sent as {.code null} and
               will read back as {.code FALSE}."),
      class = "harbour_warning_checkbox_value",
      columns = checkbox,
      call = call
    )
  }
  invisible(NULL)
}

#' Warn about one cell that could not be sent as it was
#'
#' The default `report` of `.hb_serialise_cell()`.
#' `.hb_serialise_rows()` reports for a whole write instead.
#'
#' @param problem `"non_finite"` or `"checkbox"`.
#' @param values The values that could not be sent.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_report_cell <- function(problem, values) {
  if (identical(problem, "non_finite")) {
    # A number in a cli string is taken as the quantity to pluralise by,
    # so the count is given explicitly.
    n <- length(values)
    cli::cli_warn(
      c("{.val {values}} cannot be represented in JSON and
         {cli::qty(n)}{?is/are} sent as {.code null}.",
        "i" = "The cell will read back as {.val {NA_real_}}."),
      class = "harbour_warning_non_finite"
    )
  } else {
    cli::cli_warn(
      c("{.val {values}} {?is/are} neither TRUE nor FALSE and {?is/are}
         sent as {.code null}.",
        "i" = "A checkbox takes {.code TRUE} or {.code FALSE}, or a number,
               where 0 is unticked."),
      class = "harbour_warning_checkbox_value"
    )
  }
  invisible(NULL)
}

#' The number a difftime is sent as
#'
#' SeaTable stores a duration in seconds, while a difftime carries its own
#' units, which subtracting two times in R picks automatically. In another
#' numeric column it is a plain number in its own units; in any other
#' column it is left as it is.
#'
#' @param value A difftime.
#' @param type The SeaTable column type.
#' @return A double vector, or `value` itself.
#' @keywords internal
#' @noRd
.hb_difftime_value <- function(value, type) {
  if (identical(type, "duration")) {
    return(as.numeric(value, units = "secs"))
  }
  if (.hb_r_type(type) %in% c("double", "integer")) {
    return(as.numeric(value))
  }
  value
}

#' Is a value a single file object rather than an array of them?
#'
#' [hb_upload_file()] returns one object - a named list of scalars with
#' `name` and `url` among them - and a file cell holds an array of those.
#'
#' @param value A list.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_is_file_object <- function(value) {
  all(c("name", "url") %in% names(value)) &&
    !any(vapply(value, is.list, logical(1)))
}

#' Serialise a checkbox cell
#'
#' SeaTable honours only a JSON boolean: the number 1 is stored as an
#' unticked box. Numbers are read as harbouR reads them, non-zero being
#' ticked, and strings as [as.logical()] reads them. Anything else is sent
#' as `null` rather than guessed.
#'
#' @param value One cell's value.
#' @param report Called as `report("checkbox", values)` with the values
#'   that were not understood.
#' @return A logical vector, or `NULL` for an empty cell.
#' @keywords internal
#' @noRd
.hb_serialise_checkbox <- function(value, report) {
  if (is.list(value)) {
    value <- unlist(value, use.names = FALSE)
  }
  if (length(value) == 0L) {
    # Left out of the row, as an empty cell of any other scalar type is.
    return(NULL)
  }
  if (is.logical(value)) {
    return(value)
  }
  if (is.numeric(value)) {
    return(value != 0)
  }
  text <- as.character(value)
  out <- as.logical(text)
  # An empty string is a blank cell, not a value to warn about.
  unread <- is.na(out) & !is.na(text) & nzchar(text)
  if (any(unread)) {
    report("checkbox", unique(text[unread]))
  }
  out
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
#' @param report Called as `report(problem, values)` when a cell cannot be
#'   sent as it is. The default warns for this cell alone.
#' @return A value ready to be passed to `jsonlite`.
#' @keywords internal
#' @noRd
.hb_serialise_cell <- function(value, type, report = .hb_report_cell) {
  if (inherits(value, c("Date", "POSIXt"))) {
    # format() of a POSIXlt ignores `tz`, and would label its own
    # wall-clock time as UTC, so it goes through POSIXct. A Date does not:
    # that would turn a fraction of a day into a time.
    if (inherits(value, "POSIXlt")) value <- as.POSIXct(value)
    return(format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }
  # A difftime that arrives whole - a list-column cell, say - still has
  # its units.
  if (inherits(value, "difftime")) {
    value <- .hb_difftime_value(value, type)
  }
  # A geolocation or digital-sign cell is a single object, not an array of
  # them. Unnaming it would send {"lat": 50, "lng": 8.23} as [50, 8.23].
  if (type %in% c("geolocation", "digital-sign")) {
    # Tolerate the object arriving wrapped in a one-element list.
    wrapped <- is.list(value) && is.null(names(value)) &&
      length(value) == 1L && is.list(value[[1L]])
    if (wrapped) {
      value <- value[[1L]]
    }
    # NA, taken from an ordinary vector, is no object: sent as [null] it was
    # stored as a cell that later broke every export of the base.
    missing <- !is.list(value) && all(is.na(value))
    if (length(value) == 0L || missing) {
      # NA reaches the server as null, which clears the cell.
      return(NA)
    }
    return(as.list(value))
  }
  # Array-valued cells stay arrays. A file or link cell's elements are
  # objects, and each one must reach the server as an object.
  if (type %in% c("file", "image", "link")) {
    if (is.null(value)) {
      return(list())
    }
    # Names would turn a vector of image URLs into a JSON object. An NA
    # from an ordinary vector is no attachment, and is left out rather
    # than stored as null.
    if (!is.list(value)) {
      return(as.list(unname(value[!is.na(value)])))
    }
    value <- Filter(function(item) !(is.atomic(item) && all(is.na(item))), value)
    # The object hb_upload_file() returns, written as it is: unnaming it
    # would send its fields as an array of scalars.
    if (identical(type, "file") && .hb_is_file_object(value)) {
      return(list(value))
    }
    return(unname(value))
  }
  # Flat list-columns - multiple-select, collaborator - are vectors of
  # scalars, so flattening is exactly right.
  if (type %in% c("multiple-select", "collaborator")) {
    if (is.null(value)) {
      return(list())
    }
    flat <- unlist(value, use.names = FALSE)
    return(as.list(flat[!is.na(flat)]))
  }
  if (identical(type, "checkbox")) {
    return(.hb_serialise_checkbox(value, report))
  }
  if (is.list(value)) {
    value <- unlist(value, use.names = FALSE)
  }
  # A text column stores what it is given as text. A number sent as one
  # was rounded to a double on the server - an integer64 key past 2^53
  # lost its last digits - and shown in whatever notation JSON used.
  if (identical(.hb_r_type(type), "character") &&
        (is.numeric(value) || inherits(value, "integer64"))) {
    return(.hb_number_text(value))
  }
  if (is.double(value)) {
    # JSON has no Inf or NaN, so the cell is sent as null either way; the
    # point is that a cell quietly emptied on the server gets reported.
    non_finite <- is.infinite(value) | is.nan(value)
    if (any(non_finite)) {
      report("non_finite", unique(value[non_finite]))
      value[non_finite] <- NA_real_
    }
  }
  value
}
