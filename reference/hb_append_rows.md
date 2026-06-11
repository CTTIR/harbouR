# Append rows to a table

Append rows to a table

## Usage

``` r
hb_append_rows(client, table, data, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Name of the table.

- data:

  A tibble or data frame whose columns match the table schema.

- call:

  Internal: error-propagation env.

## Value

A tibble of the appended rows (with server-generated `_id`s).

## See also

Other rows:
[`hb_delete_rows()`](https://cttir.github.io/harbouR/reference/hb_delete_rows.md),
[`hb_get_row()`](https://cttir.github.io/harbouR/reference/hb_get_row.md),
[`hb_lock_rows()`](https://cttir.github.io/harbouR/reference/hb_lock_rows.md),
[`hb_query()`](https://cttir.github.io/harbouR/reference/hb_query.md),
[`hb_read_table()`](https://cttir.github.io/harbouR/reference/hb_read_table.md),
[`hb_unlock_rows()`](https://cttir.github.io/harbouR/reference/hb_unlock_rows.md),
[`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_append_rows(client, "Samples", tibble::tibble(Name = "S1"))
}
```
