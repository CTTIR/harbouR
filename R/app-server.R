#' The explorer's server logic
#'
#' @param preset A `harbour_client` or `harbour_dtable` to open with, or
#'   `NULL` for the connect screen.
#' @return A shiny server function.
#' @keywords internal
#' @noRd
.hb_app_server <- function(preset = NULL) {
  function(input, output, session) {
    state <- shiny::reactiveValues(
      source = if (is.null(preset)) NULL else preset,
      kind = .hb_source_kind(preset),
      table = NULL,
      query = NULL
    )

    # The asset folder the app itself unpacked for the open base. Removed
    # when another base is opened and when the session ends; uploads may be
    # 1 GB, and each stayed in the temporary folder until R quit. A
    # preset's folder belongs to whoever passed it in, and stays.
    scratch <- new.env(parent = emptyenv())
    release_assets <- function() {
      if (!is.null(scratch$assets)) unlink(scratch$assets, recursive = TRUE)
      scratch$assets <- NULL
    }
    session$onSessionEnded(release_assets)

    open_source <- function(value, kind, owned = FALSE) {
      release_assets()
      if (owned) scratch$assets <- value$assets_dir
      state$source <- value
      state$kind <- kind
      state$table <- .hb_first_table(value)
      state$query <- NULL
    }

    if (!is.null(preset)) {
      state$table <- .hb_first_table(preset)
    }

    shiny::observeEvent(input$dtable_file, {
      file <- input$dtable_file
      shiny::req(file)
      .hb_try(session, sprintf("Could not open %s", file$name), {
        # Extract the assets: without them a download would write an
        # archive whose attachment cells point at files it does not carry.
        # What the read warns about - attachments it could not all
        # extract, a newer format - would reach only the console, which
        # the app's user cannot see, so it is shown here instead.
        base <- withCallingHandlers(
          hb_read_dtable(file$datapath, assets = "extract"),
          warning = function(cnd) {
            shiny::showNotification(
              shiny::tags$div(
                shiny::tags$strong(sprintf("While opening %s", file$name)),
                shiny::tags$div(class = "small", .hb_plain_message(cnd))
              ),
              type = "warning", duration = NULL
            )
            invokeRestart("muffleWarning")
          }
        )
        open_source(base, "file", owned = TRUE)
        # datapath is a temporary upload name; keep the real one for the
        # download filename.
        state$source$base_name <- tools::file_path_sans_ext(file$name)
      })
    })

    shiny::observeEvent(input$use_demo, {
      .hb_try(session, "Could not open the example base", {
        open_source(
          hb_read_dtable(.hb_example_dtable(), assets = "extract"),
          "demo", owned = TRUE
        )
      })
    })

    shiny::observeEvent(input$connect, {
      .hb_try(session, "Could not connect", {
        client <- hb_client(server = input$server, api_token = input$token)
        hb_metadata(client)
        open_source(client, "server")
      })
    })

    output$source_panel <- shiny::renderUI({
      # Open while there is nothing to browse, folded away once there is:
      # the common case after opening a base is looking at it.
      .hb_source_fields(open = is.null(state$source))
    })

    output$source_badge <- shiny::renderUI({
      if (is.null(state$kind)) {
        return(NULL)
      }
      label <- switch(state$kind,
        server = "Live base",
        file = "Local file",
        demo = "Example base",
        "Connected"
      )
      class <- switch(state$kind,
        file = "hb-source hb-file",
        demo = "hb-source hb-demo",
        "hb-source"
      )
      shiny::tags$span(class = class, label)
    })

    tables <- shiny::reactive({
      shiny::req(state$source)
      hb_list_tables(state$source)
    })

    output$table_count <- shiny::renderText({
      if (is.null(state$source)) "" else as.character(nrow(tables()))
    })

    output$table_list <- shiny::renderUI({
      if (is.null(state$source)) {
        return(shiny::tags$div(
          class = "hb-empty mt-2",
          shiny::tags$p("No base open."),
          shiny::tags$p(
            class = "small mb-0",
            "Open a .dtable file, or use the example base."
          )
        ))
      }
      index <- tables()
      cards <- lapply(seq_len(nrow(index)), function(i) {
        name <- index$name[[i]]
        types <- .hb_safe_types(state$source, name)
        rows <- if ("n_rows" %in% names(index)) {
          sprintf("%s rows", format(index$n_rows[[i]], big.mark = ","))
        } else {
          "server-side"
        }
        shiny::tags$button(
          class = paste(
            "hb-table-card w-100 text-start border-0",
            if (identical(name, state$table)) "hb-active" else ""
          ),
          onclick = sprintf(
            "Shiny.setInputValue('pick_table', %s, {priority: 'event'})",
            jsonlite::toJSON(name, auto_unbox = TRUE)
          ),
          shiny::tags$div(class = "hb-name", name),
          shiny::tags$div(
            class = "hb-meta",
            sprintf("%d columns \u00b7 %s", index$n_columns[[i]], rows)
          ),
          shiny::HTML(.hb_sounding(types))
        )
      })
      shiny::tags$div(class = "mt-2", cards)
    })

    shiny::observeEvent(input$pick_table, {
      state$table <- input$pick_table
    })

    output$data_title <- shiny::renderUI({
      if (is.null(state$table)) {
        return(NULL)
      }
      shiny::tags$strong(state$table)
    })

    table_data <- shiny::reactive({
      shiny::req(state$source, state$table)
      n_max <- input$n_max %||% 1000
      if (!is.numeric(n_max) || is.na(n_max) || n_max < 1) n_max <- 1000
      hb_read_table(state$source, state$table, n_max = n_max)
    })

    output$data_panel <- shiny::renderUI({
      if (is.null(state$source)) {
        return(.hb_placeholder("Open a base to see its data."))
      }
      if (is.null(state$table)) {
        return(.hb_placeholder("Pick a table."))
      }
      reactable::reactableOutput("data_table")
    })

    output$data_table <- reactable::renderReactable({
      data <- table_data()
      reactable::reactable(
        .hb_display_frame(data),
        searchable = TRUE, filterable = TRUE, resizable = TRUE,
        highlight = TRUE, compact = TRUE, defaultPageSize = 15,
        showPageSizeOptions = TRUE, pageSizeOptions = c(15, 50, 100),
        defaultColDef = reactable::colDef(
          minWidth = 130, headerVAlign = "bottom"
        ),
        theme = reactable::reactableTheme(
          borderColor = "#e3ebe9",
          highlightColor = "#eef6f3",
          cellPadding = "6px 8px",
          headerStyle = list(
            whiteSpace = "nowrap", overflow = "hidden",
            textOverflow = "ellipsis"
          )
        )
      )
    })

    output$schema_legend <- shiny::renderUI({
      families <- unique(.hb_type_families()[, c("family", "colour")])
      chips <- Map(function(family, colour) {
        shiny::tags$span(
          class = "hb-chip me-1",
          style = sprintf("background:%s2E;border-color:%s99", colour, colour),
          family
        )
      }, families$family, families$colour)
      shiny::tags$div(class = "mb-3", chips)
    })

    output$schema_panel <- shiny::renderUI({
      if (is.null(state$source) || is.null(state$table)) {
        return(.hb_placeholder("Pick a table to see its schema."))
      }
      reactable::reactableOutput("schema_table")
    })

    output$schema_table <- reactable::renderReactable({
      shiny::req(state$source, state$table)
      columns <- hb_list_columns(state$source, state$table)
      types <- hb_column_types()
      schema <- data.frame(
        Column = columns$name,
        Type = columns$type,
        `Read as` = types$r[match(columns$type, types$seatable)],
        Key = columns$key,
        Writable = ifelse(columns$editable, "yes", "no"),
        check.names = FALSE, stringsAsFactors = FALSE
      )
      reactable::reactable(
        schema,
        searchable = TRUE, compact = TRUE, defaultPageSize = 20,
        columns = list(
          Type = reactable::colDef(html = TRUE, cell = function(value) {
            .hb_type_chip(value)
          }),
          Key = reactable::colDef(class = "hb-key"),
          `Read as` = reactable::colDef(class = "hb-key")
        ),
        theme = reactable::reactableTheme(borderColor = "#e3ebe9")
      )
    })

    output$run_sql_ui <- shiny::renderUI({
      # Offering a button that cannot work is worse than not offering it.
      ready <- identical(state$kind, "server")
      shiny::actionButton(
        "run_sql", "Run query",
        class = "btn-primary btn-sm",
        disabled = !ready,
        title = if (ready) NULL else "Connect to a server to run SQL"
      )
    })

    shiny::observeEvent(input$run_sql, {
      .hb_try(session, "The query failed", {
        sql <- input$sql
        # hb_query() warns about a missing LIMIT in the console, which the
        # user cannot see, and only now and then. The panel says it here,
        # on every query it applies to, and keeps it out of the console.
        state$query <- withCallingHandlers(
          hb_query(state$source, sql),
          harbour_warning_query_limit = function(cnd) {
            invokeRestart("muffleWarning")
          }
        )
        if (.hb_sql_is_select(sql) && .hb_sql_lacks_limit(sql)) {
          shiny::showNotification(
            shiny::tags$div(
              shiny::tags$strong("No LIMIT clause"),
              shiny::tags$div(
                class = "small",
                "SeaTable returned at most 100 rows; add LIMIT n for more."
              )
            ),
            type = "warning", duration = 12
          )
        }
      })
    })

    output$query_panel <- shiny::renderUI({
      if (!identical(state$kind, "server")) {
        return(.hb_placeholder(
          "SQL needs a server. A .dtable is a file, not a database."
        ))
      }
      if (is.null(state$query)) {
        return(.hb_placeholder("Run a query to see results."))
      }
      # An UPDATE, INSERT or DELETE answers with no result to show.
      if (ncol(state$query) == 0L) {
        return(.hb_placeholder(
          "The statement ran and returned no columns. A statement other
           than SELECT may have changed the base."
        ))
      }
      reactable::reactableOutput("query_table")
    })

    output$query_table <- reactable::renderReactable({
      # A result with no columns is the panel's to explain; a table still
      # on screen from an earlier query would otherwise try to draw it.
      shiny::req(state$query, ncol(state$query) > 0L)
      reactable::reactable(
        .hb_display_frame(state$query),
        searchable = TRUE, compact = TRUE, defaultPageSize = 15
      )
    })

    output$export_panel <- shiny::renderUI({
      if (is.null(state$source)) {
        return(.hb_placeholder("Open a base to export it."))
      }
      # A file is written back as it was read, its attachments with it
      # only if they were extracted when it was opened. A live base has no
      # file behind it: its .dtable is rebuilt from the rows, which carry
      # the values but not the base's configuration.
      note <- if (!is_harbour_dtable(state$source)) {
        "Download the whole base. A live base is rebuilt from its rows, so
         its .dtable keeps the values but not the column types, select
         options, attachments or views; a spreadsheet flattens the columns
         a cell cannot hold."
      } else if (.hb_assets_left_out(state$source)) {
        "Download the whole base. This file was opened without its
         attachments, so its .dtable leaves them out; open it from the
         Source panel to keep them. A spreadsheet flattens the columns a
         cell cannot hold."
      } else {
        "Download the whole base. A .dtable keeps everything; a spreadsheet
         flattens the columns a cell cannot hold."
      }
      shiny::tagList(
        shiny::tags$p(class = "text-muted small", note),
        shiny::tags$div(
          class = "d-flex gap-2 flex-wrap",
          shiny::downloadButton("dl_dtable", ".dtable",
                                class = "btn-primary btn-sm"),
          shiny::downloadButton("dl_xlsx", "Excel workbook",
                                class = "btn-outline-secondary btn-sm"),
          shiny::downloadButton("dl_csv", "CSV (zipped)",
                                class = "btn-outline-secondary btn-sm"),
          shiny::downloadButton("dl_table_csv", "This table as CSV",
                                class = "btn-outline-secondary btn-sm")
        )
      )
    })

    # An output inside a hidden nav panel is suspended, so switching tab
    # shows an empty card. This must cover the reactable widgets as well as
    # the uiOutputs that wrap them: opting out only the wrapper renders the
    # widget's container and leaves the widget itself blank.
    for (id in c("data_panel", "schema_panel", "schema_legend",
                 "query_panel", "export_panel",
                 "data_table", "schema_table", "query_table",
                 "run_sql_ui")) {
      shiny::outputOptions(output, id, suspendWhenHidden = FALSE)
    }

    # The handlers delegate to .hb_export(), an ordinary function, so every
    # export can also be tested with any source and path, no session needed.
    output$dl_dtable <- shiny::downloadHandler(
      filename = function() .hb_download_name(state, "dtable"),
      content = function(file) {
        .hb_download(session, file, "Could not write the .dtable", {
          .hb_export(state$source, "dtable", file)
          if (!is_harbour_dtable(state$source)) .hb_notify_rebuilt()
        })
      }
    )

    output$dl_xlsx <- shiny::downloadHandler(
      filename = function() .hb_download_name(state, "xlsx"),
      content = function(file) {
        .hb_download(session, file, "Could not write the Excel workbook", {
          .hb_notify_flattening(session, {
            .hb_export(state$source, "xlsx", file)
          })
        })
      }
    )

    output$dl_csv <- shiny::downloadHandler(
      filename = function() .hb_download_name(state, "zip"),
      content = function(file) {
        .hb_download(session, file, "Could not write the CSV files", {
          .hb_notify_flattening(session, {
            .hb_export(state$source, "csv-zip", file)
          })
        })
      }
    )

    output$dl_table_csv <- shiny::downloadHandler(
      filename = function() {
        paste0(.hb_safe_filename(state$table %||% "table"), ".csv")
      },
      content = function(file) {
        .hb_download(session, file, "Could not write the CSV", {
          # The whole table, read afresh: table_data() is the Data panel's
          # preview, capped by its Rows setting, and a file named after the
          # table must not quietly hold only its first rows.
          data <- if (!is.null(state$table)) {
            hb_read_table(state$source, state$table)
          }
          .hb_export(state$source, "table-csv", file, data = data)
        })
      }
    )
  }
}

