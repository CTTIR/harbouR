# Read a table as a tibble

Reads all rows from `table` (optionally filtered by `view`) and returns
them as a typed tibble. Pagination is handled internally; the returned
tibble always has the table's columns in declared order plus an `_id`
column.

## Usage

``` r
hb_read_table(
  client,
  table,
  view = NULL,
  limit = 1000L,
  call = rlang::caller_env()
)
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Name of the table.

- view:

  Optional view name.

- limit:

  Page size for paginated fetches. Default `1000`.

- call:

  Internal: error-propagation env.

## Value

A tibble with one row per SeaTable row and one column per SeaTable
column, plus `_id` (chr). A 0-row tibble is returned for an empty table.

## See also

Other rows:
[`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md),
[`hb_delete_rows()`](https://cttir.github.io/harbouR/reference/hb_delete_rows.md),
[`hb_get_row()`](https://cttir.github.io/harbouR/reference/hb_get_row.md),
[`hb_lock_rows()`](https://cttir.github.io/harbouR/reference/hb_lock_rows.md),
[`hb_query()`](https://cttir.github.io/harbouR/reference/hb_query.md),
[`hb_unlock_rows()`](https://cttir.github.io/harbouR/reference/hb_unlock_rows.md),
[`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_read_table(client, "Samples")
}
```
