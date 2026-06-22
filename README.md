
<!-- README.md is generated from README.Rmd. Please edit that file. -->

# harbouR <img src="man/figures/logo.png" align="right" height="139" alt="harbouR logo"/>

<!-- badges: start -->

[![R-CMD-check](https://github.com/CTTIR/harbouR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/CTTIR/harbouR/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/CTTIR/harbouR/actions/workflows/pkgdown.yaml/badge.svg)](https://cttir.github.io/harbouR/)
[![CRAN
status](https://www.r-pkg.org/badges/version/harbouR)](https://CRAN.R-project.org/package=harbouR)
[![Codecov test
coverage](https://codecov.io/gh/CTTIR/harbouR/branch/main/graph/badge.svg)](https://app.codecov.io/gh/CTTIR/harbouR?branch=main)
[![CRAN
downloads](https://cranlogs.r-pkg.org/badges/harbouR)](https://cran.r-project.org/package=harbouR)
[![CRAN downloads
total](https://cranlogs.r-pkg.org/badges/grand-total/harbouR)](https://cran.r-project.org/package=harbouR)
[![License:
MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**harbouR** is an unofficial R client for the
[SeaTable](https://seatable.io) REST API. It lets you authenticate,
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
#> # A tibble: 2 × 4
#>   name     n_rows n_columns n_views
#>   <chr>     <int>     <int>   <int>
#> 1 Samples       0         7       1
#> 2 Patients      0         4       1

hb_example_rows("Samples")
#> # A tibble: 3 × 8
#>   Name  Concentration Status  Tags   Collected           Collaborators Reports
#>   <chr>         <dbl> <chr>   <list> <dttm>              <list>        <list> 
#> 1 S-001          12.4 draft   <chr>  2026-04-01 09:00:00 <chr [1]>     <list> 
#> 2 S-002           8.1 ready   <chr>  2026-04-03 12:30:00 <chr [2]>     <list> 
#> 3 S-003          21   shipped <chr>  2026-04-05 16:15:00 <chr [0]>     <list> 
#> # ℹ 1 more variable: `_id` <chr>
```

## Interactive explorer

`hb_run_explorer()` launches a Shiny app for inspecting any base
interactively, with a demo mode that needs no credentials.
