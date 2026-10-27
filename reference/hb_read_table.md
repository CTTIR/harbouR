# Read a table as a tibble

Reads all rows from `table` (optionally filtered by `view`) and returns
them as a typed tibble. Pagination is handled internally; the returned
tibble always has the table's columns in declared order plus an `_id`
column.

## Usage

``` r
hb_read_table(x, table, ...)

# S3 method for class 'harbour_dtable'
hb_read_table(x, table, ..., view = NULL, n_max = Inf, option_labels = TRUE)

# Default S3 method
hb_read_table(x, table, ...)

# S3 method for class 'harbour_client'
hb_read_table(x, table, ..., view = NULL, page_size = 1000L, n_max = Inf)
```

## Arguments

- x:

  A `harbour_client` connected to a base, or a `harbour_dtable` read
  from a local file.

- table:

  Name of the table.

- ...:

  These dots are for future extensions and must be empty.

- view:

  Optional view name. A server returns only the columns a view shows, so
  a read through a view gives `NA` for the columns it hides, and harbouR
  warns naming them. A `.dtable` read keeps their values.

- n_max:

  Maximum number of rows to return. `Inf`, the default, reads the whole
  table.

- option_labels:

  Translate select-option ids to their display names. On disk a select
  cell holds an option id; over the API it holds the name, so this is
  what makes a local read and a server read of the same column agree.
  Set `FALSE` to see the raw ids.

- page_size:

  Rows fetched per request. SeaTable caps this at 1000 and harbouR
  clamps it, warning if you asked for more.

## Value

A tibble with one row per SeaTable row and one column per SeaTable
column, plus `_id` (chr). A 0-row tibble is returned for an empty table.

## Views on a `.dtable` file

On a `harbour_dtable`, `view` restricts the rows only to the row ids the
file records for that view, kept in table order. The view's filters and
sorts are not applied. A view that records no rows returns the whole
table, with a warning of class `harbour_warning_view_filters` when the
view has filters that were therefore not applied.

## See also

Other rows:
[`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md),
[`hb_delete_rows()`](https://cttir.github.io/harbouR/reference/hb_delete_rows.md),
[`hb_get_row()`](https://cttir.github.io/harbouR/reference/hb_get_row.md),
[`hb_lock_rows()`](https://cttir.github.io/harbouR/reference/hb_lock_rows.md),
[`hb_query()`](https://cttir.github.io/harbouR/reference/hb_query.md),
[`hb_unlock_rows()`](https://cttir.github.io/harbouR/reference/hb_unlock_rows.md),
[`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)

## Examples

``` r
# a .dtable file needs no server
path <- system.file("extdata", "example.dtable", package = "harbouR")
base <- hb_read_dtable(path)
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
hb_read_table(base, "Samples", n_max = 1)
#> # A tibble: 1 × 28
#>   Name  Notes           Concentration Share  Cost Preis Runtime Rating Consented
#>   <chr> <chr>                   <dbl> <dbl> <dbl> <dbl>   <dbl>  <int> <lgl>    
#> 1 S-001 A plain **mark…      0.000587  0.42  20.0  17.5    3661      4 TRUE     
#> # ℹ 19 more variables: Collected <dttm>, Status <chr>, Tags <list>,
#> #   Collaborators <list>, Photos <list>, Reports <list>, Where <list>,
#> #   Homepage <chr>, Contact <chr>, `Temperatur (°C)` <dbl>, Doubled <chr>,
#> #   Ref <chr>, `Created by` <chr>, `Changed by` <chr>, Created <dttm>,
#> #   Changed <dttm>, Action <list>, Signature <list>, `_id` <chr>

# a live base needs a SeaTable server and an API token
if (FALSE) { # \dontrun{
client <- hb_client()
hb_read_table(client, "Samples")

# just the first 10 rows
hb_read_table(client, "Samples", n_max = 10)
} # }
```
