# Get a single row by ID

Get a single row by ID

## Usage

``` r
hb_get_row(client, table, row_id, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Name of the table.

- row_id:

  The SeaTable row identifier.

- call:

  Internal: error-propagation env.

## Value

A 1-row tibble, or a 0-row tibble if the row is not found.

## See also

Other rows:
[`hb_append_rows()`](https://r-heller.github.io/harbouR/reference/hb_append_rows.md),
[`hb_delete_rows()`](https://r-heller.github.io/harbouR/reference/hb_delete_rows.md),
[`hb_lock_rows()`](https://r-heller.github.io/harbouR/reference/hb_lock_rows.md),
[`hb_query()`](https://r-heller.github.io/harbouR/reference/hb_query.md),
[`hb_read_table()`](https://r-heller.github.io/harbouR/reference/hb_read_table.md),
[`hb_unlock_rows()`](https://r-heller.github.io/harbouR/reference/hb_unlock_rows.md),
[`hb_update_rows()`](https://r-heller.github.io/harbouR/reference/hb_update_rows.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_get_row(client, "Samples", "abc123")
}
```
