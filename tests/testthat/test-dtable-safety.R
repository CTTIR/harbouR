fixture <- function() {
  system.file("extdata", "example.dtable", package = "harbouR")
}

minimal_content <- paste0(
  '{"version":1,"format_version":9,"statistics":[],"links":[],',
  '"tables":[],"collaborators":[]}'
)

# Build a .dtable from entry names and their contents; a name ending in "/"
# is a folder. zip::zip() stores whatever `keys` it is given, so an archive
# whose names climb out of the extraction directory can be made without
# writing anything outside a temporary directory.
dtable_with <- function(entries = character(), links = character(),
                        content = minimal_content, env = parent.frame()) {
  skip_if_not("keys" %in% names(formals(zip::zip)), "zip is older than 3.0.0")
  path <- withr::local_tempfile(fileext = ".dtable", .local_envir = env)
  src <- withr::local_tempdir()
  entries <- c("content.json" = content, entries)
  files <- as.character(seq_along(entries))
  for (i in seq_along(entries)) {
    if (endsWith(names(entries)[[i]], "/")) {
      dir.create(file.path(src, files[[i]]))
    } else {
      writeBin(charToRaw(entries[[i]]), file.path(src, files[[i]]))
    }
  }
  # zip::zip() warns about names that climb out, which is the point here.
  suppressWarnings(zip::zip(
    path, files = files, keys = sub("/$", "", names(entries)),
    root = src, mode = "mirror"
  ))
  mark_as_links(path, links)
  path
}

# zip::zip() follows a link rather than storing it, so a link entry is made
# by rewriting an ordinary entry's central-directory record: made by Unix,
# with mode 0120777. The entry's data, the link's target, is left as it is.
mark_as_links <- function(path, links) {
  if (length(links) == 0L) {
    return(invisible(path))
  }
  bytes <- readBin(path, "raw", file.size(path))
  u16 <- function(i) {
    as.integer(bytes[[i]]) + 256L * as.integer(bytes[[i + 1L]])
  }
  header <- as.raw(c(0x50, 0x4b, 0x01, 0x02))
  for (i in which(bytes == header[[1L]])) {
    if (i + 46L > length(bytes) || !identical(bytes[i + 0:3], header)) next
    name <- bytes[i + 45L + seq_len(u16(i + 28L))]
    if (any(name == as.raw(0L)) || !rawToChar(name) %in% links) next
    bytes[[i + 5L]] <- as.raw(3L)
    bytes[i + 38:41] <- as.raw(c(0x00, 0x00, 0xff, 0xa1))
  }
  writeBin(bytes, path)
  invisible(path)
}

# zip::zip() refuses some names outright, so those are made by renaming an
# entry in place, in its local header and in the central directory. The
# new name must be as long as the old one.
rename_entry <- function(path, from, to) {
  bytes <- readBin(path, "raw", file.size(path))
  old <- charToRaw(from)
  new <- charToRaw(to)
  stopifnot(length(old) == length(new))
  for (i in which(bytes == old[[1L]])) {
    at <- i + seq_along(old) - 1L
    if (max(at) <= length(bytes) && identical(bytes[at], old)) {
      bytes[at] <- new
    }
  }
  writeBin(bytes, path)
  invisible(path)
}

everything_under <- function(dir) {
  list.files(dir, recursive = TRUE, all.files = TRUE, include.dirs = TRUE)
}

test_that("an asset entry that climbs out of asset/ refuses the archive", {
  sandbox <- withr::local_tempdir()
  target <- file.path(sandbox, "deep", "target")
  archive <- dtable_with(c(
    "asset/files/ok.txt" = "legit",
    "asset/../../escaped.txt" = "escaped"
  ))
  expect_error(
    hb_read_dtable(archive, assets = "extract", assets_dir = target),
    "asset/../../escaped.txt", fixed = TRUE,
    class = "harbour_error_bad_argument"
  )
  # Refused before anything was extracted, inside the target or out of it.
  expect_identical(everything_under(sandbox), character())
  # Reading without extracting writes nothing, so that still works.
  expect_s3_class(hb_read_dtable(archive), "harbour_dtable")
})

