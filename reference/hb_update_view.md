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

  Name of the view to update.

- settings:

  Named list of the fields to change: `name` to rename the view,
  `is_locked`, `filters`, `filter_conjunction`, `sorts`, `groupbys` or
  `hidden_columns`. Fields you leave out are unchanged. `hidden_columns`
  takes column keys - the `key` column of
  [`hb_list_columns()`](https://cttir.github.io/harbouR/reference/hb_list_columns.md) -
  not names.

- ...:

  These dots are for future extensions and must be empty.

## Value

Invisibly returns the client.

## See also

Other views:
[`hb_create_view()`](https://cttir.github.io/harbouR/reference/hb_create_view.md),
[`hb_delete_view()`](https://cttir.github.io/harbouR/reference/hb_delete_view.md),
[`hb_get_view()`](https://cttir.github.io/harbouR/reference/hb_get_view.md),
[`hb_list_views()`](https://cttir.github.io/harbouR/reference/hb_list_views.md)

## Examples

``` r
if (FALSE) { # \dontrun{
client <- hb_client()
hb_update_view(client, "Samples", "Active", list(filter_conjunction = "And"))
} # }
```
