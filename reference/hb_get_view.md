# Get a view's settings

SeaTable's API addresses one view by its name in the URL, and its server
reads a slash in that name as a path separator and a name of one or two
dots as a folder. Such a view is looked up in the table's list of views
instead.

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
[`hb_list_views()`](https://cttir.github.io/harbouR/reference/hb_list_views.md),
[`hb_update_view()`](https://cttir.github.io/harbouR/reference/hb_update_view.md)

## Examples

``` r
if (FALSE) { # \dontrun{
client <- hb_client()
hb_get_view(client, "Samples", "Default")
} # }
```