test_that("a refused archive is not named by its temporary path", {
  # The explorer shows this message for an upload, whose path is Shiny's
  # temporary name for it rather than the file the user chose.
  archive <- dtable_with(c("asset/../escaped.txt" = "escaped"))
  cnd <- rlang::catch_cnd(hb_read_dtable(archive, assets = "extract"),
                          classes = "error")
  shown <- harbouR:::.hb_plain_message(cnd)
  expect_match(shown, "cannot be extracted safely", fixed = TRUE)
  expect_match(shown, "asset/../escaped.txt", fixed = TRUE)
  expect_false(grepl(basename(archive), shown, fixed = TRUE))
})

test_that("a backslash that climbs out refuses the archive", {
  # A separator on Windows, so "asset/..\.." climbs out there.
  sandbox <- withr::local_tempdir()
  archive <- dtable_with(c("asset/..X..Xescaped.txt" = "escaped"))
  rename_entry(archive, "asset/..X..Xescaped.txt", "asset/..\\..\\escaped.txt")
  expect_true("asset/..\\..\\escaped.txt" %in% zip::zip_list(archive)$filename)
  expect_error(
    hb_read_dtable(archive, assets = "extract",
                   assets_dir = file.path(sandbox, "target")),
    class = "harbour_error_bad_argument"
  )
  expect_identical(everything_under(sandbox), character())
})

test_that("a backslash that climbs nowhere is part of a file's name", {
  # Outside Windows a backslash is an ordinary character in a file name,
  # and an uploaded attachment may have one: it extracts like any other.
  sandbox <- withr::local_tempdir()
  target <- file.path(sandbox, "target")
  archive <- dtable_with(c("asset/files/aXb.txt" = "kept"))
  rename_entry(archive, "asset/files/aXb.txt", "asset/files/a\\b.txt")
  base <- hb_read_dtable(archive, assets = "extract", assets_dir = target)
  expect_true("asset/files/a\\b.txt" %in% base$assets$filename)
  expect_true(file.exists(file.path(target, "asset/files/a\\b.txt")))
  expect_true(all(startsWith(
    normalizePath(file.path(sandbox, everything_under(sandbox))),
    normalizePath(target)
  )))
})

test_that("only the asset/ tree is extracted, not names that start alike", {
  sandbox <- withr::local_tempdir()
  target <- file.path(sandbox, "deep", "target")
  archive <- dtable_with(c(
    "asset/files/ok.txt" = "legit",
    "assets.txt" = "sibling",
    "assetX/y.txt" = "sibling",
    "asset_evil/../../escaped.txt" = "escaped"
  ))
  base <- hb_read_dtable(archive, assets = "extract", assets_dir = target)
  expect_identical(base$assets$filename, "asset/files/ok.txt")
  expect_identical(
    list.files(sandbox, recursive = TRUE, all.files = TRUE),
    "deep/target/asset/files/ok.txt"
  )
})

test_that("a link in the asset tree refuses the archive", {
  skip_on_os("windows")
  sandbox <- withr::local_tempdir()
  outside <- file.path(sandbox, "outside")
  dir.create(outside)
  secret <- file.path(sandbox, "secret.txt")
  writeLines("secret", secret)
  archive <- dtable_with(
    c(
      "asset/" = "",
      "asset/link" = outside,
      "asset/link/evil.txt" = "evil",
      "asset/notes.txt" = secret
    ),
    links = c("asset/link", "asset/notes.txt")
  )
  listing <- zip::zip_list(archive)
  expect_identical(
    listing$type[listing$filename %in% c("asset/link", "asset/notes.txt")],
    c("symlink", "symlink")
  )
  err <- expect_error(
    hb_read_dtable(archive, assets = "extract",
                   assets_dir = file.path(sandbox, "target")),
    class = "harbour_error_bad_argument"
  )
  expect_match(conditionMessage(err), "asset/link", fixed = TRUE)
  expect_match(conditionMessage(err), "asset/notes.txt", fixed = TRUE)
  # Nothing was written through the link, and no link was made that a
  # later hb_write_dtable() would follow to secret.txt.
  expect_setequal(everything_under(sandbox), c("outside", "secret.txt"))
})

