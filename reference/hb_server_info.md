# Server information

Returns the SeaTable server's reported version and basic info.

## Usage

``` r
hb_server_info(client, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- call:

  Internal: error-propagation env.

## Value

A one-row tibble with columns `server` (chr), `version` (chr) and
`edition` (chr) where reported.

## See also

Other client:
[`hb_client()`](https://cttir.github.io/harbouR/reference/hb_client.md),
[`hb_ping()`](https://cttir.github.io/harbouR/reference/hb_ping.md),
[`is_harbour_client()`](https://cttir.github.io/harbouR/reference/is_harbour_client.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_server_info(client)
}
```
