# Attach a file to a cell

Convenience: uploads `path` then writes the resulting file object into
the given file/image column of the chosen row.

## Usage

``` r
hb_attach_file(client, table, row_id, column, path, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- row_id:

  Row ID.

- column:

  File or image column name.

- path:

  Local file path. Must exist.

- call:

  Internal: error-propagation env.

## Value

Invisibly returns the client.

## See also

Other files:
[`hb_delete_asset()`](https://cttir.github.io/harbouR/reference/hb_delete_asset.md),
[`hb_download_file()`](https://cttir.github.io/harbouR/reference/hb_download_file.md),
[`hb_upload_file()`](https://cttir.github.io/harbouR/reference/hb_upload_file.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_attach_file(client, "Samples", "abc", "Report", "report.pdf")
}
```
