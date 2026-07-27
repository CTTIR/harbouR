# Create a table

Create a table

## Usage

``` r
hb_create_table(client, table, ..., columns = list())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Name of the new table.

- ...:

  These dots are for future extensions and must be empty.

- columns:

  A list of column specifications: each element a named list with at
  least `name` and `type` (a SeaTable type string).

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
