#' Generate a SeaTable row identifier
#'
#' Row ids in real exports are 22-character URL-safe base64 strings. All
#' 839 in the reference file decode to 16 bytes, and every one of a
#' 200-row sample is an RFC-4122 version-4 UUID, so that is what harbouR
#' generates: 16 random bytes with the version and variant bits set,
#' base64url-encoded, padding stripped.
#'
#' @return A single 22-character string.
#' @keywords internal
#' @noRd
.hb_new_row_id <- function() {
  bytes <- as.raw(sample.int(256L, 16L, replace = TRUE) - 1L)
  # RFC 4122: version 4 in the high nibble of byte 7, variant 10 in the
  # top bits of byte 9.
  bytes[[7L]] <- as.raw(bitwOr(bitwAnd(as.integer(bytes[[7L]]), 0x0f), 0x40))
  bytes[[9L]] <- as.raw(bitwOr(bitwAnd(as.integer(bytes[[9L]]), 0x3f), 0x80))
  .hb_base64url(bytes)
}

#' Base64url-encode raw bytes without padding
#'
#' @param bytes A raw vector.
#' @return A single string using the URL-safe alphabet.
#' @keywords internal
#' @noRd
.hb_base64url <- function(bytes) {
  standard <- jsonlite::base64_enc(bytes)
  out <- gsub("+", "-", standard, fixed = TRUE)
  out <- gsub("/", "_", out, fixed = TRUE)
  gsub("=", "", out, fixed = TRUE)
}

#' The alphabet SeaTable draws short identifiers from
#'
#' @keywords internal
#' @noRd
.hb_id_alphabet <- c(0:9, letters, LETTERS)

#' Generate a short identifier not already in use
#'
#' Column keys, table ids and view ids are all four characters. Generated
#' by rejection sampling so a collision is impossible rather than
#' improbable.
#'
#' @param existing Character vector of identifiers already taken.
#' @param n Length of the identifier.
#' @return A single string.
#' @keywords internal
#' @noRd
.hb_new_short_id <- function(existing = character(), n = 4L) {
  repeat {
    candidate <- paste(
      sample(.hb_id_alphabet, n, replace = TRUE),
      collapse = ""
    )
    if (!candidate %in% existing) {
      return(candidate)
    }
  }
}

#' Generate a column key
#'
#' The first column of a table is always keyed `"0000"` - true of all ten
#' tables in the reference file - so a table's first column takes that key
#' and every later one is random.
#'
#' @param existing Keys already used in the table.
#' @return A single 4-character string.
#' @keywords internal
#' @noRd
.hb_new_column_key <- function(existing = character()) {
  if (length(existing) == 0L) {
    return("0000")
  }
  .hb_new_short_id(existing)
}

#' Generate a table id
#'
#' @param existing Ids already used in the base.
#' @return A single 4-character string.
#' @keywords internal
#' @noRd
.hb_new_table_id <- function(existing = character()) {
  .hb_new_short_id(existing)
}

#' Generate a view id
#'
#' A table's first view is always `"0000"`, matching SeaTable's own
#' default view.
#'
#' @param existing Ids already used in the table.
#' @return A single 4-character string.
#' @keywords internal
#' @noRd
.hb_new_view_id <- function(existing = character()) {
  if (length(existing) == 0L) {
    return("0000")
  }
  .hb_new_short_id(existing)
}

#' Current time in the format SeaTable writes into `_ctime` / `_mtime`
#'
#' @return A single string, e.g. `2026-07-27T18:00:00.000+00:00`.
#' @keywords internal
#' @noRd
.hb_dtable_timestamp <- function(time = Sys.time()) {
  paste0(
    format(as.POSIXct(time, tz = "UTC"), "%Y-%m-%dT%H:%M:%OS3"),
    "+00:00"
  )
}