test_that("extracted files that resolve outside assets_dir are refused", {
  skip_on_os("windows")
  sandbox <- withr::local_tempdir()
  target <- file.path(sandbox, "target")
  elsewhere <- file.path(sandbox, "elsewhere")
  dir.create(target)
  dir.create(elsewhere)
  # The archive's names are clean; a link already in assets_dir is what
  # sends the files elsewhere.
  expect_true(file.symlink(elsewhere, file.path(target, "asset")))
  expect_error(
    hb_read_dtable(fixture(), assets = "extract", assets_dir = target),
    class = "harbour_error_bad_argument"
  )
})

test_that("the example file extracts and round-trips byte for byte", {
  path <- fixture()
  dir <- withr::local_tempdir()
  base <- hb_read_dtable(path, assets = "extract", assets_dir = dir)
  listing <- zip::zip_list(path)
  assets <- listing[startsWith(listing$filename, "asset/"), ]
  expect_identical(base$assets$filename, assets$filename)
  expect_setequal(
    paste0(everything_under(dir), ifelse(
      dir.exists(file.path(dir, everything_under(dir))), "/", ""
    )),
    assets$filename
  )
  for (entry in assets$filename[assets$type == "file"]) {
    con <- unz(path, entry, open = "rb")
    inside <- readBin(con, "raw", 1e6)
    close(con)
    extracted <- file.path(dir, entry)
    expect_identical(readBin(extracted, "raw", file.size(extracted)), inside)
  }

  out <- withr::local_tempfile(fileext = ".dtable")
  expect_no_warning(hb_write_dtable(base, out))
  again <- zip::zip_list(out)
  expect_identical(again$filename, listing$filename)
  expect_identical(again$type, listing$type)
  expect_identical(again$uncompressed_size, listing$uncompressed_size)
  expect_identical(again$crc32, listing$crc32)
})

test_that("content.json parses exactly as it did through fromJSON()", {
  # In a UTF-8 session, where the old reading was right.
  skip_if_not(isTRUE(l10n_info()[["UTF-8"]]), "the session is not UTF-8")
  con <- unz(fixture(), "content.json", open = "rb")
  bytes <- readBin(con, "raw", 1e6)
  close(con)
  expect_identical(
    harbouR:::.hb_dtable_from_json(bytes),
    jsonlite::fromJSON(rawToChar(bytes), simplifyVector = FALSE,
                       simplifyDataFrame = FALSE, simplifyMatrix = FALSE)
  )
})

test_that("a content.json that names another file is not read as that file", {
  # jsonlite::fromJSON() reads a short string that is not JSON as a path,
  # or fetches it as a URL; a .dtable's content.json is whatever its
  # author wrote.
  real <- withr::local_tempfile(fileext = ".json")
  writeLines('{"version": 1, "tables": [], "leaked": "not-for-reading"}', real)
  archive <- dtable_with(content = normalizePath(real))
  err <- expect_error(hb_read_dtable(archive))
  expect_no_match(conditionMessage(err), "not-for-reading", fixed = TRUE)
})

test_that("text reads back the same in a session that is not UTF-8", {
  text <- "M\u00fcller \u00b5g \u65e5\u672c"
  base <- hb_dtable(T1 = data.frame(x = text))
  out <- withr::local_tempfile(fileext = ".dtable")
  hb_write_dtable(base, out)
  expected <- hb_read_dtable(out)$content
  withr::local_locale(c(LC_CTYPE = "C"))
  skip_if(isTRUE(l10n_info()[["UTF-8"]]), "could not leave a UTF-8 locale")
  content <- hb_read_dtable(out)$content
  expect_identical(content, expected)
  expect_identical(content$tables[[1L]]$rows[[1L]][["0000"]], text)
})

test_that("a table name is shown, not run, when a base cannot be written", {
  base <- hb_dtable(A = data.frame(x = 1), B = data.frame(x = 2))
  for (i in 1:2) {
    base$content$tables[[i]]$name <- "{cat('X')}"
    base$content$tables[[i]][["_id"]] <- "{cat('Y')}"
  }
  out <- withr::local_tempfile(fileext = ".dtable")
  expect_output(
    err <- expect_error(hb_write_dtable(base, out),
                        class = "harbour_error_bad_argument"),
    NA
  )
  expect_match(conditionMessage(err), "duplicate table name `{cat('X')}`",
               fixed = TRUE)
  expect_match(conditionMessage(err), "duplicate table id `{cat('Y')}`",
               fixed = TRUE)
  expect_false(file.exists(out))
})

