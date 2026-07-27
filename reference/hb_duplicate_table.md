# Duplicate a table

Duplicate a table

## Usage

``` r
hb_duplicate_table(client, table, ..., new_name = NULL)
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Source table name.

- ...:

  These dots are for future extensions and must be empty.

- new_name:

  Optional new name. If `NULL` the server picks one.

## Value

Invisibly returns the client.

## See also

Other tables:
[`hb_create_table()`](https://cttir.github.io/harbouR/reference/hb_create_table.md),
[`hb_delete_table()`](https://cttir.github.io/harbouR/reference/hb_delete_table.md),
[`hb_rename_table()`](https://cttir.github.io/harbouR/reference/hb_rename_table.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_duplicate_table(client, "Samples", "Samples_copy")
}
```
