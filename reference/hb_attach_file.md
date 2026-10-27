# Attach a file to a cell

Convenience: uploads `path` then writes it into the given file or image
column of the chosen row. A file column receives the file object; an
image column, which holds URLs, receives the image's URL.

## Usage

``` r
hb_attach_file(client, table, row_id, column, path, ...)
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

- ...:

  These dots are for future extensions and must be empty.

## Value

Invisibly returns the client.

## Details

The cell is **replaced**, not appended to: whatever it held before is no
longer referenced by the row, although the earlier upload stays in the
base's assets. To keep several attachments, read the cell, add the new
object from
[`hb_upload_file()`](https://cttir.github.io/harbouR/reference/hb_upload_file.md)
and write it back with
[`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md).

## See also

Other files:
[`hb_delete_asset()`](https://cttir.github.io/harbouR/reference/hb_delete_asset.md),
[`hb_download_file()`](https://cttir.github.io/harbouR/reference/hb_download_file.md),
[`hb_upload_file()`](https://cttir.github.io/harbouR/reference/hb_upload_file.md)

## Examples

``` r
if (FALSE) { # \dontrun{
client <- hb_client()
hb_attach_file(client, "Samples", "abc", "Reports", "report.pdf")
} # }
```
