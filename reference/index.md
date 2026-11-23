# Package index

## Errors

Every error harbouR raises itself, and every HTTP or transport failure,
carries a condition class, so callers can react to what went wrong
rather than matching on message text. Argument-matching errors from
rlang keep the classes rlang gives them.

- [`harbouR-conditions`](https://cttir.github.io/harbouR/reference/harbouR-conditions.md)
  : Conditions signalled by harbouR

## Client & authentication

Describe a server and its credentials, and check that both work.

- [`hb_client()`](https://cttir.github.io/harbouR/reference/hb_client.md)
  [`print(`*`<harbour_client>`*`)`](https://cttir.github.io/harbouR/reference/hb_client.md)
  [`format(`*`<harbour_client>`*`)`](https://cttir.github.io/harbouR/reference/hb_client.md)
  : Create a SeaTable client
- [`hb_ping()`](https://cttir.github.io/harbouR/reference/hb_ping.md) :
  Check that a SeaTable server is reachable
- [`hb_check_credentials()`](https://cttir.github.io/harbouR/reference/hb_check_credentials.md)
  : Check that the client's credentials are accepted
- [`hb_server_info()`](https://cttir.github.io/harbouR/reference/hb_server_info.md)
  : Server information
- [`is_harbour_client()`](https://cttir.github.io/harbouR/reference/is_harbour_client.md)
  : Test whether an object is a harbour client

## Metadata

The tables, columns and collaborators of a base, and how column types
map to R.

- [`hb_metadata()`](https://cttir.github.io/harbouR/reference/hb_metadata.md)
  : Fetch base metadata
- [`hb_list_tables()`](https://cttir.github.io/harbouR/reference/hb_list_tables.md)
  : List the tables in a base
- [`hb_list_collaborators()`](https://cttir.github.io/harbouR/reference/hb_list_collaborators.md)
  : List collaborators of the active base
- [`hb_column_types()`](https://cttir.github.io/harbouR/reference/hb_column_types.md)
  : SeaTable column types and how harbouR maps them
- [`print(`*`<harbour_metadata>`*`)`](https://cttir.github.io/harbouR/reference/print.harbour_metadata.md)
  [`format(`*`<harbour_metadata>`*`)`](https://cttir.github.io/harbouR/reference/print.harbour_metadata.md)
  : Print method for harbour metadata
- [`as_tibble(`*`<harbour_metadata>`*`)`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_metadata.md)
  : Coerce harbour metadata to a tibble
- [`summary(`*`<harbour_metadata>`*`)`](https://cttir.github.io/harbouR/reference/summary.harbour_metadata.md)
  : Summary of harbour metadata
- [`is_harbour_metadata()`](https://cttir.github.io/harbouR/reference/is_harbour_metadata.md)
  : Test whether an object is harbour metadata

## Rows

Read rows as a tibble, query them with SQL, and add, change, lock or
delete them.

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

Create, rename, duplicate and delete the tables of a base on a server.

- [`hb_create_table()`](https://cttir.github.io/harbouR/reference/hb_create_table.md)
  : Create a table
- [`hb_rename_table()`](https://cttir.github.io/harbouR/reference/hb_rename_table.md)
  : Rename a table
- [`hb_delete_table()`](https://cttir.github.io/harbouR/reference/hb_delete_table.md)
  : Delete a table
- [`hb_duplicate_table()`](https://cttir.github.io/harbouR/reference/hb_duplicate_table.md)
  : Duplicate a table

## Columns

List, add, change and delete columns and the options of select columns.

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

List, read, create, change and delete the views of a table.

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

Upload files, attach them to a row, download them and delete them.

- [`hb_upload_file()`](https://cttir.github.io/harbouR/reference/hb_upload_file.md)
  : Upload a file to SeaTable
- [`hb_attach_file()`](https://cttir.github.io/harbouR/reference/hb_attach_file.md)
  : Attach a file to a cell
- [`hb_download_file()`](https://cttir.github.io/harbouR/reference/hb_download_file.md)
  : Download an asset
- [`hb_delete_asset()`](https://cttir.github.io/harbouR/reference/hb_delete_asset.md)
  : Delete an asset

## Local .dtable files

Read, build, check and write a base as a file, with no server involved.

- [`hb_read_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_dtable.md)
  :

  Read a SeaTable `.dtable` file

- [`hb_write_dtable()`](https://cttir.github.io/harbouR/reference/hb_write_dtable.md)
  :

  Write a `harbour_dtable` back to a `.dtable` file

- [`hb_dtable()`](https://cttir.github.io/harbouR/reference/hb_dtable.md)
  :

  Build a `.dtable` base from data frames

- [`hb_validate_dtable()`](https://cttir.github.io/harbouR/reference/hb_validate_dtable.md)
  : Check a base for problems before writing it

- [`hb_asset_path()`](https://cttir.github.io/harbouR/reference/hb_asset_path.md)
  : Resolve a bundled asset URL to a local file

- [`is_harbour_dtable()`](https://cttir.github.io/harbouR/reference/is_harbour_dtable.md)
  : Test whether an object is a harbour dtable

- [`print(`*`<harbour_dtable>`*`)`](https://cttir.github.io/harbouR/reference/print.harbour_dtable.md)
  [`format(`*`<harbour_dtable>`*`)`](https://cttir.github.io/harbouR/reference/print.harbour_dtable.md)
  : Print a harbour dtable

- [`names(`*`<harbour_dtable>`*`)`](https://cttir.github.io/harbouR/reference/names.harbour_dtable.md)
  : Names of the tables in a dtable

- [`length(`*`<harbour_dtable>`*`)`](https://cttir.github.io/harbouR/reference/length.harbour_dtable.md)
  : Number of tables in a dtable

- [`as_tibble(`*`<harbour_dtable>`*`)`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_dtable.md)
  : Coerce a dtable's table index to a tibble

- [`summary(`*`<harbour_dtable>`*`)`](https://cttir.github.io/harbouR/reference/summary.harbour_dtable.md)
  : Summarise the schema of a dtable

## Import and export

Convert a base to and from Excel workbooks and CSV files.

- [`hb_write_xlsx()`](https://cttir.github.io/harbouR/reference/hb_write_xlsx.md)
  : Export a base to an Excel workbook
- [`hb_write_csv()`](https://cttir.github.io/harbouR/reference/hb_write_csv.md)
  : Export a base to CSV files
- [`hb_read_xlsx()`](https://cttir.github.io/harbouR/reference/hb_read_xlsx.md)
  : Read tables into a new base from an Excel workbook
- [`hb_read_csv()`](https://cttir.github.io/harbouR/reference/hb_read_csv.md)
  : Read tables into a new base from CSV files

## Example data

Bundled metadata and rows for trying the package offline.

- [`hb_example_metadata()`](https://cttir.github.io/harbouR/reference/hb_example_metadata.md)
  : Offline example metadata
- [`hb_example_rows()`](https://cttir.github.io/harbouR/reference/hb_example_rows.md)
  : Offline example rows

## Shiny explorer

Browse a base interactively in a Shiny app.

- [`hb_run_explorer()`](https://cttir.github.io/harbouR/reference/hb_run_explorer.md)
  : Launch the harbouR explorer
