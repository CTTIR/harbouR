# Delete a column

Delete a column

## Usage

``` r
hb_delete_column(client, table, name, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- name:

  Column name.

- call:

  Internal: error-propagation env.

## Value

Invisibly returns the client.

## See also

Other columns:
[`hb_add_column()`](https://cttir.github.io/harbouR/reference/hb_add_column.md),
[`hb_add_columns()`](https://cttir.github.io/harbouR/reference/hb_add_columns.md),
[`hb_add_select_option()`](https://cttir.github.io/harbouR/reference/hb_add_select_option.md),
[`hb_delete_select_option()`](https://cttir.github.io/harbouR/reference/hb_delete_select_option.md),
[`hb_list_columns()`](https://cttir.github.io/harbouR/reference/hb_list_columns.md),
[`hb_update_column()`](https://cttir.github.io/harbouR/reference/hb_update_column.md),
[`hb_update_select_option()`](https://cttir.github.io/harbouR/reference/hb_update_select_option.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_delete_column(client, "Samples", "Old")
}
```
