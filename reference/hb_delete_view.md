# Delete a view

SeaTable's API addresses one view by its name in the URL, and its server
reads a slash in that name as a path separator and a name of one or two
dots as a folder. Such a view cannot be deleted through the API, and
harbouR says so before sending anything: rename it in SeaTable first.

## Usage

``` r
hb_delete_view(client, table, view, ...)
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

Invisibly returns the client.

## See also

Other views:
[`hb_create_view()`](https://cttir.github.io/harbouR/reference/hb_create_view.md),
[`hb_get_view()`](https://cttir.github.io/harbouR/reference/hb_get_view.md),
[`hb_list_views()`](https://cttir.github.io/harbouR/reference/hb_list_views.md),
[`hb_update_view()`](https://cttir.github.io/harbouR/reference/hb_update_view.md)

## Examples

``` r
if (FALSE) { # \dontrun{
client <- hb_client()
hb_delete_view(client, "Samples", "Old")
} # }
```
