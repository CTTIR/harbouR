local_mock_client <- function(server = "https://demo.example.org",
                              api_token = "TOKENSECRET1234") {
  cl <- new_harbour_client(
    server = server,
    api_token = api_token,
    username = NULL,
    password = NULL,
    base_uuid = "demo-uuid",
    timeout = 10
  )
  cl$.base_token <- "BASETOKENSECRET"
  cl$.dtable_server <- server
  cl$.dtable_db <- server
  cl$.base_name <- "harbouR demo base"
  cl$.metadata <- harbouR::hb_example_metadata()
  cl
}

# Record every .hb_request() call made by the code under test and return a
# canned body. Returns an environment whose `$calls` list grows with each
# invocation, so tests can assert on path / method / body without touching
# the network. Use inside withr::with_… / test_that via with_mocked_request().
new_request_recorder <- function(response = list()) {
  rec <- new.env(parent = emptyenv())
  rec$calls <- list()
  rec$response <- response
  rec
}

# Run `code` with .hb_request() replaced by a recorder. `response` is what the
# fake .hb_request returns (a body list, or a function of the call args).
with_mocked_request <- function(code, response = list(), recorder = NULL) {
  rec <- recorder %||% new_request_recorder(response)
  fake <- function(client, path, service = "dtable_server", auth = "base",
                   method = "GET", query = NULL, body = NULL) {
    rec$calls[[length(rec$calls) + 1L]] <- list(
      path = path, service = service, auth = auth,
      method = method, query = query, body = body
    )
    if (is.function(rec$response)) {
      rec$response(path = path, method = method, query = query, body = body)
    } else {
      rec$response
    }
  }
  testthat::local_mocked_bindings(.hb_request = fake, .package = "harbouR")
  force(code)
  rec
}

`%||%` <- function(x, y) if (is.null(x)) y else x
