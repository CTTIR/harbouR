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
