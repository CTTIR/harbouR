# harbouR 0.1.0

First release.

* **A write is no longer sent twice after a server error.** Every request
  was retried after a 500, 502, 503 or 504, so an append that a proxy
  gave up on after the server had applied it could store its rows twice.
  `POST`, `PUT` and `DELETE` requests are now retried only after a 429,
  which means the server declined them; `GET` requests keep their
  retries. `hb_query()` sends all SQL as `POST`, so a `SELECT` that meets
  a 5xx now fails at once as well.

* **A base token is renewed before it lapses.** The API gateway refuses an
  expired base token with HTTP 403 "invalid token", and harbouR renewed it
  only after a 401, so a client older than the token's three days failed
  every base call with `harbour_error_permission`. The token is now
  renewed a few minutes before the expiry it carries, and once more after
  a 403 "invalid token"; any other 403 is still not retried.
  `hb_check_credentials()` on a username/password client also drops the
  cached base token once the login succeeds.

* **Date-only cells read from a server no longer land on the day before.**
  SeaTable sends such a cell as midnight in the server's time zone, with
  its offset (`2030-06-20T00:00:00+02:00`), and harbouR converted that
  instant to UTC, so on any server east of UTC `hb_read_table()`,
  `hb_get_row()` and `hb_query()` returned the evening before. A `date`
  column whose format has no time now reads as midnight UTC on the date
  SeaTable shows, and is written as `YYYY-MM-DD`, so reading a cell and
  writing it back keeps its day on either side of UTC. Date-time cells,
  dates stored without an offset (as in a `.dtable`) and columns that
  report no format read as before.

* Security:

  * `hb_read_dtable(assets = "extract")` extracted whatever names an
    archive held, so a crafted `.dtable` - the explorer opens uploads
    this way - could write files outside `assets_dir`, `~/.Rprofile`
    among them. An archive whose asset entries are absolute, climb out
    with `..` or are symbolic links is now refused before anything is
    extracted, and only entries under `asset/` count as assets.
  * A `content.json`, or a server's reply, that is a short string rather
    than JSON is no longer read as a file path or fetched as a URL, which
    `jsonlite::fromJSON()` does with such a string. It is parsed as JSON
    text only.
  * `print()` on a client ran any `{...}` in the base name or server URL
    as R code, and so did `hb_write_dtable()` with a table name when it
    refused a base. Both now show the text as it is.
  * The error from a request that got no answer held the client's API
    token, password and cached tokens, so saving it - with `saveRDS()`,
    or by returning it from a parallel worker - wrote them out. It no
    longer holds them. A malformed `api_token` or `password` is no longer
    shown in `hb_client()`'s error message.

* Errors:

  * Credentials the server refuses raise `harbour_error_auth`, as
    `hb_check_credentials()` documents. A wrong password (HTTP 400)
    raised `harbour_error_http` with "SeaTable returned an error.", and
    an unknown API token (HTTP 403) `harbour_error_permission`. The old
    class is kept alongside, and the message passes on the server's
    reason.
  * A server that cannot be reached - a refused connection, a DNS or TLS
    failure, a timeout - raises `harbour_error_http` with `status` `NA`
    from every function, not only `hb_ping()`. It escaped as httr2's
    bare `httr2_failure`; that class is kept, so handlers written for it
    still match.
  * `?"harbouR-conditions"` now lists the warning classes, and says that
    argument-matching errors from rlang keep the classes rlang gives
    them.

* Reading from a server:

  * `hb_query()` returned every column of a join as `NA`: SeaTable keys
    the cells of a join by column key whatever `convert_keys` says. They
    are now read by key, under the names the server reports.
  * `hb_read_table()` through a view returns the columns the view hides
    as `NA`, because SeaTable leaves them out of the rows. That looked
    like empty data; it now warns, naming them.
  * `hb_read_table()` gave up after 1000 requests whatever their size, so
    with a small `page_size` a large table was an error, and so was one
    ending exactly on the limit. The limit is now about ten million rows,
    a read that ends on it completes, and a server that returns the same
    page twice is stopped at once.
  * `hb_query()`'s warning about a missing `LIMIT` came at most once
    every eight hours across all queries, so later ones were cut to 100
    rows without a word, and the word *limit* anywhere in the SQL
    silenced it. It is now rate-limited per query and ignores quoted
    strings and back-ticked names.
  * Reading a table whose date cells repeat is faster: each distinct date
    string in a column is parsed once, and pages are combined once at the
    end rather than on every request.

