# The harbouR explorer

[`hb_run_explorer()`](https://r-heller.github.io/harbouR/reference/hb_run_explorer.md)
launches a Shiny app for inspecting a SeaTable base interactively. Reach
for it when you want to *see* what is in a base quickly; reach for the
programmatic API
([`hb_read_table()`](https://r-heller.github.io/harbouR/reference/hb_read_table.md),
[`hb_query()`](https://r-heller.github.io/harbouR/reference/hb_query.md)
and friends) when you want to *do* something with the data.

The app and its UI dependencies (`shiny`, `bslib`, `DT`, `reactable`,
`ggplot2`) live in `Suggests`, so the core client stays headless. If
something is missing, the launcher tells you exactly what to install.

## Demo mode

You can try the app right now with no SeaTable account:

``` r

harbouR::hb_run_explorer()
```

Then click **Try demo** on the connect screen. The app loads the same
example metadata and rows you saw in the `column-types` vignette -
including list-columns and a `file` column - so every panel is exercised
without a network call.

## The panels

- **Connect.** Server URL, API token (masked), optional base UUID. The
  values default to `SEATABLE_SERVER` and `SEATABLE_API_TOKEN`. Try demo
  bypasses this entirely.
- **Overview.** Value boxes for base name, table count and total rows; a
  `reactable` of the tables and a small ggplot of rows-per-table.
- **Tables.** The centrepiece. Pick a table; the app fetches it lazily
  via
  [`hb_read_table()`](https://r-heller.github.io/harbouR/reference/hb_read_table.md),
  caches it, and shows the typed tibble in a `reactable` with the
  column-type badges and list-column chips. A side panel lists every
  column’s SeaTable type and the R type it maps to.
- **Query.** A SeaTable SQL console, results in a `reactable`.

## Launching with a pre-built client

If you already have a `harbour_client`, hand it in and the app skips the
connect screen:

``` r

client <- harbouR::hb_client()
harbouR::hb_run_explorer(client)
```

## A note on screenshots

Screenshots for the panels are not bundled with this release - taking
them requires running the app, which `R CMD check` deliberately
prevents. The interactive demo above is the canonical reference.

## Next steps

- [`vignette("harbouR")`](https://r-heller.github.io/harbouR/articles/harbouR.md) -
  the five-minute end-to-end story.
- [`vignette("column-types")`](https://r-heller.github.io/harbouR/articles/column-types.md) -
  the coercion layer in detail.
