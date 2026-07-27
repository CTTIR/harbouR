# Shared httr2 response / condition fixtures for the request-engine tests.
# Kept in a helper so any test file can build a fake response.

make_resp <- function(status = 200L, body = NULL) {
  structure(list(status_code = status, body = body),
            class = "httr2_response")
}

make_http_cond <- function(status, body_json = "{}") {
  resp <- structure(
    list(status_code = status, headers = list(),
         body = charToRaw(body_json)),
    class = "httr2_response")
  structure(list(message = "x", resp = resp),
            class = c(paste0("httr2_http_", status), "httr2_http",
                      "rlang_error", "error", "condition"))
}
