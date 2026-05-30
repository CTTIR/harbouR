# Upload a file to SeaTable

Uploads `path` to the active base and returns the SeaTable file object
(a named list with `name`, `size`, `type` and `url`) ready to be written
into a `file`-typed cell via
[`hb_update_rows()`](https://r-heller.github.io/harbouR/reference/hb_update_rows.md)
or
[`hb_attach_file()`](https://r-heller.github.io/harbouR/reference/hb_attach_file.md).

## Usage

``` r
hb_upload_file(
  client,
  path,
  relative_path = "files",
  call = rlang::caller_env()
)
```

## Arguments

- client:

  A `harbour_client`.

- path:

  Local file path. Must exist.

- relative_path:

  Optional path on the SeaTable side; defaults to `"files"`.

- call:

  Internal: error-propagation env.

## Value

A named list describing the uploaded asset.

## See also

Other files:
[`hb_attach_file()`](https://r-heller.github.io/harbouR/reference/hb_attach_file.md),
[`hb_delete_asset()`](https://r-heller.github.io/harbouR/reference/hb_delete_asset.md),
[`hb_download_file()`](https://r-heller.github.io/harbouR/reference/hb_download_file.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_upload_file(client, "report.pdf")
}
```
