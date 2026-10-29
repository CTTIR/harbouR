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
#' @param relative_path Folder under the base's asset root. The default,
#'   `"files"`, stands for the folder the upload link names:
#'   `files/<YYYY-MM>` for the current month, or `images/<YYYY-MM>` when
#'   `path` has an image extension (`.png`, `.jpg`, `.jpeg`, `.gif`,
#'   `.bmp`, `.webp` or `.svg`). Passing `"files"` yourself does the same.
#'   Any other value is used as given, but may not climb out of the asset
#'   root with `..`.
#'
#' @param ... These dots are for future extensions and must be empty.
#' @return A named list describing the uploaded asset.
#' @family files
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_upload_file(client, "report.pdf")
#' }
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
  if (".." %in% strsplit(relative_path, "[/\\\\]")[[1L]]) {
    hb_abort(
      c("{.arg relative_path} must stay inside the base's assets.",
        "x" = "{.val {relative_path}} climbs out with {.val ..}."),
      class = "harbour_error_bad_argument"
    )
  }
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
    .hb_transfer_timeout(client$timeout, stall = FALSE) |>
    httr2::req_options(followlocation = FALSE) |>
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
    # SeaTable's own file cells give every attachment the type "file";
    # the upload reply carries no type to use instead.
    type = "file",
    url = .hb_asset_url(
      client, relative_path, name,
      workspace_id = link$workspace_id %||% client$.workspace_id,
      parent_path = link$parent_path
    )
  )
}

#' Limit a transfer by how long it stalls, not by how long it takes
#'
#' A large file can take longer to move than any sensible request timeout
#' while data flows the whole time. The client's timeout bounds connecting
#' and, for a download, any stretch in which less than a byte a second
#' moves; `Inf` sets no limit. An upload is bounded by connecting alone:
#' once it is sent, the server stores it before it answers, and that wait
#' would count as a stall.
#'
#' @param req An httr2 request.
#' @param timeout The client's timeout in seconds, or `NULL` for 30.
#' @param stall Whether to bound a stretch without data as well.
#' @return The request.
#' @keywords internal
#' @noRd
.hb_transfer_timeout <- function(req, timeout, stall = TRUE) {
  timeout <- timeout %||% 30
  if (is.infinite(timeout)) {
    return(req)
  }
  req <- httr2::req_options(req, connecttimeout_ms = round(timeout * 1000))
  if (!stall) {
    return(req)
  }
  httr2::req_options(
    req,
    # Whole seconds, as curl counts them, and at least one.
    low_speed_time = max(1, ceiling(timeout)),
    low_speed_limit = 1
  )
}

