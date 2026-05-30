# Column types and coercion

![harbouR logo](../reference/figures/logo.png)

SeaTable bases have around twenty column types. harbouR maps every one
of them onto a predictable R type so the tibble you get back is
analysis-ready, not raw JSON. This vignette is the reference.

## The mapping table

The table below is derived from
[`hb_column_types()`](https://r-heller.github.io/harbouR/reference/hb_column_types.md)
so it cannot drift out of sync with the code:

``` r

library(harbouR)
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

## What the rows look like

The bundled example data exercises every column-type harbouR supports.

``` r

samples <- hb_example_rows("Samples")
samples
#> # A tibble: 3 × 8
#>   Name  Concentration Status  Tags   Collected           Collaborators Reports
#>   <chr>         <dbl> <chr>   <list> <dttm>              <list>        <list> 
#> 1 S-001          12.4 draft   <chr>  2026-04-01 09:00:00 <chr [1]>     <list> 
#> 2 S-002           8.1 ready   <chr>  2026-04-03 12:30:00 <chr [2]>     <list> 
#> 3 S-003          21   shipped <chr>  2026-04-05 16:15:00 <chr [0]>     <list> 
#> # ℹ 1 more variable: `_id` <chr>
```

### Scalars

``` r

str(samples[, c("Name", "Concentration", "Status", "Collected")])
#> tibble [3 × 4] (S3: tbl_df/tbl/data.frame)
#>  $ Name         : chr [1:3] "S-001" "S-002" "S-003"
#>  $ Concentration: num [1:3] 12.4 8.1 21
#>  $ Status       : chr [1:3] "draft" "ready" "shipped"
#>  $ Collected    : POSIXct[1:3], format: "2026-04-01 09:00:00" "2026-04-03 12:30:00" ...
```

- `text` / `single-select` come back as `character`.
- `number` becomes a `double` (caveat: SeaTable’s numeric column is
  64-bit; large integers may round - if precision matters store them as
  text).
- `date` becomes `POSIXct` when there is a time component and `Date`
  otherwise; harbouR detects this from the value.

### List-columns

`multiple-select`, `collaborator`, `image` and `file` always come back
as list-columns, even when every row has one value or none. That is the
type-stability rule: the same column has the same R type for every row.

``` r

samples$Tags
#> [[1]]
#> [1] "urgent" "blood" 
#> 
#> [[2]]
#> character(0)
#> 
#> [[3]]
#> [1] "plasma"
```

Flatten with
[`tidyr::unnest`](https://tidyr.tidyverse.org/reference/unnest.html)
when you need a long form:

``` r

tidyr::unnest(samples[, c("Name", "Tags")], cols = "Tags")
#> # A tibble: 3 × 2
#>   Name  Tags  
#>   <chr> <chr> 
#> 1 S-001 urgent
#> 2 S-001 blood 
#> 3 S-003 plasma
```

### File and image columns

``` r

samples$Reports[[1]]
#> [[1]]
#> [[1]]$name
#> [1] "S-001.pdf"
#> 
#> [[1]]$size
#> [1] 1234
#> 
#> [[1]]$type
#> [1] "application/pdf"
#> 
#> [[1]]$url
#> [1] "https://example.org/files/S-001.pdf"
```

Each entry is a list of file objects with `name`, `size`, `type` and
`url` - ready to be downloaded via
[`hb_download_file()`](https://r-heller.github.io/harbouR/reference/hb_download_file.md).

### Read-only columns

`formula`, `auto-number`, `creator`, `last-modifier`, `ctime`, `mtime`
and `link-formula` are read-only on SeaTable; harbouR silently drops
them when you call
[`hb_update_rows()`](https://r-heller.github.io/harbouR/reference/hb_update_rows.md)
or
[`hb_append_rows()`](https://r-heller.github.io/harbouR/reference/hb_append_rows.md),
so you can round-trip a tibble through harbouR without writing back
computed values by accident.

## Empty tables

A table with no rows still comes back as a tibble with every column in
its correct type:

``` r

meta <- hb_example_metadata()
cols <- harbouR:::.hb_columns_from_metadata(meta, "Samples")
empty <- harbouR:::.hb_rows_to_tibble(list(), cols)
empty
#> # A tibble: 0 × 8
#> # ℹ 8 variables: Name <chr>, Concentration <dbl>, Status <chr>, Tags <list>,
#> #   Collected <dttm>, Collaborators <list>, Reports <list>, _id <chr>
```

## Next steps

- [`vignette("harbouR")`](https://r-heller.github.io/harbouR/articles/harbouR.md) -
  the five-minute end-to-end story.
- [`vignette("explorer-app")`](https://r-heller.github.io/harbouR/articles/explorer-app.md) -
  exploring a base interactively.
