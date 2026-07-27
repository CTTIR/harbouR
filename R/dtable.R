#' Read a SeaTable `.dtable` file
#'
#' Opens a `.dtable` export and returns a `harbour_dtable` object. The
#' same verbs that work against a live base work against it -
#' [hb_list_tables()], [hb_read_table()], [hb_list_columns()] - so an
#' analysis can be written once and run either way.
#'
#' A `.dtable` is a ZIP archive containing `content.json`, the complete
#' base, and optionally an `asset/` tree of uploaded files and images.
#'
#' The parsed JSON is kept **verbatim**. Real exports carry fields no
#' client would think to model - one column in the reference file holds a
#' serialised React element - and future SeaTable releases will add more.
#' Keeping the tree untouched is what makes [hb_write_dtable()] lossless;
#' rebuilding it from a typed intermediate would quietly drop whatever
#' harbouR did not know about.
#'
#' @param path Path to a `.dtable` file.
#' @param ... These dots are for future extensions and must be empty.
#' @param assets Whether to extract the bundled `asset/` tree.
#'   `"none"`, the default, reads only `content.json`. `"extract"` unpacks
#'   the assets so [hb_asset_path()] can resolve attachment URLs to local
#'   files.
#' @param assets_dir Where to extract assets to. Defaults to a session
#'   temporary directory.
#'
#' @return A `harbour_dtable`: a list with components `content` (the
#'   parsed tree), `path`, `assets` (a tibble of bundled files),
#'   `assets_dir` and `base_name`. Note that `names()` on a
#'   `harbour_dtable` gives its *table* names, not these components -
#'   reach them with `$` or `unclass()`.
#'
#' @family dtable
#' @seealso [hb_write_dtable()], [hb_dtable()]
#' @examples
#' path <- system.file("extdata", "example.dtable", package = "harbouR")
#' base <- hb_read_dtable(path)
#' base
#'
#' hb_list_tables(base)
#' hb_read_table(base, "Samples")
#' @export
hb_read_dtable <- function(path, ..., assets = c("none", "extract"),
                           assets_dir = NULL) {
  rlang::check_dots_empty()
  .check_string(path)
  .check_string(assets_dir, allow_null = TRUE)
  assets <- rlang::arg_match(assets)
  if (!file.exists(path)) {
    hb_abort(
      c("File not found.", "x" = "{.path {path}}"),
      class = "harbour_error_not_found"
    )
  }
  listing <- .hb_dtable_listing(path)
  if (!.hb_dtable_entry %in% listing$filename) {
    hb_abort(
      c("That file is not a SeaTable export.",
        "x" = "It contains no {.file content.json}.",
        "i" = "Found instead: {.file {listing$filename}}."),
      class = "harbour_error_bad_argument"
    )
  }
  content <- .hb_dtable_from_json(.hb_dtable_read_entry(path, .hb_dtable_entry))
  .hb_warn_format_version(content$format_version)

  asset_rows <- listing[startsWith(listing$filename, .hb_dtable_asset_dir), ]
  dir <- NULL
  if (identical(assets, "extract") && nrow(asset_rows) > 0L) {
    dir <- assets_dir %||% tempfile("harbour-assets-")
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    zip::unzip(path, files = asset_rows$filename, exdir = dir)
  }
  new_harbour_dtable(
    content = content,
    path = path,
    assets = asset_rows,
    assets_dir = dir
  )
}