test_that("an asset tree of folders alone is not counted as assets", {
  archive <- dtable_with(c("asset/" = "", "asset/files/" = ""))
  base <- hb_read_dtable(archive)
  # The listing is the archive's own, folders included.
  expect_identical(base$assets$filename, c("asset/", "asset/files/"))
  out <- withr::local_tempfile(fileext = ".dtable")
  expect_no_warning(hb_write_dtable(base, out))
  expect_match(cli::ansi_strip(cli::cli_fmt(print(base))), "assets : 0",
               fixed = TRUE, all = FALSE)
})

test_that("a filtered view with no recorded rows says it was not applied", {
  base <- hb_read_dtable(fixture())
  base$content$tables[[1L]]$views[[1L]]$filters <- list(list(
    column_key = "0000", filter_predicate = "is", filter_term = "S-001"
  ))
  expect_warning(
    data <- hb_read_table(base, "Samples", view = "Default View"),
    class = "harbour_warning_view_filters"
  )
  # The warning changes nothing: the whole table, as before.
  expect_identical(nrow(data), 2L)

  # Recorded rows are what a file view restricts to, filters or not.
  base$content$tables[[1L]]$views[[1L]]$rows <- list("CwD7tBAETtSXLQKQXhaR6A")
  expect_no_warning(
    data <- hb_read_table(base, "Samples", view = "Default View")
  )
  expect_identical(nrow(data), 1L)
})

test_that("a failed write leaves the file it would replace as it was", {
  base <- hb_dtable(A = data.frame(x = 1))
  dir <- withr::local_tempdir()
  out <- file.path(dir, "base.dtable")
  hb_write_dtable(base, out)
  before <- readBin(out, "raw", file.size(out))
  local_mocked_bindings(
    zip = function(zipfile, ...) {
      writeBin(as.raw(1:10), zipfile)
      stop("disk full")
    },
    .package = "zip"
  )
  expect_error(hb_write_dtable(base, out), "disk full")
  expect_identical(readBin(out, "raw", file.size(out)), before)
  # The half-written archive is not left behind either.
  expect_identical(list.files(dir, all.files = TRUE, no.. = TRUE),
                   "base.dtable")
})

test_that("a failed write of a new file leaves nothing behind", {
  base <- hb_dtable(A = data.frame(x = 1))
  dir <- withr::local_tempdir()
  local_mocked_bindings(
    zip = function(zipfile, ...) {
      writeBin(as.raw(1:10), zipfile)
      stop("disk full")
    },
    .package = "zip"
  )
  # Not a half-written archive that a later read would trip over.
  expect_error(hb_write_dtable(base, file.path(dir, "new.dtable")),
               "disk full")
  expect_identical(list.files(dir, all.files = TRUE, no.. = TRUE),
                   character())
})

test_that("a file that cannot be replaced is written into instead", {
  # As on Windows when another program holds the file open, or in a
  # folder that lets files be written but not removed.
  skip_on_os("windows")
  dir <- withr::local_tempdir()
  out <- file.path(dir, "base.dtable")
  hb_write_dtable(hb_dtable(A = data.frame(x = 1)), out)
  # A shared file's mode, which a umask would narrow.
  Sys.chmod(out, "666", use_umask = FALSE)
  local_mocked_bindings(file.rename = function(...) FALSE, .package = "base")
  expect_no_warning(hb_write_dtable(hb_dtable(B = data.frame(y = 2)), out))
  expect_identical(names(hb_read_dtable(out)), "B")
  expect_identical(format(file.mode(out)), "666")
  expect_identical(list.files(dir, all.files = TRUE, no.. = TRUE),
                   "base.dtable")
})

test_that("a file that can be neither replaced nor written is left as it was", {
  base <- hb_dtable(A = data.frame(x = 1))
  dir <- withr::local_tempdir()
  out <- file.path(dir, "base.dtable")
  hb_write_dtable(base, out)
  before <- readBin(out, "raw", file.size(out))
  local_mocked_bindings(file.rename = function(...) FALSE,
                        file.copy = function(...) FALSE, .package = "base")
  expect_error(hb_write_dtable(hb_dtable(B = data.frame(y = 2)), out),
               "base.dtable", fixed = TRUE,
               class = "harbour_error_bad_argument")
  expect_identical(readBin(out, "raw", file.size(out)), before)
  expect_identical(list.files(dir, all.files = TRUE, no.. = TRUE),
                   "base.dtable")
})

