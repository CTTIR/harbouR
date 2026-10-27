# SeaTable column types and how harbouR maps them

The single source of truth for the coercion layer: one row per type
name, giving the R type harbouR produces when reading, whether that R
type is a list-column, and whether harbouR leaves the column out of
writes. The coercion functions and the column-types vignette are both
derived from this table, so they cannot drift apart.

## Usage

``` r
hb_column_types()
```

## Value

A tibble with one row per type and columns:

- `seatable`:

  chr. The type name as SeaTable reports it, or one of the number
  formats above.

- `r`:

  chr. The R type harbouR reads it as.

- `is_list`:

  lgl. Whether the result is a list-column.

- `read_only`:

  lgl. Whether harbouR leaves the column out of writes. Most of these
  are computed or maintained by SeaTable; a `digital-sign` cell is left
  out because a signature should come from the signer.

- `notes`:

  chr. Anything worth knowing.

## Details

`percent`, `dollar` and `euro` are number formats rather than column
types: SeaTable reports such a column as type `"number"`, with the
format in its `data$format`. They are listed so that tables carrying
them as a type still coerce.

A `date` column reads as `POSIXct` in UTC. When the column's format has
no time part, the cell holds a calendar date, and harbouR reads the date
SeaTable shows as midnight UTC, whatever UTC offset the server sends
with it, so [`as.Date()`](https://rdrr.io/r/base/as.Date.html) gives
that date. A date-time read from a server is an instant and is converted
to UTC; a date-time stored without an offset, as in a `.dtable` file, is
read as UTC. A column that reports no format is read as a date-time.

Written to a date-only column, a `Date` is sent as itself and a
date-time as the date it shows in its own time zone, except one at
exactly midnight UTC, which keeps its UTC date: a cell read and written
back keeps its day. A date-time column is sent the instant, in UTC.

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

# the types harbouR does not write
subset(hb_column_types(), read_only)
#> # A tibble: 10 × 5
#>    seatable      r         is_list read_only notes                              
#>    <chr>         <chr>     <lgl>   <lgl>     <chr>                              
#>  1 link          list      TRUE    TRUE      managed via the link endpoints, no…
#>  2 link-formula  list      TRUE    TRUE      mirrors a column in a linked table 
#>  3 formula       character FALSE   TRUE      computed server-side               
#>  4 auto-number   character FALSE   TRUE      server-generated identifier        
#>  5 button        list      TRUE    TRUE      carries no data                    
#>  6 digital-sign  list      TRUE    TRUE      signature metadata; not written, s…
#>  7 creator       character FALSE   TRUE      user email                         
#>  8 last-modifier character FALSE   TRUE      user email                         
#>  9 ctime         POSIXct   FALSE   TRUE      row creation time                  
#> 10 mtime         POSIXct   FALSE   TRUE      row modification time              
```
