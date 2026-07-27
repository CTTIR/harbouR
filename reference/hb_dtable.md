# Build a `.dtable` base from data frames

Creates a `harbour_dtable` from scratch, so a set of R data frames can
be written out as a SeaTable base and imported.

## Usage

``` r
hb_dtable(..., base_name = "harbouR base", collaborators = NULL)
```

## Arguments

- ...:

  Named data frames, one per table.

- base_name:

  Name recorded for the base.

- collaborators:

  Optional list of collaborator records.

## Value

A `harbour_dtable`.

## Details

Column types are inferred: `character` becomes `text`, `numeric`
`number`, `logical` `checkbox`, `Date` and `POSIXct` `date`, `factor`
`single-select` with its levels as options, and list-columns
`multiple-select`.

## See also

Other dtable:
[`as_tibble.harbour_dtable()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_dtable.md),
[`hb_asset_path()`](https://cttir.github.io/harbouR/reference/hb_asset_path.md),
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
base <- hb_dtable(
  Samples = data.frame(Name = c("a", "b"), Value = c(1.5, 2.5)),
  base_name = "My base"
)
base
#> 
#> ── <harbour_dtable> ────────────────────────────────────────────────────────────
#> • base : "My base"
#> • tables : 1
#> • rows : 2
#> • assets : 0
#> 
#> - Samples (2 cols, 2 rows)

hb_read_table(base, "Samples")
#> # A tibble: 2 × 3
#>   Name  Value `_id`                 
#>   <chr> <dbl> <chr>                 
#> 1 a       1.5 Rf6-A--hQtiVKoYftEUIlQ
#> 2 b       2.5 _gmfdKEQQ7eVXoBFobKtQA
```
