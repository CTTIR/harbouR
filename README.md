<!-- README.md is generated from README.Rmd. Please edit that file. -->

# harbouR <img src="man/figures/logo.png" align="right" height="139" alt="harbouR logo"/>

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![R-CMD-check](https://github.com/r-heller/harbouR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/r-heller/harbouR/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/r-heller/harbouR/branch/main/graph/badge.svg)](https://app.codecov.io/gh/r-heller/harbouR?branch=main)
<!-- badges: end -->

**harbouR** is an unofficial R client for the
[SeaTable](https://seatable.io) REST API. It lets you authenticate,
read, write and manage SeaTable bases entirely from R, with results
returned as tidy tibbles and a column-type-aware coercion layer that
makes spreadsheets feel like data frames.

> SeaTable is a trademark of SeaTable GmbH; this package is not
> affiliated with or endorsed by SeaTable GmbH.

## Installation

```r
# install.packages("pak")
pak::pak("r-heller/harbouR")
```

## Quick example

```r
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

```r
library(harbouR)

meta <- hb_example_metadata()
tibble::as_tibble(meta)
#> # A tibble: 2 x 4
#>   name     n_rows n_columns n_views
#>   <chr>     <int>     <int>   <int>
#> 1 Samples       0         7       1
#> 2 Patients      0         4       1

hb_example_rows("Samples")
```

## Interactive explorer

`hb_run_explorer()` launches a Shiny app for inspecting any base
interactively, with a demo mode that needs no credentials.