* Writing to a server:

  * A checkbox is sent as a JSON boolean. A 0/1 column, which is how
    `read.csv()` and most exports store a flag, went out as numbers,
    which SeaTable stores as unticked. A string that is neither `TRUE`
    nor `FALSE` is sent as empty, with a warning, rather than guessed.
  * The file object `hb_upload_file()` returns, written as
    `tibble(Reports = list(obj))`, went out as an array of its fields; it
    is now the array of objects a file cell holds. A named vector of
    image URLs, one `hidden_columns` key in `hb_update_view()`, named row
    ids in `hb_lock_rows()` and `hb_unlock_rows()`, and named `parameters`
    in `hb_query()` all went out as JSON objects or strings rather than
    arrays.
  * `Inf`, `-Inf` and `NaN`, which JSON cannot hold, are still sent as
    `null`, but now with one warning per write naming the columns. A
    `difftime` written to a duration column is sent in seconds, the unit
    SeaTable stores; 90 minutes went out as 90. `hb_update_rows()` now
    serialises through the same path as `hb_append_rows()`.
  * `hb_update_column()` with only `column_data` named the type from the
    cached schema, so a column whose type had changed since was converted
    back. It now asks the server.

* Files:

  * `hb_download_file()` recognised an asset URL only when it began with
    the client's `server` exactly as typed. A relative URL, the form
    SeaTable writes into cells, failed, and a host in other capitals,
    `http` for `https` or an explicit `:443` was fetched directly, saving
    SeaTable's login page as the file. Asset URLs are now recognised by
    their path, and a download that ends on the login page fails.
  * The download and delete endpoints act on the client's base whatever
    a URL names, so a URL from another base downloaded, or deleted, this
    base's file at the same path. `hb_download_file()` and
    `hb_delete_asset()` now refuse a URL of another base or server, and
    `hb_delete_asset()` refuses one that names no file - the server
    itself, or an asset URL cut short - instead of asking to delete the
    asset root.
  * `hb_upload_file()` escapes the folders of a custom `relative_path`
    like the file name, and its file object has the type `"file"`, as
    SeaTable's own file cells do, rather than a MIME type. Its help says
    what the default `relative_path = "files"` stands for.

* The client:

  * Logging in and exchanging an API token work for a server reached
    under a path, such as `https://example.org/seatable`; both went to
    the root of the host.
  * `hb_client()` refuses a `workspace_id`, `base_name` or `timeout` that
    could not work, instead of failing at the first request, and sends a
    round workspace id such as `1e5` as `100000` rather than `1e+05`. A
    username/password client remembers the base it named, so
    `hb_metadata()$base_name` is its name rather than `NA`.

* `.dtable` files:

  * `hb_write_dtable()` builds the archive beside its destination and
    moves it into place once complete, so a failed write cannot destroy
    the file it replaces, even the one the base was read from. The bytes
    written are the same. An asset that cannot be copied stops the write,
    and links in the asset tree are left out, with a warning, instead of
    followed.
  * Text in a `.dtable` read in a session that is not UTF-8 - `Rscript`
    under cron, or a container with `LANG` unset - came back mangled, and
    `hb_write_dtable()` then saved it that way. It now reads as it does
    in a UTF-8 session.
  * `print()` and the warning about assets that will not be written
    counted the archive's folders as assets: the example showed 7 for its
    2 files.
  * On a `.dtable`, `hb_read_table(view = )` applies none of the view's
    filters or sorts, which its help now says; a filtered view that
    records no rows warns that every row was returned.

