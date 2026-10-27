# Delete an asset

Removes a file or image from the base's assets. Like the other file
endpoints this authenticates with the API token. Cells that still point
at the asset are not changed.

## Usage

``` r
hb_delete_asset(client, url, ...)
```

## Arguments

- client:

  A `harbour_client`.

- url:

  Asset URL (as returned by SeaTable in a file/image cell).

- ...:

  These dots are for future extensions and must be empty.

## Value

Invisibly returns the client.

## Details

`url` is the URL from a file or image cell, absolute or relative to the
server, or a path below the base's asset root such as
`/files/2026-07/report.pdf`. The endpoint acts on the client's base
whatever the URL names, so a URL on another server, or an asset URL of
another base, raises a `harbour_error_bad_argument` condition rather
than deleting this base's file at the same path.

## See also

Other files:
[`hb_attach_file()`](https://cttir.github.io/harbouR/reference/hb_attach_file.md),
[`hb_download_file()`](https://cttir.github.io/harbouR/reference/hb_download_file.md),
[`hb_upload_file()`](https://cttir.github.io/harbouR/reference/hb_upload_file.md)

## Examples

``` r
if (FALSE) { # \dontrun{
client <- hb_client()
# A path below the asset root, or the URL from a file or image cell
hb_delete_asset(client, "/files/2026-07/report.pdf")
} # }
```
