example_dtable <- function() {
  system.file("extdata", "example.dtable", package = "harbouR")
}

# hb_read_csv() used to hand each file straight to read.csv() and keep its
# type conversion. Columns with nothing to protect must still come out
# exactly as this did.
read_csv_as_before <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE,
                  fileEncoding = "UTF-8")
}

column_types <- function(base, table) {
  hb_list_columns(base, table)$type
}

# Reading CSV files ---------------------------------------------------------

test_that("hb_read_csv keeps zero-padded and long integers as text", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "Code,Ref,Barcode,Signed,Count,Share",
    '"007","0001","1234567890123456789",-007,0,0.5',
    '"010",NA,"0000000000000000001",+12,3,1.5'
  ), path)
  base <- hb_read_csv(c(T = path))
  expect_identical(
    column_types(base, "T"),
    c("text", "text", "text", "text", "number", "number")
  )
  data <- hb_read_table(base, "T")
  expect_identical(data$Code, c("007", "010"))
  expect_identical(data$Ref, c("0001", NA))
  expect_identical(data$Barcode,
                   c("1234567890123456789", "0000000000000000001"))
  expect_identical(data$Signed, c("-007", "+12"))
  # A lone zero and a decimal below one have no zeros to lose.
  expect_identical(data$Count, c(0, 3))
  expect_identical(data$Share, c(0.5, 1.5))
})

test_that("hb_read_csv keeps codes that end in an exponent letter as text", {
  # Before R 4.4.1, read.csv() read "12E" as 12, taking the letter for an
  # exponent with no digits. A number with a real exponent is still one.
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("Code,Small,Big", "12E,2.5E-1,1e5", "6e,5e-1,2E+5"), path)
  base <- hb_read_csv(c(T = path))
  expect_identical(column_types(base, "T"), c("text", "number", "number"))
  data <- hb_read_table(base, "T")
  expect_identical(data$Code, c("12E", "6e"))
  expect_identical(data$Small, c(0.25, 0.5))
  expect_identical(data$Big, c(1e5, 2e5))
})

test_that("a Unicode space after a padded code does not make it a number", {
  # type.convert() ignores a trailing full-width or em space in a UTF-8
  # session, so "0001" followed by one was read as 1.
  skip_if_not(l10n_info()[["UTF-8"]], "not a UTF-8 session")
  path <- withr::local_tempfile(fileext = ".csv")
  con <- file(path, open = "wb")
  writeLines(enc2utf8(c("Code,Ref,Plain", "0001\u3000,0002\u2003,1\u3000",
                        "0003,0004,2")), con, useBytes = TRUE)
  close(con)
  base <- hb_read_csv(c(T = path))
  expect_identical(column_types(base, "T"), c("text", "text", "number"))
  data <- hb_read_table(base, "T")
  expect_identical(data$Code, c("0001\u3000", "0003"))
  expect_identical(data$Ref, c("0002\u2003", "0004"))
  expect_identical(data$Plain, c(1, 2))
})

test_that("a sixteen-digit integer is text, a fifteen-digit one a number", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("Long,Short", "1234567890123456,123456789012345"), path)
  base <- hb_read_csv(c(T = path))
  expect_identical(column_types(base, "T"), c("text", "number"))
  data <- hb_read_table(base, "T")
  expect_identical(data$Long, "1234567890123456")
  expect_identical(data$Short, 123456789012345)
})

