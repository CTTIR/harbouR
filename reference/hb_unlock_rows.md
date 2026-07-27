# Unlock rows

Unlock rows

## Usage

``` r
hb_unlock_rows(client, table, row_ids, ...)
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

## Value

Invisibly returns the client.

## See also

Other rows:
[`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md),
[`hb_delete_rows()`](https://cttir.github.io/harbouR/reference/hb_delete_rows.md),
[`hb_get_row()`](https://cttir.github.io/harbouR/reference/hb_get_row.md),
[`hb_lock_rows()`](https://cttir.github.io/harbouR/reference/hb_lock_rows.md),
[`hb_query()`](https://cttir.github.io/harbouR/reference/hb_query.md),
[`hb_read_table.harbour_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_table.md),
[`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_unlock_rows(client, "Samples", "abc")
}
```
