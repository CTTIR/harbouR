# Check that the client's credentials are accepted

Exchanges the client's credentials for a token, which is the cheapest
way to find out whether they work. For an API-token client this fetches
a base token, and so also confirms the token is valid *for that base*;
for a username/password client it fetches an account token.

## Usage

``` r
hb_check_credentials(client, ...)
```

## Arguments

- client:

  A `harbour_client`.

- ...:

  These dots are for future extensions and must be empty.

## Value

The `client`, invisibly. Errors with a `harbour_error_auth` condition if
the credentials are rejected.

## Details

Unlike
[`hb_ping()`](https://cttir.github.io/harbouR/reference/hb_ping.md),
which only proves the server is up, this proves the credentials are
usable.

## See also

[`hb_ping()`](https://cttir.github.io/harbouR/reference/hb_ping.md)

Other client:
[`hb_client()`](https://cttir.github.io/harbouR/reference/hb_client.md),
[`hb_ping()`](https://cttir.github.io/harbouR/reference/hb_ping.md),
[`hb_server_info()`](https://cttir.github.io/harbouR/reference/hb_server_info.md),
[`is_harbour_client()`](https://cttir.github.io/harbouR/reference/is_harbour_client.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_check_credentials(client)
}
```
