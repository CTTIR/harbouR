# Add a column to a table

Add a column to a table

## Usage

``` r
hb_add_column(
  client,
  table,
  name,
  type,
  data = NULL,
  call = rlang::caller_env()
)
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- name:

  Column name.

- type:

  SeaTable column type, e.g. `"text"`, `"number"`, `"date"`.

- data:

  Optional list of column options (e.g. select options).

- call:

  Internal: error-propagation env.

## Value

Invisibly returns the client.

## See also

Other columns:
[`hb_add_columns()`](https://r-heller.github.io/harbouR/reference/hb_add_columns.md),
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
hb_add_column(client, "Samples", "Notes", "text")
}
```
