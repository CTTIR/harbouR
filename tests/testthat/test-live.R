# The only tests that talk to a real SeaTable server.
#
# Everything else in this suite replaces harbouR's request seam, which
# means it can prove that a wrapper builds the URL harbouR intends - but
# not that SeaTable agrees. These close that gap.
#
# They are skipped unless HARBOUR_TEST_SERVER and HARBOUR_TEST_TOKEN name
# a base you are willing to have written to and cleaned up:
#
#   Sys.setenv(HARBOUR_TEST_SERVER = "https://seatable.example.org")
#   Sys.setenv(HARBOUR_TEST_TOKEN  = "<an API token for a throwaway base>")
#
# They never run on CRAN.

live_client <- function() {
  testthat::skip_on_cran()
  server <- Sys.getenv("HARBOUR_TEST_SERVER")
  token <- Sys.getenv("HARBOUR_TEST_TOKEN")
  testthat::skip_if(
    !nzchar(server) || !nzchar(token),
    "HARBOUR_TEST_SERVER / HARBOUR_TEST_TOKEN not set"
  )
  hb_client(server = server, api_token = token)
}

test_that("the server is reachable and the credentials work", {
  client <- live_client()
  expect_identical(hb_ping(client), client)
  expect_identical(hb_check_credentials(client), client)
  info <- hb_server_info(client)
  expect_identical(nrow(info), 1L)
  expect_true(nzchar(info$version))
})

test_that("metadata comes back and names a base", {
  client <- live_client()
  meta <- hb_metadata(client)
  expect_s3_class(meta, "harbour_metadata")
  expect_true(nzchar(client$base_uuid))
  tables <- hb_list_tables(client)
  expect_named(tables, c("name", "n_columns", "n_views"))
  expect_gt(nrow(tables), 0L)
})

test_that("a table reads with the columns its schema declares", {
  client <- live_client()
  table <- hb_list_tables(client)$name[[1L]]
  columns <- hb_list_columns(client, table)
  data <- hb_read_table(client, table, n_max = 5L)
  expect_true(all(columns$name %in% names(data)))
  expect_true("_id" %in% names(data))
})

test_that("SQL runs and agrees with the read path on types", {
  client <- live_client()
  table <- hb_list_tables(client)$name[[1L]]
  sql <- sprintf("select * from `%s` limit 5", table)
  queried <- hb_query(client, sql)
  expect_s3_class(queried, "tbl_df")
})

test_that("a row round-trips: append, read, update, delete", {
  client <- live_client()
  table <- hb_list_tables(client)$name[[1L]]
  columns <- hb_list_columns(client, table)
  text_col <- columns$name[columns$type == "text" & columns$editable][[1L]]
  testthat::skip_if(is.na(text_col), "no writable text column in the base")

  marker <- paste0("harbouR-test-", as.integer(Sys.time()))
  payload <- tibble::tibble(x = marker)
  names(payload) <- text_col

  written <- hb_append_rows(client, table, payload)
  expect_identical(written$n_rows, 1L)
  withr::defer({
    found <- hb_read_table(client, table)
    ids <- found[["_id"]][found[[text_col]] %in% c(marker, "updated")]
    if (length(ids) > 0L) hb_delete_rows(client, table, ids)
  })

  found <- hb_read_table(client, table)
  expect_true(marker %in% found[[text_col]])

  id <- found[["_id"]][match(marker, found[[text_col]])]
  update <- tibble::tibble(`_id` = id, x = "updated")
  names(update)[2L] <- text_col
  expect_identical(hb_update_rows(client, table, update)$n_rows, 1L)
  expect_true("updated" %in% hb_read_table(client, table)[[text_col]])
})

test_that("a live base exports to a .dtable that reads back", {
  client <- live_client()
  base <- .hb_as_dtable(client)
  expect_true(is_harbour_dtable(base))
  out <- withr::local_tempfile(fileext = ".dtable")
  hb_write_dtable(base, out)
  expect_identical(hb_read_dtable(out)$content, base$content)
})
