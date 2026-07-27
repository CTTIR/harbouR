# Delete an asset

Delete an asset

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

## See also

Other files:
[`hb_attach_file()`](https://cttir.github.io/harbouR/reference/hb_attach_file.md),
[`hb_download_file()`](https://cttir.github.io/harbouR/reference/hb_download_file.md),
[`hb_upload_file()`](https://cttir.github.io/harbouR/reference/hb_upload_file.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_delete_asset(client, "https://server/path/to/file.pdf")
}
```