* CSV and Excel:

  * Re-importing an export gave a base none of whose tables could be
    read: the exported `_id` became an ordinary column. `hb_read_csv()`
    and `hb_read_xlsx()` now drop it.
  * `hb_read_csv()` kept `read.csv()`'s type guessing, which ignores
    quoting, so `"0001"` came back as `1` - the auto-number column of an
    export among them - and a 19-digit barcode was rounded. A column
    holding an integer with a leading zero, or one of more than 15
    digits, now stays text; every other column is typed as before. The
    help now says that dates arrive as text and that a literal `NA` is
    read as missing.
  * `hb_read_csv()` refuses a file that is not UTF-8, naming the line; a
    Windows-1252 file, as Excel's plain "CSV" often is, was cut off at
    its first accented letter. An empty file is refused, naming it, and
    an empty column is text rather than a checkbox reading `FALSE` in
    every row.
  * `hb_read_xlsx()` judges a column's type by every row of the sheet.
    `readxl` looked at the first 1000, and later values that did not fit
    were lost.
  * A file or sheet named `collaborators` or `base_name` imports as a
    table; the first used to vanish into the base's collaborator list.
    `hb_write_xlsx()` refuses table names that differ only in case, which
    Excel cannot hold as separate sheets. The flattening message names
    every column instead of the first 20, and the help lists every loss
    the exports make.

* The explorer:

  * "This table as CSV" held only the rows the Data panel had loaded,
    1000 by default; it now holds the whole table. The zipped CSV left
    out any table whose name starts with a dot.
  * The Export panel said a `.dtable` keeps everything. For a live base
    that file is rebuilt from the rows, so column types are inferred
    again and select options, attachments and views are lost; for a file
    opened without its assets, the attachments are left out. The panel
    now says which applies, and a live base's `.dtable` download shows a
    notification. That download also kept a table named `collaborators`
    out of the file, and failed on one named `base_name`.
  * A failed download is reported in the app rather than only in the R
    console, and a missing `writexl` is named instead of prompting at
    the console. The Query panel says, on every query without `LIMIT`,
    that SeaTable returned at most 100 rows. The app accepts uploads up
    to 1 GB while it runs, unless `shiny.maxRequestSize` is set: the
    5 MB that Shiny allows by default refused most real exports.

* Documentation and tests:

  * The API lock pins the signatures of the registered S3 methods as
    well as the exports: the arguments users pass to `hb_read_table()`
    and the `hb_list_*()` verbs belong to the methods, not the generics,
    so a changed default there passed the lock. The new section matches the
    manuscript anchor exactly.
  * Golden tests pin what the offline paths return: every column of the
    bundled example as read, `hb_column_types()`, the example data, the
    `.dtable` and CSV files the writers produce, and what the CSV and
    Excel exports read back as.
  * pkgdown builds the citation page from the source `DESCRIPTION`, so it
    cited the maintainer alone; it now lists all six authors.
  * `hb_column_types()` corrects three notes: single-select values are
    not validated on write (SeaTable adds an unknown name as a new
    option), an unset checkbox reads as `FALSE`, and digital-signature
    cells are left out of writes because a signature should come from
    the signer. Its help says `percent`, `dollar` and `euro` are number
    formats, which SeaTable reports as type `number`, rather than column
    types.
  * The examples and README read the example file with
    `assets = "extract"` before writing it back, the `hb_asset_path()`
    example resolves a file the example holds, and `hb_dtable()`'s help
    notes that building a base advances `.Random.seed`. The help no
    longer says `hb_append_rows()`'s reply lacks the new rows' ids, nor
    that the example rows cover every column type.
  * The explorer's tests skip rather than error without `readxl`,
    `shiny` or `htmltools`, and two static checks that skipped in every
    CI job now run there. The live-server tests compare harbouR's reads
    with what the server sent, and delete only the row they created.

