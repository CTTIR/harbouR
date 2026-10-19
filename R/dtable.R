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
#'   files. An archive whose asset entries could land outside
#'   `assets_dir` - a name that is absolute or has a `..` component,
#'   between slashes or backslashes, or an entry that is a symbolic link -
#'   is refused before anything is extracted. Assets whose names differ
#'   only in case may not all be extracted, and a warning names them.
#' @param assets_dir Where to extract assets to. Defaults to a session
#'   temporary directory.
#'
#' @return A `harbour_dtable`: a list with components `content` (the
#'   parsed tree), `path`, `assets` (the archive's own listing of its
#'   `asset/` tree, as [zip::zip_list()] gives it: one row per entry,
#'   folders included), `assets_dir` and `base_name`. Note that `names()`
#'   on a `harbour_dtable` gives its *table* names, not these components -
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

  # The separator is part of the match: "assets.txt" and "asset_old/..."
  # are not in the asset tree.
  prefix <- paste0(.hb_dtable_asset_dir, "/")
  asset_rows <- listing[startsWith(listing$filename, prefix), ]
  dir <- NULL
  if (identical(assets, "extract") && nrow(asset_rows) > 0L) {
    .hb_check_asset_entries(asset_rows)
    .hb_warn_asset_case(asset_rows)
    dir <- assets_dir %||% tempfile("harbour-assets-")
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    zip::unzip(path, files = asset_rows$filename, exdir = dir)
    .hb_check_extracted(dir, asset_rows$filename)
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
#' to an identical structure, verified against a real 750 KB export. The
#' attachments go back in too when the file was read with
#' `assets = "extract"`.
#'
#' The archive is built in a temporary file beside `path` and moved into
#' place only once it is complete, so a failed write cannot destroy the
#' file it replaces - even when that is the file the base was read from.
#' Replacing a file gives it a new identity on disk, so any other hard
#' link to it keeps the old content. Where no new file can be made beside
#' `path`, or there is nothing at `path` to lose - an empty file such as
#' `/dev/null`, or a link to a file not made yet - the archive is written
#' straight into it. A file that cannot be replaced, because another
#' program holds it open or the folder lets files be written but not
#' removed, is written into once the archive is complete; that needs room
#' for a second copy, and should it fail, the complete archive is kept
#' beside `path` and the error says where. A symbolic link in the
#' extracted asset tree is left out, with a warning, rather than followed
#' to wherever it points.
#'
#' @param x A `harbour_dtable`.
#' @param path Destination path.
#' @param ... These dots are for future extensions and must be empty.
#' @param assets Whether to repack the extracted asset tree, if there is
#'   one. Default `TRUE`.
#' @param overwrite Whether to replace an existing file at `path`. Default
#'   `TRUE`; set `FALSE` to refuse.
#'
#' @return `x`, invisibly.
#'
#' @family dtable
#' @seealso [hb_read_dtable()]
#' @examples
#' path <- system.file("extdata", "example.dtable", package = "harbouR")
#' # extract the assets, so the attachments are written back too
#' base <- hb_read_dtable(path, assets = "extract")
#'
#' out <- tempfile(fileext = ".dtable")
#' hb_write_dtable(base, out)
#'
#' # content.json round-trips exactly
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
  # The archive is moved into place rather than written into the file, so
  # a file that may not be written would no longer stop it: refuse one
  # here, as opening it for writing did. An empty destination is written
  # into, and so tested by the write itself; opening a pipe here would
  # end its reader's input and leave the write waiting for ever.
  unwritable <- dir.exists(path) ||
    (isTRUE(file.size(path) > 0) && !.hb_can_write(.hb_absolute_path(path)))
  if (unwritable) {
    hb_abort(
      c("Destination cannot be written.", "x" = "{.path {path}}"),
      class = "harbour_error_bad_argument"
    )
  }
  .hb_warn_dropped_assets(x, assets)
  problems <- hb_validate_dtable(x)
  if (nrow(problems) > 0L) {
    fatal <- problems[problems$severity == "error", ]
    if (nrow(fatal) > 0L) {
      # The problems quote table names and ids from the file, and cli runs
      # whatever is in braces in a message, so they go in as data.
      issues <- paste0(fatal$location, ": ", fatal$problem)
      bullets <- sprintf("{issues[[%d]]}", seq_along(issues))
      hb_abort(
        c("This base cannot be written.",
          stats::setNames(bullets, rep("x", length(bullets)))),
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
      .hb_stage_assets(from, file.path(staging, .hb_dtable_asset_dir))
      entries <- c(entries, .hb_dtable_asset_dir)
    }
  }
  parent <- dirname(path)
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE)
  # zip::zip() runs with `root` as its working directory, so a relative
  # destination would be written inside the staging directory and lost.
  target <- .hb_absolute_path(path)
  # Writing onto a link has always replaced the file it points at.
  if (file.exists(target)) target <- normalizePath(target)
  # Build the archive beside its destination and move it into place only
  # once it is complete, so a failure part-way never destroys the file it
  # replaces - which may be the very file the base was read from. A
  # destination with nothing in it to lose is written into, as before: an
  # empty one, which may be no file at all - /dev/null, or a pipe - and a
  # link whose file does not exist yet, which writing through it creates.
  in_place <- if (file.exists(target)) {
    isTRUE(file.size(target) == 0)
  } else {
    link <- Sys.readlink(target)
    !is.na(link) && nzchar(link)
  }
  partial <- target
  if (!in_place) {
    scratch <- tempfile(".harbour-dtable-", tmpdir = dirname(target))
    # Only ever the scratch file: when it cannot be made, the archive is
    # written into the destination, which must then survive this function.
    keep_scratch <- FALSE
    on.exit(if (!keep_scratch) unlink(scratch), add = TRUE)
    # Making the file is the only sure test of whether the folder takes a
    # new one. Where it does not, a file already there that may be written
    # is written into, as before.
    if (file.create(scratch, showWarnings = FALSE)) {
      partial <- scratch
    } else if (!file.exists(target)) {
      hb_abort(
        c("Destination cannot be written.", "x" = "{.path {path}}"),
        class = "harbour_error_bad_argument"
      )
    }
  }
  zip::zip(
    zipfile = partial,
    files = entries,
    root = staging,
    mode = "cherry-pick"
  )
  if (!identical(partial, target)) {
    # A replaced file keeps its permissions, as one written into did.
    if (file.exists(target)) {
      Sys.chmod(partial, file.mode(target), use_umask = FALSE)
    }
    if (!suppressWarnings(file.rename(partial, target))) {
      outcome <- .hb_write_into(partial, target)
      if (identical(outcome, "damaged")) {
        # The copy emptied the destination before it failed, so the
        # archive is the only complete copy of the base left.
        keep_scratch <- TRUE
        hb_abort(
          c("Could not write the archive into place.",
            "x" = "{.path {path}} was left incomplete.",
            "i" = "The new archive is kept at {.path {partial}}."),
          class = "harbour_error_bad_argument"
        )
      }
      if (identical(outcome, "refused")) {
        hb_abort(
          c("Could not move the archive into place.", "x" = "{.path {path}}"),
          class = "harbour_error_bad_argument"
        )
      }
    }
  }
  invisible(x)
}

