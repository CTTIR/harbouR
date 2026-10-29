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

  URL of the SeaTable server, e.g. `"https://seatable.example.org"`.
  Defaults to the `SEATABLE_SERVER` environment variable.

- api_token:

  Long-lived per-base API token. Defaults to the `SEATABLE_API_TOKEN`
  env var, which is not read when `username` or `password` is given.
  Mutually exclusive with `username`/`password`.

- ...:

  These dots are for future extensions and must be empty.

- username, password:

  Account credentials. Used to acquire an account token. Mutually
  exclusive with `api_token`.

- base_uuid:

  Optional base UUID hint; usually discovered from the base-token
  exchange.

- workspace_id, base_name:

  Which base to work on. Required for a `username`/`password` client,
  because an account token is scoped to the user rather than to a base:
  `workspace_id` is a positive whole number, or a string of its digits,
  and `base_name` a string. Ignored when `api_token` is used, since an
  API token names its base implicitly.

- timeout:

  Per-request timeout in seconds, a positive number of at most 2147483,
  or `Inf` for no limit. Default `30`. An upload or a download is not
  cut off after that long: it is limited to that long connecting, and a
  download to that long without moving data.

- x:

  A `harbour_client`.

## Value

A `harbour_client` object.

[`print()`](https://rdrr.io/r/base/print.html) returns `x`, invisibly.

[`format()`](https://rdrr.io/r/base/format.html) returns a character
vector, one element per field.

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
# creating a client does not contact the server
client <- hb_client(
  server = "https://seatable.example.org",
  api_token = "your-api-token"
)
client
#> 
#> ── <harbour_client> ────────────────────────────────────────────────────────────
#> • server : https://seatable.example.org
#> • auth : api_token
#> • token : your...oken
#> • base : <not yet fetched>
#> • base uuid: <unknown>
#> • expires : <not yet fetched>

# a live base needs a SeaTable server and an API token
if (FALSE) { # \dontrun{
client <- hb_client(
  server = Sys.getenv("SEATABLE_SERVER"),
  api_token = Sys.getenv("SEATABLE_API_TOKEN")
)
print(client)
} # }
```