#' Run an expression, reporting failure to the user rather than crashing
#'
#' cli formats for a terminal, so its markup is stripped before the
#' message reaches the browser.
#'
#' @param session The shiny session.
#' @param title What was being attempted.
#' @param expr The expression to run.
#' @return The value of `expr`, or `NULL` on failure.
#' @keywords internal
#' @noRd
.hb_try <- function(session, title, expr) {
  rlang::try_fetch(
    expr,
    error = function(cnd) {
      shiny::showNotification(
        shiny::tags$div(
          shiny::tags$strong(title),
          shiny::tags$div(class = "small", .hb_plain_message(cnd))
        ),
        type = "error", duration = NULL
      )
      NULL
    }
  )
}

#' Reduce a condition to plain text a browser can show
#'
#' @param cnd A condition.
#' @return A single string.
#' @keywords internal
#' @noRd
.hb_plain_message <- function(cnd) {
  # inherit = FALSE keeps this condition's own message and bullets but
  # drops the chained parents. conditionMessage() would include them, which
  # for a failed upload means showing a C-level zip error and an internal
  # temp path the user never chose.
  text <- rlang::cnd_message(cnd, inherit = FALSE, prefix = FALSE)
  text <- gsub("\033\\[[0-9;]*m", "", text)
  text <- gsub("[\u2716\u2139\u2022]", "", text)
  text <- text[nzchar(trimws(text))]
  trimws(paste(text, collapse = " "))
}

