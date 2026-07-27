# List collaborators of the active base

List collaborators of the active base

## Usage

``` r
hb_list_collaborators(client, ...)
```

## Arguments

- client:

  A `harbour_client`.

- ...:

  These dots are for future extensions and must be empty.

## Value

A tibble with columns `email` (chr), `name` (chr) and `contact_email`
(chr). Zero rows if none are reported.

## See also

Other metadata:
[`as_tibble.harbour_metadata()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_metadata.md),
[`hb_column_types()`](https://cttir.github.io/harbouR/reference/hb_column_types.md),
[`hb_list_tables.harbour_dtable()`](https://cttir.github.io/harbouR/reference/hb_list_tables.md),
[`hb_metadata()`](https://cttir.github.io/harbouR/reference/hb_metadata.md),
[`is_harbour_metadata()`](https://cttir.github.io/harbouR/reference/is_harbour_metadata.md),
[`print.harbour_metadata()`](https://cttir.github.io/harbouR/reference/print.harbour_metadata.md),
[`summary.harbour_metadata()`](https://cttir.github.io/harbouR/reference/summary.harbour_metadata.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_list_collaborators(client)
}
```
