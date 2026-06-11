# Offline example metadata

A small, hand-crafted SeaTable base used to power offline examples,
tests, the column-types vignette and the Shiny demo mode. The shape of
the returned object matches what the SeaTable metadata endpoint would
yield.

## Usage

``` r
hb_example_metadata()
```

## Value

A `harbour_metadata` object describing a tiny base with two tables:
`Samples` and `Patients`.

## See also

Other example data:
[`hb_example_rows()`](https://cttir.github.io/harbouR/reference/hb_example_rows.md)

## Examples

``` r
meta <- hb_example_metadata()
tibble::as_tibble(meta)
#> # A tibble: 2 × 4
#>   name     n_rows n_columns n_views
#>   <chr>     <int>     <int>   <int>
#> 1 Samples       0         7       1
#> 2 Patients      0         4       1
```