test_that("every other column is typed exactly as read.csv() types it", {
  dir <- withr::local_tempdir()
  cases <- list(
    numbers = c(
      "neg,dec,exp,int,wide,quoted,padded,inf,hex",
      '-1,0.5,1e5,0,2147483648,"12", 7,Inf,0x1A',
      '-2.5,.25,2.5E-3,10,123456789012345,"-3",8 ,-Inf,0x10',
      ",,,,,,,,"
    ),
    # More digits than a double holds: read.csv() keeps the nearest one.
    decimals = c("long", "3.14159265358979323846", "0.1234567890123456789"),
    logicals = c("tf,word,gaps", "T,TRUE,T", "F,FALSE,", "NA,NA,F"),
    text = c(
      "blank,spaces,na,quoted_na,date,stamp,lower",
      ',  ,NA,"NA",2026-04-01,2026-07-27 12:00:00,true',
      'a, b ,x,y,2026-04-03,2026-07-27,false'
    ),
    empty = c("a,b", ",", '"",""'),
    header = "a,b",
    # One field fewer in the header makes the first column row names.
    row_names = c("a,b", "r1,1,2", "r2,3,4"),
    quoted = c("a,b", '"x, y","1"', '"two\nlines",2', '"say ""hi""",3')
  )
  for (name in names(cases)) {
    path <- file.path(dir, paste0(name, ".csv"))
    writeLines(cases[[name]], path)
    expect_identical(
      harbouR:::.hb_read_csv_file(path), read_csv_as_before(path),
      label = name
    )
  }
  bytes <- list(
    crlf = charToRaw("a,b\r\n1,x\r\n2,y\r\n"),
    bom = c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("a,b\n1,T\n2,F\n"))
  )
  for (name in names(bytes)) {
    path <- file.path(dir, paste0(name, ".csv"))
    writeBin(bytes[[name]], path)
    # read.csv(fileEncoding = "UTF-8") reads a byte-order mark only in a
    # UTF-8 session, so only there is it a reference for one.
    if (name == "bom" && !isTRUE(l10n_info()[["UTF-8"]])) next
    expect_identical(
      harbouR:::.hb_read_csv_file(path), read_csv_as_before(path),
      label = name
    )
  }
})

test_that("the example base's CSV export reads as before but for its Ref", {
  # Outside a UTF-8 session read.csv(fileEncoding = "UTF-8") cuts the file
  # off at its first non-ASCII character, so it is a reference only here.
  skip_if_not(isTRUE(l10n_info()[["UTF-8"]]), "the session is not UTF-8")
  dir <- withr::local_tempdir()
  base <- hb_read_dtable(example_dtable())
  files <- suppressMessages(hb_write_csv(base, dir))
  for (path in files) {
    before <- read_csv_as_before(path)
    now <- harbouR:::.hb_read_csv_file(path)
    expect_identical(names(now), names(before))
    same <- setdiff(names(before), "Ref")
    expect_identical(now[same], before[same])
  }
  samples <- harbouR:::.hb_read_csv_file(file.path(dir, "Samples.csv"))
  # An auto-number is zero-padded text, and used to come back as 1.
  expect_identical(samples$Ref, c("0001", NA))
})

test_that("T/F text, a literal NA and dates keep read.csv()'s handling", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "Flag,Code,When",
    '"T","NA",2026-04-01',
    '"F","EU",2026-04-03'
  ), path)
  base <- hb_read_csv(c(T = path))
  expect_identical(column_types(base, "T"), c("checkbox", "text", "text"))
  data <- hb_read_table(base, "T")
  expect_identical(data$Flag, c(TRUE, FALSE))
  expect_identical(data$Code, c(NA, "EU"))
  expect_identical(data$When, c("2026-04-01", "2026-04-03"))
})

test_that("hb_read_csv refuses a file that is not UTF-8, naming the line", {
  path <- withr::local_tempfile(fileext = ".csv")
  # "Muller" with a u-umlaut as Windows-1252 writes it: 0xFC on its own is
  # not valid UTF-8, and read.csv() used to stop there without an error.
  writeBin(
    c(charToRaw("Name,Temp\nA,1\nM"), as.raw(0xfc),
      charToRaw("ller,2\nC,3\nD,4\n")),
    path
  )
  err <- expect_error(hb_read_csv(c(T = path)),
                      class = "harbour_error_bad_argument")
  message <- conditionMessage(err)
  expect_match(message, basename(path), fixed = TRUE)
  expect_match(message, "line 3", fixed = TRUE)
  expect_match(message, "CSV UTF-8", fixed = TRUE)
})

