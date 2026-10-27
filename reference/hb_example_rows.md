# Offline example rows

Returns a tibble of example rows for one of the tables provided by
[`hb_example_metadata()`](https://cttir.github.io/harbouR/reference/hb_example_metadata.md),
so tests and the column-types vignette can demonstrate the coercion
layer without a SeaTable server.

## Usage

``` r
hb_example_rows(table = c("Samples", "Patients"))
```

## Arguments

- table:

  One of `"Samples"` or `"Patients"`.

## Value

A tibble with one row per example record: a column for each column of
`table` in
[`hb_example_metadata()`](https://cttir.github.io/harbouR/reference/hb_example_metadata.md),
and the row id `_id`. Multiple-select, collaborator and file columns are
list-columns, and dates are date-times in UTC.

## Details

Between them the two tables cover the common column types - text,
number, single-select, multiple-select, date, collaborator, file and
checkbox - so the rows include list-columns and date-times. For the
fuller set, read the bundled `.dtable` file with
[`hb_read_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_dtable.md):
it carries a column of nearly every type, at
`system.file("extdata", "example.dtable", package = "harbouR")`.

## See also

Other example data:
[`hb_example_metadata()`](https://cttir.github.io/harbouR/reference/hb_example_metadata.md)

## Examples

``` r
hb_example_rows("Samples")
#> # A tibble: 3 × 8
#>   Name  Concentration Status  Tags   Collected           Collaborators Reports
#>   <chr>         <dbl> <chr>   <list> <dttm>              <list>        <list> 
#> 1 S-001          12.4 draft   <chr>  2026-04-01 09:00:00 <chr [1]>     <list> 
#> 2 S-002           8.1 ready   <chr>  2026-04-03 12:30:00 <chr [2]>     <list> 
#> 3 S-003          21   shipped <chr>  2026-04-05 16:15:00 <chr [0]>     <list> 
#> # ℹ 1 more variable: `_id` <chr>
```
