# Read tables into a new base from CSV files

Builds a fresh `harbour_dtable` from CSV files, one table per file. This
is **not** the inverse of
[`hb_write_csv()`](https://cttir.github.io/harbouR/reference/hb_write_csv.md):
it produces a new base with new identifiers, and only text, number, date
and checkbox columns. Nothing that a CSV cannot carry is recovered.

## Usage

``` r
hb_read_csv(files, ..., base_name = "harbouR base")
```

## Arguments

- files:

  Paths to `.csv` files. Table names come from the file names unless
  `files` is named.

- ...:

  These dots are for future extensions and must be empty.

- base_name:

  Name recorded for the new base.

## Value

A `harbour_dtable`.

## See also

Other dtable:
[`as_tibble.harbour_dtable()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_dtable.md),
[`hb_asset_path()`](https://cttir.github.io/harbouR/reference/hb_asset_path.md),
[`hb_dtable()`](https://cttir.github.io/harbouR/reference/hb_dtable.md),
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
csv <- tempfile(fileext = ".csv")
utils::write.csv(data.frame(x = 1:2, y = c("a", "b")), csv,
                 row.names = FALSE)
hb_read_csv(c(Measurements = csv))
#> 
#> ── <harbour_dtable> ────────────────────────────────────────────────────────────
#> • base : "harbouR base"
#> • tables : 1
#> • rows : 2
#> • assets : 0
#> 
#> - Measurements (2 cols, 2 rows)
```