#' Write a finished archive into a destination that cannot be replaced
#'
#' Another program may hold the file open, or the folder may let files be
#' written but not removed. The archive is then copied into the file, as
#' writing into it always did, but only now that it is complete.
#' `file.copy()` empties the destination before it writes and misses some
#' failed writes, so the result is checked against the archive.
#'
#' @param archive The finished archive, beside `target`.
#' @param target The destination, as an absolute path.
#' @return `"written"`; `"refused"` when the destination is as it was;
#'   or `"damaged"` when the copy changed it but did not complete.
#' @keywords internal
#' @noRd
.hb_write_into <- function(archive, target) {
  digest <- function(file) unname(tools::md5sum(file))
  before <- digest(target)
  copied <- suppressWarnings(
    file.copy(archive, target, overwrite = TRUE, copy.mode = FALSE)
  )
  written <- digest(target)
  if (!copied || !identical(written, digest(archive))) {
    return(if (identical(written, before)) "refused" else "damaged")
  }
  # A folder that lets files be written but not removed keeps the archive
  # beside the destination as well; emptied, it at least takes no room.
  unlink(archive)
  if (file.exists(archive)) {
    file.create(archive, showWarnings = FALSE)
    cli::cli_warn(
      c("Could not remove the temporary file {.path {archive}}.",
        "i" = "It has been emptied; delete it once the folder allows.")
    )
  }
  "written"
}