#' Write a `harbour_dtable` back to a `.dtable` file
#'
#' Produces a ZIP archive SeaTable can import. Round-tripping is lossless:
#' reading a file and writing it back yields a `content.json` that parses
#' to an identical structure, verified against a real 750 KB export.
#'
#' @param x A `harbour_dtable`.
#' @param path Destination path.
#' @param ... These dots are for future extensions and must be empty.
#' @param assets Whether to repack the extracted asset tree, if there is
#'   one. Default `TRUE`.
#' @param overwrite Refuse to clobber an existing file unless `TRUE`.
#'
#' @return `x`, invisibly.
#'
#' @family dtable
#' @seealso [hb_read_dtable()]
#' @examples
#' path <- system.file("extdata", "example.dtable", package = "harbouR")
#' base <- hb_read_dtable(path)
#'
#' out <- tempfile(fileext = ".dtable")
#' hb_write_dtable(base, out)
#'
#' # the round trip preserves the base exactly
#' identical(hb_read_dtable(out)$content, base$content)
#' @export
hb_write_dtable <- function(x, path, ..., assets = TRUE, overwrite = TRUE) {
  rlang::check_dots_empty()
  .check_dtable(x)
  .check_string(path)
  .check_flag(assets)
  .check_flag(overwrite)
  if (file.exists(path) && !overwrite) {
    hb_abort(
      c("Destination already exists.",
        "x" = "{.path {path}}",
        "i" = "Pass {.code overwrite = TRUE} to replace it."),
      class = "harbour_error_bad_argument"
    )
  }
  .hb_warn_dropped_assets(x, assets)
  problems <- hb_validate_dtable(x)
  if (nrow(problems) > 0L) {
    fatal <- problems[problems$severity == "error", ]
    if (nrow(fatal) > 0L) {
      issues <- paste0(fatal$location, ": ", fatal$problem)
      hb_abort(
        c("This base cannot be written.", stats::setNames(issues, "x")),
        class = "harbour_error_bad_argument"
      )
    }
  }

  staging <- tempfile("harbour-dtable-")
  dir.create(staging, recursive = TRUE)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)

  json <- .hb_dtable_to_json(x$content)
  writeBin(charToRaw(as.character(json)),
           file.path(staging, .hb_dtable_entry))
  entries <- .hb_dtable_entry

  if (assets && !is.null(x$assets_dir) && dir.exists(x$assets_dir)) {
    from <- file.path(x$assets_dir, .hb_dtable_asset_dir)
    if (dir.exists(from)) {
      file.copy(from, staging, recursive = TRUE)
      entries <- c(entries, .hb_dtable_asset_dir)
    }
  }
  parent <- dirname(path)
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE)
  # zip::zip() runs with `root` as its working directory, so a relative
  # destination would be written inside the staging directory and lost.
  zip::zip(
    zipfile = .hb_absolute_path(path),
    files = entries,
    root = staging,
    mode = "cherry-pick"
  )
  invisible(x)
}

#' Build a `.dtable` base from data frames
#'
#' Creates a `harbour_dtable` from scratch, so a set of R data frames can
#' be written out as a SeaTable base and imported.
#'
#' Column types are inferred: `character` becomes `text`, `numeric`
#' `number`, `logical` `checkbox`, `Date` and `POSIXct` `date`, `factor`
#' `single-select` with its levels as options, and list-columns
#' `multiple-select`.
#'
#' @param ... Named data frames, one per table.
#' @param base_name Name recorded for the base.
#' @param collaborators Optional list of collaborator records.
#'
#' @return A `harbour_dtable`.
#'
#' @family dtable
#' @examples
#' base <- hb_dtable(
#'   Samples = data.frame(Name = c("a", "b"), Value = c(1.5, 2.5)),
#'   base_name = "My base"
#' )
#' base
#'
#' hb_read_table(base, "Samples")
#' @export
hb_dtable <- function(..., base_name = "harbouR base",
                      collaborators = NULL) {
  tables <- rlang::list2(...)
  .check_string(base_name)
  if (length(tables) == 0L || !rlang::is_named(tables)) {
    hb_abort(
      c("Supply at least one named data frame.",
        "i" = "For example {.code hb_dtable(Samples = my_data)}."),
      class = "harbour_error_bad_argument"
    )
  }
  not_df <- names(tables)[!vapply(tables, is.data.frame, logical(1))]
  if (length(not_df) > 0L) {
    hb_abort(
      c("Every table must be a data frame.",
        "x" = "Not a data frame: {.arg {not_df}}."),
      class = "harbour_error_bad_argument"
    )
  }
  ids <- character()
  built <- vector("list", length(tables))
  for (i in seq_along(tables)) {
    id <- .hb_new_table_id(ids)
    ids <- c(ids, id)
    built[[i]] <- .hb_build_table(names(tables)[[i]], tables[[i]], id)
  }
  content <- list(
    version = 0L,
    format_version = .hb_dtable_format_version,
    statistics = .hb_empty_array(),
    links = .hb_empty_array(),
    tables = built,
    collaborators = .hb_as_json_array(collaborators)
  )
  new_harbour_dtable(
    content = content,
    path = NA_character_,
    assets = .hb_empty_asset_tibble(),
    assets_dir = NULL,
    base_name = base_name
  )
}

