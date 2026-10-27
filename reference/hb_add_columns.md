# Add several columns at once

Add several columns at once

## Usage

``` r
hb_add_columns(client, table, columns, ...)
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- columns:

  A list of column specs, each a named list with `name`, `type` and
  optionally `data` - the same shape
  [`hb_create_table()`](https://cttir.github.io/harbouR/reference/hb_create_table.md)
  takes. SeaTable's own spelling, `column_name`, `column_type` and
  `column_data`, is accepted too.

- ...:

  These dots are for future extensions and must be empty.

## Value

Invisibly returns the client.

## See also

Other columns:
[`hb_add_column()`](https://cttir.github.io/harbouR/reference/hb_add_column.md),
[`hb_add_select_option()`](https://cttir.github.io/harbouR/reference/hb_add_select_option.md),
[`hb_delete_column()`](https://cttir.github.io/harbouR/reference/hb_delete_column.md),
[`hb_delete_select_option()`](https://cttir.github.io/harbouR/reference/hb_delete_select_option.md),
[`hb_list_columns()`](https://cttir.github.io/harbouR/reference/hb_list_columns.md),
[`hb_update_column()`](https://cttir.github.io/harbouR/reference/hb_update_column.md),
[`hb_update_select_option()`](https://cttir.github.io/harbouR/reference/hb_update_select_option.md)

## Examples

``` r
if (FALSE) { # \dontrun{
client <- hb_client()
hb_add_columns(
  client, "Samples",
  list(
    list(name = "a", type = "text"),
    list(name = "b", type = "number")
  )
)
} # }
```