test_that("a nul does not hide a byte that is not UTF-8", {
  path <- withr::local_tempfile(fileext = ".csv")
  # read.csv() used to keep only "x" here, and drop every later row.
  writeBin(
    c(charToRaw("a,b\n1,x"), as.raw(0L), as.raw(0xfc), charToRaw("\n2,y\n")),
    path
  )
  err <- expect_error(hb_read_csv(c(T = path)),
                      class = "harbour_error_bad_argument")
  expect_match(conditionMessage(err), "line 2", fixed = TRUE)
})

test_that("a byte-order mark, embedded nuls and compression still read", {
  dir <- withr::local_tempdir()

  bom <- file.path(dir, "bom.csv")
  writeBin(
    c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("Name,Value\nA,1\n")),
    bom
  )
  data <- hb_read_table(hb_read_csv(c(T = bom)), "T")
  expect_identical(names(data), c("Name", "Value", "_id"))

  nul <- file.path(dir, "nul.csv")
  writeBin(c(charToRaw("a,b\n1,2\n3,"), as.raw(0L), charToRaw("4\n")), nul)
  expect_no_error(suppressWarnings(hb_read_csv(c(T = nul))))

  # A multibyte session that is not UTF-8 holds the text in its own
  # encoding, which may lack the character below.
  multibyte <- isTRUE(l10n_info()[["MBCS"]]) && !isTRUE(l10n_info()[["UTF-8"]])
  skip_if(multibyte, "the session's encoding may lack the character")
  gz <- file.path(dir, "packed.csv.gz")
  con <- gzfile(gz, "wb")
  writeLines(c("Name,Value", "M\u00fcller,1"), con, useBytes = TRUE)
  close(con)
  data <- hb_read_table(hb_read_csv(c(T = gz)), "T")
  expect_identical(data$Name, "M\u00fcller")
})

test_that("an empty CSV file is refused, naming it", {
  dir <- withr::local_tempdir()
  empty <- file.path(dir, "empty.csv")
  file.create(empty)
  err <- expect_error(hb_read_csv(empty), class = "harbour_error_bad_argument")
  expect_match(conditionMessage(err), "empty.csv", fixed = TRUE)

  # What a spreadsheet writes for a blank sheet: a byte-order mark and a
  # line break, but no header.
  bom <- file.path(dir, "blank.csv")
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("\r\n")), bom)
  expect_error(hb_read_csv(bom), class = "harbour_error_bad_argument")
})

test_that("a UTF-8 file reads whole in a session that is not UTF-8", {
  # Written before the locale changes, so the bytes are exactly these.
  path <- withr::local_tempfile(fileext = ".csv")
  writeBin(c(
    as.raw(c(0xef, 0xbb, 0xbf)),
    charToRaw("Name,Temp (\xc2\xb0C)\nM\xc3\xbcller,1\n"),
    charToRaw("\xe6\x97\xa5\xe6\x9c\xac,2\ngamma,3\n")
  ), path)
  withr::local_locale(c(LC_CTYPE = "C"))
  skip_if(isTRUE(l10n_info()[["UTF-8"]]), "The C locale is UTF-8 here.")
  data <- hb_read_table(hb_read_csv(c(T = path)), "T")
  expect_identical(names(data)[1:2], c("Name", "Temp (\u00b0C)"))
  expect_identical(data$Name, c("M\u00fcller", "\u65e5\u672c", "gamma"))
})

test_that("hb_write_csv writes UTF-8 in a session that is not UTF-8", {
  dir <- withr::local_tempdir()
  base <- hb_dtable(T = data.frame(Name = c("M\u00fcller", "\u65e5\u672c")))
  withr::local_locale(c(LC_CTYPE = "C"))
  skip_if(isTRUE(l10n_info()[["UTF-8"]]), "The C locale is UTF-8 here.")
  path <- hb_write_csv(base, dir)
  text <- rawToChar(readBin(path, "raw", file.size(path)))
  Encoding(text) <- "UTF-8"
  expect_true(grepl("M\u00fcller", text, fixed = TRUE, useBytes = TRUE))
  expect_true(grepl("\u65e5\u672c", text, fixed = TRUE, useBytes = TRUE))
  expect_false(grepl("<U+", text, fixed = TRUE, useBytes = TRUE))
})

