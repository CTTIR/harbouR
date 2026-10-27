# Write a `harbour_dtable` back to a `.dtable` file

Produces a ZIP archive SeaTable can import. Round-tripping is lossless:
reading a file and writing it back yields a `content.json` that parses
to an identical structure, verified against a real 750 KB export. The
attachments go back in too when the file was read with
`assets = "extract"`.

## Usage

``` r
hb_write_dtable(x, path, ..., assets = TRUE, overwrite = TRUE)
```

## Arguments

- x:

  A `harbour_dtable`.

- path:

  Destination path.

- ...:

  These dots are for future extensions and must be empty.

- assets:

  Whether to repack the extracted asset tree, if there is one. Default
  `TRUE`.

- overwrite:

  Whether to replace an existing file at `path`. Default `TRUE`; set
  `FALSE` to refuse.

## Value

`x`, invisibly.

## Details

The archive is built in a temporary file beside `path` and moved into
place only once it is complete, so a failed write cannot destroy the
file it replaces - even when that is the file the base was read from.
Replacing a file gives it a new identity on disk, so any other hard link
to it keeps the old content. Where no new file can be made beside
`path`, or there is nothing at `path` to lose - an empty file such as
`/dev/null`, or a link to a file not made yet - the archive is written
straight into it. A file that cannot be replaced, because another
program holds it open or the folder lets files be written but not
removed, is written into once the archive is complete; that needs room
for a second copy, and should it fail, the complete archive is kept
beside `path` and the error says where. A symbolic link in the extracted
asset tree is left out, with a warning, rather than followed to wherever
it points.

## See also

[`hb_read_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_dtable.md)

Other dtable:
[`as_tibble.harbour_dtable()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_dtable.md),
[`hb_asset_path()`](https://cttir.github.io/harbouR/reference/hb_asset_path.md),
[`hb_dtable()`](https://cttir.github.io/harbouR/reference/hb_dtable.md),
[`hb_read_csv()`](https://cttir.github.io/harbouR/reference/hb_read_csv.md),
[`hb_read_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_dtable.md),
[`hb_read_xlsx()`](https://cttir.github.io/harbouR/reference/hb_read_xlsx.md),
[`hb_validate_dtable()`](https://cttir.github.io/harbouR/reference/hb_validate_dtable.md),
[`hb_write_csv()`](https://cttir.github.io/harbouR/reference/hb_write_csv.md),
[`hb_write_xlsx()`](https://cttir.github.io/harbouR/reference/hb_write_xlsx.md),
[`is_harbour_dtable()`](https://cttir.github.io/harbouR/reference/is_harbour_dtable.md),
[`length.harbour_dtable()`](https://cttir.github.io/harbouR/reference/length.harbour_dtable.md),
[`names.harbour_dtable()`](https://cttir.github.io/harbouR/reference/names.harbour_dtable.md),
[`print.harbour_dtable()`](https://cttir.github.io/harbouR/reference/print.harbour_dtable.md),
[`summary.harbour_dtable()`](https://cttir.github.io/harbouR/reference/summary.harbour_dtable.md)

## Examples

``` r
path <- system.file("extdata", "example.dtable", package = "harbouR")
# extract the assets, so the attachments are written back too
base <- hb_read_dtable(path, assets = "extract")

out <- tempfile(fileext = ".dtable")
hb_write_dtable(base, out)

# content.json round-trips exactly
identical(hb_read_dtable(out)$content, base$content)
#> [1] TRUE
```