#' Build a `.dtable` base from data frames
#'
#' Creates a `harbour_dtable` from scratch, so a set of R data frames can
#' be written out as a SeaTable base and imported.
#'
#' Column types are inferred: `character` becomes `text`, `numeric`
#' `number`, `logical` `checkbox`, `Date` and `POSIXct` `date`, `factor`
#' `single-select` with its levels as options, and a list-column of
#' character vectors `multiple-select` with the values it uses as options.
#' A list-column holding objects - file, image or location cells read from
#' a live base - is flattened to `text`: a new base has none of the assets
#' those cells point at.
#'
#' New row ids, table ids, column keys and select-option ids are drawn
#' from the session's random number generator, so building a base
#' advances `.Random.seed`: a random draw made after `hb_dtable()` differs
#' from the same draw made without it. Set the seed after building the
#' base when an analysis needs its random numbers not to depend on it.
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
#' hb_asset_path(base, "file://dtable-bundle/asset/files/2026-07/readme.txt")
#' @export
hb_asset_path <- function(x, url, ...) {
  rlang::check_dots_empty()
  .check_dtable(x)
  .check_string(url)
  if (is.null(x$assets_dir)) {
    return(NA_character_)
  }
  relative <- sub("^file://dtable-bundle/", "", url)
  if (.hb_climbs_out(relative)) {
    return(NA_character_)
  }
  relative <- sub("^/+", "", relative)
  if (!startsWith(relative, "asset/")) return(NA_character_)
  candidate <- file.path(x$assets_dir, relative)
  if (!file.exists(candidate) || dir.exists(candidate)) {
    return(NA_character_)
  }
  if (!.hb_path_inside(candidate, x$assets_dir)) {
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
  # Growing one raw vector chunk by chunk copies it every time; collecting
  # the chunks and joining them once keeps a large base linear.
  chunks <- list()
  repeat {
    chunk <- readBin(con, "raw", n = 1048576L)
    if (length(chunk) == 0L) break
    chunks[[length(chunks) + 1L]] <- chunk
  }
  unlist(chunks, use.names = FALSE) %||% raw()
}

#' Does a relative path climb out of the directory it is resolved in?
#'
#' A `..` component climbs out. A backslash separates folders on Windows,
#' where `asset\..\..` means what `asset/../..` does, so `..` is looked
#' for between either separator; elsewhere a backslash is a character in a
#' name, as extraction treats it.
#'
#' @param paths Relative paths.
#' @return A logical vector as long as `paths`.
#' @keywords internal
#' @noRd
.hb_climbs_out <- function(paths) {
  vapply(
    strsplit(paths, "[/\\\\]"),
    function(parts) any(parts == ".."),
    logical(1)
  )
}

#' Do paths lead to somewhere inside a directory?
#'
#' Links are followed, so a path that only looks as if it is inside, but
#' leads elsewhere, is outside.
#'
#' @param paths Paths, which should exist.
#' @param root A directory that exists.
#' @return A logical vector as long as `paths`.
#' @keywords internal
#' @noRd
.hb_path_inside <- function(paths, root) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  resolved <- normalizePath(paths, winslash = "/", mustWork = FALSE)
  startsWith(resolved, paste0(sub("/+$", "", root), "/"))
}

#' Refuse an asset tree that would not extract inside its directory
#'
#' A `.dtable` is an ordinary ZIP archive, so its entry names are whatever
#' its author chose. One that is absolute or climbs out, or an entry that
#' is a symbolic link, could write wherever the user can - `~/.Rprofile`
#' included. A single such entry refuses the whole archive, before
#' anything is written.
#'
#' @param entries The asset rows of a `zip::zip_list()` listing.
#' @param call The frame to blame for the error.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_check_asset_entries <- function(entries, call = rlang::caller_env()) {
  name <- entries$filename
  # zip::zip_list() reports each entry's type from zip 2.3.3, the release
  # in which zip::unzip() began to make a link entry into a link.
  type <- entries[["type"]] %||% character(length(name))
  # A backslash on its own is a character an uploaded file's name may
  # hold, so only a `..` between either separator refuses a name.
  unsafe <- .hb_climbs_out(name) | grepl("^([/\\\\]|[A-Za-z]:)", name) |
    type %in% "symlink"
  bad <- name[unsafe]
  if (length(bad) > 0L) {
    # Not the path: in the explorer that is a temporary upload name the user
    # never chose, and its notice names the file already.
    hb_abort(
      c("That file's assets cannot be extracted safely.",
        "x" = "{length(bad)} unsafe entr{?y/ies}: {.file {bad}}.",
        "i" = "An asset must be a plain file or folder inside
               {.file asset/}, with no {.file ..} in its name and no
               leading {.file /} or drive letter."),
      class = "harbour_error_bad_argument",
      call = call
    )
  }
  invisible(NULL)
}

