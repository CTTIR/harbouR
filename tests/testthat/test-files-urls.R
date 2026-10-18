# Asset URLs, coming and going
# ----------------------------
# The download-link and delete endpoints take only the path below the
# base's asset root, and the API token names the client's own base.
# Whatever server or base a URL names, the call therefore acts on the
# client's base, so the URL has to be checked before it is reduced to a
# path. The other way round, the URL harbouR builds after an upload has
# to reduce to the folder the file went to.

# An asset of the mock client's base ("demo-uuid"), as a cell holds it
# relative to the server, and the download link the exchange hands back.
ASSET <- "/workspace/42/asset/demo-uuid/files/2026-07/a.pdf"
LINK <- "https://demo.example.org/seafhttp/files/t/a.pdf"

# Stand in for the server for the rest of the calling test: the
# download-link exchange answers LINK, and every fetch writes `body` and
# ends at `final` (where a redirect would leave it) with content `type`.
# The returned recorder lists the exchanges in `$calls` and the URLs
# fetched in `$fetched`.
local_fake_server <- function(type = "application/pdf", final = NULL,
                              body = "payload",
                              .env = rlang::caller_env()) {
  server <- new_request_recorder(list(download_link = LINK))
  server$fetched <- character()
  testthat::local_mocked_bindings(
    req_perform = function(req, path = NULL, ...) {
      server$fetched <- c(server$fetched, req$url)
      writeLines(body, path)
      httr2::response(
        200L,
        url = final %||% req$url,
        headers = list(`Content-Type` = type)
      )
    },
    .package = "httr2",
    .env = .env
  )
  with_mocked_request(NULL, recorder = server, .env = .env)
  server
}

test_that("an asset URL is exchanged however its server is spelt", {
  # The token only ever goes to the client's server, never to the URL,
  # so the scheme, the host's case and a default port can be ignored.
  cases <- list(
    relative = c("https://demo.example.org", ASSET),
    upper_case_url = c(
      "https://demo.example.org", paste0("https://DEMO.Example.ORG", ASSET)
    ),
    upper_case_server = c(
      "https://Demo.Example.org", paste0("https://demo.example.org", ASSET)
    ),
    upper_case_scheme = c(
      "https://demo.example.org", paste0("HTTPS://demo.example.org", ASSET)
    ),
    http = c(
      "https://demo.example.org", paste0("http://demo.example.org", ASSET)
    ),
    default_port = c(
      "https://demo.example.org", paste0("https://demo.example.org:443", ASSET)
    )
  )
  for (case in names(cases)) {
    server <- local_fake_server()
    cl <- mock_client(server = cases[[case]][[1L]])
    dest <- withr::local_tempfile(fileext = ".pdf")
    hb_download_file(cl, cases[[case]][[2L]], dest)
    expect_length(server$calls, 1L)
    expect_identical(
      server$calls[[1L]]$path, "/api/v2.1/dtable/app-download-link/",
      info = case
    )
    expect_identical(
      server$calls[[1L]]$query$path, "/files/2026-07/a.pdf",
      info = case
    )
    expect_identical(server$fetched, LINK, info = case)
    expect_identical(readLines(dest), "payload", info = case)
  }
})

test_that("a preview URL is an asset, and another port another server", {
  preview <- "/workspace/42/asset-preview/demo-uuid/images/2026-07/p.png"
  server <- local_fake_server(type = "image/png")
  dest <- withr::local_tempfile(fileext = ".png")
  hb_download_file(
    mock_client(), paste0("https://demo.example.org", preview), dest
  )
  expect_identical(server$calls[[1L]]$query$path, "/images/2026-07/p.png")
  # Only a default port is ignored; any other names another server, even
  # on the same host.
  expect_error(
    hb_download_file(
      mock_client(), paste0("https://demo.example.org:8443", ASSET),
      withr::local_tempfile(fileext = ".pdf")
    ),
    class = "harbour_error_bad_argument"
  )
  expect_length(server$calls, 1L)
})

test_that("an asset URL on another server is refused, not fetched", {
  server <- local_fake_server()
  dest <- withr::local_tempfile(fileext = ".pdf")
  cnd <- expect_error(
    hb_download_file(
      mock_client(), paste0("https://other.example.org", ASSET), dest
    ),
    class = "harbour_error_bad_argument"
  )
  expect_match(conditionMessage(cnd), "other.example.org", fixed = TRUE)
  expect_length(server$calls, 0L)
  expect_length(server$fetched, 0L)
  expect_false(file.exists(dest))
})

test_that("a URL that is not an asset is still fetched as it is", {
  # Whatever such a URL returns is what the caller asked for, HTML
  # included; only an asset download can mistake a login page for a file.
  # An asset's path in the query string or the fragment does not make a
  # URL an asset; only its own path does.
  urls <- c(
    "https://other.example.org/report",
    paste0("https://demo.example.org/search?q=", ASSET),
    paste0("https://demo.example.org/page#", ASSET)
  )
  server <- local_fake_server(type = "text/html")
  for (url in urls) {
    dest <- withr::local_tempfile(fileext = ".html")
    hb_download_file(mock_client(), url, dest)
    expect_identical(readLines(dest), "payload", info = url)
  }
  expect_length(server$calls, 0L)
  expect_identical(server$fetched, urls)
})