* Audited the server wrappers against SeaTable's published OpenAPI
  specification (v6.2) and the server responses recorded in its test
  suite. The mocked tests could only prove that harbouR built the
  request it intended; several of those requests were not the ones the
  server expects:

  * `hb_read_table()` and `hb_get_row()` now send `convert_keys=true`.
    The server's default keys every cell by column key, so a live read
    came back with every column `NA`.
  * `hb_create_view()`, `hb_get_view()`, `hb_update_view()` and
    `hb_delete_view()` name the table in the query string, where the
    server reads it, rather than in the body. `hb_list_views()` and
    `hb_get_view()` recognise the default view by its id, because the
    server reports no `is_default`.
  * `hb_upload_file()`, `hb_delete_asset()` and `hb_download_file()`
    authenticate with the API token, as SeaTable's file endpoints
    require, instead of a base token. `hb_download_file()` exchanges an
    asset URL for a download link first - fetching a cell's URL
    directly saved SeaTable's login page - and writes through a
    temporary file, so a failed download leaves nothing behind and does
    not destroy the file it was asked to replace.
  * `hb_attach_file()` writes the shape each column holds: a file
    object, wrapped in the array a file cell is, or the URL for an
    image column. It refuses other column types.
  * `hb_add_columns()` accepts `name`/`type` specs like
    `hb_create_table()`; they were sent verbatim, with field names the
    server does not read. `hb_update_column()` with only `column_data`
    names the column's current type, which the server requires.

* Every HTTP error whose body parsed as JSON - most of them - crashed
  with "Can't supply conflicting bodies" from `rlang::abort()` instead of
  raising a `harbour_error`, because the body was stored in the field
  `abort()` reserves for its own use. It is now `response_body`. The server's
  message is shown whether it arrives as `error_msg`, `error_message`
  or plain text. The test fixture could not be parsed, which is how this
  went unnoticed.

* A missing number in `hb_append_rows()` or `hb_update_rows()` was sent
  as the string `"NA"`; it is now `null`.

* Geolocation and digital-signature cells keep their field names when
  read, and geolocation cells are written back as objects. Unnamed, a
  location read as `list(50, 8.23)` and was written as `[50, 8.23]`.

* An empty multiple-select cell read from a `.dtable` is `character(0)`,
  matching a populated one; it was `logical(0)`.

* `hb_dtable()` stores select cells as option ids, as SeaTable's own
  files do, and creates options for multiple-select columns. Cells held
  option names, which harbouR read back correctly but SeaTable showed
  as empty. List-columns of objects are flattened to text rather than
  becoming nonsense select options.

* `hb_append_rows()` warns about columns the table does not have, which
  it drops; it used to drop them silently. Row-id verbs refuse missing
  or empty ids, and `hb_query(convert_keys = FALSE)` reads cells by key.

* Final minor refinements: constrain bundled asset paths to their extraction
  directory and reject colliding CSV filenames before writing files.
* Exclude local administration and repository citation metadata from source
  builds, and use the repository citation URL until the archival record is
  publicly available.

harbouR is an unofficial R client for the SeaTable REST API. It
connects to a SeaTable server, reads and writes rows as tidy
tibbles, manages tables, columns and views, uploads and attaches
files, reads and writes local `.dtable` exports with no server at
all, and ships a Shiny explorer for doing all of that without
writing code.

The notes below record what changed during development, against an
0.1.0 that was tagged but never published.

* The maintainer address is now `raban.heller@uni-ulm.de`, and `URL` /
  `BugReports` point at <https://github.com/CTTIR/harbouR>, which is where
  the package actually lives. Paul Elsinghorst, Wiebke Derz, Matthias Ring,
  Gerhard Achatz and Vinzent Forstmeier are credited as contributors.

* `hb_example_metadata()` now reads the demo base from
  `inst/extdata/example_metadata.json` rather than duplicating it in R
  source, so there is a single definition to maintain.

* HTTP 404 responses now name the failing endpoint instead of erroring
  while trying to format the message.

* `httptest2` has been dropped from `Suggests`: it was never used, and its
  absence turned `R CMD check` red on any machine without it. HTTP is
  replaced at the package's own request seam instead.

* Errors now carry condition classes under a shared `harbour_error`, so
  they can be caught by kind rather than by message text. See
  `?"harbouR-conditions"`. HTTP errors carry `status`, `url` and
  `response_body`.

* A `403` response is no longer retried as though the base token had
  expired. A `401` triggers a refresh, and so does a `403` that says the
  token itself is invalid.

* `hb_ping()` and `hb_server_info()` no longer send an `Authorization`
  header. Both endpoints are unauthenticated, and demanding an API token
  made them fail for username/password clients - exactly the case where
  checking connectivity matters most.

