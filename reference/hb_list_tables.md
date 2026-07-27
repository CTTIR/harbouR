# List the tables in a base

List the tables in a base

## Usage

``` r
# S3 method for class 'harbour_dtable'
hb_list_tables(x, ...)

# Default S3 method
hb_list_tables(x, ...)

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
(int) and `n_views` (int). The metadata endpoint carries no row
payloads, so there is no row count here; use
[`hb_read_table()`](https://cttir.github.io/harbouR/reference/hb_read_table.md)
if you need one.

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
if (FALSE) { # interactive()
client <- hb_client()
hb_list_tables(client)
}
```
