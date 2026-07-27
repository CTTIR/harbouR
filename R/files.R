#' Upload a file to SeaTable
#'
#' Uploads `path` to the active base and returns the SeaTable file object
#' (a named list with `name`, `size`, `type` and `url`) ready to be written
#' into a `file`-typed cell via [hb_update_rows()] or [hb_attach_file()].
#'
#' @inheritParams hb_metadata
#' @param path Local file path. Must exist.
#' @param relative_path Optional path on the SeaTable side; defaults to
#'   `"files"`.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @return A named list describing the uploaded asset.
#' @family files
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_upload_file(client, "report.pdf")
#' @export
hb_upload_file <- function(client, path, ..., relative_path = "files") {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(path)
  if (!file.exists(path)) {
    hb_abort(
      c("File not found.",
        "x" = "{.path {path}}"
      ),
      class = "harbour_error_not_found"
    )
  }
  .check_string(relative_path)
  link <- .hb_request(client, "/api/v2.1/dtable/app-upload-link/",
    service = "web", auth = "base", method = "GET"
  )
  upload_url <- link$upload_link %||% link$url
  parent_dir <- link$parent_path %||% "/"
  if (is.null(upload_url)) {
    hb_abort("SeaTable did not return an upload URL.",
      class = "harbour_error_http"
    )
  }
  # The upload link reports where images and other files are meant to go.
  # Using it rather than a hard-coded "files" is what puts an image in the
  # images tree, where an image column expects to find it.
  if (identical(relative_path, "files")) {
    relative_path <- if (.hb_is_image(path)) {
      link$img_relative_path %||% "images"
    } else {
      link$file_relative_path %||% "files"
    }
  }
  # Without ret-json the endpoint answers with the stored filename as plain
  # text, not JSON, so the response could never be parsed.
  req <- httr2::request(upload_url) |>
    httr2::req_url_query(`ret-json` = 1L) |>
    httr2::req_user_agent(.hb_user_agent()) |>
    httr2::req_headers(
      Authorization = .hb_auth_header(client, "base")
    ) |>
    httr2::req_body_multipart(
      file = curl::form_file(path),
      parent_dir = parent_dir,
      relative_path = relative_path,
      replace = "0"
    )
  resp <- .hb_perform_raw(req)
  body <- .hb_resp_json(resp)
  entry <- if (length(body) > 0L) body[[1L]] else list()
  name <- as.character(entry$name %||% basename(path))
  list(
    name = name,
    size = entry$size %||% file.info(path)$size,
    type = entry$type %||% .hb_guess_mime(path),
    url = .hb_asset_url(client, relative_path, name)
  )
}

#' Build the asset URL for a freshly uploaded file
#'
#' The upload endpoint returns only `name`, `id` and `size`. The URL a
#' file-typed cell needs has to be assembled from the workspace id, the
#' base UUID and the path the file was uploaded to.
#'
#' @param client A `harbour_client`.
#' @param relative_path Path under the base's asset root.
#' @param name The stored file name, which may differ from the local one
#'   if SeaTable had to deduplicate it.
#' @return A single string.
#' @keywords internal
#' @noRd
.hb_asset_url <- function(client, relative_path, name) {
  workspace <- client$.workspace_id
  uuid <- client$base_uuid
  if (is.null(workspace) || is.null(uuid)) {
    return(NA_character_)
  }
  paste0(
    client$server,
    "/workspace/", workspace,
    "/asset/", uuid,
    "/", relative_path,
    "/", .hb_url_escape(name)
  )
}

#' Does this path look like an image to SeaTable?
#'
#' @param path A file path.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_is_image <- function(path) {
  ext <- tolower(tools::file_ext(path))
  ext %in% c("png", "jpg", "jpeg", "gif", "bmp", "webp", "svg")
}

#' @keywords internal
#' @noRd
.hb_guess_mime <- function(path) {
  ext <- tolower(tools::file_ext(path))
  switch(ext,
    "pdf" = "application/pdf",
    "png" = "image/png",
    "jpg" = ,
    "jpeg" = "image/jpeg",
    "gif" = "image/gif",
    "csv" = "text/csv",
    "tsv" = "text/tab-separated-values",
    "txt" = "text/plain",
    "md" = "text/markdown",
    "json" = "application/json",
    "xlsx" = paste0(
      "application/vnd.openxmlformats-officedocument",
      ".spreadsheetml.sheet"
    ),
    "application/octet-stream"
  )
}

#' Attach a file to a cell
#'
#' Convenience: uploads `path` then writes the resulting file object into
#' the given file/image column of the chosen row.
#'
#' @inheritParams hb_upload_file
#' @param table Table name.
#' @param row_id Row ID.
#' @param column File or image column name.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family files
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_attach_file(client, "Samples", "abc", "Report", "report.pdf")
#' @export
hb_attach_file <- function(client, table, row_id, column, path, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(table)
  .check_string(row_id)
  .check_string(column)
  obj <- hb_upload_file(client, path)
  data <- tibble::tibble(`_id` = row_id)
  data[[column]] <- list(obj)
  hb_update_rows(client, table, data)
  invisible(client)
}

#' Download an asset
#'
#' @inheritParams hb_metadata
#' @param url Asset URL (as returned by SeaTable in a file/image cell).
#' @param dest Destination path. Parent directories are created if needed.
#' @param overwrite Refuse to clobber an existing file unless `TRUE`.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns `dest`.
#' @family files
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_download_file(client, "https://...", tempfile())
#' @export
hb_download_file <- function(client, url, dest, ..., overwrite = FALSE) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(url)
  .check_string(dest)
  .check_flag(overwrite)
  if (file.exists(dest) && !overwrite) {
    hb_abort(
      c("Destination already exists.",
        "x" = "{.path {dest}}",
        "i" = "Pass {.code overwrite = TRUE} to replace it."
      ),
      class = "harbour_error_bad_argument"
    )
  }
  parent <- dirname(dest)
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE)
  req <- httr2::request(url) |>
    httr2::req_user_agent(.hb_user_agent()) |>
    httr2::req_timeout(client$timeout %||% 30)
  resp <- httr2::req_perform(req, path = dest)
  if (httr2::resp_status(resp) >= 400L) {
    hb_abort(
      c("Download failed.",
        "x" = "HTTP {httr2::resp_status(resp)}"
      ),
      class = "harbour_error_bad_argument"
    )
  }
  invisible(dest)
}

#' Delete an asset
#'
#' @inheritParams hb_download_file
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family files
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_delete_asset(client, "https://server/path/to/file.pdf")
#' @export
hb_delete_asset <- function(client, url, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(url)
  .hb_request(client, "/api/v2.1/dtable/app-asset/",
    service = "web", auth = "base", method = "DELETE",
    query = list(path = .hb_asset_path(url))
  )
  invisible(client)
}

#' Reduce an asset URL to the path SeaTable's asset endpoints take
#'
#' Cells store a full URL; the delete endpoint wants only the part below
#' the base's asset root.
#'
#' @param url A full asset URL, or an already-relative path.
#' @return A single string beginning with `/`.
#' @keywords internal
#' @noRd
.hb_asset_path <- function(url) {
  stripped <- sub("^https?://[^/]+", "", url)
  relative <- sub("^/workspace/[^/]+/asset/[^/]+", "", stripped)
  if (!nzchar(relative)) relative <- stripped
  if (!startsWith(relative, "/")) relative <- paste0("/", relative)
  relative
}
