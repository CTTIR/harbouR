# Unlock rows

Unlock rows

## Usage

``` r
hb_unlock_rows(client, table, row_ids, call = rlang::caller_env())
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
[`hb_append_rows()`](https://r-heller.github.io/harbouR/reference/hb_append_rows.md),
[`hb_delete_rows()`](https://r-heller.github.io/harbouR/reference/hb_delete_rows.md),
[`hb_get_row()`](https://r-heller.github.io/harbouR/reference/hb_get_row.md),
[`hb_lock_rows()`](https://r-heller.github.io/harbouR/reference/hb_lock_rows.md),
[`hb_query()`](https://r-heller.github.io/harbouR/reference/hb_query.md),
[`hb_read_table()`](https://r-heller.github.io/harbouR/reference/hb_read_table.md),
[`hb_update_rows()`](https://r-heller.github.io/harbouR/reference/hb_update_rows.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_unlock_rows(client, "Samples", "abc")
}
```
