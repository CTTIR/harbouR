# SeaTable column type mapping

Returns the mapping between SeaTable column types and the R types
harbouR produces when reading rows. This is the single source of truth
for the coercion layer; the column-types vignette is derived from it.

## Usage

``` r
hb_column_types()
```

## Value

A tibble with columns `seatable` (chr), `r` (chr) and `notes` (chr).

## See also

Other metadata:
[`as_tibble.harbour_metadata()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_metadata.md),
[`hb_list_collaborators()`](https://cttir.github.io/harbouR/reference/hb_list_collaborators.md),
[`hb_list_tables()`](https://cttir.github.io/harbouR/reference/hb_list_tables.md),
[`hb_metadata()`](https://cttir.github.io/harbouR/reference/hb_metadata.md),
[`is_harbour_metadata()`](https://cttir.github.io/harbouR/reference/is_harbour_metadata.md),
[`print.harbour_metadata()`](https://cttir.github.io/harbouR/reference/print.harbour_metadata.md),
[`summary.harbour_metadata()`](https://cttir.github.io/harbouR/reference/summary.harbour_metadata.md)

## Examples

``` r
hb_column_types()
#> # A tibble: 23 × 3
#>    seatable      r               notes                                   
#>    <chr>         <chr>           <chr>                                   
#>  1 text          character       free text                               
#>  2 long-text     character       markdown blob                           
#>  3 email         character       validated as email server-side          
#>  4 url           character       validated as URL server-side            
#>  5 auto-number   character       server-generated identifier             
#>  6 number        double          64-bit precision caveat applies         
#>  7 rate          integer         0..N stars                              
#>  8 checkbox      logical         TRUE/FALSE                              
#>  9 date          Date or POSIXct POSIXct when a time component is present
#> 10 single-select character       validated against options on write      
#> # ℹ 13 more rows
```
