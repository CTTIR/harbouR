# Fetch base metadata

Retrieves the structural metadata for a SeaTable base — the list of
tables, their columns (with SeaTable types) and views. The result is
cached on the client.

## Usage

``` r
hb_metadata(client, ...)
```

## Arguments

- client:

  A `harbour_client`.

- ...:

  These dots are for future extensions and must be empty.

## Value

A `harbour_metadata` object — a list with components `base_name` (chr),
`tables` (list), `version` (chr).

## See also

Other metadata:
[`as_tibble.harbour_metadata()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_metadata.md),
[`hb_column_types()`](https://cttir.github.io/harbouR/reference/hb_column_types.md),
[`hb_list_collaborators()`](https://cttir.github.io/harbouR/reference/hb_list_collaborators.md),
[`hb_list_tables.harbour_dtable()`](https://cttir.github.io/harbouR/reference/hb_list_tables.md),
[`is_harbour_metadata()`](https://cttir.github.io/harbouR/reference/is_harbour_metadata.md),
[`print.harbour_metadata()`](https://cttir.github.io/harbouR/reference/print.harbour_metadata.md),
[`summary.harbour_metadata()`](https://cttir.github.io/harbouR/reference/summary.harbour_metadata.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
meta <- hb_metadata(client)
as_tibble(meta)
}
```
