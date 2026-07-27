# The contract these tests defend
# -------------------------------
# Before this file existed, every network test replaced .hb_request() and
# asserted only on the canned response. Mutating four endpoint URLs to
# garbage left the whole suite green, and two real defects had been sitting
# in the code unnoticed: no base-scoped path carried the mandatory
# {base_uuid} segment, and hb_metadata() used a service prefix that does
# not exist.
#
# The spec below is written out literally, so changing an endpoint requires
# changing it in two places - the implementation and this table.
#
# Authoritative surface: https://api.seatable.com/reference/
# /dtable-server/ and /dtable-db/ were deprecated in SeaTable 5.2 and
# removed in 5.3; everything base-scoped is on the api gateway.

UUID <- "uuid-under-test"
GATEWAY <- paste0("/api-gateway/api/v2/dtables/", UUID, "/")

contract_client <- function() {
  cl <- mock_client()
  cl$base_uuid <- UUID
  cl
}

# fn:      label used in failure messages
# call:    a function of (cl) that invokes the wrapper
# method:  expected HTTP verb
# path:    expected fully-resolved path
# service: expected host selector
# auth:    expected credential type
ENDPOINTS <- list(
  list(
    fn = "hb_metadata", method = "GET",
    path = paste0(GATEWAY, "metadata/"), service = "gateway", auth = "base",
    call = function(cl) hb_metadata(cl)
  ),
  list(
    fn = "hb_list_collaborators", method = "GET",
    path = paste0(GATEWAY, "related-users/"),
    service = "gateway", auth = "base",
    call = function(cl) hb_list_collaborators(cl)
  ),
  list(
    fn = "hb_read_table", method = "GET",
    path = paste0(GATEWAY, "rows/"), service = "gateway", auth = "base",
    call = function(cl) hb_read_table(cl, "Samples")
  ),
  list(
    fn = "hb_get_row", method = "GET",
    path = paste0(GATEWAY, "rows/r0001/"),
    service = "gateway", auth = "base",
    call = function(cl) hb_get_row(cl, "Samples", "r0001")
  ),
  list(
    fn = "hb_query",
    body = c("sql", "convert_keys"), method = "POST",
    path = paste0(GATEWAY, "sql/"), service = "gateway", auth = "base",
    call = function(cl) hb_query(cl, "SELECT * FROM Samples")
  ),
  list(
    fn = "hb_append_rows",
    body = c("table_name", "rows"), method = "POST",
    path = paste0(GATEWAY, "rows/"), service = "gateway", auth = "base",
    call = function(cl) {
      hb_append_rows(cl, "Samples", tibble::tibble(Name = "x"))
    }
  ),
  list(
    fn = "hb_update_rows",
    body = c("table_name", "updates"), method = "PUT",
    path = paste0(GATEWAY, "rows/"), service = "gateway", auth = "base",
    call = function(cl) {
      hb_update_rows(cl, "Samples", tibble::tibble(`_id` = "r1", Name = "x"))
    }
  ),
  list(
    fn = "hb_delete_rows",
    body = c("table_name", "row_ids"), method = "DELETE",
    path = paste0(GATEWAY, "rows/"), service = "gateway", auth = "base",
    call = function(cl) hb_delete_rows(cl, "Samples", "r1")
  ),
  list(
    fn = "hb_lock_rows",
    body = c("table_name", "row_ids"), method = "PUT",
    path = paste0(GATEWAY, "lock-rows/"), service = "gateway", auth = "base",
    call = function(cl) hb_lock_rows(cl, "Samples", "r1")
  ),
  list(
    fn = "hb_unlock_rows",
    body = c("table_name", "row_ids"), method = "PUT",
    path = paste0(GATEWAY, "unlock-rows/"),
    service = "gateway", auth = "base",
    call = function(cl) hb_unlock_rows(cl, "Samples", "r1")
  ),
  list(
    fn = "hb_add_column",
    body = c("table_name", "column_name", "column_type"), method = "POST",
    path = paste0(GATEWAY, "columns/"), service = "gateway", auth = "base",
    call = function(cl) hb_add_column(cl, "Samples", "Notes", "text")
  ),
  list(
    fn = "hb_add_columns",
    body = c("table_name", "columns"), method = "POST",
    path = paste0(GATEWAY, "batch-append-columns/"),
    service = "gateway", auth = "base",
    call = function(cl) {
      hb_add_columns(cl, "Samples", list(list(name = "N", type = "text")))
    }
  ),
  list(
    fn = "hb_update_column",
    body = c("table_name", "column", "op_type", "new_column_name"), method = "PUT",
    path = paste0(GATEWAY, "columns/"), service = "gateway", auth = "base",
    call = function(cl) {
      hb_update_column(cl, "Samples", "Notes", new_name = "Comments")
    }
  ),
  list(
    fn = "hb_delete_column",
    body = c("table_name", "column"), method = "DELETE",
    path = paste0(GATEWAY, "columns/"), service = "gateway", auth = "base",
    call = function(cl) hb_delete_column(cl, "Samples", "Notes")
  ),
  list(
    fn = "hb_add_select_option",
    body = c("table_name", "column", "options"), method = "POST",
    path = paste0(GATEWAY, "column-options/"),
    service = "gateway", auth = "base",
    call = function(cl) hb_add_select_option(cl, "Samples", "Status", "new")
  ),
  list(
    fn = "hb_update_select_option",
    body = c("table_name", "column", "options"), method = "PUT",
    path = paste0(GATEWAY, "column-options/"),
    service = "gateway", auth = "base",
    # Addresses the option by id, so it reads the column first.
    index = 2L, response = select_column_response(),
    call = function(cl) {
      hb_update_select_option(cl, "Samples", "Status", "draft", "pending")
    }
  ),
  list(
    fn = "hb_delete_select_option",
    body = c("table_name", "column", "option_names"), method = "DELETE",
    path = paste0(GATEWAY, "column-options/"),
    service = "gateway", auth = "base",
    call = function(cl) {
      hb_delete_select_option(cl, "Samples", "Status", "draft")
    }
  ),
  list(
    fn = "hb_create_view",
    body = c("table_name", "name"), method = "POST",
    path = paste0(GATEWAY, "views/"), service = "gateway", auth = "base",
    call = function(cl) hb_create_view(cl, "Samples", "New view")
  ),
  list(
    fn = "hb_get_view", method = "GET",
    path = paste0(GATEWAY, "views/Default/"),
    service = "gateway", auth = "base",
    call = function(cl) hb_get_view(cl, "Samples", "Default")
  ),
  list(
    fn = "hb_update_view",
    # view_name is redundant with the path segment but harmless, and
    # pinning it here documents that harbouR sends both.
    body = c("table_name", "view_name", "row_height"), method = "PUT",
    path = paste0(GATEWAY, "views/Default/"),
    service = "gateway", auth = "base",
    call = function(cl) {
      hb_update_view(cl, "Samples", "Default", list(row_height = "tall"))
    }
  ),
  list(
    fn = "hb_delete_view",
    body = c("table_name", "view_name"), method = "DELETE",
    path = paste0(GATEWAY, "views/Default/"),
    service = "gateway", auth = "base",
    call = function(cl) hb_delete_view(cl, "Samples", "Default")
  ),
  list(
    fn = "hb_create_table",
    body = c("table_name", "columns"), method = "POST",
    path = paste0(GATEWAY, "tables/"), service = "gateway", auth = "base",
    call = function(cl) hb_create_table(cl, "NewTable")
  ),
  list(
    fn = "hb_rename_table",
    body = c("table_name", "new_table_name"), method = "PUT",
    path = paste0(GATEWAY, "tables/"), service = "gateway", auth = "base",
    call = function(cl) hb_rename_table(cl, "Samples", "Specimens")
  ),
  list(
    fn = "hb_delete_table",
    body = c("table_name"), method = "DELETE",
    path = paste0(GATEWAY, "tables/"), service = "gateway", auth = "base",
    call = function(cl) hb_delete_table(cl, "Samples")
  ),
  list(
    fn = "hb_duplicate_table",
    body = c("table_name", "is_duplicate_records"), method = "POST",
    path = paste0(GATEWAY, "tables/duplicate-table/"),
    service = "gateway", auth = "base",
    call = function(cl) hb_duplicate_table(cl, "Samples")
  ),
  list(
    fn = "hb_ping", method = "GET",
    path = "/api2/ping/", service = "web", auth = "none",
    call = function(cl) hb_ping(cl)
  ),
  list(
    fn = "hb_server_info", method = "GET",
    path = "/server-info/", service = "web", auth = "none",
    call = function(cl) hb_server_info(cl)
  )
)

