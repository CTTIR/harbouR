# harbouR

**harbouR** is an unofficial R client for the
[SeaTable](https://seatable.com/) REST API. It lets you authenticate,
read, write and manage SeaTable bases entirely from R, with results
returned as tidy tibbles and a column-type-aware coercion layer that
makes spreadsheets feel like data frames.

> SeaTable is a trademark of SeaTable GmbH; this package is not
> affiliated with or endorsed by SeaTable GmbH.

## Installation

``` r

# install.packages("pak")
pak::pak("CTTIR/harbouR")
```

## Quick example

``` r

library(harbouR)

client <- hb_client(
  server    = Sys.getenv("SEATABLE_SERVER"),
  api_token = Sys.getenv("SEATABLE_API_TOKEN")
)

hb_list_tables(client)
samples <- hb_read_table(client, "Samples")
samples |>
  dplyr::filter(.data$Status == "ready") |>
  dplyr::arrange(.data$Collected)
```

Everything in harbouR also works fully offline against bundled example
data — handy for exploring the data model before you connect anything:

``` r

library(harbouR)

meta <- hb_example_metadata()
tibble::as_tibble(meta)
#> # A tibble: 2 × 3
#>   name     n_columns n_views
#>   <chr>        <int>   <int>
#> 1 Samples          7       1
#> 2 Patients         4       1

hb_example_rows("Samples")
#> # A tibble: 3 × 8
#>   Name  Concentration Status  Tags   Collected           Collaborators Reports
#>   <chr>         <dbl> <chr>   <list> <dttm>              <list>        <list> 
#> 1 S-001          12.4 draft   <chr>  2026-04-01 09:00:00 <chr [1]>     <list> 
#> 2 S-002           8.1 ready   <chr>  2026-04-03 12:30:00 <chr [2]>     <list> 
#> 3 S-003          21   shipped <chr>  2026-04-05 16:15:00 <chr [0]>     <list> 
#> # ℹ 1 more variable: `_id` <chr>
```

## Working offline

harbouR reads and writes SeaTable’s own `.dtable` export, so an analysis
can run with no server at all. The same verbs work either way:

``` r

path <- system.file("extdata", "example.dtable", package = "harbouR")
base <- hb_read_dtable(path)

hb_list_tables(base)
#> # A tibble: 2 × 4
#>   name      n_rows n_columns n_views
#>   <chr>      <int>     <int>   <int>
#> 1 Samples        2        27       1
#> 2 Reference      2         2       1
hb_read_table(base, "Samples")[, 1:4]
#> # A tibble: 2 × 4
#>   Name  Notes                        Concentration Share
#>   <chr> <chr>                                <dbl> <dbl>
#> 1 S-001 A plain **markdown** string.      0.000587  0.42
#> 2 S-002 Rendered elsewhere.               8.1      NA
```

Writing one back is lossless, and
[`hb_dtable()`](https://cttir.github.io/harbouR/reference/hb_dtable.md)
builds a base out of ordinary data frames so you can import R results
into SeaTable:

``` r

hb_write_dtable(base, "my-base.dtable")

hb_dtable(Measurements = my_data) |>
  hb_write_dtable("for-seatable.dtable")
```

## Interactive explorer

[`hb_run_explorer()`](https://cttir.github.io/harbouR/reference/hb_run_explorer.md)
launches a Shiny app for inspecting any base interactively, with a demo
mode that needs no credentials.

## Roadmap

harbouR covers the parts of the SeaTable API you need to get data in and
out: authentication, metadata, rows, tables, columns, views and files.
Not yet wrapped, in rough order of intent:

- **Link columns** - reading and writing row-to-row relationships.
- Comments, snapshots, big-data (archive) storage, share links and
  webhooks.
- Server-side import/export, and the admin, team and scheduler
  endpoints.

Earlier releases exported these as stubs that raised “not yet
implemented”. They no longer exist: a function you can call is a promise
that it works. Track progress or request one at
<https://github.com/CTTIR/harbouR/issues>.

## Citation

If harbouR contributes to work you publish, please cite it. The entry is
generated from the package metadata, so it always matches the version
you have installed:

``` r

citation("harbouR")
#> To cite harbouR in publications, please use:
#> 
#>   Heller R, Elsinghorst P, Derz W, Ring M, Achatz G, Forstmeier V
#>   (2026). _harbouR: R Client for SeaTable Collaborative Databases_. R
#>   package version 0.1.0, <https://github.com/CTTIR/harbouR>.
#> 
#> A BibTeX entry for LaTeX users is
#> 
#>   @Manual{,
#>     title = {{harbouR}: R Client for {SeaTable} Collaborative Databases},
#>     author = {Raban Heller and Paul Elsinghorst and Wiebke Derz and Matthias Ring and Gerhard Achatz and Vinzent Forstmeier},
#>     year = {2026},
#>     note = {R package version 0.1.0},
#>     url = {https://github.com/CTTIR/harbouR},
#>   }
```

## Authors

harbouR is by Raban Heller, Paul Elsinghorst, Wiebke Derz, Matthias
Ring, Gerhard Achatz and Vinzent Forstmeier. It grew out of their needs,
field testing and data.

## Trademarks and affiliation

harbouR is an independent, third-party client. It is **not** affiliated
with, endorsed by, sponsored by, or officially connected to SeaTable
GmbH. Please raise anything about harbouR
[here](https://github.com/CTTIR/harbouR/issues), not with SeaTable GmbH.

SeaTable is a trademark of SeaTable GmbH, 117er Ehrenhof 5, 55118 Mainz,
Germany (Amtsgericht Mainz, HRB 49723). harbouR uses the name only to
identify the service it talks to, claims no right in the mark, and ships
none of SeaTable GmbH’s logos or brand assets — the harbouR logo is an
original work.

harbouR contains no SeaTable server code. It communicates with a
SeaTable server through the public REST API that SeaTable GmbH
[documents](https://api.seatable.com/) for third-party applications.
Your use of SeaTable itself is governed by your agreement with SeaTable
GmbH, not by this package’s licence, and harbouR is provided without
warranty (see [LICENSE](https://cttir.github.io/harbouR/LICENSE.md)).

harbouR exists because SeaTable GmbH built the platform and chose to
document its API openly. If SeaTable is useful to you, support them at
<https://seatable.com/>.

The full notice is in
[NOTICE.md](https://cttir.github.io/harbouR/NOTICE.md).
