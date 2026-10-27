# Print method for harbour metadata

Print method for harbour metadata

## Usage

``` r
# S3 method for class 'harbour_metadata'
print(x, ...)

# S3 method for class 'harbour_metadata'
format(x, ...)
```

## Arguments

- x:

  A `harbour_metadata` object.

- ...:

  These dots are for future extensions and must be empty.

## Value

[`print()`](https://rdrr.io/r/base/print.html) returns `x`, invisibly.

[`format()`](https://rdrr.io/r/base/format.html) returns a character
vector, one element per table.

## See also

Other metadata:
[`as_tibble.harbour_metadata()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_metadata.md),
[`hb_column_types()`](https://cttir.github.io/harbouR/reference/hb_column_types.md),
[`hb_list_collaborators()`](https://cttir.github.io/harbouR/reference/hb_list_collaborators.md),
[`hb_list_tables()`](https://cttir.github.io/harbouR/reference/hb_list_tables.md),
[`hb_metadata()`](https://cttir.github.io/harbouR/reference/hb_metadata.md),
[`is_harbour_metadata()`](https://cttir.github.io/harbouR/reference/is_harbour_metadata.md),
[`summary.harbour_metadata()`](https://cttir.github.io/harbouR/reference/summary.harbour_metadata.md)

## Examples

``` r
meta <- hb_example_metadata()
print(meta)
#> 
#> ── <harbour_metadata> ──────────────────────────────────────────────────────────
#> • base : "harbouR demo base"
#> • tables : 2
#> 
#> - Samples (7 cols, 1 views)
#> - Patients (4 cols, 1 views)
format(meta)
#> [1] "Samples (7 cols, 1 views)"  "Patients (4 cols, 1 views)"
```
