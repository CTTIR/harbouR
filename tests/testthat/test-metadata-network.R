test_that("hb_metadata builds and caches a harbour_metadata", {
  cl <- local_mock_client()
  cl$.metadata <- NULL
  meta_body <- list(metadata = list(
    tables = list(list(name = "T", columns = list(), views = list())),
    version = "7"
  ))
  with_mocked_request(
    m <- hb_metadata(cl),
    response = meta_body
  )
  expect_s3_class(m, "harbour_metadata")
  expect_identical(m$version, "7")
  expect_identical(cl$.metadata, m)
})

test_that("hb_metadata validates the client", {
  expect_error(hb_metadata(1L), class = "rlang_error")
})

test_that("hb_list_tables refreshes only when asked", {
  cl <- local_mock_client()
  rec <- with_mocked_request(
    res <- hb_list_tables(cl),
    response = list(metadata = list(tables = list()))
  )
  # cached metadata present -> no request needed
  expect_identical(length(rec$calls), 0L)
  expect_identical(res$name, c("Samples", "Patients"))

  rec2 <- with_mocked_request(
    hb_list_tables(cl, refresh = TRUE),
    response = list(metadata = list(tables = list()))
  )
  expect_identical(length(rec2$calls), 1L)
})

test_that("hb_list_tables validates the refresh flag", {
  cl <- local_mock_client()
  expect_error(hb_list_tables(cl, refresh = "yes"), class = "rlang_error")
})

test_that("hb_list_collaborators parses users and handles empties", {
  cl <- local_mock_client()
  with_mocked_request(
    res <- hb_list_collaborators(cl),
    response = list(user_list = list(
      list(email = "a@b", name = "A"),
      list(email = "c@d", name = "C", contact_email = "c2@d")
    ))
  )
  expect_named(res, c("email", "name", "contact_email"))
  expect_identical(res$email, c("a@b", "c@d"))
  expect_identical(res$contact_email[[2]], "c2@d")

  with_mocked_request(
    none <- hb_list_collaborators(cl),
    response = list(user_list = list())
  )
  expect_identical(nrow(none), 0L)
})

test_that("hb_server_info returns a one-row tibble", {
  cl <- local_mock_client()
  with_mocked_request(
    res <- hb_server_info(cl),
    response = list(version = "5.0", edition = "enterprise")
  )
  expect_identical(nrow(res), 1L)
  expect_identical(res$version, "5.0")
  expect_identical(res$edition, "enterprise")
})

test_that("hb_ping returns TRUE on success and errors on failure", {
  cl <- local_mock_client()
  with_mocked_request(
    ok <- hb_ping(cl),
    response = list()
  )
  expect_true(ok)

  fail <- function(...) stop("boom")
  testthat::local_mocked_bindings(.hb_request = fail, .package = "harbouR")
  expect_error(hb_ping(cl), "Could not reach")
})
