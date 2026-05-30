# Changelog

## harbouR 0.1.0

Initial release.

- Tier 1 (fully implemented):
  - Client & auth:
    [`hb_client()`](https://r-heller.github.io/harbouR/reference/hb_client.md),
    [`hb_ping()`](https://r-heller.github.io/harbouR/reference/hb_ping.md),
    [`hb_server_info()`](https://r-heller.github.io/harbouR/reference/hb_server_info.md),
    [`print.harbour_client()`](https://r-heller.github.io/harbouR/reference/hb_client.md).
  - Metadata:
    [`hb_metadata()`](https://r-heller.github.io/harbouR/reference/hb_metadata.md),
    [`hb_list_tables()`](https://r-heller.github.io/harbouR/reference/hb_list_tables.md),
    [`hb_list_collaborators()`](https://r-heller.github.io/harbouR/reference/hb_list_collaborators.md),
    [`print.harbour_metadata()`](https://r-heller.github.io/harbouR/reference/print.harbour_metadata.md),
    [`as_tibble.harbour_metadata()`](https://r-heller.github.io/harbouR/reference/as_tibble.harbour_metadata.md),
    [`summary.harbour_metadata()`](https://r-heller.github.io/harbouR/reference/summary.harbour_metadata.md).
  - Rows:
    [`hb_read_table()`](https://r-heller.github.io/harbouR/reference/hb_read_table.md),
    [`hb_query()`](https://r-heller.github.io/harbouR/reference/hb_query.md),
    [`hb_get_row()`](https://r-heller.github.io/harbouR/reference/hb_get_row.md),
    [`hb_append_rows()`](https://r-heller.github.io/harbouR/reference/hb_append_rows.md),
    [`hb_update_rows()`](https://r-heller.github.io/harbouR/reference/hb_update_rows.md),
    [`hb_delete_rows()`](https://r-heller.github.io/harbouR/reference/hb_delete_rows.md),
    [`hb_lock_rows()`](https://r-heller.github.io/harbouR/reference/hb_lock_rows.md),
    [`hb_unlock_rows()`](https://r-heller.github.io/harbouR/reference/hb_unlock_rows.md).
  - Tables:
    [`hb_create_table()`](https://r-heller.github.io/harbouR/reference/hb_create_table.md),
    [`hb_rename_table()`](https://r-heller.github.io/harbouR/reference/hb_rename_table.md),
    [`hb_delete_table()`](https://r-heller.github.io/harbouR/reference/hb_delete_table.md),
    [`hb_duplicate_table()`](https://r-heller.github.io/harbouR/reference/hb_duplicate_table.md).
  - Columns:
    [`hb_list_columns()`](https://r-heller.github.io/harbouR/reference/hb_list_columns.md),
    [`hb_add_column()`](https://r-heller.github.io/harbouR/reference/hb_add_column.md),
    [`hb_update_column()`](https://r-heller.github.io/harbouR/reference/hb_update_column.md),
    [`hb_delete_column()`](https://r-heller.github.io/harbouR/reference/hb_delete_column.md),
    [`hb_add_columns()`](https://r-heller.github.io/harbouR/reference/hb_add_columns.md),
    [`hb_add_select_option()`](https://r-heller.github.io/harbouR/reference/hb_add_select_option.md),
    [`hb_update_select_option()`](https://r-heller.github.io/harbouR/reference/hb_update_select_option.md),
    [`hb_delete_select_option()`](https://r-heller.github.io/harbouR/reference/hb_delete_select_option.md).
  - Views:
    [`hb_list_views()`](https://r-heller.github.io/harbouR/reference/hb_list_views.md),
    [`hb_get_view()`](https://r-heller.github.io/harbouR/reference/hb_get_view.md),
    [`hb_create_view()`](https://r-heller.github.io/harbouR/reference/hb_create_view.md),
    [`hb_update_view()`](https://r-heller.github.io/harbouR/reference/hb_update_view.md),
    [`hb_delete_view()`](https://r-heller.github.io/harbouR/reference/hb_delete_view.md).
  - Files:
    [`hb_upload_file()`](https://r-heller.github.io/harbouR/reference/hb_upload_file.md),
    [`hb_attach_file()`](https://r-heller.github.io/harbouR/reference/hb_attach_file.md),
    [`hb_download_file()`](https://r-heller.github.io/harbouR/reference/hb_download_file.md),
    [`hb_delete_asset()`](https://r-heller.github.io/harbouR/reference/hb_delete_asset.md).
  - Offline example data:
    [`hb_example_metadata()`](https://r-heller.github.io/harbouR/reference/hb_example_metadata.md),
    [`hb_example_rows()`](https://r-heller.github.io/harbouR/reference/hb_example_rows.md).
  - Shiny explorer launcher:
    [`hb_run_explorer()`](https://r-heller.github.io/harbouR/reference/hb_run_explorer.md).
- Tiers 2 and 3 (links, big data, comments, notifications, snapshots,
  bases, import/export, sharing, integrations, admin, team, scheduler)
  are scaffolded with documented stubs and will land in later minor
  releases.
