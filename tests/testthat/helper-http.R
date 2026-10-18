# Shared httr2 response / condition fixtures for the request-engine tests.
# Kept in a helper so any test file can build a fake response.

make_resp <- function(status = 200L, body = NULL) {
  structure(list(status_code = status, body = body),
            class = "httr2_response")
}

# A real httr2 response, with the JSON content type SeaTable sends. A
# hand-built structure without one cannot be parsed by resp_body_json(),
# which once hid the fact that every parsed error body crashed the error
# translator.
make_http_cond <- function(status, body_json = "{}") {
  resp <- httr2::response(
    status_code = status,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw(body_json)
  )
  structure(list(message = "x", resp = resp),
            class = c(paste0("httr2_http_", status), "httr2_http",
                      "rlang_error", "error", "condition"))
}
