# Add several columns at once

Add several columns at once

## Usage

``` r
hb_add_columns(client, table, columns, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- columns:

  A list of column specs (each a named list).

- call:

  Internal: error-propagation env.

## Value

Invisibly returns the client.

## See also

Other columns:
[`hb_add_column()`](https://r-heller.github.io/harbouR/reference/hb_add_column.md),
[`hb_add_select_option()`](https://r-heller.github.io/harbouR/reference/hb_add_select_option.md),
[`hb_delete_column()`](https://r-heller.github.io/harbouR/reference/hb_delete_column.md),
[`hb_delete_select_option()`](https://r-heller.github.io/harbouR/reference/hb_delete_select_option.md),
[`hb_list_columns()`](https://r-heller.github.io/harbouR/reference/hb_list_columns.md),
[`hb_update_column()`](https://r-heller.github.io/harbouR/reference/hb_update_column.md),
[`hb_update_select_option()`](https://r-heller.github.io/harbouR/reference/hb_update_select_option.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_add_columns(client, "Samples",
  list(list(column_name = "a", column_type = "text"),
       list(column_name = "b", column_type = "number")))
}
```
