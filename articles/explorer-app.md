# The harbouR explorer

[`hb_run_explorer()`](https://cttir.github.io/harbouR/reference/hb_run_explorer.md)
launches a Shiny app for working with a SeaTable base without writing
any R. Reach for it when you want to *see* what is in a base; reach for
the programmatic API
([`hb_read_table()`](https://cttir.github.io/harbouR/reference/hb_read_table.md),
[`hb_query()`](https://cttir.github.io/harbouR/reference/hb_query.md)
and friends) when you want to *do* something with the data.

The app and its UI dependencies (`shiny`, `bslib`, `reactable`) live in
`Suggests`, so the client itself stays headless. If something is
missing, the launcher names it.

## Open something

You can try the app right now with no SeaTable account and no network:

``` r

harbouR::hb_run_explorer()
```

Then choose **Use the example base** in the Source panel. It loads a
bundled `.dtable` holding one column of every type harbouR supports, so
every panel has something to show.

The Source panel takes three kinds of input:

- **A `.dtable` file.** Drop in a SeaTable export and work entirely
  offline. Nothing leaves your machine.
- **A server.** A URL and an API token. The token field is never
  pre-filled from your environment, because a value passed to a password
  input is written into the page’s HTML.
- **The example base**, above.

You can also hand the app something you already have:

``` r

harbouR::hb_run_explorer(harbouR::hb_read_dtable("my-base.dtable"))
harbouR::hb_run_explorer(harbouR::hb_client())
```

## The panels

The left rail lists every table in the base. Under each name is a band
of coloured segments - one per column, coloured by what kind of thing
the column holds. It is there so you can see the *shape* of a
sixty-column table before you open it: a table that is mostly
measurements looks different from one that is mostly text.

- **Data.** The table as a tibble, searchable and filterable.
  List-valued cells - attachments, multi-selects - are joined for
  display, because a cell shows one value. Set how many rows to read.
- **Schema.** Every column, the SeaTable type it holds, the R type
  harbouR reads it as, its four-character key, and whether it can be
  written. The colours match the bands in the rail.
- **Query.** A SeaTable SQL console. It needs a server: a `.dtable` is a
  file, not a database, and the panel says so rather than failing.
- **Export.** Download the base as `.dtable`, as an Excel workbook, or
  as zipped CSVs - or just the table you are looking at, as one CSV. The
  `.dtable` keeps everything; the spreadsheet formats flatten whatever a
  cell cannot hold, which the app tells you about.

## Colour

The palette is the package logo’s, which is viridis: colourblind-safe
and perceptually uniform. Column types are grouped into families - text,
quantity, time, choice, attachment, relationship, and the ones SeaTable
maintains itself - and each family keeps its colour everywhere in the
app, so the rail and the schema table read as one system.

## Next steps

- [`vignette("harbouR")`](https://cttir.github.io/harbouR/articles/harbouR.md) -
  the five-minute end-to-end story.
- [`vignette("column-types")`](https://cttir.github.io/harbouR/articles/column-types.md) -
  the coercion layer in detail.
