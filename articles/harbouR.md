# Get started with harbouR

You have a SeaTable base of patient samples and you want to pull it into
R for analysis, push your results back, and attach the resulting PDF
reports - all without leaving R. `harbouR` is an unofficial R client
that lets you do exactly that, against a **self-hosted SeaTable server**
or against an exported **`.dtable` file** with no server at all.

> SeaTable is a trademark of SeaTable GmbH; harbouR is not affiliated
> with or endorsed by SeaTable GmbH.

## Connect

``` r

library(harbouR)

client <- hb_client(
  server    = Sys.getenv("SEATABLE_SERVER"),
  api_token = Sys.getenv("SEATABLE_API_TOKEN")
)
```

SeaTable uses a three-token model. You hand harbouR either an API-token
(long-lived, per-base, generated in the SeaTable UI) or a
username+password pair. harbouR exchanges these for a short-lived
**base-token** the first time it needs to, caches it, and refreshes
transparently when it expires - you never see it.

## Inspect the base

The remaining chunks here all run **offline**, against the bundled
example data, so you can knit the vignette without a server.

``` r

library(harbouR)

meta <- hb_example_metadata()
meta
#> 
#> ── <harbour_metadata> ──────────────────────────────────────────────────────────
#> • base : "harbouR demo base"
#> • tables : 2
#> 
#> - Samples (7 cols, 1 views)
#> - Patients (4 cols, 1 views)

tibble::as_tibble(meta)
#> # A tibble: 2 × 3
#>   name     n_columns n_views
#>   <chr>        <int>   <int>
#> 1 Samples          7       1
#> 2 Patients         4       1
```

## Read a table

Against a live server this is a single call:

``` r

samples <- hb_read_table(client, "Samples")
```

The offline equivalent returns a tibble of the same shape, including
list-columns for multi-select / collaborator / file values:

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

## Analyse

`samples` is a regular tibble. Everything you already know about dplyr /
ggplot2 / etc. just works:

``` r

samples[samples$Status == "ready", c("Name", "Concentration", "Collected")]
#> # A tibble: 1 × 3
#>   Name  Concentration Collected          
#>   <chr>         <dbl> <dttm>             
#> 1 S-002           8.1 2026-04-03 12:30:00
```

## Write back

Appending and updating accept any tibble whose columns match the schema:

``` r

new_rows <- tibble::tibble(
  Name = "S-004",
  Concentration = 17.2,
  Status = "draft"
)
hb_append_rows(client, "Samples", new_rows)

hb_update_rows(
  client, "Samples",
  tibble::tibble(`_id` = "r0001", Concentration = 99.9)
)
```

## Attach a file

``` r

hb_attach_file(client, "Samples", "r0001", "Reports", "report.pdf")
```

## Next steps

- The `column-types` vignette explains the coercion layer in detail.
- The `explorer-app` vignette walks through
  [`hb_run_explorer()`](https://cttir.github.io/harbouR/reference/hb_run_explorer.md).

## Citation

If harbouR contributes to work you publish, please cite it:

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

The text and the BibTeX entry are both generated from the package
metadata, so they always match the version you have installed.

## Authors

harbouR is by Raban Heller, Paul Elsinghorst, Wiebke Derz, Matthias
Ring, Gerhard Achatz and Vinzent Forstmeier. It grew out of their needs,
field testing and data.

## Trademarks and affiliation

harbouR is an independent, third-party client. It is **not** affiliated
with, endorsed by, sponsored by, or officially connected to SeaTable
GmbH, and support requests about harbouR should go to its own issue
tracker rather than to SeaTable GmbH.

SeaTable is a trademark of SeaTable GmbH, 117er Ehrenhof 5, 55118 Mainz,
Germany (Amtsgericht Mainz, HRB 49723). harbouR uses the name only to
identify the service it communicates with and claims no right in the
mark.

harbouR contains no SeaTable server code; it speaks to a SeaTable server
through the public REST API documented at <https://api.seatable.com/>.
Your use of SeaTable itself is governed by your agreement with SeaTable
GmbH, not by this package’s licence.

The full notice is at
<https://github.com/CTTIR/harbouR/blob/main/NOTICE.md>.

## Acknowledgements

harbouR is a client, and it rests on work SeaTable GmbH and Seafile Ltd.
did first — in particular on their decisions about how open that work
would be.

They publish the OpenAPI 3.0 specification for the REST API as a public
repository, kept on one branch per server version, so the contract a
release promised remains available afterwards. The full reference reads
without an account or payment. The admin and developer manuals are
public repositories that accept pull requests. The official Python and
PHP clients are Apache-2.0.

They also write down what they break. The public API changelog recorded
that `/dtable-server` and `/dtable-db` were deprecated in 5.2 and
removed in 5.3. harbouR was aimed at exactly those endpoints; without
that entry this package would still be talking to an API that no longer
exists.

For accuracy: SeaTable Server is not open source — `dtable-server`, the
component holding the tables, is proprietary. The official clients and
SDKs are Apache-2.0. The API specification and reference are published
publicly but carry no open licence, and harbouR relies on none: it
reproduces no documentation prose, and it relies on the exclusion of the
ideas and principles underlying a program’s interfaces from copyright
protection (Art. 1(2), Directive 2009/24/EC; § 69a(2) UrhG; CJEU
C-406/10). SeaTable’s own dtable-server EULA points the same way —
applications using the API are “third-party software”, and “\[t\]he
provisions of the EULA do not apply to any such third-party software”.
This is reasoning, not legal advice; see `NOTICE.md` for its limits.

SeaTable is developed by Seafile Ltd. (Beijing); SeaTable GmbH (Mainz)
is the German company behind it. Thanks are owed to both.
