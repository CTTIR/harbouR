# hb_client() reads SEATABLE_SERVER and SEATABLE_API_TOKEN as argument
# defaults. If either is set in the developer's environment the auth tests
# see credentials they never supplied and fail. Neutralise both for the
# whole run, and restore them afterwards.
withr::local_envvar(
  c(SEATABLE_SERVER = NA, SEATABLE_API_TOKEN = NA),
  .local_envir = testthat::teardown_env()
)
