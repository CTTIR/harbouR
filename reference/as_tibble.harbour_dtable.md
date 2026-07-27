# Coerce a dtable's table index to a tibble

Coerce a dtable's table index to a tibble

## Usage

``` r
# S3 method for class 'harbour_dtable'
as_tibble(x, ...)
```

## Arguments

- x:

  A `harbour_dtable`.

- ...:

  Unused.

## Value

A tibble with one row per table and columns `name` (chr), `n_rows`
(int), `n_columns` (int) and `n_views` (int). Unlike the server path,
the row count is real: the rows are in the file.

## See also

Other dtable:
[`hb_asset_path()`](https://cttir.github.io/harbouR/reference/hb_asset_path.md),
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
tibble::as_tibble(hb_dtable(Samples = data.frame(x = 1)))
#> # A tibble: 1 × 4
#>   name    n_rows n_columns n_views
#>   <chr>    <int>     <int>   <int>
#> 1 Samples      1         1       1
```
