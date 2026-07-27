test_that("hb_create_table validates and posts columns", {
  cl <- mock_client()
  expect_error(hb_create_table(cl, ""), regexp = "`table` must be a single non-empty string\\.")
  expect_error(hb_create_table(cl, "T", columns = "x"), "list of column specs")
  rec <- with_mocked_request(
    res <- hb_create_table(cl, "NewT",
                columns = list(list(name = "N", type = "text"))),
    response = list()
  )
  expect_identical(res, cl)
  expect_null(cl$.metadata)
  expect_identical(rec$calls[[1]]$method, "POST")
  expect_identical(rec$calls[[1]]$body$table_name, "NewT")
})

test_that("hb_rename_table sends both names", {
  cl <- mock_client()
  expect_error(hb_rename_table(cl, "Old", ""), regexp = "`new_name` must be a single non-empty string\\.")
  rec <- with_mocked_request(
    hb_rename_table(cl, "Old", "New"), response = list())
  expect_identical(rec$calls[[1]]$method, "PUT")
  expect_identical(rec$calls[[1]]$body$new_table_name, "New")
})

test_that("hb_delete_table issues a DELETE and clears cache", {
  cl <- mock_client()
  rec <- with_mocked_request(
    hb_delete_table(cl, "DropMe"), response = list())
  expect_identical(rec$calls[[1]]$method, "DELETE")
  expect_null(cl$.metadata)
})

test_that("hb_duplicate_table sends the documented body", {
  cl <- mock_client()
  expect_error(hb_duplicate_table(cl, "S", duplicate_records = "yes"),
               class = "harbour_error_bad_argument")

  rec <- with_mocked_request(
    res <- hb_duplicate_table(cl, "Samples"),
    response = list()
  )
  expect_identical(res, cl)
  expect_match(rec$calls[[1]]$path, "tables/duplicate-table/$")
  # SeaTable's model has table_name and is_duplicate_records, and no
  # new_table_name: the copy is always named "<original> (copy)".
  expect_setequal(names(rec$calls[[1]]$body),
                  c("table_name", "is_duplicate_records"))
  expect_true(rec$calls[[1]]$body$is_duplicate_records)

  rec2 <- with_mocked_request(
    hb_duplicate_table(cl, "Samples", duplicate_records = FALSE),
    response = list()
  )
  expect_false(rec2$calls[[1]]$body$is_duplicate_records)
})

test_that("hb_create_table accepts friendly column specs", {
  cl <- mock_client()
  # The documented spelling is name/type, matching hb_add_column()'s
  # arguments; the wire wants column_name/column_type.
  rec <- with_mocked_request(
    hb_create_table(cl, "New", columns = list(list(name = "N", type = "text"))),
    response = list()
  )
  expect_setequal(names(rec$calls[[1]]$body$columns[[1]]),
                  c("column_name", "column_type"))

  # and the wire spelling still works
  rec2 <- with_mocked_request(
    hb_create_table(cl, "New", columns = list(
      list(column_name = "N", column_type = "text")
    )),
    response = list()
  )
  expect_identical(rec2$calls[[1]]$body$columns[[1]]$column_name, "N")

  expect_error(
    hb_create_table(cl, "New", columns = list(list(name = "N"))),
    class = "harbour_error_bad_argument"
  )
  expect_error(
    hb_create_table(cl, "New", columns = list("not a list")),
    class = "harbour_error_bad_argument"
  )
})
