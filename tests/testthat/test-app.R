test_that("hb_run_explorer errors cleanly when UI deps are missing", {
  needed <- c("shiny", "bslib", "DT", "reactable", "ggplot2")
  skip_if(all(vapply(needed, requireNamespace, logical(1), quietly = TRUE)))
  expect_error(hb_run_explorer(), "needs additional packages")
})

test_that("app.R and module files source without error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("DT")
  skip_if_not_installed("reactable")
  skip_if_not_installed("ggplot2")
  app_dir <- system.file("shiny", "harbour_explorer", package = "harbouR")
  expect_true(nzchar(app_dir))
  # Parse-only check; running the app needs an event loop.
  for (f in c("app.R",
              "modules/mod_connect.R",
              "modules/mod_base_overview.R",
              "modules/mod_table_browser.R",
              "modules/mod_query.R",
              "modules/mod_cell_detail.R")) {
    expect_silent(parse(file = file.path(app_dir, f)))
  }
})
