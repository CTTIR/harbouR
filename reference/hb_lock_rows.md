# Lock rows

Lock rows

## Usage

``` r
hb_lock_rows(client, table, row_ids, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Name of the table.

- row_ids:

  A character vector of row IDs to delete.

- call:

  Internal: error-propagation env.

## Value

Invisibly returns the client.

## See also

Other rows:
[`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md),
[`hb_delete_rows()`](https://cttir.github.io/harbouR/reference/hb_delete_rows.md),
[`hb_get_row()`](https://cttir.github.io/harbouR/reference/hb_get_row.md),
[`hb_query()`](https://cttir.github.io/harbouR/reference/hb_query.md),
[`hb_read_table()`](https://cttir.github.io/harbouR/reference/hb_read_table.md),
[`hb_unlock_rows()`](https://cttir.github.io/harbouR/reference/hb_unlock_rows.md),
[`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_lock_rows(client, "Samples", "abc")
}
```
