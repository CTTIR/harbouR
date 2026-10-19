# hb_client() reads SEATABLE_SERVER and SEATABLE_API_TOKEN as argument
# defaults. If either is set in the developer's environment the auth tests
# see credentials they never supplied and fail. Neutralise both for the
# whole run, and restore them afterwards.
withr::local_envvar(
  c(SEATABLE_SERVER = NA, SEATABLE_API_TOKEN = NA),
  .local_envir = testthat::teardown_env()
)

# bslib compiles the explorer's theme through sass, which caches the CSS
# in tools::R_user_dir("sass", "cache") under the user's home. Keep a
# test run from leaving anything there.
withr::local_options(
  sass.cache = FALSE,
  .local_envir = testthat::teardown_env()
)
