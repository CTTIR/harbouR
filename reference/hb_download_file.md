# Download an asset

A URL in a file or image cell is not directly downloadable: the asset
sits behind SeaTable's login. harbouR recognises such a URL by its path,
`/workspace/<id>/asset/<base uuid>/...`, whether it is absolute or
relative to the server, and exchanges it, with the client's API token,
for a short-lived download link. The URL must name the client's server -
the host is compared ignoring case, the scheme and a default port - and
the client's base: an asset of another server or another base raises a
`harbour_error_bad_argument` condition instead of being fetched. A URL
that is not an asset URL is fetched as it is.

## Usage

``` r
hb_download_file(client, url, dest, ..., overwrite = FALSE)
```

## Arguments

- client:

  A `harbour_client`.

- url:

  Asset URL (as returned by SeaTable in a file/image cell).

- dest:

  Destination path. Parent directories are created if needed.

- ...:

  These dots are for future extensions and must be empty.

- overwrite:

  Refuse to clobber an existing file unless `TRUE`.

## Value

Invisibly returns `dest`.

## Details

Should SeaTable answer an asset download with its login page, the
download fails with a `harbour_error_http` condition rather than saving
the page in place of the file.

The file is written to a temporary name beside `dest` and moved into
place only once complete, so a failed download never leaves a partial
file and never destroys the file `overwrite = TRUE` would replace.

## See also

Other files:
[`hb_attach_file()`](https://cttir.github.io/harbouR/reference/hb_attach_file.md),
[`hb_delete_asset()`](https://cttir.github.io/harbouR/reference/hb_delete_asset.md),
[`hb_upload_file()`](https://cttir.github.io/harbouR/reference/hb_upload_file.md)

## Examples

``` r
if (FALSE) { # \dontrun{
client <- hb_client()
hb_download_file(client, "https://...", tempfile())
} # }
```