test_that("SeaTable's login page is never saved as the asset", {
  # httr2 follows the redirect to the login page, which then arrives with
  # status 200, so the status alone cannot tell it from the file.
  dir <- withr::local_tempdir()
  dest <- file.path(dir, "a.pdf")
  writeLines("original", dest)
  local_fake_server(
    type = "text/html; charset=utf-8",
    final = paste0("https://demo.example.org/accounts/login/?next=", ASSET),
    body = "<html><title>Log In - SeaTable</title></html>"
  )
  expect_error(
    hb_download_file(mock_client(), paste0("https://demo.example.org", ASSET),
                     dest, overwrite = TRUE),
    class = "harbour_error_http"
  )
  expect_identical(readLines(dest), "original")
  expect_identical(list.files(dir, all.files = TRUE, no.. = TRUE), "a.pdf")
})

test_that("HTML where an asset was expected is refused", {
  dest <- withr::local_tempfile(fileext = ".pdf")
  local_fake_server(type = "text/html", body = "<html>login</html>")
  expect_error(
    hb_download_file(mock_client(), ASSET, dest),
    class = "harbour_error_http"
  )
  expect_false(file.exists(dest))
})

test_that("an HTML asset may still arrive as HTML", {
  dest <- withr::local_tempfile(fileext = ".html")
  local_fake_server(type = "text/html")
  hb_download_file(
    mock_client(), "/workspace/42/asset/demo-uuid/files/2026-07/page.html",
    dest
  )
  expect_identical(readLines(dest), "payload")
})

test_that("an HTML asset that ends on the login page is refused", {
  # The login page is HTML like the asset itself, so only where the
  # request ended up tells the two apart.
  dest <- withr::local_tempfile(fileext = ".html")
  local_fake_server(
    type = "text/html",
    final = "https://demo.example.org/accounts/login/?next=/workspace/42/",
    body = "<html><title>Log In - SeaTable</title></html>"
  )
  expect_error(
    hb_download_file(
      mock_client(), "/workspace/42/asset/demo-uuid/files/2026-07/page.html",
      dest
    ),
    class = "harbour_error_http"
  )
  expect_false(file.exists(dest))
})

test_that("an asset URL of another base is neither downloaded nor deleted", {
  other <- paste0(
    "https://demo.example.org/workspace/42/asset/",
    "11111111-2222-3333-4444-555555555555/files/2026-07/a.pdf"
  )
  server <- local_fake_server()
  cl <- mock_client()
  dest <- withr::local_tempfile(fileext = ".pdf")
  cnd <- expect_error(
    hb_download_file(cl, other, dest),
    class = "harbour_error_bad_argument"
  )
  # The message says which base the URL belongs to.
  expect_match(
    conditionMessage(cnd), "11111111-2222-3333-4444-555555555555",
    fixed = TRUE
  )
  expect_false(file.exists(dest))
  cnd <- expect_error(
    hb_delete_asset(cl, other),
    class = "harbour_error_bad_argument"
  )
  expect_match(
    conditionMessage(cnd), "11111111-2222-3333-4444-555555555555",
    fixed = TRUE
  )
  expect_length(server$calls, 0L)
  expect_length(server$fetched, 0L)
})

test_that("a base UUID matches whatever its case and dashes", {
  # The base-token exchange reports the dashed form; a user may have
  # given the client the bare 32 characters.
  cl <- mock_client()
  cl$base_uuid <- "650d8a0d7e2746a88b186cc6f3db2057"
  url <- paste0(
    "https://demo.example.org/workspace/20/asset/",
    "650D8A0D-7E27-46A8-8B18-6CC6F3DB2057/files/2026-07/a.pdf"
  )
  server <- local_fake_server()
  hb_download_file(cl, url, withr::local_tempfile(fileext = ".pdf"))
  hb_delete_asset(cl, url)
  expect_length(server$calls, 2L)
  expect_identical(server$calls[[2L]]$method, "DELETE")
  expect_identical(server$calls[[2L]]$query$path, "/files/2026-07/a.pdf")
})

test_that("hb_delete_asset refuses a URL on another server", {
  rec <- with_mocked_request(
    expect_error(
      hb_delete_asset(
        mock_client(), "https://other.example.org/files/2026-07/a.pdf"
      ),
      class = "harbour_error_bad_argument"
    )
  )
  expect_length(rec$calls, 0L)
})

test_that("hb_delete_asset refuses a URL that names no file", {
  cl <- mock_client()
  rec <- with_mocked_request({
    expect_error(
      hb_delete_asset(cl, cl$server),
      class = "harbour_error_bad_argument"
    )
    expect_error(
      hb_delete_asset(cl, "/workspace/42/asset/demo-uuid/"),
      class = "harbour_error_bad_argument"
    )
    expect_error(
      hb_delete_asset(cl, "/files/2026-07/"),
      class = "harbour_error_bad_argument"
    )
  })
  expect_length(rec$calls, 0L)
})

