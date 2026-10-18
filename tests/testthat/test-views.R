test_that("hb_list_views returns a typed tibble", {
  cl <- mock_client()
  res <- hb_list_views(cl, "Samples")
  expect_named(res, c("name", "type", "is_default"))
  expect_identical(res$name, "Default")
  expect_true(res$is_default)
})

test_that("hb_list_views validates and errors on unknown table", {
  cl <- mock_client()
  expect_error(hb_list_views(1L, "Samples"), class = "harbour_error_bad_argument")
  expect_error(hb_list_views(cl, "Nope"), "not found")
})

test_that("hb_list_views returns 0-row tibble when a table has no views", {
  cl <- mock_client()
  cl$.metadata <- new_harbour_metadata(
    list(tables = list(list(name = "T", columns = list(), views = list()))),
    base_name = "b"
  )
  res <- hb_list_views(cl, "T")
  expect_identical(nrow(res), 0L)
  expect_named(res, c("name", "type", "is_default"))
})

test_that("hb_get_view returns a 1-row tibble with list-columns", {
  cl <- mock_client()
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
  cl <- mock_client()
  with_mocked_request(
    res <- hb_get_view(cl, "Samples", "Active"),
    response = list()
  )
  expect_identical(res$name, "Active")
})

test_that("hb_create_view merges settings and clears cache", {
  cl <- mock_client()
  expect_error(hb_create_view(cl, "Samples", ""), regexp = "`view` must be a single non-empty string\\.")
  rec <- with_mocked_request(
    hb_create_view(cl, "Samples", "Active", settings = list(is_locked = TRUE)),
    response = list()
  )
  expect_identical(rec$calls[[1]]$method, "POST")
  expect_identical(rec$calls[[1]]$body$is_locked, TRUE)
  # A plain table view unless the settings say otherwise.
  expect_identical(rec$calls[[1]]$body$type, "table")
  expect_null(cl$.metadata)

  rec2 <- with_mocked_request(
    hb_create_view(cl, "Samples", "Old", settings = list(type = "archive")),
    response = list()
  )
  expect_identical(rec2$calls[[1]]$body$type, "archive")
})

test_that("view calls name the table in the query, not the body", {
  # The server reads table_name from the query string. Sent in the body
  # it is ignored, and every call fails with a 400.
  cl <- mock_client()
  rec <- with_mocked_request({
    hb_create_view(cl, "Samples", "Active")
    hb_update_view(cl, "Samples", "Active", settings = list(name = "Live"))
    hb_delete_view(cl, "Samples", "Live")
  }, response = list())
  for (call in rec$calls) {
    expect_identical(call$query$table_name, "Samples")
    expect_null(call$body$table_name)
  }
})

test_that("hb_update_view validates the settings list", {
  cl <- mock_client()
  expect_error(hb_update_view(cl, "Samples", "Active", settings = "x"),
               "must be a named list")
  expect_error(hb_update_view(cl, "Samples", "Active", settings = list(1)),
               class = "harbour_error_bad_argument")
  # An empty update would reach the server as [] rather than an object.
  expect_error(hb_update_view(cl, "Samples", "Active", settings = list()),
               class = "harbour_error_bad_argument")
  rec <- with_mocked_request(
    hb_update_view(cl, "Samples", "Active", settings = list(a = 1)),
    response = list()
  )
  expect_identical(rec$calls[[1]]$method, "PUT")
  expect_identical(rec$calls[[1]]$body, list(a = 1))
})

test_that("hb_delete_view issues a DELETE with no body", {
  cl <- mock_client()
  rec <- with_mocked_request(
    hb_delete_view(cl, "Samples", "Old"), response = list())
  expect_identical(rec$calls[[1]]$method, "DELETE")
  expect_match(rec$calls[[1]]$path, "/views/Old/$")
  expect_null(rec$calls[[1]]$body)
})

test_that("the default view is recognised by its id", {
  # SeaTable reports no is_default; its default view has id "0000".
  cl <- mock_client()
  cl$.metadata <- new_harbour_metadata(
    list(tables = list(list(name = "T", columns = list(), views = list(
      list(`_id` = "0000", name = "Default View", type = "table"),
      list(`_id` = "a1b2", name = "Other", type = "table")
    )))),
    base_name = "b"
  )
  expect_identical(hb_list_views(cl, "T")$is_default, c(TRUE, FALSE))
  with_mocked_request(
    res <- hb_get_view(cl, "T", "Default View"),
    response = list(`_id` = "0000", name = "Default View", type = "table")
  )
  expect_true(res$is_default)
})
