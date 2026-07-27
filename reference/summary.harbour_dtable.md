# Summarise the schema of a dtable

Summarise the schema of a dtable

## Usage

``` r
# S3 method for class 'harbour_dtable'
summary(object, ...)
```

## Arguments

- object:

  A `harbour_dtable`.

- ...:

  Unused.

## Value

A tibble with one row per column across all tables: `table` (chr),
`column` (chr), `type` (chr), `key` (chr).

## See also

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
[`hb_write_xlsx()`](https://cttir.github.io/harbouR/reference/hb_write_xlsx.md),
[`is_harbour_dtable()`](https://cttir.github.io/harbouR/reference/is_harbour_dtable.md),
[`length.harbour_dtable()`](https://cttir.github.io/harbouR/reference/length.harbour_dtable.md),
[`names.harbour_dtable()`](https://cttir.github.io/harbouR/reference/names.harbour_dtable.md),
[`print.harbour_dtable()`](https://cttir.github.io/harbouR/reference/print.harbour_dtable.md)

## Examples

``` r
summary(hb_dtable(Samples = data.frame(x = 1, y = "a")))
#> # A tibble: 2 × 4
#>   table   column type   key  
#>   <chr>   <chr>  <chr>  <chr>
#> 1 Samples x      number 0000 
#> 2 Samples y      text   Gwfm 
```
