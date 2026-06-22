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
  cl <- local_mock_client()
  expect_error(hb_upload_file(cl, "no-such-file.pdf"), "File not found")
  expect_error(hb_upload_file(1L, "x"), class = "rlang_error")
})

test_that("hb_download_file validates inputs and refuses to clobber", {
  cl <- local_mock_client()
  expect_error(hb_download_file(cl, 1L, "d"), class = "rlang_error")
  expect_error(hb_download_file(cl, "u", "d", overwrite = "yes"),
               class = "rlang_error")
  existing <- withr::local_tempfile(fileext = ".bin")
  writeLines("hi", existing)
  expect_error(
    hb_download_file(cl, "https://x/file", existing),
    "already exists"
  )
})

test_that("hb_download_file writes the body and returns dest", {
  cl <- local_mock_client()
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
  cl <- local_mock_client()
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
  cl <- local_mock_client()
  expect_error(hb_delete_asset(cl, 1L), class = "rlang_error")
  rec <- with_mocked_request(
    res <- hb_delete_asset(cl, "https://server/path/file.pdf"),
    response = list()
  )
  expect_identical(res, cl)
  expect_identical(rec$calls[[1]]$method, "DELETE")
  expect_identical(rec$calls[[1]]$body$url, "https://server/path/file.pdf")
})

test_that("hb_upload_file requests a link then uploads and returns a file object", {
  cl <- local_mock_client()
  src <- withr::local_tempfile(fileext = ".pdf")
  writeLines("content", src)
  testthat::local_mocked_bindings(
    .hb_request = function(client, path, ...) list(
      upload_link = "https://up.example.org/upload",
      parent_path = "/files"
    ),
    .package = "harbouR"
  )
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp, ...) list(list(
      name = "doc.pdf", size = 99, type = "application/pdf",
      url = "https://up.example.org/files/doc.pdf"
    )),
    .package = "httr2"
  )
  obj <- hb_upload_file(cl, src)
  expect_identical(obj$name, "doc.pdf")
  expect_identical(obj$type, "application/pdf")
  expect_match(obj$url, "doc.pdf")
})

test_that("hb_upload_file errors when no upload URL is returned", {
  cl <- local_mock_client()
  src <- withr::local_tempfile(fileext = ".pdf")
  writeLines("content", src)
  testthat::local_mocked_bindings(
    .hb_request = function(client, path, ...) list(parent_path = "/files"),
    .package = "harbouR"
  )
  expect_error(hb_upload_file(cl, src), "did not return an upload URL")
})

test_that("hb_attach_file uploads then updates the target cell", {
  cl <- local_mock_client()
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
  cl <- local_mock_client()
  expect_error(hb_attach_file(cl, "Samples", "", "Reports", "x.pdf"),
               class = "rlang_error")
})
