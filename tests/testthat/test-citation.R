# inst/CITATION builds its author list from DESCRIPTION. An installed
# package carries a rendered `Author` field; a reader handed the source
# DESCRIPTION - pkgdown, when it builds the site - has only `Authors@R`,
# and used to get a citation naming the maintainer alone.

citation_file <- function() {
  path <- system.file("CITATION", package = "harbouR")
  skip_if(!nzchar(path), "the CITATION file is not available")
  path
}

# DESCRIPTION as pkgdown sees it: Authors@R, but no rendered Author.
source_meta <- function() {
  path <- system.file("DESCRIPTION", package = "harbouR")
  meta <- as.list(read.dcf(path)[1L, ])
  meta[["Author"]] <- NULL
  meta
}

cited_names <- function(cite) {
  format(cite[[1L]]$author, include = c("given", "family"))
}

test_that("the citation names every author when only Authors@R is given", {
  meta <- source_meta()
  expect_false("Author" %in% names(meta))
  cite <- utils::readCitationFile(citation_file(), meta = meta)
  expect_identical(
    cited_names(cite),
    c(
      "Raban Heller", "Paul Elsinghorst", "Wiebke Derz", "Matthias Ring",
      "Gerhard Achatz", "Vinzent Forstmeier"
    )
  )
  bib <- paste(utils::toBibtex(cite), collapse = " ")
  expect_match(bib, "Raban Heller and Paul Elsinghorst", fixed = TRUE)
  expect_match(bib, "and Vinzent Forstmeier", fixed = TRUE)
})

test_that("a rendered Author field still takes precedence", {
  meta <- source_meta()
  meta[["Author"]] <- "Ann Author [aut, cre], Bob Builder [aut], Cy Ctb [ctb]"
  cite <- utils::readCitationFile(citation_file(), meta = meta)
  expect_identical(cited_names(cite), c("Ann Author", "Bob Builder"))
})

test_that("both DESCRIPTION fields give the same citation", {
  path <- system.file("DESCRIPTION", package = "harbouR")
  installed <- as.list(read.dcf(path)[1L, ])
  skip_if(
    is.null(installed[["Author"]]),
    "DESCRIPTION has no rendered Author field"
  )
  from_rendered <- utils::readCitationFile(citation_file(), meta = installed)
  from_code <- utils::readCitationFile(citation_file(), meta = source_meta())
  expect_identical(
    format(from_code, style = "text"),
    format(from_rendered, style = "text")
  )
  expect_identical(utils::toBibtex(from_code), utils::toBibtex(from_rendered))
})

test_that("evaluating Authors@R runs nothing beyond person() and c()", {
  marker <- withr::local_tempfile()
  touch <- sprintf("file.create(%s)", deparse(marker))
  shell <- deparse(paste("touch", shQuote(marker)))
  eve <- 'person("Eve", "Mallory", role = "aut")'
  hostile <- c(
    sprintf("c(%s, %s)", eve, touch),
    sprintf("c(%s, base::%s)", eve, touch),
    sprintf("c(%s, system(%s))", eve, shell),
    sprintf('person("Eve", "Mallory", role = "aut", comment = %s)', touch),
    sprintf("{%s; %s}", touch, eve),
    sprintf("%s; %s", touch, eve),
    '"not a person"'
  )
  for (code in hostile) {
    unlink(marker)
    meta <- source_meta()
    meta[["Authors@R"]] <- code
    # try(), so that the file is checked even when reading fails some
    # other way. None of the code may reach the file system, and anything
    # the restricted evaluation cannot run falls back to the maintainer.
    cite <- try(
      utils::readCitationFile(citation_file(), meta = meta),
      silent = TRUE
    )
    expect_false(file.exists(marker))
    expect_s3_class(cite, "citation")
    if (inherits(cite, "citation")) {
      expect_identical(cited_names(cite), "Raban Heller")
    }
  }
})

test_that("with no author fields at all the maintainer is cited", {
  meta <- source_meta()
  meta[["Authors@R"]] <- NULL
  cite <- utils::readCitationFile(citation_file(), meta = meta)
  expect_identical(cited_names(cite), "Raban Heller")
})
