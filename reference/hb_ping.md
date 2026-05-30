# Ping the SeaTable server

Issues a lightweight request against the server's ping endpoint to
verify connectivity and credentials. Returns `TRUE` on success and
errors informatively on failure.

## Usage

``` r
hb_ping(client, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- call:

  Internal: error-propagation env.

## Value

A single `TRUE` on success; errors otherwise.

## See also

Other client:
[`hb_client()`](https://r-heller.github.io/harbouR/reference/hb_client.md),
[`hb_server_info()`](https://r-heller.github.io/harbouR/reference/hb_server_info.md),
[`is_harbour_client()`](https://r-heller.github.io/harbouR/reference/is_harbour_client.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_ping(client)
}
```
