#' Upload a file to SeaTable
#'
#' Uploads `path` to the active base and returns the SeaTable file object
#' (a named list with `name`, `size`, `type` and `url`) ready to be written
#' into a `file`-typed cell via [hb_update_rows()] or [hb_attach_file()].
#'
#' SeaTable's file endpoints authenticate with the base's API token, so
#' this needs a client created with `api_token`; a username/password
#' client gets a `harbour_error_auth` condition.
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
    service = "web", auth = "api", method = "GET"
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
      Authorization = .hb_auth_header(client, "api")
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
    url = .hb_asset_url(
      client, relative_path, name,
      workspace_id = link$workspace_id %||% client$.workspace_id,
      parent_path = link$parent_path
    )
  )
}

#' Build the asset URL for a freshly uploaded file
#'
#' The upload endpoint returns only `name`, `id` and `size`. The URL a
#' file-typed cell needs has to be assembled from the workspace id, the
#' base's asset root and the path the file was uploaded to.
#'
#' @param client A `harbour_client`.
#' @param relative_path Path under the base's asset root.
#' @param name The stored file name, which may differ from the local one
#'   if SeaTable had to deduplicate it.
#' @param workspace_id The base's workspace id. The upload link reports
#'   it; the base-token exchange records it on the client.
#' @param parent_path The base's asset root, `/asset/<base uuid>`, as the
#'   upload link reports it.
#' @return A single string, or `NA` if the location cannot be determined.
#' @keywords internal
#' @noRd
.hb_asset_url <- function(client, relative_path, name,
                          workspace_id = client$.workspace_id,
                          parent_path = NULL) {
  if (is.null(parent_path) && !is.null(client$base_uuid)) {
    parent_path <- paste0("/asset/", client$base_uuid)
  }
  if (is.null(workspace_id) || is.null(parent_path)) {
    return(NA_character_)
  }
  paste0(
    client$server,
    "/workspace/", workspace_id,
    parent_path,
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
#' Convenience: uploads `path` then writes it into the given file or image
#' column of the chosen row. A file column receives the file object; an
#' image column, which holds URLs, receives the image's URL.
#'
#' The cell is **replaced**, not appended to: whatever it held before is
#' no longer referenced by the row, although the earlier upload stays in
#' the base's assets. To keep several attachments, read the cell, add the
#' new object from [hb_upload_file()] and write it back with
#' [hb_update_rows()].
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
  type <- .hb_column_type(client, table, column)
  if (!type %in% c("file", "image")) {
    hb_abort(
      c("Column {.val {column}} cannot hold an attachment.",
        "x" = "It is a {.val {type}} column.",
        "i" = "Attach to a {.val file} or {.val image} column."),
      class = "harbour_error_bad_argument"
    )
  }
  obj <- hb_upload_file(client, path)
  # An image cell is a list of URLs; a file cell is a list of file objects.
  cell <- if (identical(type, "image")) list(obj$url) else list(obj)
  data <- tibble::tibble(`_id` = row_id)
  data[[column]] <- list(cell)
  hb_update_rows(client, table, data)
  invisible(client)
}

#' Download an asset
#'
#' A URL in a file or image cell is not directly downloadable: the asset
#' sits behind SeaTable's login. When `url` points at an asset on the
#' client's server, harbouR first exchanges it, with the client's API
#' token, for a short-lived download link. Any other URL is fetched as it
#' is.
#'
#' The file is written to a temporary name beside `dest` and moved into
#' place only once complete, so a failed download never leaves a partial
#' file and never destroys the file `overwrite = TRUE` would replace.
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
  source <- .hb_download_source(client, url)
  parent <- dirname(dest)
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE)
  partial <- tempfile(".harbour-download-", tmpdir = parent)
  on.exit(unlink(partial), add = TRUE)
  req <- httr2::request(source) |>
    httr2::req_user_agent(.hb_user_agent()) |>
    httr2::req_timeout(client$timeout %||% 30)
  resp <- .hb_perform_raw(req, path = partial)
  if (httr2::resp_status(resp) >= 400L) {
    hb_abort(
      c("Download failed.",
        "x" = "HTTP {httr2::resp_status(resp)}"
      ),
      class = "harbour_error_http",
      status = httr2::resp_status(resp)
    )
  }
  if (!file.rename(partial, dest)) {
    hb_abort(
      c("Could not move the download into place.", "x" = "{.path {dest}}"),
      class = "harbour_error_bad_argument"
    )
  }
  invisible(dest)
}

#' Turn a cell's asset URL into something that can be downloaded
#'
#' @param client A `harbour_client`.
#' @param url The URL from the cell.
#' @param call The frame to blame for any error.
#' @return A single URL.
#' @keywords internal
#' @noRd
.hb_download_source <- function(client, url, call = rlang::caller_env()) {
  if (!.hb_is_asset_url(client, url)) {
    return(url)
  }
  link <- .hb_request(client, "/api/v2.1/dtable/app-download-link/",
    service = "web", auth = "api", method = "GET",
    query = list(path = .hb_asset_path(url)), call = call
  )
  if (is.null(link$download_link)) {
    hb_abort("SeaTable did not return a download link.",
      class = "harbour_error_http", call = call
    )
  }
  link$download_link
}

#' Is this URL an asset of a base on the client's server?
#'
#' @param client A `harbour_client`.
#' @param url A URL.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_is_asset_url <- function(client, url) {
  startsWith(url, paste0(client$server, "/")) &&
    grepl("/workspace/[^/]+/asset(-preview)?/[^/]+/", url)
}

#' Delete an asset
#'
#' Removes a file or image from the base's assets. Like the other file
#' endpoints this authenticates with the API token. Cells that still point
#' at the asset are not changed.
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
    service = "web", auth = "api", method = "DELETE",
    query = list(path = .hb_asset_path(url))
  )
  invisible(client)
}

#' Reduce an asset URL to the path SeaTable's asset endpoints take
#'
#' Cells store a full, percent-encoded URL; the download-link and delete
#' endpoints want only the decoded part below the base's asset root -
#' `/files/2026-07/report.pdf`.
#'
#' @param url A full asset URL, or an already-relative path.
#' @return A single string beginning with `/`.
#' @keywords internal
#' @noRd
.hb_asset_path <- function(url) {
  stripped <- sub("^https?://[^/]+", "", url)
  relative <- sub("^/workspace/[^/]+/asset(-preview)?/[^/]+", "", stripped)
  if (!nzchar(relative)) relative <- stripped
  if (!startsWith(relative, "/")) relative <- paste0("/", relative)
  utils::URLdecode(relative)
}
