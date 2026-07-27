# SeaTable column types and how harbouR maps them

The single source of truth for the coercion layer. Every column type
SeaTable supports appears here exactly once, together with the R type
harbouR produces when reading, whether that R type is a list-column, and
whether the column is computed server-side and therefore cannot be
written. The coercion functions and the column-types vignette are both
derived from this table, so they cannot drift apart.

## Usage

``` r
hb_column_types()
```

## Value

A tibble with one row per SeaTable column type and columns:

- `seatable`:

  chr. The type name as SeaTable reports it.

- `r`:

  chr. The R type harbouR reads it as.

- `is_list`:

  lgl. Whether the result is a list-column.

- `read_only`:

  lgl. Whether the value is computed server-side and is dropped on
  write.

- `notes`:

  chr. Anything worth knowing.

## See also

Other metadata:
[`as_tibble.harbour_metadata()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_metadata.md),
[`hb_list_collaborators()`](https://cttir.github.io/harbouR/reference/hb_list_collaborators.md),
[`hb_list_tables.harbour_dtable()`](https://cttir.github.io/harbouR/reference/hb_list_tables.md),
[`hb_metadata()`](https://cttir.github.io/harbouR/reference/hb_metadata.md),
[`is_harbour_metadata()`](https://cttir.github.io/harbouR/reference/is_harbour_metadata.md),
[`print.harbour_metadata()`](https://cttir.github.io/harbouR/reference/print.harbour_metadata.md),
[`summary.harbour_metadata()`](https://cttir.github.io/harbouR/reference/summary.harbour_metadata.md)

## Examples

``` r
hb_column_types()
#> # A tibble: 28 × 5
#>    seatable  r         is_list read_only notes                                  
#>    <chr>     <chr>     <lgl>   <lgl>     <chr>                                  
#>  1 text      character FALSE   FALSE     free text                              
#>  2 long-text character FALSE   FALSE     markdown blob                          
#>  3 email     character FALSE   FALSE     validated as email server-side         
#>  4 url       character FALSE   FALSE     validated as URL server-side           
#>  5 number    double    FALSE   FALSE     64-bit precision caveat applies        
#>  6 percent   double    FALSE   FALSE     stored as a fraction, displayed as a p…
#>  7 dollar    double    FALSE   FALSE     number with a currency format          
#>  8 euro      double    FALSE   FALSE     number with a currency format          
#>  9 duration  double    FALSE   FALSE     seconds                                
#> 10 rate      integer   FALSE   FALSE     0..N stars                             
#> # ℹ 18 more rows

# the types you cannot write to
subset(hb_column_types(), read_only)
#> # A tibble: 10 × 5
#>    seatable      r         is_list read_only notes                              
#>    <chr>         <chr>     <lgl>   <lgl>     <chr>                              
#>  1 link          list      TRUE    TRUE      managed via the link endpoints, no…
#>  2 link-formula  list      TRUE    TRUE      mirrors a column in a linked table 
#>  3 formula       character FALSE   TRUE      computed server-side               
#>  4 auto-number   character FALSE   TRUE      server-generated identifier        
#>  5 button        list      TRUE    TRUE      carries no data                    
#>  6 digital-sign  list      TRUE    TRUE      signature metadata                 
#>  7 creator       character FALSE   TRUE      user email                         
#>  8 last-modifier character FALSE   TRUE      user email                         
#>  9 ctime         POSIXct   FALSE   TRUE      row creation time                  
#> 10 mtime         POSIXct   FALSE   TRUE      row modification time              
```
