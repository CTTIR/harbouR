# Update a view

Update a view

## Usage

``` r
hb_update_view(client, table, view, settings, ...)
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

- ...:

  These dots are for future extensions and must be empty.

## Value

Invisibly returns the client.

## See also

Other views:
[`hb_create_view()`](https://cttir.github.io/harbouR/reference/hb_create_view.md),
[`hb_delete_view()`](https://cttir.github.io/harbouR/reference/hb_delete_view.md),
[`hb_get_view()`](https://cttir.github.io/harbouR/reference/hb_get_view.md),
[`hb_list_views.harbour_dtable()`](https://cttir.github.io/harbouR/reference/hb_list_views.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_update_view(client, "Samples", "Active", list(filter_conjunction = "And"))
}
```
