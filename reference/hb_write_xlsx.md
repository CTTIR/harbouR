# Export a base to an Excel workbook

Writes one worksheet per table. This is deliberately **one-way**: a
spreadsheet cell holds a single value, so several SeaTable column types
have no faithful representation.

## Usage

``` r
hb_write_xlsx(x, path, ..., tables = NULL)
```

## Arguments

- x:

  A `harbour_dtable`, or a `harbour_client` to read from first.

- path:

  Destination `.xlsx` path.

- ...:

  These dots are for future extensions and must be empty.

- tables:

  Table names to export. Default: all of them.

## Value

`path`, invisibly.

## What is lost

- `multiple-select`, `collaborator` and `image` cells are joined with
  `", "`.

- `file` cells are reduced to their file names.

- `link` and `link-formula` cells reference rows in other tables and are
  exported as their display values.

- `formula` columns export their computed value, not the formula.

- Views, filters, colours, column widths and every other piece of base
  configuration have no cell to live in.

harbouR reports which columns were flattened. To keep everything, write
a `.dtable` with
[`hb_write_dtable()`](https://cttir.github.io/harbouR/reference/hb_write_dtable.md)
instead.

## See also

[`hb_write_csv()`](https://cttir.github.io/harbouR/reference/hb_write_csv.md),
[`hb_write_dtable()`](https://cttir.github.io/harbouR/reference/hb_write_dtable.md)

Other dtable:
[`as_tibble.harbour_dtable()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_dtable.md),
[`hb_asset_path()`](https://cttir.github.io/harbouR/reference/hb_asset_path.md),
[`hb_dtable()`](https://cttir.github.io/harbouR/reference/hb_dtable.md),
[`hb_read_csv()`](https://cttir.github.io/harbouR/reference/hb_read_csv.md),
[`hb_read_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_dtable.md),
[`hb_read_xlsx()`](https://cttir.github.io/harbouR/reference/hb_read_xlsx.md),
[`hb_validate_dtable()`](https://cttir.github.io/harbouR/reference/hb_validate_dtable.md),
[`hb_write_csv()`](https://cttir.github.io/harbouR/reference/hb_write_csv.md),
[`hb_write_dtable()`](https://cttir.github.io/harbouR/reference/hb_write_dtable.md),
[`is_harbour_dtable()`](https://cttir.github.io/harbouR/reference/is_harbour_dtable.md),
[`length.harbour_dtable()`](https://cttir.github.io/harbouR/reference/length.harbour_dtable.md),
[`names.harbour_dtable()`](https://cttir.github.io/harbouR/reference/names.harbour_dtable.md),
[`print.harbour_dtable()`](https://cttir.github.io/harbouR/reference/print.harbour_dtable.md),
[`summary.harbour_dtable()`](https://cttir.github.io/harbouR/reference/summary.harbour_dtable.md)

## Examples

``` r
base <- hb_read_dtable(
  system.file("extdata", "example.dtable", package = "harbouR")
)
#> Error in hb_read_dtable(system.file("extdata", "example.dtable", package = "harbouR")): `path` must be a single non-empty string.
#> ✖ You supplied "".
out <- tempfile(fileext = ".xlsx")
hb_write_xlsx(base, out)
#> Error: object 'base' not found
```
