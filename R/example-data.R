#' Offline example metadata
#'
#' A small, hand-crafted SeaTable base used to power offline examples,
#' tests, the column-types vignette and the Shiny demo mode. The shape of
#' the returned object matches what the SeaTable metadata endpoint would
#' yield.
#'
#' @return A `harbour_metadata` object describing a tiny base with two
#'   tables: `Samples` and `Patients`.
#' @family example data
#' @examples
#' meta <- hb_example_metadata()
#' tibble::as_tibble(meta)
#' @export
hb_example_metadata <- function() {
  tables <- list(
    list(
      name = "Samples",
      columns = list(
        list(name = "Name", type = "text", key = "k1"),
        list(name = "Concentration", type = "number", key = "k2"),
        list(name = "Status", type = "single-select", key = "k3",
             data = list(options = list(list(name = "draft"),
                                        list(name = "ready"),
                                        list(name = "shipped")))),
        list(name = "Tags", type = "multiple-select", key = "k4"),
        list(name = "Collected", type = "date", key = "k5"),
        list(name = "Collaborators", type = "collaborator", key = "k6"),
        list(name = "Reports", type = "file", key = "k7")
      ),
      views = list(list(name = "Default", type = "table", is_default = TRUE))
    ),
    list(
      name = "Patients",
      columns = list(
        list(name = "Patient ID", type = "text", key = "p1"),
        list(name = "Age", type = "number", key = "p2"),
        list(name = "Consented", type = "checkbox", key = "p3"),
        list(name = "Last visit", type = "date", key = "p4")
      ),
      views = list(list(name = "Default", type = "table", is_default = TRUE))
    )
  )
  new_harbour_metadata(list(tables = tables), base_name = "harbouR demo base")
}

#' Offline example rows
#'
#' Returns a tibble of example rows for one of the tables provided by
#' [hb_example_metadata()]. The rows exercise every column type harbouR
#' supports, including list-columns and dates, so tests and the
#' column-types vignette can demonstrate the coercion layer without a
#' SeaTable server.
#'
#' @param table One of `"Samples"` or `"Patients"`.
#'
#' @return A tibble.
#' @family example data
#' @examples
#' hb_example_rows("Samples")
#' @export
hb_example_rows <- function(table = c("Samples", "Patients")) {
  table <- match.arg(table)
  switch(table,
    "Samples" = tibble::tibble(
      Name = c("S-001", "S-002", "S-003"),
      Concentration = c(12.4, 8.1, 21.0),
      Status = c("draft", "ready", "shipped"),
      Tags = list(c("urgent", "blood"), character(), c("plasma")),
      Collected = as.POSIXct(c("2026-04-01 09:00", "2026-04-03 12:30",
                                "2026-04-05 16:15"), tz = "UTC"),
      Collaborators = list(c("amy@example.org"),
                           c("amy@example.org", "ben@example.org"),
                           character()),
      Reports = list(
        list(list(name = "S-001.pdf", size = 1234,
                  type = "application/pdf",
                  url = "https://example.org/files/S-001.pdf")),
        list(),
        list(list(name = "S-003.pdf", size = 4567,
                  type = "application/pdf",
                  url = "https://example.org/files/S-003.pdf"))
      ),
      `_id` = c("r0001", "r0002", "r0003")
    ),
    "Patients" = tibble::tibble(
      `Patient ID` = c("P-1", "P-2", "P-3", "P-4"),
      Age = c(34, 71, 52, 19),
      Consented = c(TRUE, TRUE, FALSE, TRUE),
      `Last visit` = as.POSIXct(c("2026-03-12", "2026-04-08",
                                   "2026-02-19", "2026-05-21"), tz = "UTC"),
      `_id` = c("p1", "p2", "p3", "p4")
    )
  )
}