test_that("a CSV that may be a pipe is copied before it is read", {
  # A pipe or a FIFO reports no size and can be read only once, while the
  # check reads a file before read.csv() does; such input is copied and
  # the copy read. A regular file is read where it is, so that read.csv()'s
  # warnings name it.
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("a,b", "1,x", "2,y"), path)
  copies <- 0L
  real_copy <- base::file.copy
  local_mocked_bindings(
    file.copy = function(...) {
      copies <<- copies + 1L
      real_copy(...)
    },
    .package = "base"
  )
  expect_identical(harbouR:::.hb_read_csv_file(path)$a, c(1L, 2L))
  expect_identical(copies, 0L)
  local_mocked_bindings(file.size = function(...) 0, .package = "base")
  expect_identical(harbouR:::.hb_read_csv_file(path)$a, c(1L, 2L))
  expect_identical(copies, 1L)
  # Messages about the copy name the file as it was given.
  writeBin(as.raw(c(0x41, 0xb0, 0x0a)), path)
  expect_error(harbouR:::.hb_read_csv_file(path), basename(path),
               fixed = TRUE, class = "harbour_error_bad_argument")
})

test_that("UTF-8 files still read and write in a multibyte session", {
  # A multibyte session that is not UTF-8 checks text against its own
  # encoding, so there the text is converted, as it always was. The file
  # has a header and a value in kanji, which each such encoding holds.
  path <- withr::local_tempfile(fileext = ".csv")
  writeBin(charToRaw(paste0(
    "\xe5\x90\x8d\xe5\x89\x8d,n\n",
    "\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e,30\n"
  )), path)
  check_in <- function(locale) {
    withr::with_locale(c(LC_CTYPE = locale), {
      if (!isTRUE(l10n_info()[["MBCS"]]) || isTRUE(l10n_info()[["UTF-8"]])) {
        return(FALSE)
      }
      base <- hb_read_csv(c(T = path))
      data <- hb_read_table(base, "T")
      expect_identical(names(data)[[1L]], "\u540d\u524d", label = locale)
      expect_identical(data[[1L]], "\u65e5\u672c\u8a9e", label = locale)
      expect_no_error(hb_write_csv(base, withr::local_tempdir()))
      TRUE
    })
  }
  # A locale the system lacks only warns, and is then passed over.
  tried <- vapply(
    c("ja_JP.SJIS", "zh_TW.Big5", "zh_CN.GBK"),
    function(locale) suppressWarnings(check_in(locale)),
    logical(1)
  )
  skip_if_not(any(tried), "no multibyte locale that is not UTF-8")
})

test_that("a CSV of blank lines that read.csv() gives up on is refused", {
  for (text in c("   \n", "\t\n")) {
    path <- withr::local_tempfile(fileext = ".csv")
    writeBin(charToRaw(text), path)
    expect_error(hb_read_csv(path), basename(path), fixed = TRUE,
                 class = "harbour_error_bad_argument")
  }
  # Two such lines are a header and a row to read.csv(), and still read.
  path <- withr::local_tempfile(fileext = ".csv")
  writeBin(charToRaw("  \n  \n"), path)
  expect_no_error(hb_read_csv(path))
})

test_that("a byte-order mark alone is empty in any locale", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("\r\n")), path)
  # Outside a UTF-8 locale readLines() keeps the mark, so the check has to
  # look past it itself.
  withr::local_locale(c(LC_CTYPE = "C"))
  skip_if(isTRUE(l10n_info()[["UTF-8"]]), "The C locale is UTF-8 here.")
  expect_error(hb_read_csv(path), class = "harbour_error_bad_argument")
})