#' Which kind of source this is
#'
#' @param x A source object or `NULL`.
#' @return `"server"`, `"file"`, or `NULL`.
#' @keywords internal
#' @noRd
.hb_source_kind <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  if (is_harbour_dtable(x)) "file" else "server"
}

#' The first table of a source, or `NULL`
#'
#' @param x A source object.
#' @return A single table name, or `NULL`.
#' @keywords internal
#' @noRd
.hb_first_table <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  index <- tryCatch(hb_list_tables(x), error = function(cnd) NULL)
  if (is.null(index) || nrow(index) == 0L) {
    return(NULL)
  }
  index$name[[1L]]
}

#' A table's column types, or an empty vector if they cannot be read
#'
#' Used only to draw the schema band, which must never be the reason a
#' table fails to list.
#'
#' @param x A source object.
#' @param table A table name.
#' @return A character vector.
#' @keywords internal
#' @noRd
.hb_safe_types <- function(x, table) {
  tryCatch(hb_list_columns(x, table)$type, error = function(cnd) character())
}

#' Where the bundled example base lives
#'
#' @return A path.
#' @keywords internal
#' @noRd
.hb_example_dtable <- function() {
  system.file("extdata", "example.dtable", package = "harbouR")
}

#' Coerce a source to a dtable so it can be written to a file
#'
#' @param x A source object.
#' @return A `harbour_dtable`.
#' @keywords internal
#' @noRd
.hb_as_dtable <- function(x) {
  if (is_harbour_dtable(x)) {
    return(x)
  }
  index <- hb_list_tables(x)
  frames <- lapply(index$name, function(table) {
    data <- hb_read_table(x, table)
    # SeaTable maintains _id and the other system fields itself. Writing
    # them back as ordinary columns produces a file whose read collides on
    # the reserved _id name - an export that cannot be re-opened.
    data[, !names(data) %in% .hb_dtable_row_system_fields, drop = FALSE]
  })
  # Built the way the CSV and Excel importers build a base, so that a table
  # called "collaborators" or "base_name" is not taken for hb_dtable()'s
  # argument of that name: the first would vanish from the download, the
  # second stop it.
  names(frames) <- index$name
  .hb_dtable_from_frames(frames, x$.base_name %||% "base")
}

