# Update rows in a table

Update rows in a table

## Usage

``` r
hb_update_rows(
  client,
  table,
  data,
  row_id_col = "_id",
  call = rlang::caller_env()
)
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Name of the table.

- data:

  A tibble or data frame whose columns match the table schema.

- row_id_col:

  Name of the column in `data` that holds row IDs. Default `"_id"`.

- call:

  Internal: error-propagation env.

## Value

Invisibly returns a summary tibble with columns `row_id` (chr) and
`updated` (lgl).

## See also

Other rows:
[`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md),
[`hb_delete_rows()`](https://cttir.github.io/harbouR/reference/hb_delete_rows.md),
[`hb_get_row()`](https://cttir.github.io/harbouR/reference/hb_get_row.md),
[`hb_lock_rows()`](https://cttir.github.io/harbouR/reference/hb_lock_rows.md),
[`hb_query()`](https://cttir.github.io/harbouR/reference/hb_query.md),
[`hb_read_table()`](https://cttir.github.io/harbouR/reference/hb_read_table.md),
[`hb_unlock_rows()`](https://cttir.github.io/harbouR/reference/hb_unlock_rows.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_update_rows(client, "Samples",
               tibble::tibble(`_id` = "abc", Name = "renamed"))
}
```
