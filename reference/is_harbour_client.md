# Test whether an object is a harbour client

Test whether an object is a harbour client

## Usage

``` r
is_harbour_client(x)
```

## Arguments

- x:

  Object to test.

## Value

A single `TRUE` or `FALSE`.

## See also

Other client:
[`hb_check_credentials()`](https://cttir.github.io/harbouR/reference/hb_check_credentials.md),
[`hb_client()`](https://cttir.github.io/harbouR/reference/hb_client.md),
[`hb_ping()`](https://cttir.github.io/harbouR/reference/hb_ping.md),
[`hb_server_info()`](https://cttir.github.io/harbouR/reference/hb_server_info.md)

## Examples

``` r
# creating a client does not contact the server
client <- hb_client(
  server = "https://seatable.example.org",
  api_token = "your-api-token"
)
is_harbour_client(client)
#> [1] TRUE
is_harbour_client(list())
#> [1] FALSE
```
