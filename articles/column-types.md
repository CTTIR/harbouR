# Column types and coercion

harbouR maps SeaTable’s column types onto predictable R types, so the
tibble you get back is analysis-ready, not raw JSON. This vignette is
the reference.

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
| checkbox | logical | FALSE | FALSE | TRUE/FALSE; an unset box reads as FALSE |
| date | POSIXct | FALSE | FALSE | UTC; date-only columns have a zero time component |
| single-select | character | FALSE | FALSE | not validated on write: SeaTable adds an unknown name as a new option |
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
| digital-sign | list | TRUE | TRUE | signature metadata; not written, since it should come from the signer |
| creator | character | FALSE | TRUE | user email |
| last-modifier | character | FALSE | TRUE | user email |
| ctime | POSIXct | FALSE | TRUE | row creation time |
| mtime | POSIXct | FALSE | TRUE | row modification time |

Three of its rows are not column types of their own. `percent`, `dollar`
and `euro` are formats of a number column: SeaTable reports such a
column as type `number`, with the format in its `data`. They are listed
so that a table carrying them as a type still reads as numbers.

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

- `text` / `single-select` come back as `character`. A single-select
  value is not checked against the column’s options when you write it:
  SeaTable adds an unknown name as a new option, so a typo becomes one.
- `number` becomes a `double` (caveat: SeaTable’s numeric column is
  64-bit; large integers may round - if precision matters store them as
  text).
- `checkbox` becomes `logical`. A box that was never ticked reads as
  `FALSE`, as SeaTable shows it. When you write, harbouR sends the JSON
  `true` or `false` SeaTable needs: a number is ticked unless it is 0,
  and a string is read as
  [`as.logical()`](https://rdrr.io/r/base/logical.html) reads it, so
  `"TRUE"`, `"true"` and `"T"` tick the box and `"FALSE"`, `"false"` and
  `"F"` clear it. Any other non-empty string, `NA` and `NaN` are sent as
  empty, the string with a warning.
- `date` always becomes `POSIXct`, in UTC. In a date-only column - one
  whose format has no time - the value is midnight UTC on the date
  SeaTable shows, whatever the server’s time zone, so
  [`as.Date()`](https://rdrr.io/r/base/as.Date.html) gives that calendar
  date. A date-time column holds an instant: a server sends it with its
  UTC offset and harbouR converts it to UTC, while a `.dtable` stores it
  without one and harbouR reads it as UTC. A column that reports no
  format is read as a date-time. Written to a date-only column, a `Date`
  is sent as itself and a date-time as the date it shows in its own time
  zone, except one at exactly midnight UTC, which keeps its UTC date, so
  a cell read and written back keeps its day.

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

harbouR leaves columns of these types out of every write, so you can
round-trip a tibble through harbouR without writing back computed values
by accident.

``` r

subset(hb_column_types(), read_only)$seatable
#>  [1] "link"          "link-formula"  "formula"       "auto-number"  
#>  [5] "button"        "digital-sign"  "creator"       "last-modifier"
#>  [9] "ctime"         "mtime"
```

Most of them are computed or maintained by SeaTable. Links are kept
through SeaTable’s link endpoints rather than by writing the cell, and a
button carries no data. A `digital-sign` cell is left out for another
reason: a signature should come from the signer, not from a script.

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
