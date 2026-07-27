# Check that a SeaTable server is reachable

Issues a lightweight, unauthenticated request against the server's ping
endpoint. This tests *connectivity only* - use
[`hb_check_credentials()`](https://cttir.github.io/harbouR/reference/hb_check_credentials.md)
to test whether the client's credentials are accepted.

## Usage

``` r
hb_ping(client, ...)
```

## Arguments

- client:

  A `harbour_client`.

- ...:

  These dots are for future extensions and must be empty.

## Value

The `client`, invisibly. Errors if the server is unreachable.

## Details

Returns the client invisibly, so it composes:
`client |> hb_ping() |> hb_read_table("Samples")`.

## See also

[`hb_check_credentials()`](https://cttir.github.io/harbouR/reference/hb_check_credentials.md)

Other client:
[`hb_check_credentials()`](https://cttir.github.io/harbouR/reference/hb_check_credentials.md),
[`hb_client()`](https://cttir.github.io/harbouR/reference/hb_client.md),
[`hb_server_info()`](https://cttir.github.io/harbouR/reference/hb_server_info.md),
[`is_harbour_client()`](https://cttir.github.io/harbouR/reference/is_harbour_client.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_ping(client)
}
```
