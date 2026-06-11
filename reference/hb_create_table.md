# Create a table

Create a table

## Usage

``` r
hb_create_table(client, table, columns = list(), call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Name of the new table.

- columns:

  A list of column specifications: each element a named list with at
  least `name` and `type` (a SeaTable type string).

- call:

  Internal: error-propagation env.

## Value

Invisibly returns the client.

## See also

Other tables:
[`hb_delete_table()`](https://cttir.github.io/harbouR/reference/hb_delete_table.md),
[`hb_duplicate_table()`](https://cttir.github.io/harbouR/reference/hb_duplicate_table.md),
[`hb_rename_table()`](https://cttir.github.io/harbouR/reference/hb_rename_table.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_create_table(client, "NewTable", list(list(name = "Name", type = "text")))
}
```
