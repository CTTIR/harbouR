test_that(".check_string accepts valid and rejects invalid strings", {
  expect_null(harbouR:::.check_string("x"))
  expect_null(harbouR:::.check_string(NULL, allow_null = TRUE))
  expect_error(harbouR:::.check_string(""), "non-empty string")
  expect_error(harbouR:::.check_string(NA_character_), "non-empty string")
  expect_error(harbouR:::.check_string(c("a", "b")), "non-empty string")
  expect_error(harbouR:::.check_string(1L), "non-empty string")
  expect_error(harbouR:::.check_string(NULL), "non-empty string")
})

test_that(".check_flag enforces a single logical", {
  expect_null(harbouR:::.check_flag(TRUE))
  expect_null(harbouR:::.check_flag(FALSE))
  expect_error(harbouR:::.check_flag(NA), "TRUE.*FALSE")
  expect_error(harbouR:::.check_flag("x"), "TRUE.*FALSE")
  expect_error(harbouR:::.check_flag(c(TRUE, FALSE)), "TRUE.*FALSE")
})

test_that(".check_class enforces inheritance", {
  m <- hb_example_metadata()
  expect_null(harbouR:::.check_class(m, "harbour_metadata"))
  expect_error(harbouR:::.check_class(1L, "harbour_metadata"), "must inherit")
})

test_that(".check_client requires a harbour_client", {
  cl <- local_mock_client()
  expect_null(harbouR:::.check_client(cl))
  expect_error(harbouR:::.check_client(1L), "harbour_client")
})

test_that(".check_table validates against cached metadata", {
  cl <- local_mock_client()
  expect_null(harbouR:::.check_table(cl, "Samples"))
  expect_error(harbouR:::.check_table(cl, "Nope"), "not found")
  expect_error(harbouR:::.check_table(cl, ""), "non-empty string")

  cl2 <- local_mock_client()
  cl2$.metadata <- NULL
  # With no metadata cached, only the string check runs.
  expect_null(harbouR:::.check_table(cl2, "Anything"))
})

test_that(".mask_token masks safely across lengths", {
  expect_identical(harbouR:::.mask_token("abcd"), "****")
  expect_identical(harbouR:::.mask_token(""), "<none>")
  expect_identical(harbouR:::.mask_token(NA_character_), "<none>")
  expect_match(harbouR:::.mask_token("12345678901234567890"), "^1234\\.\\.\\.7890$")
})

test_that(".is_truthy follows rlang-style truthiness", {
  expect_false(harbouR:::.is_truthy(NULL))
  expect_false(harbouR:::.is_truthy(NA))
  expect_false(harbouR:::.is_truthy(""))
  expect_false(harbouR:::.is_truthy(character()))
  expect_true(harbouR:::.is_truthy("x"))
  expect_true(harbouR:::.is_truthy(1L))
})
