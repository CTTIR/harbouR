test_that("hb_list_columns returns typed tibble and marks editability", {
  cl <- mock_client()
  res <- hb_list_columns(cl, "Samples")
  expect_named(res, c("name", "type", "key", "editable", "data"))
  expect_true("Name" %in% res$name)
  expect_true(all(res$editable))  # example base has only editable types
})

test_that("hb_list_columns validates inputs", {
  cl <- mock_client()
  expect_error(hb_list_columns(1L, "Samples"), class = "harbour_error_bad_argument")
  expect_error(hb_list_columns(cl, ""), regexp = "`table` must be a single non-empty string\\.")
  expect_error(hb_list_columns(cl, "Nope"), "not found")
})

test_that("hb_list_columns flags read-only types as non-editable", {
  cl <- mock_client()
  cl$.metadata <- new_harbour_metadata(
    list(tables = list(list(name = "T", columns = list(
      list(name = "x", type = "text", key = "k1"),
      list(name = "f", type = "formula", key = "k2")
    )))),
    base_name = "b"
  )
  res <- hb_list_columns(cl, "T")
  expect_identical(res$editable, c(TRUE, FALSE))
})

test_that("hb_add_column posts and invalidates metadata cache", {
  cl <- mock_client()
  rec <- with_mocked_request(
    res <- hb_add_column(cl, "Samples", "Notes", "text",
                column_data = list(x = 1)),
    response = list()
  )
  expect_identical(res, cl)
  expect_null(cl$.metadata)
  expect_identical(rec$calls[[1]]$method, "POST")
  expect_identical(rec$calls[[1]]$body$column_name, "Notes")
  expect_identical(rec$calls[[1]]$body$column_data, list(x = 1))
})

test_that("hb_add_column validates name and type", {
  cl <- mock_client()
  expect_error(hb_add_column(cl, "Samples", "", "text"), regexp = "`name` must be a single non-empty string\\.")
  expect_error(hb_add_column(cl, "Samples", "n", 1L), regexp = "`type` must be a single non-empty string\\.")
})

test_that("hb_add_columns validates the columns list", {
  cl <- mock_client()
  expect_error(hb_add_columns(cl, "Samples", list()), "non-empty")
  expect_error(hb_add_columns(cl, "Samples", "x"), "non-empty")
  rec <- with_mocked_request(
    hb_add_columns(cl, "Samples", list(list(column_name = "a", column_type = "text"))),
    response = list()
  )
  expect_match(rec$calls[[1]]$path, "batch-append-columns")
})

test_that("hb_update_column sends optional fields when present", {
  cl <- mock_client()
  expect_error(hb_update_column(cl, "Samples", "n", new_name = 1L),
               regexp = "`new_name` must be a single non-empty string\\.")
  rec <- with_mocked_request(
    hb_update_column(cl, "Samples", "Notes", new_name = "Comments"),
    response = list()
  )
  expect_identical(rec$calls[[1]]$method, "PUT")
  expect_identical(rec$calls[[1]]$body$new_column_name, "Comments")
  expect_identical(rec$calls[[1]]$body$op_type, "rename_column")
})

test_that("hb_delete_column issues a DELETE", {
  cl <- mock_client()
  rec <- with_mocked_request(
    hb_delete_column(cl, "Samples", "Old"),
    response = list()
  )
  expect_identical(rec$calls[[1]]$method, "DELETE")
  expect_identical(rec$calls[[1]]$body$column, "Old")
})

test_that("select-option helpers post/put/delete with validation", {
  cl <- mock_client()
  expect_error(hb_add_select_option(cl, "Samples", "Status", ""),
               regexp = "`option` must be a single non-empty string\\.")
  ra <- with_mocked_request(
    hb_add_select_option(cl, "Samples", "Status", "Done"), response = list())
  expect_identical(ra$calls[[1]]$method, "POST")
  # Updating addresses the option by id, so the column is read first.
  ru <- with_mocked_request(
    hb_update_select_option(cl, "Samples", "Status", "Done", "Complete"),
    response = select_column_response()
  )
  expect_identical(ru$calls[[1]]$method, "GET")
  expect_identical(ru$calls[[2]]$method, "PUT")
  expect_identical(
    ru$calls[[2]]$body$options,
    list(list(id = "opt-done", name = "Complete"))
  )

  # Deleting addresses options by name, and takes an array.
  rd <- with_mocked_request(
    hb_delete_select_option(cl, "Samples", "Status", "Old"), response = list())
  expect_identical(rd$calls[[1]]$method, "DELETE")
  expect_identical(rd$calls[[1]]$body$option_names, list("Old"))
})

test_that("updating an unknown select option lists the ones that exist", {
  cl <- mock_client()
  expect_error(
    with_mocked_request(
      hb_update_select_option(cl, "Samples", "Status", "Nope", "New"),
      response = select_column_response()
    ),
    class = "harbour_error_not_found"
  )
})
