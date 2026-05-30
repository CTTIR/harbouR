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
#' @return A named list describing the uploaded asset.
#' @family files
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_upload_file(client, "report.pdf")
#' @export
hb_upload_file <- function(client, path, relative_path = "files",
                           call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(path, call = call)
  if (!file.exists(path)) {
    cli::cli_abort(c("File not found.",
                     "x" = "{.path {path}}"), call = call)
  }
  .check_string(relative_path, call = call)
  link <- .hb_request(client, "/api/v2.1/dtable/app-upload-link/",
                      service = "web", auth = "api", method = "GET")
  upload_url <- link$upload_link %||% link$url
  parent_dir <- link$parent_path %||% "/"
  if (is.null(upload_url)) {
    cli::cli_abort("SeaTable did not return an upload URL.", call = call)
  }
  req <- httr2::request(upload_url) |>
    httr2::req_user_agent(.hb_user_agent()) |>
    httr2::req_headers(Authorization = paste("Token", client$api_token)) |>
    httr2::req_body_multipart(
      file = curl::form_file(path),
      parent_dir = parent_dir,
      relative_path = relative_path,
      replace = "0"
    )
  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  entry <- if (length(body) > 0L) body[[1L]] else list()
  list(
    name = entry$name %||% basename(path),
    size = entry$size %||% file.info(path)$size,
    type = entry$type %||% .hb_guess_mime(path),
    url = entry$url %||% NA_character_
  )
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
    "md"  = "text/markdown",
    "json" = "application/json",
    "xlsx" = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
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
#' @return Invisibly returns the client.
#' @family files
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_attach_file(client, "Samples", "abc", "Report", "report.pdf")
#' @export
hb_attach_file <- function(client, table, row_id, column, path,
                           call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(table, call = call)
  .check_string(row_id, call = call)
  .check_string(column, call = call)
  obj <- hb_upload_file(client, path, call = call)
  data <- tibble::tibble(`_id` = row_id)
  data[[column]] <- list(obj)
  hb_update_rows(client, table, data, call = call)
  invisible(client)
}

#' Download an asset
#'
#' @inheritParams hb_metadata
#' @param url Asset URL (as returned by SeaTable in a file/image cell).
#' @param dest Destination path. Parent directories are created if needed.
#' @param overwrite Refuse to clobber an existing file unless `TRUE`.
#'
#' @return Invisibly returns `dest`.
#' @family files
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_download_file(client, "https://...", tempfile())
#' @export
hb_download_file <- function(client, url, dest, overwrite = FALSE,
                             call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(url, call = call)
  .check_string(dest, call = call)
  .check_flag(overwrite, call = call)
  if (file.exists(dest) && !overwrite) {
    cli::cli_abort(
      c("Destination already exists.",
        "x" = "{.path {dest}}",
        "i" = "Pass {.code overwrite = TRUE} to replace it."),
      call = call
    )
  }
  parent <- dirname(dest)
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE)
  req <- httr2::request(url) |>
    httr2::req_user_agent(.hb_user_agent()) |>
    httr2::req_timeout(client$timeout %||% 60)
  resp <- httr2::req_perform(req, path = dest)
  if (httr2::resp_status(resp) >= 400L) {
    cli::cli_abort(
      c("Download failed.",
        "x" = "HTTP {httr2::resp_status(resp)}"),
      call = call
    )
  }
  invisible(dest)
}

#' Delete an asset
#'
#' @inheritParams hb_download_file
#' @return Invisibly returns the client.
#' @family files
#' @examplesIf interactive()
#' client <- hb_client()
#' hb_delete_asset(client, "https://server/path/to/file.pdf")
#' @export
hb_delete_asset <- function(client, url, call = rlang::caller_env()) {
  .check_client(client, call = call)
  .check_string(url, call = call)
  .hb_request(client, "/api/v2.1/dtable/asset/",
              service = "web", auth = "api", method = "DELETE",
              body = list(url = url))
  invisible(client)
}
