# Update a column

Update a column

## Usage

``` r
hb_update_column(
  client,
  table,
  name,
  new_name = NULL,
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

- new_name:

  Optional new column name.

- data:

  Optional list of column options (e.g. select options).

- call:

  Internal: error-propagation env.

## Value

Invisibly returns the client.

## See also

Other columns:
[`hb_add_column()`](https://cttir.github.io/harbouR/reference/hb_add_column.md),
[`hb_add_columns()`](https://cttir.github.io/harbouR/reference/hb_add_columns.md),
[`hb_add_select_option()`](https://cttir.github.io/harbouR/reference/hb_add_select_option.md),
[`hb_delete_column()`](https://cttir.github.io/harbouR/reference/hb_delete_column.md),
[`hb_delete_select_option()`](https://cttir.github.io/harbouR/reference/hb_delete_select_option.md),
[`hb_list_columns()`](https://cttir.github.io/harbouR/reference/hb_list_columns.md),
[`hb_update_select_option()`](https://cttir.github.io/harbouR/reference/hb_update_select_option.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_update_column(client, "Samples", "Notes", new_name = "Comments")
}
```
