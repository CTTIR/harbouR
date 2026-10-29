# Conditions signalled by harbouR

Every error harbouR raises itself, and every HTTP or transport failure,
carries the class `harbour_error`, plus a more specific subclass, so
callers can react to *what* went wrong rather than matching on message
text. Errors from argument matching in rlang - a value that is not one
of an argument's choices, or an argument passed in `...` that the
function does not have - keep the classes rlang gives them.

## Condition classes

- `harbour_error_auth`:

  Credentials are missing, malformed, or were rejected by the server.
  Fields: `status`, `url` and `response_body` when the server refused
  them; none when the problem was caught before any request. The token
  exchanges refuse credentials with whatever status their endpoint
  uses - a wrong password is HTTP 400, an unknown API token HTTP 403 -
  and such an error carries `harbour_error_http` or
  `harbour_error_permission` as well.

- `harbour_error_http`:

  The server returned a non-2xx status that has no more specific
  subclass, or the request got no complete answer (status `NA`). Fields:
  `status`, `url` and `response_body` - the parsed JSON, or the text
  when the server did not send JSON. It is also raised for a redirect (a
  3xx status), which harbouR reports rather than follows, and for a
  reply that is not JSON whatever its status, a 2xx included;
  `response_body` then holds the start of its text. A request that got
  no answer - a refused connection, a DNS or TLS failure, a timeout, a
  dropped connection - also carries httr2's classes `httr2_failure` and
  `httr2_error`, and has no `response_body`. After a timeout or a
  dropped connection the server may already have applied a write, so a
  status of `NA` alone does not make sending the write again safe.

- `harbour_error_not_found`:

  HTTP 404, or a named table, view or column that does not exist in the
  base. Fields: `status`, `url`, `response_body` for the HTTP case.

- `harbour_error_permission`:

  HTTP 403. The token is not allowed to do this. Fields: `status`,
  `url`, `response_body`.

- `harbour_error_rate_limit`:

  HTTP 429. Fields: `status`, `url`, `response_body`.

- `harbour_error_bad_argument`:

  An argument failed validation before any request was made. Fields:
  none.

- `harbour_error_unsupported`:

  The operation is not available - for example an auth mode that this
  endpoint does not accept.

- `harbour_error_column_collision`:

  A column in the data would collide with a reserved SeaTable field
  name.

- `harbour_error_package_asset`:

  A packaged branding asset is missing from the installation. Field:
  `file`.

All of them also inherit from `harbour_error` and from `rlang_error`.

## Warning classes

The warnings a script may want to check for, or to silence, carry a
class of their own, and inherit from `rlang_warning`:

- `harbour_warning_unknown_column`:

  [`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md)
  was given columns the table does not have, and drops them.

- `harbour_warning_hidden_columns`:

  [`hb_read_table()`](https://cttir.github.io/harbouR/reference/hb_read_table.md)
  read through a view on a server, which leaves the columns the view
  hides out of its rows, so they are `NA`.

- `harbour_warning_view_filters`:

  [`hb_read_table()`](https://cttir.github.io/harbouR/reference/hb_read_table.md)
  read through a filtered view of a `.dtable` file that records no rows
  for it, so every row was returned.

- `harbour_warning_query_limit`:

  [`hb_query()`](https://cttir.github.io/harbouR/reference/hb_query.md)
  ran SQL without a `LIMIT` clause, so SeaTable returned at most 100
  rows.

- `harbour_warning_non_finite`:

  [`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md)
  or
  [`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)
  sent `Inf`, `-Inf` or `NaN`, which JSON cannot hold, as `null`. Field:
  `columns`.

- `harbour_warning_checkbox_value`:

  [`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md)
  or
  [`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)
  sent a checkbox string that
  [`as.logical()`](https://rdrr.io/r/base/logical.html) cannot read as
  `TRUE` or `FALSE` as `null`. Field: `columns`.

- `harbour_warning_asset_link`:

  [`hb_write_dtable()`](https://cttir.github.io/harbouR/reference/hb_write_dtable.md)
  left symbolic links in the asset tree out of the archive.

- `harbour_warning_dtable_tz`:

  [`hb_read_table()`](https://cttir.github.io/harbouR/reference/hb_read_table.md)
  read date-times from a `.dtable` that carry no time zone, as a
  server's export stores them, as UTC, because
  `options(harbouR.dtable_tz)` names none. Given once a session.

- `harbour_warning_json_keys`:

  [`hb_write_dtable()`](https://cttir.github.io/harbouR/reference/hb_write_dtable.md)
  met object keys that JSON cannot keep - empty, or repeated - so those
  values change on the way to disk.

- `harbour_warning_json_text`:

  [`hb_read_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_dtable.md)
  met a NUL character in `content.json`, which R cannot keep in a
  string.

- `harbour_warning_id_column`:

  [`hb_dtable()`](https://cttir.github.io/harbouR/reference/hb_dtable.md),
  [`hb_read_csv()`](https://cttir.github.io/harbouR/reference/hb_read_csv.md)
  or
  [`hb_read_xlsx()`](https://cttir.github.io/harbouR/reference/hb_read_xlsx.md)
  dropped a column named `_id` that held values other than SeaTable row
  ids.

## Examples

``` r
res <- tryCatch(
  hb_client(server = "https://example.org", api_token = NULL),
  harbour_error_auth = function(cnd) "no credentials"
)
res
#> [1] "no credentials"
```