test_that("an empty CSV column imports as text, not as a checkbox", {
  dir <- withr::local_tempdir()
  header <- file.path(dir, "header.csv")
  writeLines("Name,Notes", header)
  blank <- file.path(dir, "blank.csv")
  writeLines(c("Name,Notes,Done", "a,,TRUE", "b,,FALSE"), blank)
  base <- hb_read_csv(c(Header = header, Blank = blank))
  expect_identical(column_types(base, "Header"), c("text", "text"))
  expect_identical(column_types(base, "Blank"),
                   c("text", "text", "checkbox"))
  data <- hb_read_table(base, "Blank")
  # As a checkbox the empty column read back FALSE in every row.
  expect_identical(data$Notes, c(NA_character_, NA_character_))
  expect_identical(data$Done, c(TRUE, FALSE))
})

test_that("hb_dtable() itself still makes an all-NA logical a checkbox", {
  base <- hb_dtable(T = data.frame(x = c(NA, NA)))
  expect_identical(column_types(base, "T"), "checkbox")
})

test_that("a CSV export reads back into a base whose tables can be read", {
  base <- hb_read_dtable(example_dtable())
  dir <- withr::local_tempdir()
  # The exported _id holds row ids, so it is dropped without a word.
  again <- expect_no_warning(
    hb_read_csv(suppressMessages(hb_write_csv(base, dir)))
  )
  expect_identical(names(again), names(base))
  for (table in names(base)) {
    original <- hb_read_table(base, table)
    back <- hb_read_table(again, table)
    # The exported _id is not kept as an ordinary column: the new base has
    # rows of its own.
    expect_false("_id" %in% hb_list_columns(again, table)$name)
    expect_identical(names(back), names(original))
    expect_false(any(back[["_id"]] %in% original[["_id"]]))
  }
  columns <- hb_list_columns(again, "Samples")
  # A button column has no values to export, and comes back as text.
  expect_identical(columns$type[columns$name == "Action"], "text")
  expect_identical(hb_read_table(again, "Samples")$Ref, c("0001", NA))
})

test_that("only the _id column is dropped on import", {
  # A column a user named like another of SeaTable's row fields collides
  # with nothing offline, and has always been imported as a column.
  dir <- withr::local_tempdir()
  path <- file.path(dir, "T.csv")
  writeLines(c("Name,_ctime,_id", "a,x,r1", "b,y,r2"), path)
  expect_warning(base <- hb_read_csv(path),
                 class = "harbour_warning_id_column")
  expect_identical(hb_list_columns(base, "T")$name, c("Name", "_ctime"))
  expect_identical(hb_read_table(base, "T")[["_ctime"]], c("x", "y"))
})

test_that("an _id column of the user's own is dropped with a warning", {
  # A database export keeps its own keys under _id, which SeaTable keeps
  # for the row identifier; the loss is reported, naming the table.
  dir <- withr::local_tempdir()
  path <- file.path(dir, "customers.csv")
  writeLines(c("_id,name", "507f1f77bcf86cd799439011,alice",
               "507f191e810c19729de860ea,bob"), path)
  expect_warning(base <- hb_read_csv(path), "customers",
                 class = "harbour_warning_id_column")
  expect_identical(hb_list_columns(base, "customers")$name, "name")
  # Row ids, as an export holds them, go without a word.
  writeLines(c("_id,name", "S6zTWoOyQBeUyxsMzhAmWA,alice", ",bob"), path)
  expect_no_warning(hb_read_csv(path))
})

test_that("repeated column names in a CSV header are kept as they are", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("a,a,b,_id,c,c", "1,2,x,old,,"), path)
  expect_warning(base <- hb_read_csv(c(T = path)),
                 class = "harbour_warning_id_column")
  columns <- hb_list_columns(base, "T")
  expect_identical(columns$name, c("a", "a", "b", "c", "c"))
  expect_identical(columns$type,
                   c("number", "number", "text", "text", "text"))
})