test_that("an asset that cannot be copied stops the write", {
  skip_on_os("windows")
  base <- hb_read_dtable(fixture(), assets = "extract",
                         assets_dir = withr::local_tempdir())
  locked <- file.path(base$assets_dir, "asset", "files", "2026-07",
                      "readme.txt")
  Sys.chmod(locked, "000", use_umask = FALSE)
  withr::defer(Sys.chmod(locked, "644", use_umask = FALSE))
  skip_if(file.access(locked, 4L) == 0L, "this user can read any file")
  dir <- withr::local_tempdir()
  out <- file.path(dir, "base.dtable")
  expect_error(hb_write_dtable(base, out), "readme.txt", fixed = TRUE,
               class = "harbour_error_bad_argument")
  expect_identical(list.files(dir, all.files = TRUE, no.. = TRUE),
                   character())
})

test_that("a folder of assets that cannot be read stops the write", {
  skip_on_os("windows")
  base <- hb_read_dtable(fixture(), assets = "extract",
                         assets_dir = withr::local_tempdir())
  locked <- file.path(base$assets_dir, "asset", "images", "2026-07")
  Sys.chmod(locked, "000", use_umask = FALSE)
  withr::defer(Sys.chmod(locked, "755", use_umask = FALSE))
  skip_if(file.access(locked, 4L) == 0L, "this user can read any folder")
  dir <- withr::local_tempdir()
  out <- file.path(dir, "base.dtable")
  # Its files cannot even be listed, so nothing else would say they are
  # missing from the archive.
  expect_error(hb_write_dtable(base, out), "asset/images/2026-07",
               fixed = TRUE, class = "harbour_error_bad_argument")
  expect_identical(list.files(dir, all.files = TRUE, no.. = TRUE),
                   character())
})

test_that("replacing a file keeps its permissions and writes through links", {
  skip_on_os("windows")
  base <- hb_dtable(A = data.frame(x = 1))
  dir <- withr::local_tempdir()
  real <- file.path(dir, "real.dtable")
  hb_write_dtable(base, real)
  Sys.chmod(real, "600", use_umask = FALSE)
  link <- file.path(dir, "link.dtable")
  expect_true(file.symlink(real, link))
  hb_write_dtable(hb_dtable(B = data.frame(y = 2)), link)
  expect_identical(Sys.readlink(link), real)
  expect_identical(format(file.mode(real)), "600")
  expect_identical(names(hb_read_dtable(real)), "B")
})

test_that("an empty destination is written into, not replaced", {
  skip_on_os("windows")
  dir <- withr::local_tempdir()
  out <- file.path(dir, "empty.dtable")
  file.create(out)
  twin <- file.path(dir, "twin.dtable")
  skip_if_not(file.link(out, twin), "no hard links here")
  hb_write_dtable(hb_dtable(A = data.frame(x = 1)), out)
  # Its other name sees the archive too: the same file, written into.
  expect_identical(names(hb_read_dtable(twin)), "A")
})

test_that("/dev/null can still be written to", {
  skip_on_os("windows")
  skip_if_not(file.exists("/dev/null"))
  # Only where /dev takes no new files, so it could not be replaced anyway.
  skip_if(file.access("/dev", 2L) == 0L, "this user can write to /dev")
  expect_no_error(hb_write_dtable(hb_dtable(A = data.frame(x = 1)),
                                  "/dev/null"))
})

test_that("a file in a folder that takes no new files is written into", {
  skip_on_os("windows")
  dir <- withr::local_tempdir()
  out <- file.path(dir, "base.dtable")
  hb_write_dtable(hb_dtable(A = data.frame(x = 1)), out)
  Sys.chmod(dir, "555", use_umask = FALSE)
  withr::defer(Sys.chmod(dir, "755", use_umask = FALSE))
  skip_if(file.access(dir, 2L) == 0L, "this user can write any folder")
  hb_write_dtable(hb_dtable(B = data.frame(y = 2)), out)
  expect_identical(names(hb_read_dtable(out)), "B")
})

