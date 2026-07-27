# harbouR 0.1.0

First release.

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
  `?"harbouR-conditions"`. HTTP errors carry `status`, `url` and `body`.

* A `403` response is no longer retried as though the base token had
  expired. Only `401` triggers a refresh.

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
  and a `url` body. The endpoint is `/api/v2.1/dtable/app-asset/`, takes a
  base token, and identifies the asset by a `path` query parameter.

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
  hard-coded vectors, and it covers five types it previously omitted:
  `percent`, `dollar`, `euro`, `duration` and `digital-sign`.

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

