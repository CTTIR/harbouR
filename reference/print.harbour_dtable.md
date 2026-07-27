# Print a harbour dtable

Print a harbour dtable

## Usage

``` r
# S3 method for class 'harbour_dtable'
print(x, ...)

# S3 method for class 'harbour_dtable'
format(x, ...)
```

## Arguments

- x:

  A `harbour_dtable`.

- ...:

  Unused.

## Value

Invisibly returns `x`.

A character vector, one element per table.

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
[`summary.harbour_dtable()`](https://cttir.github.io/harbouR/reference/summary.harbour_dtable.md)

## Examples

``` r
print(hb_dtable(Samples = data.frame(x = 1)))
#> 
#> ── <harbour_dtable> ────────────────────────────────────────────────────────────
#> • base : "harbouR base"
#> • tables : 1
#> • rows : 1
#> • assets : 0
#> 
#> - Samples (1 cols, 1 rows)
```
