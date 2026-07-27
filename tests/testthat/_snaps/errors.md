# hb_client() rejects bad credentials and servers

    Code
      hb_client(server = "")
    Condition
      Error in `hb_client()`:
      ! `server` must be a single non-empty string.
      x You supplied .

---

    Code
      hb_client(server = "ftp://nope.example.org", api_token = "t")
    Condition
      Error in `hb_client()`:
      ! `server` must begin with "http://" or "https://".
      x You supplied "ftp://nope.example.org".

---

    Code
      hb_client(server = "https://x.example.org")
    Condition
      Error in `hb_client()`:
      ! No credentials supplied.
      i Provide `api_token` or `username` and `password`, or set `SEATABLE_API_TOKEN`.

---

    Code
      hb_client(server = "https://x.example.org", api_token = "t", username = "u",
        password = "p")
    Condition
      Error in `hb_client()`:
      ! Supply either `api_token` or `username`/`password`, not both.

# scalar validators name the argument and the bad value

    Code
      hb_read_table(cl, "")
    Condition
      Error in `hb_read_table()`:
      ! `table` must be a single non-empty string.
      x You supplied "".

---

    Code
      hb_read_table(1L, "Samples")
    Condition
      Error in `hb_read_table()`:
      ! `client` must be a <harbour_client>.
      i Create one with `harbouR::hb_client()`.

---

    Code
      hb_list_tables(cl, refresh = "yes")
    Condition
      Error in `hb_list_tables()`:
      ! `refresh` must be a single `TRUE` or `FALSE`.
      x You supplied "yes".

# an unknown table lists the tables that do exist

    Code
      hb_read_table(cl, "Nope")
    Condition
      Error in `hb_read_table()`:
      ! Table "Nope" not found.
      i Known tables: "Samples" and "Patients".

# HTTP status codes translate to actionable messages

    Code
      .hb_translate_error(cond)
    Condition
      Error:
      ! SeaTable request failed (HTTP 401).
      x SeaTable returned an error.
      i Check that the API token is valid for this base.

---

    Code
      .hb_translate_error(cond)
    Condition
      Error:
      ! SeaTable request failed (HTTP 403).
      x SeaTable returned an error.
      i Check that the token has permission for this endpoint.

---

    Code
      .hb_translate_error(cond)
    Condition
      Error:
      ! SeaTable request failed (HTTP 404).
      x SeaTable returned an error.
      i Verify the path and base UUID.

---

    Code
      .hb_translate_error(cond)
    Condition
      Error:
      ! SeaTable request failed (HTTP 429).
      x SeaTable returned an error.
      i Rate-limited - slow down or batch your requests.

---

    Code
      .hb_translate_error(cond)
    Condition
      Error:
      ! SeaTable request failed (HTTP 500).
      x SeaTable returned an error.

# hb_update_rows() insists on an id column

    Code
      hb_update_rows(cl, "Samples", tibble::tibble(Name = "x"))
    Condition
      Error in `hb_update_rows()`:
      ! Column _id not present in `data`.
      i Set `row_id_col` to whichever column holds the row IDs.

# hb_download_file() refuses to clobber without overwrite

    Code
      hb_download_file(cl, "https://demo.example.org/asset/x.pdf", path)
    Condition
      Error in `hb_download_file()`:
      ! Destination already exists.
      x '<tmp>/report.pdf'
      i Pass `overwrite = TRUE` to replace it.

