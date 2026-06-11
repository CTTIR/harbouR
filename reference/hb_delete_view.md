# Delete a view

Delete a view

## Usage

``` r
hb_delete_view(client, table, view, call = rlang::caller_env())
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

Invisibly returns the client.

## See also

Other views:
[`hb_create_view()`](https://cttir.github.io/harbouR/reference/hb_create_view.md),
[`hb_get_view()`](https://cttir.github.io/harbouR/reference/hb_get_view.md),
[`hb_list_views()`](https://cttir.github.io/harbouR/reference/hb_list_views.md),
[`hb_update_view()`](https://cttir.github.io/harbouR/reference/hb_update_view.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_delete_view(client, "Samples", "Old")
}
```