#' Build the asset URL for a freshly uploaded file
#'
#' The upload endpoint returns only `name`, `id` and `size`. The URL a
#' file-typed cell needs has to be assembled from the workspace id, the
#' base's asset root and the path the file was uploaded to.
#'
#' @param client A `harbour_client`.
#' @param relative_path Folder under the base's asset root, unescaped.
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
  # The folders are escaped like the name: a space or "#" would break the
  # URL, and a "%" would decode into another path on the way back. Stray
  # slashes would only leave empty segments, so those are dropped.
  folders <- strsplit(relative_path, "/", fixed = TRUE)[[1L]]
  segments <- vapply(
    c(folders[nzchar(folders)], name), .hb_url_escape, character(1),
    USE.NAMES = FALSE
  )
  root <- paste0(client$server, "/workspace/", workspace_id, parent_path)
  paste(c(root, segments), collapse = "/")
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
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_attach_file(client, "Samples", "abc", "Reports", "report.pdf")
#' }
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
#' sits behind SeaTable's login. harbouR recognises such a URL by its
#' path, `/workspace/<id>/asset/<base uuid>/...`, whether it is absolute
#' or relative to the server, and exchanges it, with the client's API
#' token, for a short-lived download link. The URL must name the client's
#' server - the host is compared ignoring case, the scheme and a default
#' port - and the client's base: an asset of another server or another
#' base raises a `harbour_error_bad_argument` condition instead of being
#' fetched. A URL that is not an asset URL is fetched as it is.
#'
#' Should SeaTable answer an asset download with its login page, the
#' download fails with a `harbour_error_http` condition rather than saving
#' the page in place of the file.
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
#' @examples
#' \dontrun{
#' client <- hb_client()
#' hb_download_file(client, "https://...", tempfile())
#' }
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
  asset <- .hb_is_asset_url(url)
  source <- .hb_download_source(client, url)
  parent <- dirname(dest)
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE)
  partial <- tempfile(".harbour-download-", tmpdir = parent)
  on.exit(unlink(partial), add = TRUE)
  req <- httr2::request(source) |>
    httr2::req_user_agent(.hb_user_agent()) |>
    .hb_transfer_timeout(client$timeout)
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
  if (asset && .hb_is_login_page(resp, url)) {
    file <- .hb_asset_path(url)
    hb_abort(
      c("Download failed.",
        "x" = "SeaTable sent its login page instead of {.file {file}}.",
        "i" = "Nothing was written to {.path {dest}}."
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
  if (!.hb_is_asset_url(url)) {
    return(url)
  }
  .hb_check_asset_url(client, url, call = call)
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

#' Is this the login page rather than the asset?
#'
#' A download link leads straight to the file. Should the server want a
#' login instead, httr2 follows its redirect and the page arrives with
#' status 200, so only where the request ended up, or HTML for a file
#' that is not HTML, gives it away.
#'
#' @param resp The `httr2_response` of the download.
#' @param url The asset URL that was asked for.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_is_login_page <- function(resp, url) {
  final <- httr2::resp_url(resp) %||% ""
  if (grepl("/accounts/login", final, fixed = TRUE)) {
    return(TRUE)
  }
  type <- tolower(httr2::resp_content_type(resp))
  identical(type, "text/html") &&
    !grepl("\\.html?$", .hb_asset_path(url), ignore.case = TRUE)
}

#' A pattern for the scheme and host at the front of an absolute URL
#'
#' Its one group captures what follows the scheme: the host, with any
#' port and user name.
#'
#' @keywords internal
#' @noRd
.hb_origin_pattern <- "^[A-Za-z][A-Za-z0-9+.-]*://([^/?#]*)"

#' Does this URL point at an asset of a base?
#'
#' @param url A URL.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_is_asset_url <- function(url) {
  !is.null(.hb_asset_uuid(url))
}

#' The base an asset URL belongs to
#'
#' A file or image cell holds `/workspace/<id>/asset/<base uuid>/...`,
#' with the server in front or relative to it; a preview has
#' `asset-preview` instead. The segment is looked for anywhere in the
#' path, not only at its start: a URL with something in front of it is
#' still an asset, and fetching it directly would save the login page.
#'
#' @param url A URL.
#' @return The base UUID as the URL spells it, or `NULL` if `url` is not
#'   an asset URL.
#' @keywords internal
#' @noRd
.hb_asset_uuid <- function(url) {
  # Only the path counts: the same text in a query string or a fragment
  # does not make a URL an asset.
  path <- sub("[?#].*$", "", sub(.hb_origin_pattern, "", url))
  found <- regmatches(
    path, regexec("/workspace/[^/]+/asset(-preview)?/([^/]+)/", path)
  )[[1L]]
  if (length(found) == 0L) NULL else found[[3L]]
}

#' The server an absolute URL names
#'
#' The host is lower-cased and a default port dropped, so spellings of
#' the same server compare equal. The scheme is left out: the API token
#' only ever goes to the client's server, never to the URL, so http
#' against https can do no harm.
#'
#' @param url A URL.
#' @return The host, with any other port, or `NULL` for a relative URL.
#' @keywords internal
#' @noRd
.hb_url_host <- function(url) {
  authority <- regmatches(url, regexec(.hb_origin_pattern, url))[[1L]][2L]
  if (is.na(authority)) {
    return(NULL)
  }
  host <- tolower(sub("^.*@", "", authority))
  sub(":(80|443)$", "", host)
}

#' Refuse a URL that names another server or another base
#'
#' The download-link and delete endpoints take only the path below the
#' asset root, and the API token stands for the client's base, so they act
#' on that base whatever the URL names. Unchecked, a URL from another base
#' would download, or delete, this base's file at the same path.
#'
#' A relative URL or a bare path is on the client's server. A bare path
#' names no base, so only a URL that carries a base UUID is compared with
#' the client's base, and only then is that base looked up, which may cost
#' a base-token exchange.
#'
#' @param client A `harbour_client`.
#' @param url A URL, or a path below the base's asset root.
#' @param call The frame to blame for any error.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_check_asset_url <- function(client, url, call = rlang::caller_env()) {
  host <- .hb_url_host(url)
  server <- .hb_url_host(client$server)
  if (!is.null(host) && !identical(host, server)) {
    hb_abort(
      c("{.arg url} points at another server.",
        "x" = "It names {.val {host}}; this client works with
               {.val {server}}.",
        "i" = "If that is the same server under another name, create the
               client with that address."
      ),
      class = "harbour_error_bad_argument",
      call = call
    )
  }
  uuid <- .hb_asset_uuid(url)
  # Without an API token the file endpoints refuse the client before any
  # request goes out, so there is nothing to protect, and logging in just
  # to learn the base would be wasted.
  if (is.null(uuid) || is.null(client$api_token)) {
    return(invisible(NULL))
  }
  base <- .hb_base_uuid(client, call = call)
  # The base-token exchange reports the dashed form, while a client may
  # have been given the bare 32 characters, and either may be in capitals.
  same <- identical(
    tolower(gsub("-", "", uuid, fixed = TRUE)),
    tolower(gsub("-", "", base, fixed = TRUE))
  )
  if (!same) {
    hb_abort(
      c("{.arg url} is an asset of another base.",
        "x" = "It belongs to base {.val {uuid}}; this client works on base
               {.val {base}}.",
        "i" = "Use a client for that base."
      ),
      class = "harbour_error_bad_argument",
      call = call
    )
  }
  invisible(NULL)
}

