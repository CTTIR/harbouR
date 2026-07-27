# Resolve a bundled asset URL to a local file

Attachment cells in an export point at `file://dtable-bundle/asset/...`.
When the base was read with `assets = "extract"`, this gives the path
the file was extracted to.

## Usage

``` r
hb_asset_path(x, url, ...)
```

## Arguments

- x:

  A `harbour_dtable` read with `assets = "extract"`.

- url:

  An asset URL taken from a `file` or `image` cell.

- ...:

  These dots are for future extensions and must be empty.

## Value

A single path, or `NA_character_` if the asset is not bundled.

## See also

Other dtable:
[`as_tibble.harbour_dtable()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_dtable.md),
[`hb_dtable()`](https://cttir.github.io/harbouR/reference/hb_dtable.md),
[`hb_read_csv()`](https://cttir.github.io/harbouR/reference/hb_read_csv.md),
[`hb_read_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_dtable.md),
[`hb_read_xlsx()`](https://cttir.github.io/harbouR/reference/hb_read_xlsx.md),
[`hb_validate_dtable()`](https://cttir.github.io/harbouR/reference/hb_validate_dtable.md),
[`hb_write_csv()`](https://cttir.github.io/harbouR/reference/hb_write_csv.md),
[`hb_write_dtable()`](https://cttir.github.io/harbouR/reference/hb_write_dtable.md),
[`hb_write_xlsx()`](https://cttir.github.io/harbouR/reference/hb_write_xlsx.md),
[`is_harbour_dtable()`](https://cttir.github.io/harbouR/reference/is_harbour_dtable.md),
[`length.harbour_dtable()`](https://cttir.github.io/harbouR/reference/length.harbour_dtable.md),
[`names.harbour_dtable()`](https://cttir.github.io/harbouR/reference/names.harbour_dtable.md),
[`print.harbour_dtable()`](https://cttir.github.io/harbouR/reference/print.harbour_dtable.md),
[`summary.harbour_dtable()`](https://cttir.github.io/harbouR/reference/summary.harbour_dtable.md)

## Examples

``` r
path <- system.file("extdata", "example.dtable", package = "harbouR")
base <- hb_read_dtable(path, assets = "extract")
hb_asset_path(base, "file://dtable-bundle/asset/files/readme.txt")
#> [1] NA
```
