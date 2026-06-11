# Launch the harbouR explorer

Starts the bundled Shiny explorer app for inspecting a SeaTable base
interactively. Pass a connected `harbour_client` to skip the connect
screen, or run with no arguments to open the connect screen — which also
offers a fully offline demo mode powered by
[`hb_example_metadata()`](https://cttir.github.io/harbouR/reference/hb_example_metadata.md)
and
[`hb_example_rows()`](https://cttir.github.io/harbouR/reference/hb_example_rows.md).

## Usage

``` r
hb_run_explorer(client = NULL, ..., host = "127.0.0.1", port = NULL)
```

## Arguments

- client:

  Optional `harbour_client`. If `NULL`, the app opens its connect
  screen.

- ...:

  Forwarded to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

- host:

  Host to bind. Default `"127.0.0.1"`.

- port:

  Port. Default `NULL` (let Shiny choose).

## Value

Invisible `NULL`; launches a Shiny application.

## Details

The Shiny app and its UI dependencies (`shiny`, `bslib`, `DT`,
`reactable`, `ggplot2`) are in `Suggests`, not `Imports` — the core
client works headless. Missing dependencies produce a single informative
error rather than a stack trace.

## Examples

``` r
if (FALSE) { # interactive()
hb_run_explorer()
}
```
