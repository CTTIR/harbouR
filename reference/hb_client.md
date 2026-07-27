# Create a SeaTable client

Builds a `harbour_client` object that holds the server URL, the user's
credentials and a lazily-fetched, transparently-refreshed base token.
The client is environment-backed, so internal token refreshes mutate
cached state in place without reassigning your variable.

## Usage

``` r
hb_client(
  server = Sys.getenv("SEATABLE_SERVER"),
  api_token = Sys.getenv("SEATABLE_API_TOKEN"),
  ...,
  username = NULL,
  password = NULL,
  base_uuid = NULL,
  workspace_id = NULL,
  base_name = NULL,
  timeout = 30
)

# S3 method for class 'harbour_client'
print(x, ...)

# S3 method for class 'harbour_client'
format(x, ...)
```

## Arguments

- server:

  SeaTable server URL, e.g. `"https://cloud.seatable.io"`. Defaults to
  the `SEATABLE_SERVER` env var.

- api_token:

  Long-lived per-base API token. Defaults to the `SEATABLE_API_TOKEN`
  env var. Mutually exclusive with `username`/`password`.

- ...:

  Unused.

- username, password:

  Account credentials. Used to acquire an account token. Mutually
  exclusive with `api_token`.

- base_uuid:

  Optional base UUID hint; usually discovered from the base-token
  exchange.

- workspace_id, base_name:

  Which base to work on. Required for a `username`/`password` client,
  because an account token is scoped to the user rather than to a base.
  Ignored when `api_token` is used, since an API token names its base
  implicitly.

- timeout:

  Per-request timeout in seconds. Default `30`.

- x:

  A `harbour_client`.

## Value

A `harbour_client` object.

## Details

SeaTable uses a three-token model. `hb_client()` accepts either an **API
token** (per-base, long-lived, generated in the SeaTable UI) or
**username + password** (which yields an account token). In-base calls
transparently exchange these for a short-lived **base token**.

Defaults for `server` and `api_token` are read from the environment
variables `SEATABLE_SERVER` and `SEATABLE_API_TOKEN`.

## See also

Other client:
[`hb_check_credentials()`](https://cttir.github.io/harbouR/reference/hb_check_credentials.md),
[`hb_ping()`](https://cttir.github.io/harbouR/reference/hb_ping.md),
[`hb_server_info()`](https://cttir.github.io/harbouR/reference/hb_server_info.md),
[`is_harbour_client()`](https://cttir.github.io/harbouR/reference/is_harbour_client.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client(
  server = "https://cloud.seatable.io",
  api_token = Sys.getenv("SEATABLE_API_TOKEN")
)
print(client)
}
```
