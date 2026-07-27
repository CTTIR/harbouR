# The app lives in R/, so R CMD check, covr and lintr all see it, and its
# server logic can be driven headlessly with shiny::testServer(). The old
# app was in inst/, where the only possible assertion was that its source
# parsed - which is how an unqualified %||% shipped in it.

skip_if_no_ui <- function() {
  needed <- c("shiny", "bslib", "reactable")
  present <- vapply(needed, requireNamespace, logical(1), quietly = TRUE)
  testthat::skip_if_not(all(present), "UI packages not installed")
}

test_that("hb_run_explorer rejects a source it cannot open", {
  skip_if_no_ui()
  expect_error(hb_run_explorer(42), class = "harbour_error_bad_argument")
})

test_that("hb_run_explorer names the packages it is missing", {
  skip_if_no_ui()
  testthat::local_mocked_bindings(
    requireNamespace = function(package, ...) !identical(package, "reactable"),
    .package = "base"
  )
  expect_error(hb_run_explorer(), class = "harbour_error_unsupported")
})

test_that("the UI builds and declares a page language", {
  skip_if_no_ui()
  ui <- harbouR:::.hb_app_ui()
  expect_s3_class(ui, "shiny.tag.list")
  html <- as.character(htmltools::renderTags(ui)$html)
  expect_match(html, 'lang="en"', fixed = TRUE)
  expect_match(html, "harbou", fixed = TRUE)
})

test_that("the API token input is never seeded from the environment", {
  skip_if_no_ui()
  withr::local_envvar(c(SEATABLE_API_TOKEN = "SUPERSECRETTOKEN"))
  html <- as.character(htmltools::renderTags(harbouR:::.hb_app_ui())$html)
  # passwordInput(value = ) writes the value straight into the page HTML.
  expect_false(grepl("SUPERSECRETTOKEN", html, fixed = TRUE))
})

test_that("the app opens a .dtable and lists its tables", {
  skip_if_no_ui()
  path <- system.file("extdata", "example.dtable", package = "harbouR")
  base <- hb_read_dtable(path)
  shiny::testServer(harbouR:::.hb_app_server(preset = base), {
    expect_identical(session$getReturned(), NULL)
    expect_identical(output$table_count, "2")
    expect_identical(session$env$state$table, "Samples")
    expect_identical(session$env$state$kind, "file")
  })
})

test_that("picking a table switches the data panel to it", {
  skip_if_no_ui()
  base <- hb_read_dtable(
    system.file("extdata", "example.dtable", package = "harbouR")
  )
  shiny::testServer(harbouR:::.hb_app_server(preset = base), {
    session$setInputs(pick_table = "Reference")
    expect_identical(session$env$state$table, "Reference")
  })
})

test_that("the example base loads with no credentials", {
  skip_if_no_ui()
  shiny::testServer(harbouR:::.hb_app_server(), {
    expect_null(session$env$state$source)
    session$setInputs(use_demo = 1)
    expect_true(is_harbour_dtable(session$env$state$source))
    expect_identical(session$env$state$kind, "demo")
    expect_identical(session$env$state$table, "Samples")
  })
})

test_that("a failed connection is reported, not thrown", {
  skip_if_no_ui()
  shiny::testServer(harbouR:::.hb_app_server(), {
    # No token: hb_client() aborts. The app must survive it.
    session$setInputs(server = "https://example.org", token = "",
                      connect = 1)
    expect_null(session$env$state$source)
  })
})

test_that("query results are refused without a server", {
  skip_if_no_ui()
  base <- hb_read_dtable(
    system.file("extdata", "example.dtable", package = "harbouR")
  )
  shiny::testServer(harbouR:::.hb_app_server(preset = base), {
    panel <- as.character(htmltools::renderTags(output$query_panel$html)$html)
    expect_match(panel, "not a database")
  })
})

test_that("every column type has a colour, and it is stable", {
  families <- harbouR:::.hb_type_families()
  expect_identical(nrow(families), nrow(hb_column_types()))
  expect_false(any(is.na(families$colour)))
  # An unknown type must still render rather than producing NA in the CSS.
  expect_identical(
    harbouR:::.hb_type_colour("brand-new-type"),
    unname(harbouR:::.hb_palette()[["mist"]])
  )
})

