# Delete a table

Delete a table

## Usage

``` r
hb_delete_table(client, table, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Name of the table to delete.

- call:

  Internal: error-propagation env.

## Value

Invisibly returns the client.

## See also

Other tables:
[`hb_create_table()`](https://r-heller.github.io/harbouR/reference/hb_create_table.md),
[`hb_duplicate_table()`](https://r-heller.github.io/harbouR/reference/hb_duplicate_table.md),
[`hb_rename_table()`](https://r-heller.github.io/harbouR/reference/hb_rename_table.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_delete_table(client, "DropMe")
}
```
