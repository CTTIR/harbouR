# List columns of a table

List columns of a table

## Usage

``` r
hb_list_columns(x, table, ...)

# S3 method for class 'harbour_client'
hb_list_columns(x, table, ..., refresh = FALSE)

# S3 method for class 'harbour_dtable'
hb_list_columns(x, table, ...)

# Default S3 method
hb_list_columns(x, table, ...)
```

## Arguments

- x:

  A `harbour_client` connected to a base, or a `harbour_dtable` read
  from a local file.

- table:

  Table name.

- ...:

  These dots are for future extensions and must be empty.

- refresh:

  Logical. Ask the server rather than reusing the cached base metadata.
  Default `FALSE`.

## Value

A tibble with one row per column and columns `name` (chr), `type` (chr),
`key` (chr), `editable` (lgl) and `data` (list). The `data` list-column
holds the column's type-specific configuration - for a select column,
its options.

## See also

Other columns:
[`hb_add_column()`](https://cttir.github.io/harbouR/reference/hb_add_column.md),
[`hb_add_columns()`](https://cttir.github.io/harbouR/reference/hb_add_columns.md),
[`hb_add_select_option()`](https://cttir.github.io/harbouR/reference/hb_add_select_option.md),
[`hb_delete_column()`](https://cttir.github.io/harbouR/reference/hb_delete_column.md),
[`hb_delete_select_option()`](https://cttir.github.io/harbouR/reference/hb_delete_select_option.md),
[`hb_update_column()`](https://cttir.github.io/harbouR/reference/hb_update_column.md),
[`hb_update_select_option()`](https://cttir.github.io/harbouR/reference/hb_update_select_option.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_list_columns(client, "Samples")
}
```
