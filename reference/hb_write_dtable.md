# Write a `harbour_dtable` back to a `.dtable` file

Produces a ZIP archive SeaTable can import. Round-tripping is lossless:
reading a file and writing it back yields a `content.json` that parses
to an identical structure, verified against a real 750 KB export.

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

  Refuse to clobber an existing file unless `TRUE`.

## Value

`x`, invisibly.

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
base <- hb_read_dtable(path)
#> Error in hb_read_dtable(path): `path` must be a single non-empty string.
#> ✖ You supplied "".

out <- tempfile(fileext = ".dtable")
hb_write_dtable(base, out)
#> Error: object 'base' not found

# the round trip preserves the base exactly
identical(hb_read_dtable(out)$content, base$content)
#> Error in hb_read_dtable(out): File not found.
#> ✖ /tmp/RtmpIcaxd9/file18a1d078ae4.dtable
```