* `hb_ping()` now returns the client invisibly rather than `TRUE`, so it
  composes: `client |> hb_ping() |> hb_read_table("Samples")`. New
  `hb_check_credentials()` covers the other half of the old behaviour -
  proving the credentials are accepted, not just that the server is up.

* Reading a table whose schema contains a column literally named `_id` now
  errors with a `harbour_error_column_collision` condition instead of
  silently overwriting it with the SeaTable row identifier.

* `hb_run_explorer()` restores the previous value of the
  `harbouR_preset_client` Shiny option when it exits. A client carrying a
  plaintext token used to stay reachable in process-global state for the
  rest of the session.

* **Every base-scoped request now addresses a real resource.** The base
  UUID was captured from the token exchange and then never interpolated
  into a URL, so all 24 base-scoped paths pointed at a collection with no
  base identifier. `hb_metadata()` additionally used a service prefix,
  `/dtables/api/v1/`, that does not exist - and because every other
  function lazily depends on it, its failure cascaded to all of them.

* **harbouR now targets the SeaTable API gateway.** `/dtable-server/` and
  `/dtable-db/` were deprecated in SeaTable 5.2 and removed in 5.3;
  harbouR addressed them exclusively. Base operations move to
  `/api-gateway/api/v2/dtables/{base_uuid}/`, which also collapses the
  three-host service switch to one. Base tokens are sent as `Bearer`,
  which is what the gateway expects; the web API keeps `Token`.
  **This requires SeaTable 5.3 (June 2025) or newer.**

## Legal position

* `NOTICE.md`, the README, the vignette and `?harbouR` now cite the basis
  on which harbouR uses SeaTable's interface, rather than implying it
  rests on a licence grant. Endpoint paths, HTTP verbs and JSON field
  names are the ideas and principles underlying an interface, excluded
  from copyright protection by Article 1(2) of Directive 2009/24/EC and
  by the CJEU in *SAS Institute v World Programming* (C-406/10) - which
  was referred, on these facts, the question whether a program may be
  written to read and write another's data file format.

* They also cite the clause in SeaTable's own dtable-server EULA that
  defines applications communicating over the API as "third-party
  software" and states that the EULA's provisions "do not apply to any
  such third-party software".

* Two factual corrections: the per-component licences previously
  attributed to SeaTable Server could not be verified from the
  repositories, and the API specification is published publicly but is
  not openly licensed. Both statements are gone. The one verbatim
  quotation in the package is now attributed to its source.

* The wording is deliberately narrow. harbouR *relies on* the interface
  exclusion rather than asserting that it settles the question, because
  it does not settle everything: the CJEU reserved the possibility that
  a data file format could attract ordinary copyright as a work
  (C-406/10, para. 45), and § 69g(1) UrhG leaves unfair competition,
  trade secrets, trademarks and contract untouched. Both limits are
  stated in `NOTICE.md`, along with the fact that none of this is legal
  advice.

## Scope

* harbouR is stated, throughout, as being for two things: **SeaTable
  `.dtable` data files**, read and written directly with no server; and
  **a SeaTable Server you run yourself**, over its REST API. The Title
  and Description say so, and there is a "What harbouR is for" section in
  the README and in `?harbouR`.

* The explorer's server field no longer pre-fills a vendor-hosted
  address; it is empty, with a neutral placeholder, unless
  `SEATABLE_SERVER` is set. The documented
  examples for `hb_client()` and for the live tests use a self-hosted
  URL.

* Nothing here restricts where you point the package. `hb_client()`
  takes a server URL as an argument and makes no judgement about the
  host; the scope statement describes what harbouR is built and
  documented for, not what it will refuse to do.

## Acknowledgement