test_that("files named after hb_dtable()'s arguments are still tables", {
  dir <- withr::local_tempdir()
  tables <- c("Samples", "collaborators", "base_name")
  files <- file.path(dir, paste0(tables, ".csv"))
  for (file in files) {
    utils::write.csv(data.frame(x = 1:2), file, row.names = FALSE)
  }
  base <- hb_read_csv(files, base_name = "Imported")
  expect_identical(names(base), tables)
  expect_identical(base$base_name, "Imported")
  expect_identical(base$content$collaborators, list())
  for (table in tables) {
    expect_identical(hb_read_table(base, table)$x, c(1, 2))
  }
})

test_that("a missing name in `files` gives the table hb_dtable() makes", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("x", "1"), path)
  base <- hb_read_csv(stats::setNames(path, NA_character_))
  # hb_dtable() calls such a table "NA"; putting the real names back must
  # not turn that into a missing name.
  expect_identical(names(base), "NA")
  expect_identical(hb_read_table(base, "NA")$x, 1)
})

test_that("restoring the table names leaves every id and option as built", {
  testthat::local_mocked_bindings(
    .hb_dtable_timestamp = function(time = Sys.time()) {
      "2026-01-01T00:00:00.000+00:00"
    },
    .package = "harbouR"
  )
  frames <- list(
    collaborators = data.frame(
      Name = c("a", "b"), Group = factor(c("x", "y"))
    ),
    base_name = data.frame(Value = c(1.5, 2.5))
  )
  imported <- withr::with_seed(
    1L, harbouR:::.hb_import_base(frames, "B")
  )
  direct <- withr::with_seed(
    1L, hb_dtable(One = frames[[1L]], Two = frames[[2L]], base_name = "B")
  )
  expect_identical(names(imported), names(frames))
  direct$content$tables[[1L]]$name <- "collaborators"
  direct$content$tables[[2L]]$name <- "base_name"
  expect_identical(imported, direct)
})

# Reading workbooks ---------------------------------------------------------

test_that("hb_read_xlsx judges a column by every row, not the first 1000", {
  skip_if_not_installed("writexl")
  skip_if_not_installed("readxl")
  path <- withr::local_tempfile(fileext = ".xlsx")
  n <- 1200L
  writexl::write_xlsx(
    list(Samples = data.frame(
      id = sprintf("S-%04d", seq_len(n)),
      note = c(rep(NA_character_, 1100L), rep("late note", n - 1100L))
    )),
    path
  )
  expect_no_warning(base <- hb_read_xlsx(path))
  expect_identical(column_types(base, "Samples"), c("text", "text"))
  data <- hb_read_table(base, "Samples")
  expect_identical(data$note, c(rep(NA, 1100L), rep("late note", 100L)))
})

test_that("an empty column in a workbook imports as text", {
  skip_if_not_installed("writexl")
  skip_if_not_installed("readxl")
  path <- withr::local_tempfile(fileext = ".xlsx")
  writexl::write_xlsx(
    list(
      Template = data.frame(Name = character(), Value = numeric()),
      Data = data.frame(Name = c("a", "b"), Notes = NA_character_)
    ),
    path
  )
  base <- hb_read_xlsx(path)
  expect_identical(column_types(base, "Template"), c("text", "text"))
  expect_identical(column_types(base, "Data"), c("text", "text"))
  expect_identical(hb_read_table(base, "Data")$Notes,
                   c(NA_character_, NA_character_))
})

test_that("an xlsx export reads back into a base whose tables can be read", {
  skip_if_not_installed("writexl")
  skip_if_not_installed("readxl")
  base <- hb_read_dtable(example_dtable())
  path <- withr::local_tempfile(fileext = ".xlsx")
  suppressMessages(hb_write_xlsx(base, path))
  again <- hb_read_xlsx(path)
  for (table in names(base)) {
    original <- hb_read_table(base, table)
    back <- hb_read_table(again, table)
    expect_false("_id" %in% hb_list_columns(again, table)$name)
    expect_identical(names(back), names(original))
    expect_false(any(back[["_id"]] %in% original[["_id"]]))
  }
})