#' Check a base for problems before writing it
#'
#' Reports structural issues that would make SeaTable reject the file, or
#' that indicate the base was built incorrectly in R.
#'
#' @param x A `harbour_dtable`.
#' @param ... These dots are for future extensions and must be empty.
#'
#' @return A tibble with columns `location` (chr), `problem` (chr) and
#'   `severity` (chr, `"error"` or `"warning"`). Zero rows means the base
#'   is well-formed.
#'
#' @family dtable
#' @examples
#' base <- hb_dtable(Samples = data.frame(x = 1))
#' hb_validate_dtable(base)
#' @export
hb_validate_dtable <- function(x, ...) {
  rlang::check_dots_empty()
  .check_dtable(x)
  # An environment rather than <<-: the accumulation is explicit, and
  # lintr flags <<- for good reason.
  state <- new.env(parent = emptyenv())
  state$found <- list()
  add <- function(location, problem, severity = "error") {
    state$found[[length(state$found) + 1L]] <- list(
      location = location, problem = problem, severity = severity
    )
  }
  content <- x$content
  for (key in setdiff(.hb_dtable_top_keys, names(content))) {
    add("content.json", sprintf("missing top-level key `%s`", key))
  }
  tables <- content$tables %||% list()
  if (length(tables) == 0L) {
    add("tables", "the base has no tables", "warning")
  }
  seen_names <- character()
  seen_ids <- character()
  for (i in seq_along(tables)) {
    tbl <- tables[[i]]
    where <- sprintf("tables[[%d]]", i)
    name <- tbl$name %||% NA_character_
    if (is.na(name) || !nzchar(name)) {
      add(where, "table has no name")
    } else if (name %in% seen_names) {
      add(where, sprintf("duplicate table name `%s`", name))
    }
    seen_names <- c(seen_names, name)
    id <- tbl[["_id"]] %||% NA_character_
    if (!is.na(id) && id %in% seen_ids) {
      add(where, sprintf("duplicate table id `%s`", id))
    }
    seen_ids <- c(seen_ids, id)
    for (slot in .hb_dtable_object_slots$table) {
      value <- tbl[[slot]]
      if (!is.null(value) && length(value) == 0L && is.null(names(value))) {
        add(
          paste0(where, "$", slot),
          "empty list would serialise as [] but SeaTable expects {}",
          "warning"
        )
      }
    }
    columns <- tbl$columns %||% list()
    keys <- .hb_chr_field(columns, "key")
    if (anyDuplicated(keys) > 0L) {
      add(paste0(where, "$columns"), "duplicate column keys")
    }
    col_names <- .hb_chr_field(columns, "name")
    if (anyDuplicated(col_names) > 0L) {
      add(paste0(where, "$columns"), "duplicate column names")
    }
    row_ids <- vapply(
      tbl$rows %||% list(),
      function(row) as.character(row[["_id"]] %||% NA_character_),
      character(1)
    )
    if (anyDuplicated(row_ids) > 0L) {
      add(paste0(where, "$rows"), "duplicate row ids")
    }
  }
  found <- state$found
  if (length(found) == 0L) {
    return(tibble::tibble(
      location = character(), problem = character(), severity = character()
    ))
  }
  tibble::tibble(
    location = vapply(found, function(f) f$location, character(1)),
    problem = vapply(found, function(f) f$problem, character(1)),
    severity = vapply(found, function(f) f$severity, character(1))
  )
}

#' Resolve a bundled asset URL to a local file
#'
#' Attachment cells in an export point at
#' `file://dtable-bundle/asset/...`. When the base was read with
#' `assets = "extract"`, this gives the path the file was extracted to.
#'
#' @param x A `harbour_dtable` read with `assets = "extract"`.
#' @param url An asset URL taken from a `file` or `image` cell.
#' @param ... These dots are for future extensions and must be empty.
#'
#' @return A single path, or `NA_character_` if the asset is not bundled.
#'
#' @family dtable
#' @examples
#' path <- system.file("extdata", "example.dtable", package = "harbouR")
#' base <- hb_read_dtable(path, assets = "extract")
#' hb_asset_path(base, "file://dtable-bundle/asset/files/readme.txt")
#' @export
hb_asset_path <- function(x, url, ...) {
  rlang::check_dots_empty()
  .check_dtable(x)
  .check_string(url)
  if (is.null(x$assets_dir)) {
    return(NA_character_)
  }
  relative <- sub("^file://dtable-bundle/", "", url)
  relative <- sub("^/+", "", relative)
  candidate <- file.path(x$assets_dir, relative)
  if (!file.exists(candidate)) {
    return(NA_character_)
  }
  candidate
}

#' Test whether an object is a harbour dtable
#'
#' @param x Object to test.
#' @return A single `TRUE` or `FALSE`.
#' @family dtable
#' @examples
#' is_harbour_dtable(hb_dtable(Samples = data.frame(x = 1)))
#' @export
is_harbour_dtable <- function(x) inherits(x, "harbour_dtable")

