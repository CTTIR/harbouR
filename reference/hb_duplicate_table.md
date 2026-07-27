# Duplicate a table

Duplicate a table

## Usage

``` r
hb_duplicate_table(client, table, ..., duplicate_records = TRUE)
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Source table name.

- ...:

  These dots are for future extensions and must be empty.

- duplicate_records:

  Copy the rows as well as the structure. Default `TRUE`.

## Value

Invisibly returns the client.

## Naming

SeaTable names the copy after the original with `(copy)` appended, and
offers no way to set the name in the same request. Follow with
[`hb_rename_table()`](https://cttir.github.io/harbouR/reference/hb_rename_table.md)
if you need a particular name.

## See also

Other tables:
[`hb_create_table()`](https://cttir.github.io/harbouR/reference/hb_create_table.md),
[`hb_delete_table()`](https://cttir.github.io/harbouR/reference/hb_delete_table.md),
[`hb_rename_table()`](https://cttir.github.io/harbouR/reference/hb_rename_table.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_duplicate_table(client, "Samples")
hb_rename_table(client, "Samples (copy)", "Samples_backup")
}
```
