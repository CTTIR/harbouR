# Update a single-select option

Update a single-select option

## Usage

``` r
hb_update_select_option(
  client,
  table,
  name,
  option,
  new_option,
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

- option:

  Option name to add.

- new_option:

  New option name.

- call:

  Internal: error-propagation env.

## Value

Invisibly returns the client.

## See also

Other columns:
[`hb_add_column()`](https://r-heller.github.io/harbouR/reference/hb_add_column.md),
[`hb_add_columns()`](https://r-heller.github.io/harbouR/reference/hb_add_columns.md),
[`hb_add_select_option()`](https://r-heller.github.io/harbouR/reference/hb_add_select_option.md),
[`hb_delete_column()`](https://r-heller.github.io/harbouR/reference/hb_delete_column.md),
[`hb_delete_select_option()`](https://r-heller.github.io/harbouR/reference/hb_delete_select_option.md),
[`hb_list_columns()`](https://r-heller.github.io/harbouR/reference/hb_list_columns.md),
[`hb_update_column()`](https://r-heller.github.io/harbouR/reference/hb_update_column.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_update_select_option(client, "Samples", "Status", "Done", "Complete")
}
```
