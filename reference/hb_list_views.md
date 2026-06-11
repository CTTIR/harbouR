# List views of a table

List views of a table

## Usage

``` r
hb_list_views(client, table, call = rlang::caller_env())
```

## Arguments

- client:

  A `harbour_client`.

- table:

  Table name.

- call:

  Internal: error-propagation env.

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
