# Arguments of the writing verbs that are refused, or corrected, before
# anything is sent. Each test also checks what reached the server: a
# refused call must send nothing.

test_that("a chunk size that is not a positive number sends nothing", {
  cl <- mock_client()
  rec <- new_request_recorder()
  rows <- data.frame(Name = "S-010")
  for (bad in list(0, -1, NA_integer_, "10", c(1, 2), NULL)) {
    expect_error(
      with_mocked_request(
        hb_append_rows(cl, "Samples", rows, chunk_size = bad),
        recorder = rec
      ),
      class = "harbour_error_bad_argument"
    )
  }
  expect_error(
    with_mocked_request(
      hb_update_rows(
        cl, "Samples", data.frame(`_id` = "r1", Name = "S-010",
                                  check.names = FALSE),
        chunk_size = 0
      ),
      recorder = rec
    ),
    class = "harbour_error_bad_argument"
  )
  expect_length(rec$calls, 0L)
})

test_that("a chunk size above SeaTable's maximum is capped with a warning", {
  cl <- mock_client()
  rec <- new_request_recorder(
    function(path, method, query, body) {
      list(inserted_row_count = length(body$rows))
    }
  )
  rows <- data.frame(Name = sprintf("S-%04d", seq_len(1001L)))
  expect_warning(
    out <- with_mocked_request(
      hb_append_rows(cl, "Samples", rows, chunk_size = 5000),
      recorder = rec
    ),
    "capped"
  )
  sent <- vapply(rec$calls, function(call) length(call$body$rows), integer(1))
  expect_identical(sent, c(1000L, 1L))
})

test_that("a chunk size is used as given, a fraction rounded down", {
  cl <- mock_client()
  rec <- new_request_recorder(
    function(path, method, query, body) {
      list(inserted_row_count = length(body$rows))
    }
  )
  rows <- data.frame(Name = sprintf("S-%04d", seq_len(5L)))
  with_mocked_request(
    result <- hb_append_rows(cl, "Samples", rows, chunk_size = 2.9),
    recorder = rec
  )
  sent <- vapply(rec$calls, function(call) length(call$body$rows), integer(1))
  expect_identical(sent, c(2L, 2L, 1L))
  expect_identical(result$n_rows, 5L)
  expect_identical(result$n_requests, 3L)
})

test_that("appending no rows sends nothing and reports none", {
  cl <- mock_client()
  rec <- new_request_recorder()
  with_mocked_request(
    result <- hb_append_rows(cl, "Samples", data.frame(Name = character())),
    recorder = rec
  )
  expect_length(rec$calls, 0L)
  expect_identical(result$n_rows, 0L)
  expect_identical(result$n_requests, 0L)
})

test_that("hb_update_column refuses a call with nothing to update", {
  cl <- mock_client()
  rec <- new_request_recorder()
  expect_error(
    with_mocked_request(
      hb_update_column(cl, "Samples", "Name"),
      recorder = rec
    ),
    class = "harbour_error_bad_argument"
  )
  expect_length(rec$calls, 0L)
})

test_that("hb_update_column refuses a rename and a type change at once", {
  cl <- mock_client()
  rec <- new_request_recorder()
  expect_error(
    with_mocked_request(
      hb_update_column(
        cl, "Samples", "Name", new_name = "Label", new_type = "long-text"
      ),
      recorder = rec
    ),
    class = "harbour_error_bad_argument"
  )
  expect_error(
    with_mocked_request(
      hb_update_column(
        cl, "Samples", "Name", new_name = "Label",
        column_data = list(format = "number")
      ),
      recorder = rec
    ),
    class = "harbour_error_bad_argument"
  )
  expect_length(rec$calls, 0L)
  # the cached schema is still the one the refused call found
  expect_false(is.null(cl$.metadata))
})
