# Run a SeaTable SQL query

Run a SeaTable SQL query

## Usage

``` r
hb_query(client, sql, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- sql:

  SeaTable SQL query string.

- call:

  Internal: error-propagation env.

## Value

A tibble. Always a tibble, even when the query returns no rows.

## See also

Other rows:
[`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md),
[`hb_delete_rows()`](https://cttir.github.io/harbouR/reference/hb_delete_rows.md),
[`hb_get_row()`](https://cttir.github.io/harbouR/reference/hb_get_row.md),
[`hb_lock_rows()`](https://cttir.github.io/harbouR/reference/hb_lock_rows.md),
[`hb_read_table()`](https://cttir.github.io/harbouR/reference/hb_read_table.md),
[`hb_unlock_rows()`](https://cttir.github.io/harbouR/reference/hb_unlock_rows.md),
[`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_query(client, "select * from Samples limit 5")
}
```