* New Acknowledgements section in the README, the introductory vignette
  and `?harbouR`, naming what SeaTable GmbH and Seafile Ltd. built that
  made an independent client possible: a publicly published OpenAPI
  specification kept per server version, a reference readable without an
  account, manuals in repositories that accept pull requests,
  Apache-2.0 client libraries, a Developer Edition you can host yourself - and a changelog that records removals as plainly as
  additions. That last one is not abstract: it is how harbouR learned it
  had been aimed at endpoints removed in SeaTable 5.3.

  The section is careful about what it does and does not claim: SeaTable
  Server is not open source, and it says so. A later adversarial review
  found two assertions in the first version of this text that were not
  in fact supported by their sources - the per-component licences of
  SeaTable Server, and the claim that the API specification is "openly
  licensed" - and both have been corrected. harbouR needs no licence to
  the specification: endpoint paths, verbs and field names are excluded
  from copyright protection as the ideas underlying an interface.

## Authorship and citation

* Paul Elsinghorst, Wiebke Derz, Matthias Ring, Gerhard Achatz and
  Vinzent Forstmeier are credited as **authors** (`aut`), not
  contributors.

* New `inst/CITATION`, so `citation("harbouR")` produces a proper
  reference and BibTeX entry naming every author. It reads the package's
  own metadata, so the authors, version and year cannot drift out of
  step with `DESCRIPTION`. README and the introductory vignette both
  carry a Citation section.

## Fixes from the post-rewrite audit

* **Security:** the explorer's Schema tab rendered a column's type string
  as raw HTML. A `.dtable` carrying a crafted type could run script in a
  session that may hold the user's API token. The type is now escaped.

* **Data loss:** `hb_write_dtable()` dropped the bundled `asset/` tree
  unless the base had been read with `assets = "extract"`, producing an
  archive whose attachment cells pointed at files it did not contain. The
  explorer now extracts on open, and the writer warns rather than
  discarding silently.

* Exporting a live base to `.dtable` wrote `_id` as an ordinary column,
  which then collided with the reserved name on read - the export could
  not be re-opened. System fields are dropped first.

* `hb_update_rows()` threw a bare "subscript out of bounds" for any column
  not in the table's schema, which is what
  `hb_read_table() |> mutate() |> hb_update_rows()` produces. It now names
  the offending column. It also drops server-computed columns, which
  `hb_append_rows()` already did.

* `hb_duplicate_table()` sent an undocumented `new_table_name` and omitted
  the required `is_duplicate_records`. It gains `duplicate_records` and
  documents that SeaTable always names the copy `<original>(copy)`,
  with no space.

* `hb_create_table()` documented column specs as `name`/`type` while the
  API wants `column_name`/`column_type`, so following the package's own
  example produced a body the server rejects. Both spellings now work.

* `hb_client()` and `hb_read_dtable()` validate their arguments before
  using them, so a wrong type gives a classed harbouR error rather than a
  raw R one.

* Writing `Inf` or `NaN` to a `.dtable` warns. JSON cannot hold them, so
  they become `null` and read back as `NA`; that is now visible.

* The endpoint contract test pins request-body field names as well as
  paths. Renaming a body field previously left the suite green.

## The explorer

* **The Shiny app has been rebuilt, and it lives in `R/`.** It was under
  `inst/`, where `R CMD check`, `covr` and `lintr` could not see it - which
  is how it came to use an operator that does not exist on three of the
  four R versions the package claims to support. Its logic is now driven
  headlessly by `shiny::testServer()` in the test suite, and `codecov.yml`
  no longer hides it from the coverage number.

* `hb_run_explorer()` opens a local `.dtable`, connects to a server, or
  loads a bundled example base that needs no credentials and no network.
  Its first argument takes either a `harbour_client` or a
  `harbour_dtable`.

* Everything is reachable without code: browse tables, read the schema,
  run SQL, and download the base as `.dtable`, Excel or zipped CSV - or
  the open table as a single CSV.

* The palette is the package logo's, which is viridis. Column types are
  grouped into families, each keeping one colour throughout, and every
  table in the sidebar carries a band showing its columns by family - so
  the shape of a sixty-column table is legible before you open it.

* The API token field is never pre-filled from the environment. A value
  passed to a password input is serialised into the page's HTML.

## Local `.dtable` files

* **harbouR reads and writes SeaTable `.dtable` exports.**
  `hb_read_dtable()` opens one; `hb_write_dtable()` writes it back.
  Round-tripping is lossless, verified against a real 750 KB export: read
  then write then read yields an identical structure, including fields
  harbouR does not model.

