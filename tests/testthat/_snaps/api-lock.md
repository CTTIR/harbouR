# exported API surface is unchanged

    Code
      cat(sigs, sep = "\n")
    Output
      hb_add_column(client, table, name, type, ..., column_data = NULL)
      hb_add_columns(client, table, columns, ...)
      hb_add_select_option(client, table, name, option, ...)
      hb_append_rows(client, table, data, ..., chunk_size = 1000L)
      hb_asset_path(x, url, ...)
      hb_attach_file(client, table, row_id, column, path, ...)
      hb_check_credentials(client, ...)
      hb_client(server = Sys.getenv("SEATABLE_SERVER"), api_token = Sys.getenv("SEATABLE_API_TOKEN"), ..., username = NULL, password = NULL, base_uuid = NULL, workspace_id = NULL, base_name = NULL, timeout = 30)
      hb_column_types()
      hb_create_table(client, table, ..., columns = list())
      hb_create_view(client, table, view, ..., settings = list())
      hb_delete_asset(client, url, ...)
      hb_delete_column(client, table, name, ...)
      hb_delete_rows(client, table, row_ids, ..., chunk_size = 1000L)
      hb_delete_select_option(client, table, name, option, ...)
      hb_delete_table(client, table, ...)
      hb_delete_view(client, table, view, ...)
      hb_download_file(client, url, dest, ..., overwrite = FALSE)
      hb_dtable(..., base_name = "harbouR base", collaborators = NULL)
      hb_duplicate_table(client, table, ..., duplicate_records = TRUE)
      hb_example_metadata()
      hb_example_rows(table = c("Samples", "Patients"))
      hb_get_row(client, table, row_id, ...)
      hb_get_view(client, table, view, ...)
      hb_list_collaborators(client, ...)
      hb_list_columns(x, table, ...)
      hb_list_tables(x, ...)
      hb_list_views(x, table, ...)
      hb_lock_rows(client, table, row_ids, ...)
      hb_metadata(client, ...)
      hb_ping(client, ...)
      hb_query(client, sql, ..., parameters = NULL, convert_keys = TRUE)
      hb_read_csv(files, ..., base_name = "harbouR base")
      hb_read_dtable(path, ..., assets = c("none", "extract"), assets_dir = NULL)
      hb_read_table(x, table, ...)
      hb_read_xlsx(path, ..., sheets = NULL, base_name = "harbouR base")
      hb_rename_table(client, table, new_name, ...)
      hb_run_explorer(x = NULL, ..., host = "127.0.0.1", port = NULL)
      hb_server_info(client, ...)
      hb_unlock_rows(client, table, row_ids, ...)
      hb_update_column(client, table, name, ..., new_name = NULL, new_type = NULL, column_data = NULL)
      hb_update_rows(client, table, data, ..., row_id_col = "_id", chunk_size = 1000L)
      hb_update_select_option(client, table, name, option, new_option, ...)
      hb_update_view(client, table, view, settings, ...)
      hb_upload_file(client, path, ..., relative_path = "files")
      hb_validate_dtable(x, ...)
      hb_write_csv(x, dir, ..., tables = NULL)
      hb_write_dtable(x, path, ..., assets = TRUE, overwrite = TRUE)
      hb_write_xlsx(x, path, ..., tables = NULL)
      is_harbour_client(x)
      is_harbour_dtable(x)
      is_harbour_metadata(x)

# registered S3 methods are unchanged

    Code
      cat(methods, sep = "\n")
    Output
      as_tibble.harbour_dtable
      as_tibble.harbour_metadata
      format.harbour_client
      format.harbour_dtable
      format.harbour_metadata
      hb_list_columns.default
      hb_list_columns.harbour_client
      hb_list_columns.harbour_dtable
      hb_list_tables.default
      hb_list_tables.harbour_client
      hb_list_tables.harbour_dtable
      hb_list_views.default
      hb_list_views.harbour_client
      hb_list_views.harbour_dtable
      hb_read_table.default
      hb_read_table.harbour_client
      hb_read_table.harbour_dtable
      length.harbour_dtable
      names.harbour_dtable
      print.harbour_client
      print.harbour_dtable
      print.harbour_metadata
      summary.harbour_dtable
      summary.harbour_metadata

# declared dependencies are unchanged

    Code
      cat(out, sep = "\n")
    Output
      Depends:
        R (>= 4.1)
      Imports:
        cli
        curl
        httr2
        jsonlite
        lubridate
        rlang
        stats
        tibble
        tools
        zip

