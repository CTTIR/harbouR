# List columns of a table

List columns of a table

## Usage

``` r
hb_list_columns(client, table, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- call:

  Internal: error-propagation env.

## Value

A tibble with columns `name` (chr), `type` (chr), `key` (chr) and
`editable` (lgl).

## See also

Other columns:
[`hb_add_column()`](https://r-heller.github.io/harbouR/reference/hb_add_column.md),
[`hb_add_columns()`](https://r-heller.github.io/harbouR/reference/hb_add_columns.md),
[`hb_add_select_option()`](https://r-heller.github.io/harbouR/reference/hb_add_select_option.md),
[`hb_delete_column()`](https://r-heller.github.io/harbouR/reference/hb_delete_column.md),
[`hb_delete_select_option()`](https://r-heller.github.io/harbouR/reference/hb_delete_select_option.md),
[`hb_update_column()`](https://r-heller.github.io/harbouR/reference/hb_update_column.md),
[`hb_update_select_option()`](https://r-heller.github.io/harbouR/reference/hb_update_select_option.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_list_columns(client, "Samples")
}
```
