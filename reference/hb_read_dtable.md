# Read a SeaTable `.dtable` file

Opens a `.dtable` export and returns a `harbour_dtable` object. The same
verbs that work against a live base work against it -
[`hb_list_tables()`](https://cttir.github.io/harbouR/reference/hb_list_tables.md),
[`hb_read_table()`](https://cttir.github.io/harbouR/reference/hb_read_table.md),
[`hb_list_columns()`](https://cttir.github.io/harbouR/reference/hb_list_columns.md) -
so an analysis can be written once and run either way.

## Usage

``` r
hb_read_dtable(path, ..., assets = c("none", "extract"), assets_dir = NULL)
```

## Arguments

- path:

  Path to a `.dtable` file.

- ...:

  These dots are for future extensions and must be empty.

- assets:

  Whether to extract the bundled `asset/` tree. `"none"`, the default,
  reads only `content.json`. `"extract"` unpacks the assets so
  [`hb_asset_path()`](https://cttir.github.io/harbouR/reference/hb_asset_path.md)
  can resolve attachment URLs to local files.

- assets_dir:

  Where to extract assets to. Defaults to a session temporary directory.

## Value

A `harbour_dtable`: a list with components `content` (the parsed tree),
`path`, `assets` (a tibble of bundled files), `assets_dir` and
`base_name`. Note that [`names()`](https://rdrr.io/r/base/names.html) on
a `harbour_dtable` gives its *table* names, not these components - reach
them with `$` or [`unclass()`](https://rdrr.io/r/base/class.html).

## Details

A `.dtable` is a ZIP archive containing `content.json`, the complete
base, and optionally an `asset/` tree of uploaded files and images.

The parsed JSON is kept **verbatim**. Real exports carry fields no
client would think to model - one column in the reference file holds a
serialised React element - and future SeaTable releases will add more.
Keeping the tree untouched is what makes
[`hb_write_dtable()`](https://cttir.github.io/harbouR/reference/hb_write_dtable.md)
lossless; rebuilding it from a typed intermediate would quietly drop
whatever harbouR did not know about.

## See also

[`hb_write_dtable()`](https://cttir.github.io/harbouR/reference/hb_write_dtable.md),
[`hb_dtable()`](https://cttir.github.io/harbouR/reference/hb_dtable.md)

Other dtable:
[`as_tibble.harbour_dtable()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_dtable.md),
[`hb_asset_path()`](https://cttir.github.io/harbouR/reference/hb_asset_path.md),
[`hb_dtable()`](https://cttir.github.io/harbouR/reference/hb_dtable.md),
[`hb_read_csv()`](https://cttir.github.io/harbouR/reference/hb_read_csv.md),
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
path <- system.file("extdata", "example.dtable", package = "harbouR")
base <- hb_read_dtable(path)
base
#> 
#> ── <harbour_dtable> ────────────────────────────────────────────────────────────
#> • base : "example"
#> • tables : 2
#> • rows : 4
#> • assets : 7
#> 
#> - Samples (27 cols, 2 rows)
#> - Reference (2 cols, 2 rows)

hb_list_tables(base)
#> # A tibble: 2 × 4
#>   name      n_rows n_columns n_views
#>   <chr>      <int>     <int>   <int>
#> 1 Samples        2        27       1
#> 2 Reference      2         2       1
hb_read_table(base, "Samples")
#> # A tibble: 2 × 28
#>   Name  Notes           Concentration Share  Cost Preis Runtime Rating Consented
#>   <chr> <chr>                   <dbl> <dbl> <dbl> <dbl>   <dbl>  <int> <lgl>    
#> 1 S-001 A plain **mark…      0.000587  0.42  20.0  17.5    3661      4 TRUE     
#> 2 S-002 Rendered elsew…      8.1      NA     NA    NA        NA     NA FALSE    
#> # ℹ 19 more variables: Collected <dttm>, Status <chr>, Tags <list>,
#> #   Collaborators <list>, Photos <list>, Reports <list>, Where <list>,
#> #   Homepage <chr>, Contact <chr>, `Temperatur (°C)` <dbl>, Doubled <chr>,
#> #   Ref <chr>, `Created by` <chr>, `Changed by` <chr>, Created <dttm>,
#> #   Changed <dttm>, Action <list>, Signature <list>, `_id` <chr>
```
