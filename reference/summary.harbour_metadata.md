# Summary of harbour metadata

Summary of harbour metadata

## Usage

``` r
# S3 method for class 'harbour_metadata'
summary(object, ...)
```

## Arguments

- object:

  A `harbour_metadata` object.

- ...:

  Unused.

## Value

A tibble with one row per column across all tables, suitable for
inspecting the SeaTable schema. Columns: `table` (chr), `column` (chr),
`type` (chr).

## See also

Other metadata:
[`as_tibble.harbour_metadata()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_metadata.md),
[`hb_column_types()`](https://cttir.github.io/harbouR/reference/hb_column_types.md),
[`hb_list_collaborators()`](https://cttir.github.io/harbouR/reference/hb_list_collaborators.md),
[`hb_list_tables()`](https://cttir.github.io/harbouR/reference/hb_list_tables.md),
[`hb_metadata()`](https://cttir.github.io/harbouR/reference/hb_metadata.md),
[`is_harbour_metadata()`](https://cttir.github.io/harbouR/reference/is_harbour_metadata.md),
[`print.harbour_metadata()`](https://cttir.github.io/harbouR/reference/print.harbour_metadata.md)
