# Delete rows

Delete rows

## Usage

``` r
hb_delete_rows(client, table, row_ids, ..., chunk_size = 1000L)
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- row_ids:

  A character vector of row IDs to delete.

- ...:

  These dots are for future extensions and must be empty.

- chunk_size:

  Rows per request. SeaTable caps batch writes at 1000 and harbouR
  clamps it, warning if you asked for more.

## Value

Invisibly, a one-row tibble with columns `table` (chr), `n_rows` (int)
and `n_requests` (int).

## See also

Other rows:
[`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md),
[`hb_get_row()`](https://cttir.github.io/harbouR/reference/hb_get_row.md),
[`hb_lock_rows()`](https://cttir.github.io/harbouR/reference/hb_lock_rows.md),
[`hb_query()`](https://cttir.github.io/harbouR/reference/hb_query.md),
[`hb_read_table.harbour_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_table.md),
[`hb_unlock_rows()`](https://cttir.github.io/harbouR/reference/hb_unlock_rows.md),
[`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_delete_rows(client, "Samples", c("abc", "def"))
}
```