#' Whether a .dtable written from a file would leave its attachments out
#'
#' A file read with `assets = "none"` keeps the cells that point at its
#' attachments but not the files, so a download of it cannot carry them.
#' Only file entries count: the listing has a row for each folder too.
#'
#' @param x A `harbour_dtable`.
#' @return `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
.hb_assets_left_out <- function(x) {
  bundled <- !endsWith(x$assets$filename %||% character(), "/")
  extracted <- !is.null(x$assets_dir) && dir.exists(x$assets_dir)
  any(bundled) && !extracted
}

#' Build the download filename for the current base
#'
#' @param state The app's reactive state.
#' @param ext File extension.
#' @return A single string.
#' @keywords internal
#' @noRd
.hb_download_name <- function(state, ext) {
  base <- if (is_harbour_dtable(state$source)) {
    state$source$base_name
  } else {
    state$source$.base_name %||% "base"
  }
  paste0(.hb_safe_filename(base %||% "base"), ".", ext)
}

#' Render a tibble for display, flattening what a cell cannot show
#'
#' @param data A tibble.
#' @return A data frame of display-ready columns.
#' @keywords internal
#' @noRd
.hb_display_frame <- function(data) {
  for (name in names(data)) {
    column <- data[[name]]
    if (is.list(column)) {
      data[[name]] <- .hb_flatten_column(column)
    } else if (inherits(column, "POSIXt")) {
      # Show a date as a date. The wire format - 2023-01-10T00:00:00Z -
      # is precise and unreadable; drop the time when there is none.
      has_time <- any(
        format(column, "%H:%M:%S") != "00:00:00",
        na.rm = TRUE
      )
      data[[name]] <- format(
        column,
        if (has_time) "%Y-%m-%d %H:%M" else "%Y-%m-%d"
      )
    }
  }
  as.data.frame(data, check.names = FALSE, stringsAsFactors = FALSE)
}

