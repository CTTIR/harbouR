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

    open_source <- function(value, kind) {
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
      .hb_try(session, "Could not open that file", {
        open_source(hb_read_dtable(file$datapath), "file")
        # datapath is a temporary upload name; keep the real one for the
        # download filename.
        state$source$base_name <- tools::file_path_sans_ext(file$name)
      })
    })

    shiny::observeEvent(input$use_demo, {
      open_source(hb_read_dtable(.hb_example_dtable()), "demo")
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

    shiny::observeEvent(input$run_sql, {
      .hb_try(session, "The query failed", {
        state$query <- hb_query(state$source, input$sql)
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
      reactable::reactableOutput("query_table")
    })

    output$query_table <- reactable::renderReactable({
      shiny::req(state$query)
      reactable::reactable(
        .hb_display_frame(state$query),
        searchable = TRUE, compact = TRUE, defaultPageSize = 15
      )
    })

    output$export_panel <- shiny::renderUI({
      if (is.null(state$source)) {
        return(.hb_placeholder("Open a base to export it."))
      }
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
    })

    output$dl_dtable <- shiny::downloadHandler(
      filename = function() .hb_download_name(state, "dtable"),
      content = function(file) {
        hb_write_dtable(.hb_as_dtable(state$source), file)
      }
    )

    output$dl_xlsx <- shiny::downloadHandler(
      filename = function() .hb_download_name(state, "xlsx"),
      content = function(file) {
        hb_write_xlsx(state$source, file)
      }
    )

    output$dl_csv <- shiny::downloadHandler(
      filename = function() .hb_download_name(state, "zip"),
      content = function(file) {
        dir <- tempfile("harbour-csv-")
        dir.create(dir)
        on.exit(unlink(dir, recursive = TRUE), add = TRUE)
        hb_write_csv(state$source, dir)
        zip::zip(
          zipfile = .hb_absolute_path(file),
          files = list.files(dir), root = dir, mode = "cherry-pick"
        )
      }
    )

    # A uiOutput inside a hidden nav panel is suspended, so switching tab
    # shows an empty card until the next reactive flush happens to run.
    # These four decide what their panel contains, so they must stay live.
    for (id in c("data_panel", "schema_panel", "schema_legend",
                 "query_panel", "export_panel")) {
      shiny::outputOptions(output, id, suspendWhenHidden = FALSE)
    }

    output$dl_table_csv <- shiny::downloadHandler(
      filename = function() {
        paste0(.hb_safe_filename(state$table %||% "table"), ".csv")
      },
      content = function(file) {
        utils::write.csv(
          .hb_display_frame(table_data()), file,
          row.names = FALSE, fileEncoding = "UTF-8"
        )
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
  text <- conditionMessage(cnd)
  text <- gsub("\033\\[[0-9;]*m", "", text)
  text <- gsub("[\u2716\u2139\u2022]", "", text)
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
  frames <- lapply(index$name, function(table) hb_read_table(x, table))
  names(frames) <- index$name
  rlang::exec(hb_dtable, !!!frames, base_name = x$.base_name %||% "base")
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
