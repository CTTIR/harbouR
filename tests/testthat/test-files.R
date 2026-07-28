test_that(".hb_guess_mime maps known extensions and defaults otherwise", {
  expect_identical(harbouR:::.hb_guess_mime("a.pdf"), "application/pdf")
  expect_identical(harbouR:::.hb_guess_mime("a.PNG"), "image/png")
  expect_identical(harbouR:::.hb_guess_mime("a.jpg"), "image/jpeg")
  expect_identical(harbouR:::.hb_guess_mime("a.jpeg"), "image/jpeg")
  expect_identical(harbouR:::.hb_guess_mime("a.csv"), "text/csv")
  expect_identical(harbouR:::.hb_guess_mime("a.json"), "application/json")
  expect_identical(harbouR:::.hb_guess_mime("a.zzz"), "application/octet-stream")
})

test_that("hb_upload_file errors when the file is missing", {
  cl <- mock_client()
  expect_error(hb_upload_file(cl, "no-such-file.pdf"), "File not found")
  expect_error(hb_upload_file(1L, "x"), regexp = "`client` must be a <harbour_client>\\.")
})

test_that("hb_download_file validates inputs and refuses to clobber", {
  cl <- mock_client()
  expect_error(hb_download_file(cl, 1L, "d"), regexp = "`url` must be a single non-empty string\\.")
  expect_error(hb_download_file(cl, "u", "d", overwrite = "yes"),
               regexp = "`overwrite` must be a single `TRUE` or `FALSE`\\.")
  existing <- withr::local_tempfile(fileext = ".bin")
  writeLines("hi", existing)
  expect_error(
    hb_download_file(cl, "https://x/file", existing),
    "already exists"
  )
})

test_that("hb_download_file writes the body and returns dest", {
  cl <- mock_client()
  dest <- withr::local_tempfile(fileext = ".bin")
  fake_resp <- structure(list(status_code = 200L), class = "httr2_response")
  testthat::local_mocked_bindings(
    req_perform = function(req, path = NULL, ...) {
      if (!is.null(path)) writeLines("payload", path)
      fake_resp
    },
    resp_status = function(resp) 200L,
    .package = "httr2"
  )
  res <- hb_download_file(cl, "https://x/file", dest)
  expect_identical(res, dest)
  expect_true(file.exists(dest))
})

test_that("hb_download_file errors on an HTTP failure status", {
  cl <- mock_client()
  dest <- withr::local_tempfile(fileext = ".bin")
  testthat::local_mocked_bindings(
    req_perform = function(req, path = NULL, ...)
      structure(list(status_code = 404L), class = "httr2_response"),
    resp_status = function(resp) 404L,
    .package = "httr2"
  )
  expect_error(hb_download_file(cl, "https://x/file", dest), "Download failed")
})

test_that("hb_delete_asset routes a DELETE through the request engine", {
  cl <- mock_client()
  expect_error(hb_delete_asset(cl, 1L), regexp = "`url` must be a single non-empty string\\.")
  rec <- with_mocked_request(
    res <- hb_delete_asset(cl, "https://server/path/file.pdf"),
    response = list()
  )
  expect_identical(res, cl)
  expect_identical(rec$calls[[1]]$method, "DELETE")
  expect_identical(rec$calls[[1]]$path, "/api/v2.1/dtable/app-asset/")
  expect_identical(rec$calls[[1]]$auth, "base")
  # The endpoint takes the path below the base's asset root as a query
  # parameter, not the whole URL in the body.
  expect_identical(rec$calls[[1]]$query$path, "/path/file.pdf")
})

test_that("hb_upload_file requests a link then uploads and returns a file object", {
  cl <- mock_client()
  src <- withr::local_tempfile(fileext = ".pdf")
  writeLines("content", src)
  testthat::local_mocked_bindings(
    .hb_request = function(client, path, ...) list(
      upload_link = "https://up.example.org/upload",
      parent_path = "/asset/demo-uuid",
      file_relative_path = "files/2026-07"
    ),
    .package = "harbouR"
  )
  captured <- NULL
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      captured <<- req
      structure(list(), class = "httr2_response")
    },
    resp_body_json = function(resp, ...) list(list(
      name = "doc.pdf", size = 99, type = "application/pdf"
    )),
    .package = "httr2"
  )
  cl$.workspace_id <- 42L
  obj <- hb_upload_file(cl, src)
  expect_identical(obj$name, "doc.pdf")
  expect_identical(obj$type, "application/pdf")
  # The upload response carries no URL; harbouR builds it from the
  # workspace id, the base uuid and the path the file went to.
  expect_identical(
    obj$url,
    "https://demo.example.org/workspace/42/asset/demo-uuid/files/2026-07/doc.pdf"
  )
  # Without ret-json the endpoint answers in plain text, not JSON.
  expect_match(captured$url, "ret-json=1", fixed = TRUE)
})

test_that("hb_upload_file errors when no upload URL is returned", {
  cl <- mock_client()
  src <- withr::local_tempfile(fileext = ".pdf")
  writeLines("content", src)
  testthat::local_mocked_bindings(
    .hb_request = function(client, path, ...) list(parent_path = "/files"),
    .package = "harbouR"
  )
  expect_error(hb_upload_file(cl, src), "did not return an upload URL")
})

test_that("hb_attach_file uploads then updates the target cell", {
  cl <- mock_client()
  src <- withr::local_tempfile(fileext = ".pdf")
  writeLines("content", src)
  calls <- new.env(); calls$update <- NULL
  testthat::local_mocked_bindings(
    hb_upload_file = function(client, path, ...) list(
      name = "doc.pdf", size = 1, type = "application/pdf", url = "u"),
    hb_update_rows = function(client, table, data, ...) {
      calls$update <- list(table = table, data = data)
      invisible(client)
    },
    .package = "harbouR"
  )
  res <- hb_attach_file(cl, "Samples", "r1", "Reports", src)
  expect_identical(res, cl)
  expect_identical(calls$update$table, "Samples")
  expect_true("Reports" %in% names(calls$update$data))
})

test_that("hb_attach_file validates row/column args", {
  cl <- mock_client()
  expect_error(hb_attach_file(cl, "Samples", "", "Reports", "x.pdf"),
               regexp = "`row_id` must be a single non-empty string\\.")
})

test_that(".hb_asset_path strips the workspace and base prefix", {
  expect_identical(
    harbouR:::.hb_asset_path(
      "https://seatable.example.org/workspace/42/asset/uu-id/files/a.pdf"
    ),
    "/files/a.pdf"
  )
  expect_identical(
    harbouR:::.hb_asset_path("/workspace/7/asset/x/images/2026-07/p.png"),
    "/images/2026-07/p.png"
  )
  # An already-relative path is left alone.
  expect_identical(harbouR:::.hb_asset_path("/files/x.pdf"), "/files/x.pdf")
})

test_that("images upload to the image tree, other files to the file tree", {
  expect_true(harbouR:::.hb_is_image("a.PNG"))
  expect_true(harbouR:::.hb_is_image("b.jpeg"))
  expect_false(harbouR:::.hb_is_image("c.pdf"))
})

test_that(".hb_asset_url returns NA rather than a wrong URL when unbound", {
  cl <- mock_client()
  cl$.workspace_id <- NULL
  expect_identical(harbouR:::.hb_asset_url(cl, "files", "a.pdf"),
                   NA_character_)
})
