mock_client <- function(server = "https://demo.example.org",
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
#
# The mock is registered against `.env` - by default the calling test_that()
# frame - so it stays in force for the whole test rather than being unwound
# the instant this helper returns.
with_mocked_request <- function(code, response = list(), recorder = NULL,
                                .env = rlang::caller_env()) {
  rec <- recorder %||% new_request_recorder(response)
  fake <- function(client, path, service = "gateway", auth = "base",
                   method = "GET", query = NULL, body = NULL,
                   call = NULL) {
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
  testthat::local_mocked_bindings(
    .hb_request = fake,
    .package = "harbouR",
    .env = .env
  )
  force(code)
  rec
}

# A columns/ response carrying a select column with known option ids, for
# the tests that exercise option lookup.
select_column_response <- function() {
  list(columns = list(
    list(
      name = "Status", type = "single-select", key = "k3",
      data = list(options = list(
        list(id = "opt-draft", name = "draft", color = "#aaa"),
        list(id = "opt-done", name = "Done", color = "#bbb")
      ))
    )
  ))
}
