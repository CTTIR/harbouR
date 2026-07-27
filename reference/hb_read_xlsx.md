# Read tables into a new base from an Excel workbook

One table per worksheet. Like
[`hb_read_csv()`](https://cttir.github.io/harbouR/reference/hb_read_csv.md),
this produces a *new* base rather than restoring one.

## Usage

``` r
hb_read_xlsx(path, ..., sheets = NULL, base_name = "harbouR base")
```

## Arguments

- path:

  Path to an `.xlsx` file.

- ...:

  These dots are for future extensions and must be empty.

- sheets:

  Worksheet names to read. Default: all of them.

- base_name:

  Name recorded for the new base.

## Value

A `harbour_dtable`.

## See also

Other dtable:
[`as_tibble.harbour_dtable()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_dtable.md),
[`hb_asset_path()`](https://cttir.github.io/harbouR/reference/hb_asset_path.md),
[`hb_dtable()`](https://cttir.github.io/harbouR/reference/hb_dtable.md),
[`hb_read_csv()`](https://cttir.github.io/harbouR/reference/hb_read_csv.md),
[`hb_read_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_dtable.md),
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
path <- tempfile(fileext = ".xlsx")
writexl::write_xlsx(list(Samples = data.frame(x = 1:2)), path)
hb_read_xlsx(path)
#> 
#> ── <harbour_dtable> ────────────────────────────────────────────────────────────
#> • base : "harbouR base"
#> • tables : 1
#> • rows : 2
#> • assets : 0
#> 
#> - Samples (1 cols, 2 rows)
```
