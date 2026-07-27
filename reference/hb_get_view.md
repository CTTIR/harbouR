# Get a view's settings

Get a view's settings

## Usage

``` r
hb_get_view(client, table, view, ...)
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- view:

  View name.

- ...:

  These dots are for future extensions and must be empty.

## Value

A one-row tibble with columns `name` (chr), `type` (chr), `is_default`
(lgl), `filters` (list), `sorts` (list) and `hidden_columns` (list of
chr).

## See also

Other views:
[`hb_create_view()`](https://cttir.github.io/harbouR/reference/hb_create_view.md),
[`hb_delete_view()`](https://cttir.github.io/harbouR/reference/hb_delete_view.md),
[`hb_list_views.harbour_dtable()`](https://cttir.github.io/harbouR/reference/hb_list_views.md),
[`hb_update_view()`](https://cttir.github.io/harbouR/reference/hb_update_view.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_get_view(client, "Samples", "Default")
}
```
