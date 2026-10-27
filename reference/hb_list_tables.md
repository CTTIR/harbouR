# List the tables in a base

List the tables in a base

## Usage

``` r
hb_list_tables(x, ...)

# S3 method for class 'harbour_dtable'
hb_list_tables(x, ...)

# Default S3 method
hb_list_tables(x, ...)

# S3 method for class 'harbour_client'
hb_list_tables(x, ..., refresh = FALSE)
```

## Arguments

- x:

  A `harbour_client` connected to a base, or a `harbour_dtable` read
  from a local file.

- ...:

  These dots are for future extensions and must be empty.

- refresh:

  Logical; refetch metadata even if cached. Default `FALSE`.

## Value

A tibble with one row per table and columns `name` (chr), `n_columns`
(int) and `n_views` (int).

The server path stops there: the metadata endpoint carries no row
payloads, so there is no row count to report - use
[`hb_read_table()`](https://cttir.github.io/harbouR/reference/hb_read_table.md)
if you need one. The `.dtable` path additionally returns `n_rows` (int),
because in a file the rows are right there.

## See also

Other metadata:
[`as_tibble.harbour_metadata()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_metadata.md),
[`hb_column_types()`](https://cttir.github.io/harbouR/reference/hb_column_types.md),
[`hb_list_collaborators()`](https://cttir.github.io/harbouR/reference/hb_list_collaborators.md),
[`hb_metadata()`](https://cttir.github.io/harbouR/reference/hb_metadata.md),
[`is_harbour_metadata()`](https://cttir.github.io/harbouR/reference/is_harbour_metadata.md),
[`print.harbour_metadata()`](https://cttir.github.io/harbouR/reference/print.harbour_metadata.md),
[`summary.harbour_metadata()`](https://cttir.github.io/harbouR/reference/summary.harbour_metadata.md)

## Examples

``` r
# a .dtable file needs no server
path <- system.file("extdata", "example.dtable", package = "harbouR")
hb_list_tables(hb_read_dtable(path))
#> # A tibble: 2 × 4
#>   name      n_rows n_columns n_views
#>   <chr>      <int>     <int>   <int>
#> 1 Samples        2        27       1
#> 2 Reference      2         2       1

# a live base needs a SeaTable server and an API token
if (FALSE) { # \dontrun{
client <- hb_client()
hb_list_tables(client)
} # }
```