* The same verbs work on a file as on a live base. `hb_list_tables()`,
  `hb_list_columns()`, `hb_list_views()` and `hb_read_table()` are now S3
  generics with `harbour_client` and `harbour_dtable` methods, so an
  analysis can be written once and run either way. Their first argument is
  named `x`; the write verbs keep `client`, because they need a server.

* `hb_dtable()` builds a base from R data frames, inferring column types,
  so a set of tables can be written out and imported into SeaTable.
  `hb_validate_dtable()` reports what would stop a base importing, and the
  writer refuses to produce a file that would fail.

* `hb_write_xlsx()` and `hb_write_csv()` export to spreadsheets, naming
  exactly which columns had to be flattened; `hb_read_xlsx()` and
  `hb_read_csv()` build a new base from them. The lossy direction is
  documented rather than implied.

* Select-option ids are translated to their display names, because a file
  stores the id where the API returns the name - without this a local read
  and a server read of the same column disagreed.

* `hb_asset_path()` resolves a bundled `file://dtable-bundle/` URL to a
  local file when the base was read with `assets = "extract"`.

## The SeaTable API

* `hb_query()` types its result from the schema SeaTable returns alongside
  the rows, which harbouR previously discarded. It inferred types from the
  values instead, so an all-`NULL` column came back `logical` and one stray
  string turned a numeric column into `character` - the same query could
  return different types on different days. `hb_query()` and
  `hb_read_table()` now agree.

* `hb_query()` warns when the SQL has no `LIMIT` clause, because SeaTable
  applies an implicit `LIMIT 100`, and gains `parameters` for `?`
  placeholders and `convert_keys`.

* **The username/password flow works.** `hb_client()` accepted `username`
  and `password` and documented a three-token model, but every base call
  then aborted with "not supported" and every web call with "API token
  required": such a client could do nothing at all. harbouR now performs
  the account-token to base-token exchange. Because an account token is
  scoped to the user rather than to a base, `hb_client()` gains
  `workspace_id` and `base_name`, and says so if they are missing.

* Percent-encoded path segments no longer reach the server double-encoded.
  `httr2::req_url_path()` escapes what it is given, so an already-escaped
  `%20` became `%2520`; it also leaves `/` alone, so a view named `a/b`
  would have split into two path segments.

* **Dates parse.** `_ctime` and `_mtime` come back as full ISO-8601 with a
  UTC offset - `2025-11-28T14:00:24.395+00:00` - and the parser's format
  list covered none of the offset-bearing forms, so every creation and
  modification time read as `NA`. It now handles the `T` separator,
  fractional seconds and offsets, and honours the offset instead of
  discarding it.

* **List-columns are type-stable.** A `multiple-select` column yielded a
  `character` vector for a populated cell and a `list` for an empty one, so
  `tidyr::unnest()`, `purrr::map_chr()` and `vctrs` all failed on a table
  containing a single blank cell. Empty and populated cells now agree, for
  all 28 types, and a contract test asserts it type by type.

* Reading a table with no columns returns a 0-row tibble carrying `_id`,
  as documented, rather than a 0x0 tibble.

* An unrecognised column type reads as text rather than erroring, so a
  future SeaTable release cannot break a read.

* `long-text` cells that arrive as an object rather than a string yield
  their text instead of a mangled coercion.

* Reading is roughly 70x faster: the type lookup rebuilt the column-type
  tibble once per cell. Reading the whole of a real 10-table base went from
  27s to 0.4s.

* **Breaking:** `hb_read_table(limit =)` is now `page_size =`, and there is
  a new `n_max =`. The old argument was documented as a page size but was
  also used as the stop condition, so `limit = 5000` returned 1000 rows and
  stopped - a wrong answer with no warning. `page_size` is clamped to
  SeaTable's 1000-row maximum with a warning, `n_max` bounds the total, and
  a runaway server now produces an error rather than an infinite loop.

