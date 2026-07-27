# Append rows to a table

Append rows to a table

## Usage

``` r
hb_append_rows(client, table, data, ..., chunk_size = 1000L)
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- data:

  A tibble or data frame whose columns match the table schema.

- ...:

  These dots are for future extensions and must be empty.

- chunk_size:

  Rows per request. SeaTable caps batch writes at 1000 and harbouR
  clamps it, warning if you asked for more.

## Value

Invisibly, a one-row tibble with columns `table` (chr), `n_rows` (int) -
the count the server confirmed - and `n_requests` (int). SeaTable does
not return the created rows, so neither does harbouR; read the table
back if you need their `_id`s.

## See also

Other rows:
[`hb_delete_rows()`](https://cttir.github.io/harbouR/reference/hb_delete_rows.md),
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
hb_append_rows(client, "Samples", tibble::tibble(Name = "S1"))
}
```