test_that("every wrapper targets the documented path, verb, host and auth", {
  for (spec in ENDPOINTS) {
    cl <- contract_client()
    rec <- with_mocked_request(
      try(spec$call(cl), silent = TRUE),
      response = spec$response %||% list()
    )
    idx <- spec$index %||% 1L
    expect_gte(length(rec$calls), idx)
    got <- rec$calls[[idx]]
    expect_identical(got$path, spec$path, info = spec$fn)
    expect_identical(got$method, spec$method, info = spec$fn)
    expect_identical(got$service, spec$service, info = spec$fn)
    expect_identical(got$auth, spec$auth, info = spec$fn)
    # The body's field names are the half of the contract the server
    # actually parses; pinning only the URL let any field be renamed to
    # garbage with the suite still green.
    if (!is.null(spec$body)) {
      expect_setequal(names(got$body), spec$body)
    }
  }
})

test_that("every base-scoped path carries the base UUID", {
  # This is the assertion that would have caught the defect: client$base_uuid
  # was captured from the token exchange and then never used to build a URL,
  # so no base call could ever have addressed a real resource.
  base_scoped <- Filter(function(s) s$service == "gateway", ENDPOINTS)
  expect_gt(length(base_scoped), 20L)
  for (spec in base_scoped) {
    cl <- contract_client()
    rec <- with_mocked_request(
      try(spec$call(cl), silent = TRUE),
      response = spec$response %||% list()
    )
    idx <- spec$index %||% 1L
    expect_true(grepl(UUID, rec$calls[[idx]]$path, fixed = TRUE),
                info = spec$fn)
  }
})

