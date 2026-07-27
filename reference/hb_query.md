# Run a SeaTable SQL query

Run a SeaTable SQL query

## Usage

``` r
hb_query(client, sql, ..., parameters = NULL, convert_keys = TRUE)
```

## Arguments

- client:

  A `harbour_client`.

- sql:

  SeaTable SQL query string. SeaTable applies an implicit `LIMIT 100`
  when the query has none, and caps results at 10000 rows. harbouR warns
  if there is no `LIMIT` clause.

- ...:

  These dots are for future extensions and must be empty.

- parameters:

  Optional list of values for `?` placeholders in `sql`.

- convert_keys:

  Return column names rather than column keys. Default `TRUE`.

## Value

A tibble, typed from the result schema SeaTable reports alongside the
rows, so the same table read via
[`hb_read_table()`](https://cttir.github.io/harbouR/reference/hb_read_table.md)
and via `hb_query()` yields the same column types. Always a tibble, even
when the query returns no rows.

## See also

Other rows:
[`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md),
[`hb_delete_rows()`](https://cttir.github.io/harbouR/reference/hb_delete_rows.md),
[`hb_get_row()`](https://cttir.github.io/harbouR/reference/hb_get_row.md),
[`hb_lock_rows()`](https://cttir.github.io/harbouR/reference/hb_lock_rows.md),
[`hb_read_table.harbour_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_table.md),
[`hb_unlock_rows()`](https://cttir.github.io/harbouR/reference/hb_unlock_rows.md),
[`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_query(client, "select * from Samples limit 5")
}
```
