# List views of a table

List views of a table

## Usage

``` r
# S3 method for class 'harbour_dtable'
hb_list_views(x, table, ...)

# Default S3 method
hb_list_views(x, table, ...)

hb_list_views(x, table, ...)

# S3 method for class 'harbour_client'
hb_list_views(x, table, ..., refresh = FALSE)
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

A tibble with columns `name` (chr), `type` (chr) and `is_default` (lgl).
Zero rows if no views exist.

## See also

Other views:
[`hb_create_view()`](https://cttir.github.io/harbouR/reference/hb_create_view.md),
[`hb_delete_view()`](https://cttir.github.io/harbouR/reference/hb_delete_view.md),
[`hb_get_view()`](https://cttir.github.io/harbouR/reference/hb_get_view.md),
[`hb_update_view()`](https://cttir.github.io/harbouR/reference/hb_update_view.md)

## Examples

``` r
if (FALSE) { # interactive()
client <- hb_client()
hb_list_views(client, "Samples")
}
```
