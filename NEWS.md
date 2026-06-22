# harbouR (development version)

## Bug fixes

* `.hb_perform_raw()` no longer crashes when a request returns HTTP 404. The
  404 error message now interpolates the request URL via a local variable
  instead of calling `.hb_safe_url()` inline, which cli (>= 3.4.0) misread as
  a style name beginning with a dot.

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
