# Rename a table

Rename a table

## Usage

``` r
hb_rename_table(client, table, new_name, ...)
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Current table name.

- new_name:

  New table name.

- ...:

  These dots are for future extensions and must be empty.

## Value

Invisibly returns the client.

## See also

Other tables:
[`hb_create_table()`](https://cttir.github.io/harbouR/reference/hb_create_table.md),
[`hb_delete_table()`](https://cttir.github.io/harbouR/reference/hb_delete_table.md),
[`hb_duplicate_table()`](https://cttir.github.io/harbouR/reference/hb_duplicate_table.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_rename_table(client, "Old", "New")
}
```
