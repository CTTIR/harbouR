# Conditions signalled by harbouR

Every error harbouR raises carries the class `harbour_error`, plus a
more specific subclass, so callers can react to *what* went wrong rather
than matching on message text.

## Condition classes

- `harbour_error_auth`:

  Credentials are missing, malformed, or were rejected by the server.
  Fields: none.

- `harbour_error_http`:

  The server returned a non-2xx status that has no more specific
  subclass. Fields: `status`, `url`, `body`.

- `harbour_error_not_found`:

  HTTP 404, or a named table, view or column that does not exist in the
  base. Fields: `status`, `url`, `body` for the HTTP case.

- `harbour_error_permission`:

  HTTP 403. The token is valid but is not allowed to do this. Fields:
  `status`, `url`, `body`.

- `harbour_error_rate_limit`:

  HTTP 429. Fields: `status`, `url`, `body`.

- `harbour_error_bad_argument`:

  An argument failed validation before any request was made. Fields:
  none.

- `harbour_error_unsupported`:

  The operation is not available - for example an auth mode that this
  endpoint does not accept.

- `harbour_error_column_collision`:

  A column in the data would collide with a reserved SeaTable field
  name.

All of them also inherit from `harbour_error` and from `rlang_error`.

## Examples

``` r
res <- tryCatch(
  hb_client(server = "https://example.org"),
  harbour_error_auth = function(cnd) "no credentials"
)
res
#> [1] "no credentials"
```