test_that("a link to a file not made yet is written through", {
  skip_on_os("windows")
  dir <- withr::local_tempdir()
  real <- file.path(dir, "real.dtable")
  link <- file.path(dir, "link.dtable")
  expect_true(file.symlink(real, link))
  hb_write_dtable(hb_dtable(A = data.frame(x = 1)), link)
  # The link is kept, and writing made the file it points at.
  expect_identical(Sys.readlink(link), real)
  expect_identical(names(hb_read_dtable(real)), "A")
})

test_that("a new file in a folder that takes no new files is refused", {
  skip_on_os("windows")
  dir <- withr::local_tempdir()
  Sys.chmod(dir, "555", use_umask = FALSE)
  withr::defer(Sys.chmod(dir, "755", use_umask = FALSE))
  skip_if(file.access(dir, 2L) == 0L, "this user can write any folder")
  out <- file.path(dir, "base.dtable")
  # The message names the destination, not the file it would be built in.
  expect_error(hb_write_dtable(hb_dtable(A = data.frame(x = 1)), out),
               "base.dtable", fixed = TRUE,
               class = "harbour_error_bad_argument")
  expect_identical(list.files(dir, all.files = TRUE, no.. = TRUE),
                   character())
})

test_that("the asset tree keeps its permissions in the archive", {
  skip_on_os("windows")
  assets <- withr::local_tempdir()
  tree <- file.path(assets, "asset", "files")
  dir.create(file.path(tree, "private"), recursive = TRUE)
  writeLines("run", file.path(tree, "run.sh"))
  writeLines("mine", file.path(tree, "private", "mine.txt"))
  Sys.chmod(file.path(tree, "run.sh"), "755", use_umask = FALSE)
  Sys.chmod(file.path(tree, "private", "mine.txt"), "600", use_umask = FALSE)
  Sys.chmod(file.path(tree, "private"), "700", use_umask = FALSE)
  base <- hb_dtable(A = data.frame(x = 1))
  base$assets_dir <- assets
  out <- withr::local_tempfile(fileext = ".dtable")
  hb_write_dtable(base, out)
  listing <- zip::zip_list(out)
  entries <- c("asset/files/run.sh", "asset/files/private/",
               "asset/files/private/mine.txt")
  # What copying the tree has always given them: the source's permission
  # bits, less the umask.
  umask <- as.integer(Sys.umask())
  expected <- bitwAnd(strtoi(c("755", "700", "600"), 8L), bitwNot(umask))
  expect_identical(
    format(listing$permissions[match(entries, listing$filename)]),
    format(as.octmode(expected))
  )
})

test_that("a file that may not be written is still refused", {
  skip_on_os("windows")
  base <- hb_dtable(A = data.frame(x = 1))
  dir <- withr::local_tempdir()
  out <- file.path(dir, "base.dtable")
  hb_write_dtable(base, out)
  before <- readBin(out, "raw", file.size(out))
  Sys.chmod(out, "444", use_umask = FALSE)
  withr::defer(Sys.chmod(out, "644", use_umask = FALSE))
  skip_if(file.access(out, 2L) == 0L, "this user can write any file")
  expect_error(hb_write_dtable(hb_dtable(B = data.frame(y = 2)), out))
  expect_identical(readBin(out, "raw", file.size(out)), before)
})

test_that("links in the asset tree are left out of the archive", {
  skip_on_os("windows")
  sandbox <- withr::local_tempdir()
  secret <- file.path(sandbox, "secret.txt")
  writeLines("SECRET", secret)
  outside <- file.path(sandbox, "outside")
  dir.create(outside)
  writeLines("SECRET", file.path(outside, "more.txt"))
  assets <- file.path(sandbox, "assets")
  dir.create(file.path(assets, "asset", "files"), recursive = TRUE)
  writeLines("legit", file.path(assets, "asset", "files", "ok.txt"))
  expect_true(file.symlink(secret, file.path(assets, "asset", "files",
                                             "notes.txt")))
  expect_true(file.symlink(outside, file.path(assets, "asset", "more")))
  base <- hb_dtable(A = data.frame(x = 1))
  base$assets_dir <- assets
  out <- withr::local_tempfile(fileext = ".dtable")
  expect_warning(hb_write_dtable(base, out),
                 class = "harbour_warning_asset_link")
  expect_identical(
    zip::zip_list(out)$filename,
    c("content.json", "asset/", "asset/files/", "asset/files/ok.txt")
  )
})
