# Get a single row by ID

Get a single row by ID

## Usage

``` r
hb_get_row(client, table, row_id, ...)
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- row_id:

  The SeaTable row identifier.

- ...:

  These dots are for future extensions and must be empty.

## Value

A one-row tibble with one column per SeaTable column, plus `_id` (chr).
An unknown `row_id` is an error - a `harbour_error_not_found`
condition - not an empty result, because asking for a specific row that
does not exist is a mistake worth surfacing.

## See also

Other rows:
[`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md),
[`hb_delete_rows()`](https://cttir.github.io/harbouR/reference/hb_delete_rows.md),
[`hb_lock_rows()`](https://cttir.github.io/harbouR/reference/hb_lock_rows.md),
[`hb_query()`](https://cttir.github.io/harbouR/reference/hb_query.md),
[`hb_read_table.harbour_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_table.md),
[`hb_unlock_rows()`](https://cttir.github.io/harbouR/reference/hb_unlock_rows.md),
[`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_get_row(client, "Samples", "abc123")
}
```
