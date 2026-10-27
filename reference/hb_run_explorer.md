# Launch the harbouR explorer

A Shiny app for working with a SeaTable base without writing code: open
a local `.dtable` export or connect to a server, browse the tables, read
the schema, run SQL, and download the result as `.dtable`, Excel or CSV.

## Usage

``` r
hb_run_explorer(x = NULL, ..., host = "127.0.0.1", port = NULL)
```

## Arguments

- x:

  Optional `harbour_client` or `harbour_dtable` to open with.

- ...:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

- host:

  Host to bind. Default `"127.0.0.1"`.

- port:

  Port. Default `NULL`, letting Shiny choose.

## Value

Invisible `NULL`; launches a Shiny application.

## Details

Pass a connected
[`hb_client()`](https://cttir.github.io/harbouR/reference/hb_client.md)
or a base read with
[`hb_read_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_dtable.md)
to start there. With no argument the app opens on its source panel,
which offers a bundled example base that needs no credentials and no
network.

The UI packages (`shiny`, `bslib`, `reactable`) are in `Suggests`, so
the client itself stays headless. A missing one, or a `bslib` older than
0.6.0, produces a single informative error rather than a stack trace.
The Excel download also needs `writexl`; without it the app says so when
you ask for one.

Shiny refuses uploads over 5 MB by default, and a `.dtable` with
attachments is often larger, so while the app runs it accepts files up
to 1 GB. To choose another limit, set the `shiny.maxRequestSize` option,
in bytes, before calling `hb_run_explorer()`; a value you have set is
left as it is.

## Examples

``` r
if (FALSE) { # interactive()
# the bundled example base, no credentials needed
hb_run_explorer()

# or start from a file, with its attachments, so that a .dtable
# download keeps them
path <- system.file("extdata", "example.dtable", package = "harbouR")
hb_run_explorer(hb_read_dtable(path, assets = "extract"))
}
```
