# Get a view's settings

Get a view's settings

## Usage

``` r
hb_get_view(client, table, view, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- view:

  View name.

- call:

  Internal: error-propagation env.

## Value

A 1-row tibble with the view's name, type and filters/sorts as
list-columns.

## See also

Other views:
[`hb_create_view()`](https://r-heller.github.io/harbouR/reference/hb_create_view.md),
[`hb_delete_view()`](https://r-heller.github.io/harbouR/reference/hb_delete_view.md),
[`hb_list_views()`](https://r-heller.github.io/harbouR/reference/hb_list_views.md),
[`hb_update_view()`](https://r-heller.github.io/harbouR/reference/hb_update_view.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_get_view(client, "Samples", "Default")
}
```
