# Export a base to CSV files

Writes one `.csv` per table into `dir`. Subject to the same losses as
[`hb_write_xlsx()`](https://cttir.github.io/harbouR/reference/hb_write_xlsx.md);
see its documentation.

## Usage

``` r
hb_write_csv(x, dir, ..., tables = NULL)
```

## Arguments

- x:

  A `harbour_dtable`, or a `harbour_client` to read from first.

- dir:

  Destination directory. Created if it does not exist.

- ...:

  These dots are for future extensions and must be empty.

- tables:

  Table names to export. Default: all of them.

## Value

A character vector of the files written, invisibly.

## See also

[`hb_write_xlsx()`](https://cttir.github.io/harbouR/reference/hb_write_xlsx.md),
[`hb_write_dtable()`](https://cttir.github.io/harbouR/reference/hb_write_dtable.md)

Other dtable:
[`as_tibble.harbour_dtable()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_dtable.md),
[`hb_asset_path()`](https://cttir.github.io/harbouR/reference/hb_asset_path.md),
[`hb_dtable()`](https://cttir.github.io/harbouR/reference/hb_dtable.md),
[`hb_read_csv()`](https://cttir.github.io/harbouR/reference/hb_read_csv.md),
[`hb_read_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_dtable.md),
[`hb_read_xlsx()`](https://cttir.github.io/harbouR/reference/hb_read_xlsx.md),
[`hb_validate_dtable()`](https://cttir.github.io/harbouR/reference/hb_validate_dtable.md),
[`hb_write_dtable()`](https://cttir.github.io/harbouR/reference/hb_write_dtable.md),
[`hb_write_xlsx()`](https://cttir.github.io/harbouR/reference/hb_write_xlsx.md),
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
dir <- tempfile()
hb_write_csv(base, dir)
#> ! 7 columns were flattened to text.
#> • Samples$Tags, Samples$Collaborators, Samples$Photos, Samples$Reports,
#>   Samples$Where, Samples$Action, and Samples$Signature
#> ℹ A spreadsheet cell holds one value. Use `hb_write_dtable()` to keep the
#>   structure.
list.files(dir)
#> [1] "Reference.csv" "Samples.csv"  
```
