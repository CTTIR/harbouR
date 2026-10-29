# Upload a file to SeaTable

Uploads `path` to the active base and returns the SeaTable file object
(a named list with `name`, `size`, `type` and `url`) ready to be written
into a `file`-typed cell via
[`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)
or
[`hb_attach_file()`](https://cttir.github.io/harbouR/reference/hb_attach_file.md).

## Usage

``` r
hb_upload_file(client, path, ..., relative_path = "files")
```

## Arguments

- client:

  A `harbour_client`.

- path:

  Local file path. Must exist.

- ...:

  These dots are for future extensions and must be empty.

- relative_path:

  Folder under the base's asset root. The default, `"files"`, stands for
  the folder the upload link names: `files/<YYYY-MM>` for the current
  month, or `images/<YYYY-MM>` when `path` has an image extension
  (`.png`, `.jpg`, `.jpeg`, `.gif`, `.bmp`, `.webp` or `.svg`). Passing
  `"files"` yourself does the same. Any other value is used as given,
  but may not climb out of the asset root with `..`.

## Value

A named list describing the uploaded asset.

## Details

SeaTable's file endpoints authenticate with the base's API token, so
this needs a client created with `api_token`; a username/password client
gets a `harbour_error_auth` condition.

## See also

Other files:
[`hb_attach_file()`](https://cttir.github.io/harbouR/reference/hb_attach_file.md),
[`hb_delete_asset()`](https://cttir.github.io/harbouR/reference/hb_delete_asset.md),
[`hb_download_file()`](https://cttir.github.io/harbouR/reference/hb_download_file.md)

## Examples

``` r
if (FALSE) { # \dontrun{
client <- hb_client()
hb_upload_file(client, "report.pdf")
} # }
```