#' @keywords internal
#' @noRd
new_harbour_dtable <- function(content, path, assets, assets_dir,
                               base_name = NULL) {
  obj <- list(
    content = content,
    path = path,
    assets = assets,
    assets_dir = assets_dir,
    base_name = base_name %||% tools::file_path_sans_ext(basename(path))
  )
  class(obj) <- c("harbour_dtable", "list")
  obj
}

#' @keywords internal
#' @noRd
.check_dtable <- function(x, arg = rlang::caller_arg(x),
                          call = rlang::caller_env()) {
  if (!inherits(x, "harbour_dtable")) {
    hb_abort(
      c("{.arg {arg}} must be a {.cls harbour_dtable}.",
        "i" = "Create one with {.fn hb_read_dtable} or {.fn hb_dtable}."),
      class = "harbour_error_bad_argument",
      call = call
    )
  }
  invisible(NULL)
}

#' @keywords internal
#' @noRd
.hb_empty_asset_tibble <- function() {
  tibble::tibble(
    filename = character(), compressed_size = double(),
    uncompressed_size = double()
  )
}

#' @keywords internal
#' @noRd
.hb_dtable_listing <- function(path, call = rlang::caller_env()) {
  listing <- rlang::try_fetch(
    zip::zip_list(path),
    error = function(cnd) {
      hb_abort(
        c("That file is not a SeaTable export.",
          "x" = "It could not be opened as a ZIP archive.",
          "i" = "A {.file .dtable} file is a ZIP containing
                 {.file content.json}."),
        class = "harbour_error_bad_argument",
        call = call,
        parent = cnd
      )
    }
  )
  tibble::as_tibble(listing)
}

#' @keywords internal
#' @noRd
.hb_dtable_read_entry <- function(path, entry) {
  con <- unz(path, entry, open = "rb")
  on.exit(close(con), add = TRUE)
  out <- raw()
  repeat {
    chunk <- readBin(con, "raw", n = 1048576L)
    if (length(chunk) == 0L) break
    out <- c(out, chunk)
  }
  out
}

#' @keywords internal
#' @noRd
.hb_warn_format_version <- function(version) {
  version <- suppressWarnings(as.integer(version %||% NA))
  if (!is.na(version) && version > .hb_dtable_format_version) {
    known <- .hb_dtable_format_version
    cli::cli_warn(c(
      "This file uses {.file .dtable} format version {version}.",
      "i" = "harbouR was written against version {known}.",
      "i" = "It will be read, but harbouR may not understand every field."
    ))
  }
  invisible(NULL)
}

#' Build one table object from a data frame
#'
#' @param name Table name.
#' @param data A data frame.
#' @param id Table id.
#' @return A table object in `content.json` shape.
#' @keywords internal
#' @noRd
.hb_build_table <- function(name, data, id) {
  keys <- character()
  columns <- vector("list", ncol(data))
  for (i in seq_along(data)) {
    key <- .hb_new_column_key(keys)
    keys <- c(keys, key)
    columns[[i]] <- .hb_build_column(names(data)[[i]], data[[i]], key)
  }
  rows <- vector("list", nrow(data))
  stamp <- .hb_dtable_timestamp()
  for (r in seq_len(nrow(data))) {
    row <- list(`_id` = .hb_new_row_id(), `_ctime` = stamp, `_mtime` = stamp)
    for (i in seq_along(data)) {
      value <- .hb_cell_out(data[[i]][[r]], columns[[i]]$type)
      # An empty cell is absent from the row entirely, which is what
      # SeaTable itself writes.
      if (!is.null(value)) {
        row[[keys[[i]]]] <- value
      }
    }
    rows[[r]] <- row
  }
  list(
    `_id` = id,
    name = name,
    rows = rows,
    columns = columns,
    view_structure = list(folders = .hb_empty_array(), view_ids = list("0000")),
    views = list(.hb_default_view()),
    id_row_map = .hb_empty_object(),
    summary_configs = .hb_empty_object(),
    is_header_locked = FALSE,
    header_settings = .hb_empty_object()
  )
}

#' @keywords internal
#' @noRd
.hb_default_view <- function() {
  list(
    `_id` = "0000",
    name = "Default View",
    type = "table",
    private_for = NULL,
    is_locked = FALSE,
    filter_conjunction = "And",
    filters = .hb_empty_array(),
    sorts = .hb_empty_array(),
    rows = .hb_empty_array(),
    formula_rows = .hb_empty_object(),
    hidden_columns = .hb_empty_array(),
    row_height = "default",
    groupbys = .hb_empty_array(),
    colorbys = .hb_empty_object(),
    groups = .hb_empty_array(),
    summaries = .hb_empty_object(),
    colors = .hb_empty_object(),
    column_colors = .hb_empty_object(),
    link_rows = .hb_empty_object()
  )
}

#' Infer a SeaTable column from an R vector
#'
#' @param name Column name.
#' @param values The column's values.
#' @param key The column key to assign.
#' @return A column object in `content.json` shape.
#' @keywords internal
#' @noRd
.hb_build_column <- function(name, values, key) {
  type <- .hb_infer_column_type(values)
  data <- NULL
  if (type == "single-select") {
    levels <- levels(values) %||% unique(stats::na.omit(as.character(values)))
    data <- list(options = lapply(levels, function(level) {
      list(id = .hb_new_short_id(), name = level, color = "#eaa700")
    }))
  }
  if (type == "date") {
    data <- list(format = "YYYY-MM-DD HH:mm")
  }
  list(
    key = key,
    type = type,
    name = name,
    editable = TRUE,
    width = 200L,
    resizable = TRUE,
    draggable = TRUE,
    data = data,
    permission_type = "",
    permitted_users = .hb_empty_array(),
    permitted_group = .hb_empty_array()
  )
}

#' @keywords internal
#' @noRd
.hb_infer_column_type <- function(values) {
  if (is.factor(values)) {
    return("single-select")
  }
  if (is.list(values)) {
    return("multiple-select")
  }
  if (inherits(values, c("Date", "POSIXt"))) {
    return("date")
  }
  if (is.logical(values)) {
    return("checkbox")
  }
  if (is.numeric(values)) {
    return("number")
  }
  "text"
}

#' Render one R value into its `content.json` form
#'
#' @param value A single cell value.
#' @param type The SeaTable column type.
#' @return The JSON-ready value, or `NULL` when the cell is empty - in
#'   which case the key is omitted from the row, as SeaTable does.
#' @keywords internal
#' @noRd
.hb_cell_out <- function(value, type) {
  if (is.null(value) || length(value) == 0L) {
    return(NULL)
  }
  if (is.list(value) && length(value) == 1L && !is.null(names(value))) {
    value <- value[[1L]]
  }
  if (all(is.na(value))) {
    return(NULL)
  }
  if (type == "date") {
    return(format(as.POSIXct(value), "%Y-%m-%dT%H:%M:%S", tz = "UTC"))
  }
  if (type == "multiple-select") {
    return(.hb_as_json_array(unlist(value, use.names = FALSE)))
  }
  if (type == "checkbox") {
    return(isTRUE(value))
  }
  if (type == "number") {
    out <- as.double(value)
    if (!is.finite(out)) {
      # JSON has no Inf or NaN, so this genuinely cannot be written - but
      # a value quietly becoming NA on the next read is the wrong way to
      # find that out.
      cli::cli_warn(c(
        "{.val {out}} cannot be represented in JSON and is written as
         {.code null}.",
        "i" = "It will read back as {.val {NA_real_}}."
      ))
      return(NULL)
    }
    return(out)
  }
  as.character(value)
}

#' Make a path absolute without requiring it to exist
#'
#' `normalizePath(mustWork = FALSE)` leaves a relative path relative when
#' the file is not there yet, which is exactly the case when writing.
#'
#' @param path A file path.
#' @return An absolute path.
#' @keywords internal
#' @noRd
.hb_absolute_path <- function(path) {
  if (grepl("^(/|[A-Za-z]:)", path)) {
    return(path)
  }
  file.path(normalizePath(dirname(path), mustWork = FALSE), basename(path))
}

#' Warn before writing a base whose bundled assets are not available
#'
#' A base read with `assets = "none"` keeps the cells that point at
#' `file://dtable-bundle/...` but not the files themselves. Writing it
#' back produces an archive whose attachment cells reference files that
#' are not in it - a silent, and easily missed, loss.
#'
#' @param x A `harbour_dtable`.
#' @param assets Whether the caller asked for assets to be repacked.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_warn_dropped_assets <- function(x, assets = TRUE) {
  have <- !is.null(x$assets_dir) && dir.exists(x$assets_dir)
  if (have && assets) {
    return(invisible(NULL))
  }
  referenced <- nrow(x$assets %||% .hb_empty_asset_tibble())
  if (referenced == 0L) {
    return(invisible(NULL))
  }
  cli::cli_warn(c(
    "This base references {referenced} bundled asset{?s} that will not be
     written.",
    "x" = "The attachment cells will point at files the archive does not
           contain.",
    "i" = if (!assets) {
      "You passed {.code assets = FALSE}."
    } else {
      "Re-read it with {.code hb_read_dtable(path, assets = \"extract\")}."
    }
  ))
  invisible(NULL)
}