test_that("no wrapper addresses a service SeaTable removed in 5.3", {
  sources <- list.files("../../R", pattern = "[.]R$", full.names = TRUE)
  if (!length(sources)) {
    skip("package sources not available from the installed tree")
  }
  code <- unlist(lapply(sources, readLines, warn = FALSE))
  # Comments legitimately mention the removed services; only code counts.
  code <- code[!grepl("^\\s*#", code)]
  expect_false(any(grepl("/dtable-server/", code, fixed = TRUE)))
  expect_false(any(grepl("/dtable-db/", code, fixed = TRUE)))
})

test_that("the base UUID is resolved lazily rather than demanded upfront", {
  cl <- mock_client()
  cl$base_uuid <- NULL
  fetched <- 0L
  testthat::local_mocked_bindings(
    .hb_get_base_token = function(client, call = NULL) {
      fetched <<- fetched + 1L
      client$base_uuid <- "late-uuid"
      "TOK"
    },
    .package = "harbouR"
  )
  expect_identical(harbouR:::.hb_base_uuid(cl), "late-uuid")
  expect_identical(fetched, 1L)
})

test_that("an unresolvable base UUID is an auth error, not a bad URL", {
  cl <- mock_client()
  cl$base_uuid <- NULL
  testthat::local_mocked_bindings(
    .hb_get_base_token = function(client, call = NULL) "TOK",
    .package = "harbouR"
  )
  expect_error(harbouR:::.hb_base_uuid(cl), class = "harbour_error_auth")
})

test_that("names with spaces, slashes and non-ASCII survive the path", {
  cl <- contract_client()
  rec <- with_mocked_request(
    try(hb_get_view(cl, "Samples", "Erwartungswerte Toxine 1"), silent = TRUE),
    response = list()
  )
  expect_identical(
    rec$calls[[1L]]$path,
    paste0(GATEWAY, "views/Erwartungswerte%20Toxine%201/")
  )

  rec2 <- with_mocked_request(
    try(hb_get_view(cl, "Samples", "a/b"), silent = TRUE),
    response = list()
  )
  # A slash in a view name must not split the path into two segments.
  expect_identical(rec2$calls[[1L]]$path, paste0(GATEWAY, "views/a%2Fb/"))
})

test_that("base tokens are sent as Bearer, web tokens as Token", {
  cl <- contract_client()
  expect_match(harbouR:::.hb_auth_header(cl, "base"), "^Bearer ")
  expect_match(harbouR:::.hb_auth_header(cl, "api"), "^Token ")
  cl$.account_token <- "ACCT"
  expect_match(harbouR:::.hb_auth_header(cl, "account"), "^Token ")
})

test_that("an escaped path segment reaches the wire without double-encoding", {
  # httr2::req_url_path() percent-encodes, so handing it an already-escaped
  # path turns %20 into %2520 - and it leaves "/" alone, so a view named
  # "a/b" would split into two segments. Neither is visible to a test that
  # only inspects the path string, so assert on the built URL.
  cl <- contract_client()
  req <- harbouR:::.hb_req(
    cl,
    harbouR:::.hb_base_path(cl, "views", "Erwartungswerte Toxine 1", ""),
    service = "gateway", auth = "base"
  )
  expect_match(req$url, "views/Erwartungswerte%20Toxine%201/", fixed = TRUE)
  expect_false(grepl("%25", req$url, fixed = TRUE))

  req2 <- harbouR:::.hb_req(
    cl, harbouR:::.hb_base_path(cl, "views", "a/b", ""),
    service = "gateway", auth = "base"
  )
  expect_match(req2$url, "views/a%2Fb/", fixed = TRUE)
})
