test_that("hb_list_views returns a typed tibble", {
  cl <- local_mock_client()
  res <- hb_list_views(cl, "Samples")
  expect_named(res, c("name", "type", "is_default"))
  expect_identical(res$name, "Default")
  expect_true(res$is_default)
})

test_that("hb_list_views validates and errors on unknown table", {
  cl <- local_mock_client()
  expect_error(hb_list_views(1L, "Samples"), class = "rlang_error")
  expect_error(hb_list_views(cl, "Nope"), "not found")
})

test_that("hb_list_views returns 0-row tibble when a table has no views", {
  cl <- local_mock_client()
  cl$.metadata <- new_harbour_metadata(
    list(tables = list(list(name = "T", columns = list(), views = list()))),
    base_name = "b"
  )
  res <- hb_list_views(cl, "T")
  expect_identical(nrow(res), 0L)
  expect_named(res, c("name", "type", "is_default"))
})

test_that("hb_get_view returns a 1-row tibble with list-columns", {
  cl <- local_mock_client()
  with_mocked_request(
    res <- hb_get_view(cl, "Samples", "Default"),
    response = list(name = "Default", type = "table",
                    filters = list(list(x = 1)), sorts = list())
  )
  expect_identical(nrow(res), 1L)
  expect_true(is.list(res$filters))
  expect_identical(res$name, "Default")
})

test_that("hb_get_view falls back to the requested name when none returned", {
  cl <- local_mock_client()
  with_mocked_request(
    res <- hb_get_view(cl, "Samples", "Active"),
    response = list()
  )
  expect_identical(res$name, "Active")
})

test_that("hb_create_view merges settings and clears cache", {
  cl <- local_mock_client()
  expect_error(hb_create_view(cl, "Samples", ""), class = "rlang_error")
  rec <- with_mocked_request(
    hb_create_view(cl, "Samples", "Active", settings = list(foo = "bar")),
    response = list()
  )
  expect_identical(rec$calls[[1]]$method, "POST")
  expect_identical(rec$calls[[1]]$body$foo, "bar")
  expect_null(cl$.metadata)
})

test_that("hb_update_view validates the settings list", {
  cl <- local_mock_client()
  expect_error(hb_update_view(cl, "Samples", "Active", settings = "x"),
               "must be a list")
  rec <- with_mocked_request(
    hb_update_view(cl, "Samples", "Active", settings = list(a = 1)),
    response = list()
  )
  expect_identical(rec$calls[[1]]$method, "PUT")
  expect_identical(rec$calls[[1]]$body$view_name, "Active")
})

test_that("hb_delete_view issues a DELETE", {
  cl <- local_mock_client()
  rec <- with_mocked_request(
    hb_delete_view(cl, "Samples", "Old"), response = list())
  expect_identical(rec$calls[[1]]$method, "DELETE")
  expect_identical(rec$calls[[1]]$body$view_name, "Old")
})