#' An empty-state panel
#'
#' @param message What the user should do next.
#' @return A shiny tag.
#' @keywords internal
#' @noRd
.hb_placeholder <- function(message) {
  shiny::tags$div(class = "hb-empty", message)
}

#' Write one export to a path
#'
#' The body of every download the explorer offers. Kept as a plain
#' function so tests can call it directly, with any source and path.
#'
#' @param source A `harbour_dtable` or `harbour_client`.
#' @param kind One of `"dtable"`, `"xlsx"`, `"csv-zip"`, `"table-csv"`.
#' @param path Destination path.
#' @param data For `"table-csv"`, the tibble to write.
#' @param call The frame to blame for any error.
#' @return `path`, invisibly.
#' @keywords internal
#' @noRd
.hb_export <- function(source, kind, path, data = NULL,
                       call = rlang::caller_env()) {
  kind <- rlang::arg_match(kind, c("dtable", "xlsx", "csv-zip", "table-csv"))
  if (is.null(source)) {
    hb_abort("No base is open.", class = "harbour_error_bad_argument",
             call = call)
  }
  switch(
    kind,
    dtable = hb_write_dtable(.hb_as_dtable(source), path),
    xlsx = {
      # hb_write_xlsx() asks for writexl through rlang::check_installed(),
      # which in an interactive session offers to install it at the
      # console: a prompt the explorer's user never sees, with the app
      # frozen until it is answered. Refuse with a reason the app can show.
      if (!requireNamespace("writexl", quietly = TRUE)) {
        hb_abort(
          c("The Excel workbook needs the {.pkg writexl} package.",
            "i" = "Install it with {.code install.packages(\"writexl\")}."),
          class = "harbour_error_unsupported",
          call = call
        )
      }
      hb_write_xlsx(source, path)
    },
    `csv-zip` = {
      dir <- tempfile("harbour-csv-")
      dir.create(dir)
      on.exit(unlink(dir, recursive = TRUE), add = TRUE)
      # Zip what was written rather than what list.files() finds: it skips
      # names that start with a dot, so a table called ".notes" would be
      # left out of the archive without a word.
      written <- hb_write_csv(source, dir)
      zip::zip(
        zipfile = .hb_absolute_path(path),
        files = basename(written), root = dir, mode = "cherry-pick"
      )
    },
    `table-csv` = {
      if (is.null(data)) {
        hb_abort("No table is open.", class = "harbour_error_bad_argument",
                 call = call)
      }
      .hb_write_csv_file(.hb_display_frame(data), path)
    }
  )
  invisible(path)
}

