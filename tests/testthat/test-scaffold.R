test_that("scaffolded functions raise a clear error", {
  expect_error(hb_list_links(), "not yet implemented")
  expect_error(hb_admin_list_users(), "not yet implemented")
  expect_error(hb_scheduler_list(), "not yet implemented")
})
