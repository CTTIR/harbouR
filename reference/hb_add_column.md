# Add a column to a table

Add a column to a table

## Usage

``` r
hb_add_column(client, table, name, type, ..., column_data = NULL)
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- name:

  Column name.

- type:

  SeaTable column type, e.g. `"text"`, `"number"`, `"date"`.

- ...:

  These dots are for future extensions and must be empty.

- column_data:

  Optional list of column options, e.g. the choices for a select column.
  Named `column_data` rather than `data` because `data` means "the rows
  you are writing" everywhere else in harbouR.

## Value

Invisibly returns the client.

## See also

Other columns:
[`hb_add_columns()`](https://cttir.github.io/harbouR/reference/hb_add_columns.md),
[`hb_add_select_option()`](https://cttir.github.io/harbouR/reference/hb_add_select_option.md),
[`hb_delete_column()`](https://cttir.github.io/harbouR/reference/hb_delete_column.md),
[`hb_delete_select_option()`](https://cttir.github.io/harbouR/reference/hb_delete_select_option.md),
[`hb_list_columns()`](https://cttir.github.io/harbouR/reference/hb_list_columns.md),
[`hb_update_column()`](https://cttir.github.io/harbouR/reference/hb_update_column.md),
[`hb_update_select_option()`](https://cttir.github.io/harbouR/reference/hb_update_select_option.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_add_column(client, "Samples", "Notes", "text")
}
```
