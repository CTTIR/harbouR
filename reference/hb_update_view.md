# Update a view

Update a view

## Usage

``` r
hb_update_view(client, table, view, settings, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- view:

  New view name.

- settings:

  Optional list of view settings.

- call:

  Internal: error-propagation env.

## Value

Invisibly returns the client.

## See also

Other views:
[`hb_create_view()`](https://r-heller.github.io/harbouR/reference/hb_create_view.md),
[`hb_delete_view()`](https://r-heller.github.io/harbouR/reference/hb_delete_view.md),
[`hb_get_view()`](https://r-heller.github.io/harbouR/reference/hb_get_view.md),
[`hb_list_views()`](https://r-heller.github.io/harbouR/reference/hb_list_views.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_update_view(client, "Samples", "Active", list(filter_conjunction = "And"))
}
```
