# Coerce harbour metadata to a tibble

Coerce harbour metadata to a tibble

## Usage

``` r
# S3 method for class 'harbour_metadata'
as_tibble(x, ...)
```

## Arguments

- x:

  A `harbour_metadata` object.

- ...:

  Unused.

## Value

A tibble with one row per table; see
[`hb_list_tables()`](https://r-heller.github.io/harbouR/reference/hb_list_tables.md).

## See also

Other metadata:
[`hb_column_types()`](https://r-heller.github.io/harbouR/reference/hb_column_types.md),
[`hb_list_collaborators()`](https://r-heller.github.io/harbouR/reference/hb_list_collaborators.md),
[`hb_list_tables()`](https://r-heller.github.io/harbouR/reference/hb_list_tables.md),
[`hb_metadata()`](https://r-heller.github.io/harbouR/reference/hb_metadata.md),
[`is_harbour_metadata()`](https://r-heller.github.io/harbouR/reference/is_harbour_metadata.md),
[`print.harbour_metadata()`](https://r-heller.github.io/harbouR/reference/print.harbour_metadata.md),
[`summary.harbour_metadata()`](https://r-heller.github.io/harbouR/reference/summary.harbour_metadata.md)