test_that("sheets named after hb_dtable()'s arguments are still tables", {
  skip_if_not_installed("writexl")
  skip_if_not_installed("readxl")
  path <- withr::local_tempfile(fileext = ".xlsx")
  writexl::write_xlsx(
    list(collaborators = data.frame(x = 1), base_name = data.frame(y = "a")),
    path
  )
  base <- hb_read_xlsx(path)
  expect_identical(names(base), c("collaborators", "base_name"))
  expect_identical(base$base_name, "harbouR base")
  expect_identical(base$content$collaborators, list())
  expect_identical(hb_read_table(base, "base_name")$y, "a")
})

# Writing -------------------------------------------------------------------

test_that("the export writes what the documented losses describe", {
  dir <- withr::local_tempdir()
  suppressMessages(hb_write_csv(hb_read_dtable(example_dtable()), dir))
  samples <- utils::read.csv(file.path(dir, "Samples.csv"),
                             colClasses = "character", check.names = FALSE)
  # A location keeps the order the file stores, longitude first, and loses
  # the field names that said so.
  expect_identical(samples$Where[[1L]], "11.5761, 48.1371")
  expect_identical(samples$Signature[[1L]], "<object>")
  expect_identical(samples$Action, c(NA_character_, NA_character_))
})

test_that("hb_write_xlsx refuses table names that differ only in case", {
  skip_if_not_installed("writexl")
  base <- hb_dtable(Samples = data.frame(x = 1), samples = data.frame(x = 2))
  path <- withr::local_tempfile(fileext = ".xlsx")
  err <- expect_error(hb_write_xlsx(base, path),
                      class = "harbour_error_bad_argument")
  expect_match(conditionMessage(err), "samples", fixed = TRUE)
  expect_false(file.exists(path))

  # Each clash is named, its names side by side.
  base <- hb_dtable(
    Samples = data.frame(x = 1), Notes = data.frame(x = 2),
    samples = data.frame(x = 3), NOTES = data.frame(x = 4)
  )
  err <- expect_error(hb_write_xlsx(base, path),
                      class = "harbour_error_bad_argument")
  expect_match(conditionMessage(err), "Samples.*samples.*Notes.*NOTES")
  expect_false(file.exists(path))
})

test_that("names that clash once Excel's rules apply are refused", {
  skip_if_not_installed("writexl")
  # writexl replaces "/" and "?" and keeps case, and libxlsxwriter then
  # refuses "a-b" beside "A-b" with an error that names neither table.
  path <- withr::local_tempfile(fileext = ".xlsx")
  base <- hb_dtable(`a/b` = data.frame(x = 1), `A?b` = data.frame(x = 2))
  expect_error(
    suppressWarnings(suppressMessages(hb_write_xlsx(base, path))),
    class = "harbour_error_bad_argument"
  )
  expect_false(file.exists(path))
})

test_that("only A to Z are folded when comparing sheet names", {
  # The names hold letters a session that is not UTF-8 cannot represent.
  skip_if_not(isTRUE(l10n_info()[["UTF-8"]]), "the session is not UTF-8")
  skip_if_not_installed("writexl", "2.0.0")
  skip_if_not_installed("readxl")
  frames <- stats::setNames(
    list(data.frame(x = 1), data.frame(x = 2)),
    c("\u00c4pfel", "\u00e4pfel")
  )
  base <- do.call(hb_dtable, frames)
  path <- withr::local_tempfile(fileext = ".xlsx")
  hb_write_xlsx(base, path)
  expect_identical(readxl::excel_sheets(path), names(frames))
})

