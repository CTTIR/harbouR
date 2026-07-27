# Read a table as a tibble

Reads all rows from `table` (optionally filtered by `view`) and returns
them as a typed tibble. Pagination is handled internally; the returned
tibble always has the table's columns in declared order plus an `_id`
column.

## Usage

``` r
# S3 method for class 'harbour_dtable'
hb_read_table(x, table, ..., view = NULL, n_max = Inf, option_labels = TRUE)

# Default S3 method
hb_read_table(x, table, ...)

hb_read_table(x, table, ...)

# S3 method for class 'harbour_client'
hb_read_table(x, table, ..., view = NULL, page_size = 1000L, n_max = Inf)
```

## Arguments

- x:

  A `harbour_client` connected to a base, or a `harbour_dtable` read
  from a local file.

- table:

  Name of the table.

- ...:

  These dots are for future extensions and must be empty.

- view:

  Optional view name.

- n_max:

  Maximum number of rows to return. `Inf`, the default, reads the whole
  table.

- option_labels:

  Translate select-option ids to their display names. On disk a select
  cell holds an option id; over the API it holds the name, so this is
  what makes a local read and a server read of the same column agree.
  Set `FALSE` to see the raw ids.

- page_size:

  Rows fetched per request. SeaTable caps this at 1000 and harbouR
  clamps it, warning if you asked for more.

## Value

A tibble with one row per SeaTable row and one column per SeaTable
column, plus `_id` (chr). A 0-row tibble is returned for an empty table.

## See also

Other rows:
[`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md),
[`hb_delete_rows()`](https://cttir.github.io/harbouR/reference/hb_delete_rows.md),
[`hb_get_row()`](https://cttir.github.io/harbouR/reference/hb_get_row.md),
[`hb_lock_rows()`](https://cttir.github.io/harbouR/reference/hb_lock_rows.md),
[`hb_query()`](https://cttir.github.io/harbouR/reference/hb_query.md),
[`hb_unlock_rows()`](https://cttir.github.io/harbouR/reference/hb_unlock_rows.md),
[`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_read_table(client, "Samples")

# just the first 10 rows
hb_read_table(client, "Samples", n_max = 10)
}
```
