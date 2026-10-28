test_that("a missing branding asset has a classified error", {
  error <- tryCatch(
    .hb_brand_text("missing-branding-asset.svg"),
    harbour_error_package_asset = identity
  )
  expect_s3_class(error, "harbour_error_package_asset")
  expect_s3_class(error, "harbour_error")
  expect_identical(error$file, "missing-branding-asset.svg")
})
