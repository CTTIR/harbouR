# Create a view

Create a view

## Usage

``` r
hb_create_view(client, table, view, ..., settings = list())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- view:

  New view name.

- ...:

  These dots are for future extensions and must be empty.

- settings:

  Optional list of view settings.

## Value

Invisibly returns the client.

## See also

Other views:
[`hb_delete_view()`](https://cttir.github.io/harbouR/reference/hb_delete_view.md),
[`hb_get_view()`](https://cttir.github.io/harbouR/reference/hb_get_view.md),
[`hb_list_views.harbour_dtable()`](https://cttir.github.io/harbouR/reference/hb_list_views.md),
[`hb_update_view()`](https://cttir.github.io/harbouR/reference/hb_update_view.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_create_view(client, "Samples", "Active")
}
```
