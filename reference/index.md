# Package index

## Client & authentication

- [`hb_client()`](https://cttir.github.io/harbouR/reference/hb_client.md)
  [`print(`*`<harbour_client>`*`)`](https://cttir.github.io/harbouR/reference/hb_client.md)
  : Create a SeaTable client
- [`hb_ping()`](https://cttir.github.io/harbouR/reference/hb_ping.md) :
  Ping the SeaTable server
- [`hb_server_info()`](https://cttir.github.io/harbouR/reference/hb_server_info.md)
  : Server information
- [`is_harbour_client()`](https://cttir.github.io/harbouR/reference/is_harbour_client.md)
  : Test whether an object is a harbour client

## Metadata

- [`hb_metadata()`](https://cttir.github.io/harbouR/reference/hb_metadata.md)
  : Fetch base metadata
- [`hb_list_tables()`](https://cttir.github.io/harbouR/reference/hb_list_tables.md)
  : List the tables in a base
- [`hb_list_collaborators()`](https://cttir.github.io/harbouR/reference/hb_list_collaborators.md)
  : List collaborators of the active base
- [`hb_column_types()`](https://cttir.github.io/harbouR/reference/hb_column_types.md)
  : SeaTable column type mapping
- [`print(`*`<harbour_metadata>`*`)`](https://cttir.github.io/harbouR/reference/print.harbour_metadata.md)
  : Print method for harbour metadata
- [`as_tibble(`*`<harbour_metadata>`*`)`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_metadata.md)
  : Coerce harbour metadata to a tibble
- [`summary(`*`<harbour_metadata>`*`)`](https://cttir.github.io/harbouR/reference/summary.harbour_metadata.md)
  : Summary of harbour metadata
- [`is_harbour_metadata()`](https://cttir.github.io/harbouR/reference/is_harbour_metadata.md)
  : Test whether an object is harbour metadata

## Rows

- [`hb_read_table()`](https://cttir.github.io/harbouR/reference/hb_read_table.md)
  : Read a table as a tibble
- [`hb_query()`](https://cttir.github.io/harbouR/reference/hb_query.md)
  : Run a SeaTable SQL query
- [`hb_get_row()`](https://cttir.github.io/harbouR/reference/hb_get_row.md)
  : Get a single row by ID
- [`hb_append_rows()`](https://cttir.github.io/harbouR/reference/hb_append_rows.md)
  : Append rows to a table
- [`hb_update_rows()`](https://cttir.github.io/harbouR/reference/hb_update_rows.md)
  : Update rows in a table
- [`hb_delete_rows()`](https://cttir.github.io/harbouR/reference/hb_delete_rows.md)
  : Delete rows
- [`hb_lock_rows()`](https://cttir.github.io/harbouR/reference/hb_lock_rows.md)
  : Lock rows
- [`hb_unlock_rows()`](https://cttir.github.io/harbouR/reference/hb_unlock_rows.md)
  : Unlock rows

## Tables

- [`hb_create_table()`](https://cttir.github.io/harbouR/reference/hb_create_table.md)
  : Create a table
- [`hb_rename_table()`](https://cttir.github.io/harbouR/reference/hb_rename_table.md)
  : Rename a table
- [`hb_delete_table()`](https://cttir.github.io/harbouR/reference/hb_delete_table.md)
  : Delete a table
- [`hb_duplicate_table()`](https://cttir.github.io/harbouR/reference/hb_duplicate_table.md)
  : Duplicate a table

## Columns

- [`hb_list_columns()`](https://cttir.github.io/harbouR/reference/hb_list_columns.md)
  : List columns of a table
- [`hb_add_column()`](https://cttir.github.io/harbouR/reference/hb_add_column.md)
  : Add a column to a table
- [`hb_add_columns()`](https://cttir.github.io/harbouR/reference/hb_add_columns.md)
  : Add several columns at once
- [`hb_update_column()`](https://cttir.github.io/harbouR/reference/hb_update_column.md)
  : Update a column
- [`hb_delete_column()`](https://cttir.github.io/harbouR/reference/hb_delete_column.md)
  : Delete a column
- [`hb_add_select_option()`](https://cttir.github.io/harbouR/reference/hb_add_select_option.md)
  : Add a single-select option
- [`hb_update_select_option()`](https://cttir.github.io/harbouR/reference/hb_update_select_option.md)
  : Update a single-select option
- [`hb_delete_select_option()`](https://cttir.github.io/harbouR/reference/hb_delete_select_option.md)
  : Delete a single-select option

## Views

- [`hb_list_views()`](https://cttir.github.io/harbouR/reference/hb_list_views.md)
  : List views of a table
- [`hb_get_view()`](https://cttir.github.io/harbouR/reference/hb_get_view.md)
  : Get a view's settings
- [`hb_create_view()`](https://cttir.github.io/harbouR/reference/hb_create_view.md)
  : Create a view
- [`hb_update_view()`](https://cttir.github.io/harbouR/reference/hb_update_view.md)
  : Update a view
- [`hb_delete_view()`](https://cttir.github.io/harbouR/reference/hb_delete_view.md)
  : Delete a view

## Files

- [`hb_upload_file()`](https://cttir.github.io/harbouR/reference/hb_upload_file.md)
  : Upload a file to SeaTable
- [`hb_attach_file()`](https://cttir.github.io/harbouR/reference/hb_attach_file.md)
  : Attach a file to a cell
- [`hb_download_file()`](https://cttir.github.io/harbouR/reference/hb_download_file.md)
  : Download an asset
- [`hb_delete_asset()`](https://cttir.github.io/harbouR/reference/hb_delete_asset.md)
  : Delete an asset

## Example data

- [`hb_example_metadata()`](https://cttir.github.io/harbouR/reference/hb_example_metadata.md)
  : Offline example metadata
- [`hb_example_rows()`](https://cttir.github.io/harbouR/reference/hb_example_rows.md)
  : Offline example rows

## Shiny explorer

- [`hb_run_explorer()`](https://cttir.github.io/harbouR/reference/hb_run_explorer.md)
  : Launch the harbouR explorer

## Scaffolded (later releases)
