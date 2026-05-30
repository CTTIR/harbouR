# List the tables in a base

List the tables in a base

## Usage

``` r
hb_list_tables(client, refresh = FALSE, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- refresh:

  Logical; refetch metadata even if cached. Default `FALSE`.

- call:

  Internal: error-propagation env.

## Value

A tibble with one row per table and columns `name` (chr), `n_rows`
(int), `n_columns` (int), `n_views` (int).

## See also

Other metadata:
[`as_tibble.harbour_metadata()`](https://r-heller.github.io/harbouR/reference/as_tibble.harbour_metadata.md),
[`hb_column_types()`](https://r-heller.github.io/harbouR/reference/hb_column_types.md),
[`hb_list_collaborators()`](https://r-heller.github.io/harbouR/reference/hb_list_collaborators.md),
[`hb_metadata()`](https://r-heller.github.io/harbouR/reference/hb_metadata.md),
[`is_harbour_metadata()`](https://r-heller.github.io/harbouR/reference/is_harbour_metadata.md),
[`print.harbour_metadata()`](https://r-heller.github.io/harbouR/reference/print.harbour_metadata.md),
[`summary.harbour_metadata()`](https://r-heller.github.io/harbouR/reference/summary.harbour_metadata.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_list_tables(client)
}
```
