# Every user-facing failure mode gets its message snapshotted here, so that a
# reworded or accidentally-broken error shows up as a reviewable diff. The
# per-endpoint test files assert behaviour; this file asserts what the user
# is told when things go wrong.

test_that("hb_client() rejects bad credentials and servers", {
  expect_snapshot(error = TRUE, hb_client(server = ""))
  expect_snapshot(error = TRUE, hb_client(server = "ftp://nope.example.org",
                                          api_token = "t"))
  expect_snapshot(error = TRUE, hb_client(server = "https://x.example.org"))
  expect_snapshot(error = TRUE, hb_client(
    server = "https://x.example.org",
    api_token = "t",
    username = "u",
    password = "p"
  ))
})

test_that("scalar validators name the argument and the bad value", {
  cl <- mock_client()
  expect_snapshot(error = TRUE, hb_read_table(cl, ""))
  expect_snapshot(error = TRUE, hb_read_table(1L, "Samples"))
  expect_snapshot(error = TRUE, hb_list_tables(cl, refresh = "yes"))
})

test_that("an unknown table lists the tables that do exist", {
  cl <- mock_client()
  expect_snapshot(error = TRUE, hb_read_table(cl, "Nope"))
})

test_that("HTTP status codes translate to actionable messages", {
  for (status in c(401L, 403L, 404L, 429L, 500L)) {
    cond <- make_http_cond(
      status,
      '{"error_msg": "upstream said no"}'
    )
    expect_snapshot(error = TRUE, .hb_translate_error(cond))
  }
})

test_that("hb_update_rows() insists on an id column", {
  cl <- mock_client()
  expect_snapshot(error = TRUE, hb_update_rows(
    cl, "Samples", tibble::tibble(Name = "x")
  ))
})

test_that("hb_download_file() refuses to clobber without overwrite", {
  cl <- mock_client()
  dir <- withr::local_tempdir()
  path <- file.path(dir, "report.pdf")
  writeLines("existing", path)
  # The temp directory is random, so redact it: only the message matters.
  expect_snapshot(
    error = TRUE,
    hb_download_file(cl, "https://demo.example.org/asset/x.pdf", path),
    transform = function(x) gsub(dir, "<tmp>", x, fixed = TRUE)
  )
})

test_that("scaffolded endpoints say so plainly", {
  expect_snapshot(error = TRUE, hb_list_links())
})