* `hb_append_rows()`, `hb_update_rows()` and `hb_delete_rows()` split their
  work into requests of at most 1000 rows, which is SeaTable's batch limit.
  Writing 2500 rows used to send one oversized request. All three gain a
  `chunk_size` argument.

* **Breaking:** the three write verbs return a one-row summary -
  `table`, `n_rows`, `n_requests` - instead of fabricated per-row results.
  `hb_append_rows()` previously fell back to the *request* payload, which
  has no server-assigned `_id`, while promising server-generated ids in its
  documentation; `hb_update_rows()` and `hb_delete_rows()` returned
  `rep(TRUE, n)` without looking at the response at all. `n_rows` from
  `hb_append_rows()` is the count the server confirmed.

* `hb_upload_file()` returned `url = NA` on every call, so the object it
  produced could never be written into a file cell - which is what
  `hb_attach_file()`, the flagship helper, does with it. It now requests
  `ret-json=1` (without it the endpoint replies in plain text, so the
  response was unparseable), uploads to the image or file tree the server
  nominates rather than a hard-coded `files`, and builds the asset URL from
  the workspace id, base UUID and upload path.

* `hb_delete_asset()` targeted `/api/v2.1/dtable/asset/` with an API token
  and a `url` body. The endpoint is `/api/v2.1/dtable/app-asset/`, takes
  the API token, and identifies the asset by a `path` query parameter.

* **Writing a file, image or geolocation cell no longer corrupts it.** The
  write path flattened every list-valued cell with `unlist()`, which is
  right for a multiple-select column but turns a file cell's
  `{name, size, type, url}` object into
  `c("report.pdf", "12345", "application/pdf", "https://...")`.
  Serialisation is now driven by the column type. Flat list-columns are
  emitted as JSON arrays even when they hold a single value, which
  previously auto-unboxed to a scalar and changed the cell's type.

* `hb_update_column()` sends the `op_type` field SeaTable requires; without
  it the request was rejected. It gains a `new_type` argument for type
  changes, and refuses to rename and retype in one call, because SeaTable
  performs one operation per request.

* `hb_update_select_option()` sent `option`/`new_option` scalars. The API
  identifies an option by id, so harbouR now reads the column's options and
  resolves the name first. `hb_delete_select_option()` sends the
  `option_names` array the API expects rather than a scalar `option`.

* `hb_list_columns()` and `hb_list_views()` read the `columns/` and `views/`
  endpoints rather than only the cached base metadata, and both gain a
  `refresh` argument. `hb_list_columns()` gains a `data` list-column
  carrying each column's type-specific configuration - the select options,
  the date format - which is what makes option ids resolvable.

* `hb_get_view()` coerces its scalars like every sibling function, and
  reports `is_default` and `hidden_columns`.

* Table, view and row names are percent-encoded into the path, so a view
  called `Erwartungswerte Toxine 1` or `a/b` no longer produces a broken
  or ambiguous URL.

* `hb_duplicate_table()` posted to `tables/duplicate/`; the endpoint is
  `tables/duplicate-table/`.

* `hb_list_collaborators()` called a web-service path that does not exist.
  It is a base-scoped endpoint and needs the base token.

* `hb_column_types()` is now genuinely the single source of truth for the
  coercion layer. It gains `is_list` and `read_only` logical columns, which
  the coercion functions derive their type sets from instead of repeating
  hard-coded vectors, and it covers five names it previously omitted:
  the types `duration` and `digital-sign`, and the number formats
  `percent`, `dollar` and `euro`.

* **Breaking:** `hb_list_tables()` and `as_tibble()` on a `harbour_metadata`
  no longer return an `n_rows` column. The metadata endpoint carries no row
  payloads, so the value was structurally always `0` and told every user
  their tables were empty.

* New `format()` methods for `harbour_client` and `harbour_metadata`, so
  their representation can be captured as a character vector rather than
  only printed.

* **Breaking:** the 39 scaffolded endpoints that only ever raised "not yet
  implemented" have been removed - `hb_list_links()`, `hb_create_base()`,
  `hb_export_table()`, the `hb_admin_*()` and `hb_team_*()` families, and
  the rest. They were half the exported surface and none of them worked.
  The remaining areas are listed under Roadmap in the README.

