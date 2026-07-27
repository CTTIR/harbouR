#' The SeaTable API surface harbouR targets
#'
#' SeaTable 4.4 introduced the API gateway. 5.2 deprecated the older
#' `/dtable-server/` and `/dtable-db/` services and 5.3 removed them, so
#' every base-scoped call goes through
#' `\{server\}/api-gateway/api/v2/dtables/\{base_uuid\}/...`.
#'
#' Keeping the version in one constant means a future `v3` is a one-line
#' change rather than a sweep across seven files.
#'
#' @keywords internal
#' @noRd
.hb_api_version <- "v2"

#' Resolve the UUID of the base this client is bound to
#'
#' The UUID is not something the user supplies: it comes back from the
#' base-token exchange. If it is not known yet, fetch a base token, which
#' populates it as a side effect.
#'
#' @param client A `harbour_client`.
#' @param call The frame to blame for any error.
#' @return A single string.
#' @keywords internal
#' @noRd
.hb_base_uuid <- function(client, call = rlang::caller_env()) {
  if (is.null(client$base_uuid)) {
    .hb_get_base_token(client, call = call)
  }
  uuid <- client$base_uuid
  if (is.null(uuid) || !nzchar(uuid)) {
    hb_abort(
      c("Could not determine which base this client is bound to.",
        "i" = "The base-token exchange did not report a base UUID.",
        "i" = "Pass {.arg base_uuid} to {.fn hb_client} to set it
               explicitly."),
      class = "harbour_error_auth",
      call = call
    )
  }
  uuid
}

#' Build a base-scoped API path
#'
#' Every base-scoped endpoint lives under the base's UUID. Interpolated
#' segments - a view name, a row id - are percent-encoded, because table
#' and view names may contain spaces, slashes and non-ASCII characters.
#'
#' @param client A `harbour_client`.
#' @param ... Path segments, joined with `/`. A trailing `""` produces the
#'   trailing slash SeaTable expects.
#' @param call The frame to blame for any error.
#' @return A single string beginning with `/api-gateway/`.
#' @keywords internal
#' @noRd
.hb_base_path <- function(client, ..., call = rlang::caller_env()) {
  segments <- c(...)
  uuid <- .hb_base_uuid(client, call = call)
  encoded <- vapply(
    segments,
    function(segment) {
      if (!nzchar(segment)) segment else .hb_url_escape(segment)
    },
    character(1),
    USE.NAMES = FALSE
  )
  paste(
    c("/api-gateway/api", .hb_api_version, "dtables", uuid, encoded),
    collapse = "/"
  )
}

#' Percent-encode one path segment
#'
#' `utils::URLencode(reserved = TRUE)` leaves `/` alone in some R versions
#' and encodes it in others; do it explicitly so a table named `a/b` can
#' never split into two segments.
#'
#' @param x A single string.
#' @return A single percent-encoded string.
#' @keywords internal
#' @noRd
.hb_url_escape <- function(x) {
  chars <- strsplit(enc2utf8(as.character(x)), "", fixed = TRUE)[[1L]]
  safe <- grepl("^[A-Za-z0-9._~-]$", chars)
  out <- vapply(
    seq_along(chars),
    function(i) {
      if (safe[[i]]) {
        chars[[i]]
      } else {
        bytes <- charToRaw(chars[[i]])
        paste0("%", toupper(paste(format(bytes), collapse = "%")))
      }
    },
    character(1)
  )
  paste(out, collapse = "")
}

#' SeaTable's server-side row limits
#'
#' Reads return at most 1000 rows per request and batch writes accept at
#' most 1000 rows per request. Both are server limits, not preferences.
#'
#' @keywords internal
#' @noRd
.hb_max_page_size <- 1000L

#' @rdname dot-hb_max_page_size
#' @keywords internal
#' @noRd
.hb_max_batch_size <- 1000L

#' Split a vector or list into server-sized chunks
#'
#' @param x A vector or list.
#' @param size Maximum elements per chunk.
#' @return A list of chunks. An empty input gives an empty list, so callers
#'   can loop over it without a special case.
#' @keywords internal
#' @noRd
.hb_chunk <- function(x, size = .hb_max_batch_size) {
  n <- length(x)
  if (n == 0L) {
    return(list())
  }
  split(x, ceiling(seq_len(n) / size))
}
