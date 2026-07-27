# Column types and coercion

SeaTable bases have 28 column types. harbouR maps every one of them onto
a predictable R type so the tibble you get back is analysis-ready, not
raw JSON. This vignette is the reference.

## The mapping table

The table below is derived from
[`hb_column_types()`](https://cttir.github.io/harbouR/reference/hb_column_types.md)
so it cannot drift out of sync with the code:

``` r

library(harbouR)
knitr::kable(hb_column_types())
```

| seatable | r | is_list | read_only | notes |
|:---|:---|:---|:---|:---|
| text | character | FALSE | FALSE | free text |
| long-text | character | FALSE | FALSE | markdown blob |
| email | character | FALSE | FALSE | validated as email server-side |
| url | character | FALSE | FALSE | validated as URL server-side |
| number | double | FALSE | FALSE | 64-bit precision caveat applies |
| percent | double | FALSE | FALSE | stored as a fraction, displayed as a percentage |
| dollar | double | FALSE | FALSE | number with a currency format |
| euro | double | FALSE | FALSE | number with a currency format |
| duration | double | FALSE | FALSE | seconds |
| rate | integer | FALSE | FALSE | 0..N stars |
| checkbox | logical | FALSE | FALSE | TRUE/FALSE |
| date | POSIXct | FALSE | FALSE | UTC; date-only columns have a zero time component |
| single-select | character | FALSE | FALSE | validated against the column’s options on write |
| multiple-select | list | TRUE | FALSE | always a list-column |
| collaborator | list | TRUE | FALSE | list-column of email addresses |
| image | list | TRUE | FALSE | list-column of URLs |
| file | list | TRUE | FALSE | list-column of {name,size,type,url} lists |
| geolocation | list | TRUE | FALSE | list-column with lat/lng/address |
| link | list | TRUE | TRUE | managed via the link endpoints, not by writing the cell |
| link-formula | list | TRUE | TRUE | mirrors a column in a linked table |
| formula | character | FALSE | TRUE | computed server-side |
| auto-number | character | FALSE | TRUE | server-generated identifier |
| button | list | TRUE | TRUE | carries no data |
| digital-sign | list | TRUE | TRUE | signature metadata |
| creator | character | FALSE | TRUE | user email |
| last-modifier | character | FALSE | TRUE | user email |
| ctime | POSIXct | FALSE | TRUE | row creation time |
| mtime | POSIXct | FALSE | TRUE | row modification time |

## What the rows look like

[`hb_example_rows()`](https://cttir.github.io/harbouR/reference/hb_example_rows.md)
is a small hand-written frame covering the common types. The bundled
`.dtable` fixture is the exhaustive one - it carries a column of nearly
every type - and the last section reads it.

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
- `date` always becomes `POSIXct`, in UTC. A date-only column simply has
  a zero time component. Call
  [`as.Date()`](https://rdrr.io/r/base/as.Date.html) if you want a
  calendar date.

### List-columns

These types always come back as list-columns, even when every row has
one value or none. That is the type-stability rule: the same column has
the same R type for every row.

``` r

subset(hb_column_types(), is_list)$seatable
#> [1] "multiple-select" "collaborator"    "image"           "file"           
#> [5] "geolocation"     "link"            "link-formula"    "button"         
#> [9] "digital-sign"
```

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
[`hb_download_file()`](https://cttir.github.io/harbouR/reference/hb_download_file.md).

### Read-only columns

These types are maintained by SeaTable, so harbouR drops them from any
write. You can round-trip a tibble through harbouR without writing back
computed values by accident.

``` r

subset(hb_column_types(), read_only)$seatable
#>  [1] "link"          "link-formula"  "formula"       "auto-number"  
#>  [5] "button"        "digital-sign"  "creator"       "last-modifier"
#>  [9] "ctime"         "mtime"
```

Note that `link`, `button` and `digital-sign` are in that list too:
links are maintained through SeaTable’s link endpoints rather than by
writing the cell.

## Empty tables

A table with no rows still comes back as a tibble with every column in
its correct type:

``` r

empty <- hb_example_rows("Samples")[0, ]
empty
#> # A tibble: 0 × 8
#> # ℹ 8 variables: Name <chr>, Concentration <dbl>, Status <chr>, Tags <list>,
#> #   Collected <dttm>, Collaborators <list>, Reports <list>, _id <chr>

str(empty, max.level = 1)
#> tibble [0 × 8] (S3: tbl_df/tbl/data.frame)
```

Every column keeps the type it would have had with rows present -
`Concentration` is still a double, `Collected` still a `POSIXct`, and
`Tags` still a list-column - so downstream code that expects a schema
does not have to special-case the empty result.

## Every type at once

[`hb_example_rows()`](https://cttir.github.io/harbouR/reference/hb_example_rows.md)
is deliberately small. The bundled `.dtable` fixture carries a column of
nearly every type SeaTable defines, so it is the better place to see the
whole mapping at work:

``` r

base <- hb_read_dtable(
  system.file("extdata", "example.dtable", package = "harbouR")
)
schema <- hb_list_columns(base, "Samples")
knitr::kable(schema[, c("name", "type", "editable")])
```

| name            | type            | editable |
|:----------------|:----------------|:---------|
| Name            | text            | TRUE     |
| Notes           | long-text       | TRUE     |
| Concentration   | number          | TRUE     |
| Share           | percent         | TRUE     |
| Cost            | dollar          | TRUE     |
| Preis           | euro            | TRUE     |
| Runtime         | duration        | TRUE     |
| Rating          | rate            | TRUE     |
| Consented       | checkbox        | TRUE     |
| Collected       | date            | TRUE     |
| Status          | single-select   | TRUE     |
| Tags            | multiple-select | TRUE     |
| Collaborators   | collaborator    | TRUE     |
| Photos          | image           | TRUE     |
| Reports         | file            | TRUE     |
| Where           | geolocation     | TRUE     |
| Homepage        | url             | TRUE     |
| Contact         | email           | TRUE     |
| Temperatur (°C) | number          | TRUE     |
| Doubled         | formula         | FALSE    |
| Ref             | auto-number     | FALSE    |
| Created by      | creator         | FALSE    |
| Changed by      | last-modifier   | FALSE    |
| Created         | ctime           | FALSE    |
| Changed         | mtime           | FALSE    |
| Action          | button          | FALSE    |
| Signature       | digital-sign    | FALSE    |

``` r

data <- hb_read_table(base, "Samples")
vapply(data, function(col) class(col)[[1L]], character(1))
#>            Name           Notes   Concentration           Share            Cost 
#>     "character"     "character"       "numeric"       "numeric"       "numeric" 
#>           Preis         Runtime          Rating       Consented       Collected 
#>       "numeric"       "numeric"       "integer"       "logical"       "POSIXct" 
#>          Status            Tags   Collaborators          Photos         Reports 
#>     "character"          "list"          "list"          "list"          "list" 
#>           Where        Homepage         Contact Temperatur (°C)         Doubled 
#>          "list"     "character"     "character"       "numeric"     "character" 
#>             Ref      Created by      Changed by         Created         Changed 
#>     "character"     "character"     "character"       "POSIXct"       "POSIXct" 
#>          Action       Signature             _id 
#>          "list"          "list"     "character"
```

## Next steps

- [`vignette("harbouR")`](https://cttir.github.io/harbouR/articles/harbouR.md) -
  the five-minute end-to-end story.
- [`vignette("explorer-app")`](https://cttir.github.io/harbouR/articles/explorer-app.md) -
  exploring a base interactively.
