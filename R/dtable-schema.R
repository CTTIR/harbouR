#' The .dtable container format
#'
#' A `.dtable` file is a ZIP archive. It always contains `content.json`,
#' the complete base - every table, column, row and view - and may also
#' contain an `asset/` tree holding the files and images that
#' attachment columns point at.
#'
#' These constants record what was observed in real exports. They are used
#' for validation and for building files from scratch; the reader never
#' relies on them, because it keeps the parsed tree verbatim.
#'
#' @keywords internal
#' @noRd
.hb_dtable_entry <- "content.json"

#' @keywords internal
#' @noRd
.hb_dtable_asset_dir <- "asset"

#' The `format_version` harbouR was written against
#'
#' A newer file is read anyway - the tree is kept verbatim - but the user
#' is warned that harbouR may not understand everything in it.
#'
#' @keywords internal
#' @noRd
.hb_dtable_format_version <- 9L

#' Top-level keys of `content.json`
#'
#' Not a closed set: real bases add `settings` and `plugin_settings`, and
#' future releases will add more. Used only to report what is missing.
#'
#' @keywords internal
#' @noRd
.hb_dtable_top_keys <- c(
  "version", "format_version", "statistics", "links", "tables",
  "collaborators"
)

#' Row fields SeaTable maintains itself
#'
#' These are never written back from user data.
#'
#' @keywords internal
#' @noRd
.hb_dtable_row_system_fields <- c(
  "_id", "_participants", "_creator", "_ctime", "_last_modifier", "_mtime"
)

#' Slots that must serialise as a JSON object, never an array
#'
#' `jsonlite` writes `list()` as `[]`. SeaTable's importer expects `{}` in
#' these slots, so anything harbouR constructs must use
#' `.hb_empty_object()`. Round-tripping a file that was read is safe,
#' because `fromJSON()` gives an empty *named* list.
#'
#' @keywords internal
#' @noRd
.hb_dtable_object_slots <- list(
  table = c("id_row_map", "summary_configs", "header_settings"),
  view = c(
    "formula_rows", "summaries", "colors", "column_colors", "link_rows",
    "colorbys"
  )
)

#' An empty JSON object, as opposed to an empty array
#'
#' `jsonlite::toJSON(list())` is `[]`; only a zero-length *named* list
#' becomes `{}`.
#'
#' @return A zero-length named list.
#' @keywords internal
#' @noRd
.hb_empty_object <- function() {
  structure(list(), names = character())
}

#' An empty JSON array
#'
#' @return A zero-length unnamed list.
#' @keywords internal
#' @noRd
.hb_empty_array <- function() {
  list()
}

#' Force a value to serialise as a JSON array
#'
#' `auto_unbox = TRUE` collapses a length-1 atomic vector to a scalar, so a
#' `multiple-select` cell holding one option would be written as
#' `"urgent"` rather than `["urgent"]` - a different JSON type. Wrapping in
#' a list keeps it an array at any length.
#'
#' @param x A vector or list.
#' @return An unnamed list.
#' @keywords internal
#' @noRd
.hb_as_json_array <- function(x) {
  if (is.null(x)) {
    return(.hb_empty_array())
  }
  if (is.list(x)) {
    return(unname(x))
  }
  as.list(unname(x))
}

#' Serialise a parsed .dtable tree to JSON
#'
#' The settings are not options. Each one defends against a defect
#' measured on a real 750 KB export:
#'
#' * `digits = 17` - the default of 4 turns `0.0005874747474747475` into
#'   `0.0006`, and `digits = NA` alters 6097 of the file's 8027 numeric
#'   cells. 16 and 17 both round-trip exactly; 17 is the IEEE-754
#'   guarantee for a double.
#' * `na = "null"` - without it `NA_real_` is written as the *string*
#'   `"NA"`.
#' * `null = "null"` - keeps explicit nulls rather than dropping the key.
#' * `auto_unbox = TRUE` - SeaTable writes scalars as scalars; without
#'   this every value would become a one-element array.
#'
#' @param x A parsed `content.json` tree.
#' @return A single JSON string.
#' @keywords internal
#' @noRd
.hb_dtable_to_json <- function(x) {
  jsonlite::toJSON(
    x,
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = 17L,
    pretty = FALSE
  )
}

#' Parse `content.json` bytes
#'
#' Read as raw and convert explicitly, so the result never depends on the
#' session locale.
#'
#' @param bytes A raw vector.
#' @return The parsed tree, with no simplification.
#' @keywords internal
#' @noRd
.hb_dtable_from_json <- function(bytes) {
  jsonlite::fromJSON(
    rawToChar(bytes),
    simplifyVector = FALSE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
  )
}