test_that("the schema band renders one segment per column", {
  band <- harbouR:::.hb_sounding(c("text", "number", "date"))
  expect_identical(lengths(regmatches(band, gregexpr("<i ", band))), 3L)
  expect_match(band, 'aria-hidden="true"', fixed = TRUE)
  expect_identical(harbouR:::.hb_sounding(character()), "")
})

test_that("display frames flatten list-columns so a cell can show them", {
  base <- hb_read_dtable(
    system.file("extdata", "example.dtable", package = "harbouR")
  )
  shown <- harbouR:::.hb_display_frame(hb_read_table(base, "Samples"))
  expect_false(any(vapply(shown, is.list, logical(1))))
  expect_identical(shown$Tags[[1L]], "urgent, blood")
})

test_that("cli markup is stripped before a message reaches the browser", {
  cnd <- rlang::catch_cnd(
    hb_abort("Something {.arg broke}.", class = "harbour_error_bad_argument")
  )
  plain <- harbouR:::.hb_plain_message(cnd)
  expect_false(grepl("\033", plain, fixed = TRUE))
  expect_match(plain, "broke")
})

test_that("download names are derived from the base and are filesystem-safe", {
  state <- list(source = hb_read_dtable(
    system.file("extdata", "example.dtable", package = "harbouR")
  ))
  state$source$base_name <- "Data - Wiebke/2026"
  expect_identical(
    harbouR:::.hb_download_name(state, "dtable"),
    "Data_-_Wiebke_2026.dtable"
  )
})

test_that("a live base can be turned into a dtable for download", {
  cl <- mock_client()
  # with_mocked_request() returns its recorder, so capture the value.
  converted <- NULL
  with_mocked_request(
    converted <- harbouR:::.hb_as_dtable(cl),
    response = list(rows = list())
  )
  expect_true(is_harbour_dtable(converted))
  expect_setequal(names(converted), c("Samples", "Patients"))
})

test_that(".hb_safe_types never stops a table from listing", {
  # The schema band is decoration; a schema it cannot read must not take
  # the table list down with it.
  expect_identical(harbouR:::.hb_safe_types(list(), "nope"), character())
})

test_that("a source with no base shows the empty state, not an error", {
  skip_if_no_ui()
  shiny::testServer(harbouR:::.hb_app_server(), {
    listing <- as.character(htmltools::renderTags(output$table_list)$html)
    expect_match(listing, "No base open")
    expect_identical(output$table_count, "")
    panel <- as.character(htmltools::renderTags(output$data_panel$html)$html)
    expect_match(panel, "Open a base")
    export <- as.character(htmltools::renderTags(output$export_panel$html)$html)
    expect_match(export, "Open a base to export")
  })
})

test_that("the source panel opens when there is nothing to browse", {
  skip_if_no_ui()
  open_html <- as.character(
    htmltools::renderTags(harbouR:::.hb_source_fields(open = TRUE))$html
  )
  shut_html <- as.character(
    htmltools::renderTags(harbouR:::.hb_source_fields(open = FALSE))$html
  )
  expect_match(open_html, "open", fixed = TRUE)
  expect_false(grepl("<details open", shut_html, fixed = TRUE))
})

test_that("a first table is chosen, or NULL when there is none", {
  base <- hb_read_dtable(
    system.file("extdata", "example.dtable", package = "harbouR")
  )
  expect_identical(harbouR:::.hb_first_table(base), "Samples")
  expect_null(harbouR:::.hb_first_table(NULL))
  base$content$tables <- list()
  expect_null(harbouR:::.hb_first_table(base))
})

test_that("the source kind is reported from the object", {
  base <- hb_read_dtable(
    system.file("extdata", "example.dtable", package = "harbouR")
  )
  expect_identical(harbouR:::.hb_source_kind(base), "file")
  expect_identical(harbouR:::.hb_source_kind(mock_client()), "server")
  expect_null(harbouR:::.hb_source_kind(NULL))
})

test_that("the theme is built from the logo's palette", {
  pal <- harbouR:::.hb_palette()
  expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", pal)))
  css <- as.character(harbouR:::.hb_styles())
  for (colour in pal) {
    expect_match(css, colour, fixed = TRUE)
  }
})
