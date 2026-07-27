# harbouR 0.1.0.9000 (development version)

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

# harbouR 0.1.0

Initial release.

* Tier 1 (fully implemented):
  * Client & auth: `hb_client()`, `hb_ping()`, `hb_server_info()`,
    `print.harbour_client()`.
  * Metadata: `hb_metadata()`, `hb_list_tables()`, `hb_list_collaborators()`,
    `print.harbour_metadata()`, `as_tibble.harbour_metadata()`,
    `summary.harbour_metadata()`.
  * Rows: `hb_read_table()`, `hb_query()`, `hb_get_row()`, `hb_append_rows()`,
    `hb_update_rows()`, `hb_delete_rows()`, `hb_lock_rows()`, `hb_unlock_rows()`.
  * Tables: `hb_create_table()`, `hb_rename_table()`, `hb_delete_table()`,
    `hb_duplicate_table()`.
  * Columns: `hb_list_columns()`, `hb_add_column()`, `hb_update_column()`,
    `hb_delete_column()`, `hb_add_columns()`, `hb_add_select_option()`,
    `hb_update_select_option()`, `hb_delete_select_option()`.
  * Views: `hb_list_views()`, `hb_get_view()`, `hb_create_view()`,
    `hb_update_view()`, `hb_delete_view()`.
  * Files: `hb_upload_file()`, `hb_attach_file()`, `hb_download_file()`,
    `hb_delete_asset()`.
  * Offline example data: `hb_example_metadata()`, `hb_example_rows()`.
  * Shiny explorer launcher: `hb_run_explorer()`.

* Tiers 2 and 3 (links, big data, comments, notifications, snapshots, bases,
  import/export, sharing, integrations, admin, team, scheduler) are
  scaffolded with documented stubs and will land in later minor releases.