test_that("hb_delete_asset takes a path, and checks the base only of a URL", {
  cl <- mock_client()
  cl$base_uuid <- NULL
  exchanges <- 0L
  testthat::local_mocked_bindings(
    .hb_get_base_token = function(client, ...) {
      exchanges <<- exchanges + 1L
      client$base_uuid <- "demo-uuid"
      "BASETOKENSECRET"
    },
    .package = "harbouR"
  )
  rec <- with_mocked_request(hb_delete_asset(cl, "/files/2026-07/a.pdf"))
  expect_identical(rec$calls[[1L]]$query$path, "/files/2026-07/a.pdf")
  # A bare path names no base, so it is not worth a base-token exchange.
  expect_identical(exchanges, 0L)
  rec <- with_mocked_request(hb_delete_asset(cl, ASSET))
  expect_identical(rec$calls[[1L]]$query$path, "/files/2026-07/a.pdf")
  expect_identical(exchanges, 1L)
})

test_that("a client without an API token is refused before any login", {
  cl <- mock_client()
  cl$api_token <- NULL
  cl$username <- "u@example.org"
  cl$password <- "secret"
  cl$base_uuid <- NULL
  logins <- 0L
  testthat::local_mocked_bindings(
    .hb_get_base_token = function(client, ...) {
      logins <<- logins + 1L
      "BASETOKENSECRET"
    },
    .package = "harbouR"
  )
  expect_error(hb_delete_asset(cl, ASSET), class = "harbour_error_auth")
  expect_error(
    hb_download_file(cl, ASSET, withr::local_tempfile(fileext = ".pdf")),
    class = "harbour_error_auth"
  )
  expect_identical(logins, 0L)
})

test_that("a caller's relative_path is escaped in the asset URL", {
  cl <- mock_client()
  cl$.workspace_id <- 42L
  root <- "https://demo.example.org/workspace/42/asset/demo-uuid/"
  url <- function(folder, name = "r.pdf") {
    harbouR:::.hb_asset_url(cl, folder, name)
  }
  # The folders the upload link names come out exactly as before.
  expect_identical(url("files/2026-07"), paste0(root, "files/2026-07/r.pdf"))
  expect_identical(
    url("images/2026-07", "p.png"), paste0(root, "images/2026-07/p.png")
  )
  expect_identical(url("files/100%"), paste0(root, "files/100%25/r.pdf"))
  expect_identical(
    url("files/Study 1 #2"), paste0(root, "files/Study%201%20%232/r.pdf")
  )
  expect_identical(url("/files/2026-07/"), paste0(root, "files/2026-07/r.pdf"))
  expect_identical(url("files//a"), paste0(root, "files/a/r.pdf"))
})

test_that("an asset URL harbouR built reduces to the folder it was given", {
  cl <- mock_client()
  cl$.workspace_id <- 42L
  folders <- c(
    "files/100%", "files/Study 1 #2", "files/2026-07/", "files/a b/c d"
  )
  for (folder in folders) {
    url <- harbouR:::.hb_asset_url(cl, folder, "my report #1.pdf")
    expect_identical(
      harbouR:::.hb_asset_path(url),
      paste0("/", sub("/$", "", folder), "/my report #1.pdf"),
      info = folder
    )
  }
})

test_that("hb_upload_file returns a file object SeaTable's cells accept", {
  # The upload reply carries only name, id and size; SeaTable's file
  # cells give every attachment the type "file".
  cl <- mock_client()
  src <- withr::local_tempfile(fileext = ".pdf")
  writeLines("content", src)
  testthat::local_mocked_bindings(
    .hb_request = function(client, path, ...) {
      list(
        upload_link = "https://demo.example.org/seafhttp/upload-api/t",
        workspace_id = 42L,
        parent_path = "/asset/demo-uuid",
        img_relative_path = "images/2026-07",
        file_relative_path = "files/2026-07"
      )
    },
    .package = "harbouR"
  )
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      httr2::response(
        200L,
        headers = list(`Content-Type` = "application/json"),
        body = charToRaw(
          '[{"name": "r.pdf", "id": "b4356e3000d01a37", "size": 8}]'
        )
      )
    },
    .package = "httr2"
  )
  obj <- hb_upload_file(cl, src)
  expect_identical(obj$type, "file")
  expect_identical(obj$name, "r.pdf")
  expect_identical(
    obj$url,
    "https://demo.example.org/workspace/42/asset/demo-uuid/files/2026-07/r.pdf"
  )
  obj <- hb_upload_file(cl, src, relative_path = "files/Study 1 #2")
  expect_identical(obj$type, "file")
  expect_identical(
    obj$url,
    paste0(
      "https://demo.example.org/workspace/42/asset/demo-uuid/",
      "files/Study%201%20%232/r.pdf"
    )
  )
})