test_that("the flattening message names every column, however many", {
  # cli used to cut the list after 20 names.
  columns <- sprintf("col%02d", 1:25)
  wide <- tibble::as_tibble(
    stats::setNames(rep(list(list("a", "b")), length(columns)), columns)
  )
  base <- hb_dtable(Wide = wide)
  messages <- testthat::capture_messages(
    hb_write_csv(base, withr::local_tempdir())
  )
  text <- paste(messages, collapse = "\n")
  for (column in columns) {
    expect_match(text, paste0("Wide$", column), fixed = TRUE)
  }
})

# --- findings of the 2026-10-29 audit ----------------------------------------

test_that("table names keep their letters in CSV file names", {
  # Every letter outside A to Z became "_", so two Chinese table names
  # both became _.csv and the export was refused.
  base <- hb_dtable(
    `样本` = data.frame(x = 1),
    `数据` = data.frame(x = 2),
    `Probenübersicht` = data.frame(x = 3)
  )
  dir <- withr::local_tempdir()
  hb_write_csv(base, dir)
  expect_setequal(
    list.files(dir),
    c("样本.csv", "数据.csv", "Probenübersicht.csv")
  )
  back <- hb_read_csv(file.path(dir, "Probenübersicht.csv"))
  expect_identical(hb_list_tables(back)$name, "Probenübersicht")
  # Characters a file name cannot hold are still replaced.
  expect_identical(harbouR:::.hb_safe_filename("a/b:c*d?"), "a_b_c_d_")
})

test_that("a cell with a missing or repeated field flattens", {
  # A geolocation with no latitude, or a link to a formula whose display
  # value is an array, stopped every export with "values must be length 1".
  flat <- harbouR:::.hb_flatten_column(list(
    list(lng = 11.57, lat = NULL),
    list(list(display_value = list("a", "b"))),
    list(list(name = "report.pdf"))
  ))
  expect_identical(flat, c("11.57", "a, b", "report.pdf"))
})

test_that("sheet names are made legal for Excel by harbouR itself", {
  # writexl before 2.0.0 refused such a name with an error naming no table.
  expect_identical(
    harbouR:::.hb_sheet_names(c("a/b:c?", "[x]*\\", strrep("y", 40))),
    c("a_b_c_", "_x___", strrep("y", 31))
  )
})

test_that("text longer than a workbook cell holds is refused, naming it", {
  skip_if_not_installed("writexl")
  base <- hb_dtable(T = data.frame(long = strrep("x", 32768)))
  err <- expect_error(
    hb_write_xlsx(base, withr::local_tempfile(fileext = ".xlsx")),
    class = "harbour_error_bad_argument"
  )
  expect_match(conditionMessage(err), "long", fixed = TRUE)
})

test_that("hb_read_xlsx() keeps the spaces around text", {
  skip_if_not_installed("writexl")
  skip_if_not_installed("readxl")
  path <- withr::local_tempfile(fileext = ".xlsx")
  hb_write_xlsx(hb_dtable(T = data.frame(x = c("  padded  ", "a"))), path)
  expect_identical(
    hb_read_table(hb_read_xlsx(path), "T")$x, c("  padded  ", "a")
  )
})

test_that("a leading plus keeps a CSV column text", {
  # read.csv() read +4917612345678 as the number 4917612345678.
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("phone,plain,signed", "+4917612345678,1.5,+1.5",
               "+4915112345678,2,-0.25"), path)
  base <- hb_read_csv(path)
  out <- hb_read_table(base, hb_list_tables(base)$name)
  expect_identical(out$phone, c("+4917612345678", "+4915112345678"))
  expect_identical(out$plain, c(1.5, 2))
  # A signed number is still a number.
  expect_identical(out$signed, c(1.5, -0.25))
})

test_that("hb_read_xlsx() trims the column names, as readxl always did", {
  skip_if_not_installed("writexl")
  skip_if_not_installed("readxl")
  path <- withr::local_tempfile(fileext = ".xlsx")
  writexl::write_xlsx(list(T = data.frame(` Sample ID ` = "a", check.names = FALSE)), path)
  expect_identical(hb_list_columns(hb_read_xlsx(path), "T")$name, "Sample ID")
})
