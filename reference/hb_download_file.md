# Download an asset

Download an asset

## Usage

``` r
hb_download_file(
  client,
  url,
  dest,
  overwrite = FALSE,
  call = rlang::caller_env()
)
```

## Arguments

- client:

  A `harbour_client`.

- url:

  Asset URL (as returned by SeaTable in a file/image cell).

- dest:

  Destination path. Parent directories are created if needed.

- overwrite:

  Refuse to clobber an existing file unless `TRUE`.

- call:

  Internal: error-propagation env.

## Value

Invisibly returns `dest`.

## See also

Other files:
[`hb_attach_file()`](https://cttir.github.io/harbouR/reference/hb_attach_file.md),
[`hb_delete_asset()`](https://cttir.github.io/harbouR/reference/hb_delete_asset.md),
[`hb_upload_file()`](https://cttir.github.io/harbouR/reference/hb_upload_file.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_download_file(client, "https://...", tempfile())
}
```
