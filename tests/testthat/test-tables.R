test_that("hb_create_table validates and posts columns", {
  cl <- local_mock_client()
  expect_error(hb_create_table(cl, ""), class = "rlang_error")
  expect_error(hb_create_table(cl, "T", columns = "x"), "list of column specs")
  rec <- with_mocked_request(
    res <- hb_create_table(cl, "NewT", list(list(name = "N", type = "text"))),
    response = list()
  )
  expect_identical(res, cl)
  expect_null(cl$.metadata)
  expect_identical(rec$calls[[1]]$method, "POST")
  expect_identical(rec$calls[[1]]$body$table_name, "NewT")
})

test_that("hb_rename_table sends both names", {
  cl <- local_mock_client()
  expect_error(hb_rename_table(cl, "Old", ""), class = "rlang_error")
  rec <- with_mocked_request(
    hb_rename_table(cl, "Old", "New"), response = list())
  expect_identical(rec$calls[[1]]$method, "PUT")
  expect_identical(rec$calls[[1]]$body$new_table_name, "New")
})

test_that("hb_delete_table issues a DELETE and clears cache", {
  cl <- local_mock_client()
  rec <- with_mocked_request(
    hb_delete_table(cl, "DropMe"), response = list())
  expect_identical(rec$calls[[1]]$method, "DELETE")
  expect_null(cl$.metadata)
})

test_that("hb_duplicate_table includes new_name only when supplied", {
  cl <- local_mock_client()
  expect_error(hb_duplicate_table(cl, "S", new_name = 1L), class = "rlang_error")
  rec1 <- with_mocked_request(
    hb_duplicate_table(cl, "S"), response = list())
  expect_null(rec1$calls[[1]]$body$new_table_name)
  rec2 <- with_mocked_request(
    hb_duplicate_table(cl, "S", "S_copy"), response = list())
  expect_identical(rec2$calls[[1]]$body$new_table_name, "S_copy")
})