#' Delete an asset
#'
#' Removes a file or image from the base's assets. Like the other file
#' endpoints this authenticates with the API token. Cells that still point
#' at the asset are not changed.
#'
#' `url` is the URL from a file or image cell, absolute or relative to the
#' server, or a path below the base's asset root such as
#' `/files/2026-07/report.pdf`. The endpoint acts on the client's base
#' whatever the URL names, so a URL on another server, or an asset URL of
#' another base, raises a `harbour_error_bad_argument` condition rather
#' than deleting this base's file at the same path.
#'
#' @inheritParams hb_download_file
#' @param ... These dots are for future extensions and must be empty.
#' @return Invisibly returns the client.
#' @family files
#' @examples
#' \dontrun{
#' client <- hb_client()
#' # A path below the asset root, or the URL from a file or image cell
#' hb_delete_asset(client, "/files/2026-07/report.pdf")
#' }
#' @export
hb_delete_asset <- function(client, url, ...) {
  rlang::check_dots_empty()
  .check_client(client)
  .check_string(url)
  .hb_check_asset_url(client, url)
  path <- .hb_asset_path(url)
  # The endpoint deletes one attachment. The server itself, or an asset
  # URL cut short, reduces to the asset root or a folder, and what the
  # server would delete for that is nothing anyone asked for; so does a
  # path with a `.` or `..` in it, once the server resolves it.
  segments <- strsplit(path, "/", fixed = TRUE)[[1L]]
  root <- grepl(
    "/workspace/[^/]+/asset(-preview)?/[^/]+$", sub("[?#].*$", "", url)
  )
  if (endsWith(path, "/") || root || any(segments %in% c(".", ".."))) {
    hb_abort(
      c("{.arg url} names no file.",
        "x" = "It reduces to {.path {path}} below the asset root.",
        "i" = "Pass the URL or path of the file to delete."
      ),
      class = "harbour_error_bad_argument"
    )
  }
  .hb_request(client, "/api/v2.1/dtable/app-asset/",
    service = "web", auth = "api", method = "DELETE",
    query = list(path = path)
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
  # The same front as .hb_url_host() reads, so a scheme spelt in capitals
  # is stripped as well.
  stripped <- sub(.hb_origin_pattern, "", url)
  # Anywhere in the path, not only at its start: a server can be reached
  # under a prefix such as /seatable.
  relative <- sub(
    "^.*?/workspace/[^/]+/asset(-preview)?/[^/]+", "", stripped, perl = TRUE
  )
  if (!nzchar(relative)) relative <- stripped
  if (!startsWith(relative, "/")) relative <- paste0("/", relative)
  utils::URLdecode(relative)
}