#' Run one download, reporting a failure in the browser
#'
#' An error in a download handler is printed to the R console, which the
#' app's user cannot see, and the browser is left with a failed download
#' and no reason. The reason is shown as a notification instead, as for
#' every other action in the app, and anything half-written is removed so
#' Shiny never serves a truncated file as if it were complete.
#'
#' @param session The shiny session.
#' @param path The file the download writes.
#' @param title What was being attempted.
#' @param expr The export.
#' @return `path`, invisibly.
#' @keywords internal
#' @noRd
.hb_download <- function(session, path, title, expr) {
  done <- .hb_try(session, title, {
    force(expr)
    TRUE
  })
  if (is.null(done)) unlink(path)
  invisible(path)
}

#' Say what a .dtable built from a live base leaves out
#'
#' A file source is written back as it was read, but a live base has no
#' file to copy: `.hb_as_dtable()` builds one from the rows. Without a word
#' that download would look as complete as a file export.
#'
#' @return The notification's id.
#' @keywords internal
#' @noRd
.hb_notify_rebuilt <- function() {
  shiny::showNotification(
    shiny::tags$div(
      shiny::tags$strong("The .dtable was rebuilt from the rows"),
      shiny::tags$div(
        class = "small",
        "A live base has no file to copy, so the download holds its values,
         with the column types inferred from them again. Select options,
         attachments and views are not kept."
      )
    ),
    type = "warning", duration = 12
  )
}

#' Surface the export's flattening report in the browser
#'
#' `hb_write_xlsx()` and `hb_write_csv()` report which columns had to be
#' flattened as a message. In a Shiny session that would go to the console
#' the user cannot see, so it is caught and shown as a notification - which
#' is what the explorer vignette promises.
#'
#' @param session The shiny session.
#' @param expr The export call.
#' @return The value of `expr`.
#' @keywords internal
#' @noRd
.hb_notify_flattening <- function(session, expr) {
  withCallingHandlers(
    expr,
    # Only the flattening report: anything else said during the export,
    # such as a request waiting to be retried, is not about flattening.
    harbour_message_flattened = function(cnd) {
      shiny::showNotification(
        shiny::tags$div(
          shiny::tags$strong("Some columns were flattened"),
          shiny::tags$div(class = "small", .hb_plain_message(cnd))
        ),
        type = "warning", duration = 12
      )
      invokeRestart("muffleMessage")
    }
  )
}