#' Warn about assets whose names differ only in case
#'
#' `zip::unzip()` finds an entry by name without regard to case, and a
#' macOS or Windows folder cannot hold two such files, so only one of
#' them may be extracted - and so written back.
#'
#' @param entries The asset rows of a `zip::zip_list()` listing.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_warn_asset_case <- function(entries) {
  files <- entries$filename[!endsWith(entries$filename, "/")]
  # zip folds A to Z alone, in every locale, while tolower() follows the
  # locale on Linux, where a Turkish one lowers "I" to a dotless "i".
  ascii <- chartr("A-Z", "a-z", files)
  full <- tolower(files)
  clash <- files[ascii %in% ascii[duplicated(ascii)] |
                   full %in% full[duplicated(full)]]
  if (length(clash) > 0L) {
    cli::cli_warn(c(
      "{length(clash)} assets have names that differ only in case:
       {.file {clash}}.",
      "x" = "Only one file of each such set may be extracted. A base
             written back lacks the others, and {.fn hb_asset_path} may
             give the extracted file for every name in the set."
    ))
  }
  invisible(NULL)
}

#' Check that every extracted asset landed inside its directory
#'
#' The names were checked before extracting. This catches what a name
#' cannot show, such as a link already in a user-supplied `assets_dir`
#' that leads out of it.
#'
#' @param dir The extraction directory.
#' @param entries The names of the entries extracted into it.
#' @param call The frame to blame for the error.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_check_extracted <- function(dir, entries, call = rlang::caller_env()) {
  written <- file.exists(file.path(dir, entries))
  entries <- entries[written]
  outside <- entries[!.hb_path_inside(file.path(dir, entries), dir)]
  if (length(outside) > 0L) {
    hb_abort(
      c("Some assets were extracted outside {.path {dir}}.",
        "x" = "{.file {outside}}",
        "i" = "Part of {.arg assets_dir} is a link that leads out of it."),
      class = "harbour_error_bad_argument",
      call = call
    )
  }
  invisible(NULL)
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
  for (i in seq_along(data)) {
    if (.hb_holds_objects(data[[i]])) {
      data[[i]] <- .hb_flatten_column(data[[i]])
    }
  }
  keys <- character()
  columns <- vector("list", ncol(data))
  for (i in seq_along(data)) {
    key <- .hb_new_column_key(keys)
    keys <- c(keys, key)
    columns[[i]] <- .hb_build_column(names(data)[[i]], data[[i]], key)
  }
  # On disk a select cell holds the option's id, not its name.
  option_ids <- lapply(columns, function(column) {
    options <- column$data$options
    if (is.null(options)) {
      return(NULL)
    }
    stats::setNames(
      .hb_chr_field(options, "id"), .hb_chr_field(options, "name")
    )
  })
  rows <- vector("list", nrow(data))
  stamp <- .hb_dtable_timestamp()
  for (r in seq_len(nrow(data))) {
    row <- list(`_id` = .hb_new_row_id(), `_ctime` = stamp, `_mtime` = stamp)
    for (i in seq_along(data)) {
      value <- .hb_cell_out(
        data[[i]][[r]], columns[[i]]$type, option_ids[[i]]
      )
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
    data <- list(options = .hb_select_options(levels))
  }
  if (type == "multiple-select") {
    used <- as.character(unlist(values, use.names = FALSE))
    data <- list(options = .hb_select_options(unique(used[!is.na(used)])))
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

#' Build the options of a select column
#'
#' @param labels The option names, in order.
#' @return A list of option objects with ids unique within the column.
#' @keywords internal
#' @noRd
.hb_select_options <- function(labels) {
  ids <- character()
  options <- vector("list", length(labels))
  for (i in seq_along(labels)) {
    id <- .hb_new_short_id(ids)
    ids <- c(ids, id)
    options[[i]] <- list(id = id, name = labels[[i]], color = "#eaa700")
  }
  options
}

#' Does a list-column hold objects rather than vectors of scalars?
#'
#' @param values A column.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_holds_objects <- function(values) {
  is.list(values) && !is.data.frame(values) &&
    any(vapply(values, is.list, logical(1)))
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
#' @param option_ids For a select column, option ids named by option name.
#' @return The JSON-ready value, or `NULL` when the cell is empty - in
#'   which case the key is omitted from the row, as SeaTable does.
#' @keywords internal
#' @noRd
.hb_cell_out <- function(value, type, option_ids = NULL) {
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
  if (type == "single-select") {
    return(.hb_option_id(as.character(value), option_ids))
  }
  if (type == "multiple-select") {
    labels <- as.character(unlist(value, use.names = FALSE))
    return(.hb_as_json_array(.hb_option_id(labels[!is.na(labels)], option_ids)))
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

#' Translate option names to the ids a `.dtable` stores
#'
#' @param labels Option names.
#' @param option_ids Option ids named by option name, or `NULL`.
#' @return A character vector as long as `labels`; a name with no option is
#'   kept as it is.
#' @keywords internal
#' @noRd
.hb_option_id <- function(labels, option_ids) {
  if (is.null(option_ids)) {
    return(labels)
  }
  hit <- unname(option_ids[labels])
  miss <- is.na(hit)
  hit[miss] <- labels[miss]
  hit
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

#' Can an existing file be opened for writing?
#'
#' It is opened for appending, so nothing in it changes. That is the test
#' writing straight into the file used to apply; `file.access()` only
#' approximates it, and can be wrong on a network file system.
#'
#' @param path An existing file, as an absolute path: `file()` gives some
#'   bare names, such as `"stdin"`, a meaning of their own.
#' @return A single `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_can_write <- function(path) {
  con <- tryCatch(
    suppressWarnings(file(path, open = "ab")),
    error = function(cnd) NULL
  )
  if (is.null(con)) {
    return(FALSE)
  }
  close(con)
  TRUE
}

#' Copy the extracted asset tree into the staging directory
#'
#' `file.copy(recursive = TRUE)` follows symbolic links, so a link in the
#' tree would put whatever it points at, from anywhere on the machine,
#' into the archive. The tree is copied entry by entry instead, leaving out
#' links and anything that resolves outside it, and given the permissions
#' the recursive copy gave: a tree without links is staged as before.
#'
#' @param from The `asset/` directory to copy.
#' @param to Where the copy goes. It must not exist yet.
#' @param call The frame to blame for any error.
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
.hb_stage_assets <- function(from, to, call = rlang::caller_env()) {
  entries <- list.files(from, recursive = TRUE, all.files = TRUE,
                        include.dirs = TRUE, no.. = TRUE)
  src <- file.path(from, entries)
  target <- Sys.readlink(src)
  link <- (!is.na(target) & nzchar(target)) | !.hb_path_inside(src, from)
  # list.files() also lists what is behind a link to a folder.
  behind <- vapply(
    entries,
    function(entry) any(startsWith(entry, paste0(entries[link], "/"))),
    logical(1),
    USE.NAMES = FALSE
  )
  keep <- !link & !behind
  is_dir <- dir.exists(src)
  dirs <- entries[keep & is_dir]
  files <- entries[keep & !is_dir]

  dir.create(to, showWarnings = FALSE)
  for (folder in file.path(to, dirs)) {
    dir.create(folder, recursive = TRUE, showWarnings = FALSE)
  }
  copied <- file.copy(file.path(from, files), file.path(to, files),
                      copy.mode = FALSE)
  # list.files() passes over a folder it cannot read without a word, so a
  # folder that cannot be read has failed to copy as surely as one that
  # could not be made.
  folders <- c("", dirs)
  readable <- file.access(c(from, file.path(from, dirs)), 5L) == 0L
  made <- dir.exists(c(to, file.path(to, dirs)))
  failed <- c(folders[!readable | !made], files[!copied])
  if (length(failed) > 0L) {
    failed <- file.path(basename(from), failed)
    hb_abort(
      c("The assets could not be copied into the archive.",
        "x" = "Not copied: {.file {failed}}."),
      class = "harbour_error_bad_argument",
      call = call
    )
  }
  # The source's permission bits, less the umask, as the recursive copy
  # set them; folders last, once nothing more is written into them.
  bits <- function(paths) bitwAnd(as.integer(file.mode(paths)), 511L)
  Sys.chmod(file.path(to, files), bits(file.path(from, files)))
  Sys.chmod(file.path(to, dirs), bits(file.path(from, dirs)))
  Sys.chmod(to, bits(from))

  skipped <- entries[link & !behind]
  if (length(skipped) > 0L) {
    skipped <- file.path(basename(from), skipped)
    cli::cli_warn(
      c("Left {length(skipped)} link{?s} out of the archive.",
        "x" = "{.file {skipped}}",
        "i" = "Links in the asset tree are not followed: they can lead to
               files anywhere on this machine."),
      class = "harbour_warning_asset_link",
      call = call
    )
  }
  invisible(NULL)
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
  referenced <- .hb_count_asset_files(x$assets)
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

#' Count the files in an asset listing
#'
#' `zip::zip_list()` lists each folder as an entry of its own, its name
#' ending in "/". Only the files are assets.
#'
#' @param assets The `assets` component of a `harbour_dtable`.
#' @return A single integer.
#' @keywords internal
#' @noRd
.hb_count_asset_files <- function(assets) {
  sum(!endsWith(assets$filename %||% character(), "/"))
}
