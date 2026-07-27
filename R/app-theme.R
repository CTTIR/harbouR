#' The harbouR explorer's palette
#'
#' Taken from the package logo, which is built on viridis. That is not a
#' coincidence worth discarding: viridis is the colourblind-safe,
#' perceptually uniform scale this package's users already read their own
#' figures in, so the app speaks their visual language rather than
#' inventing a second one.
#'
#' The scale is used to carry information, not decoration: every SeaTable
#' column type gets a fixed position on it, so the same type is the same
#' colour everywhere in the app.
#'
#' @return A named character vector of hex colours.
#' @keywords internal
#' @noRd
.hb_palette <- function() {
  c(
    abyss = "#021820",
    deep = "#08382C",
    kelp = "#0F6E56",
    tide = "#1D9E75",
    teal = "#21908C",
    foam = "#80CBC4",
    beacon = "#FDE725",
    paper = "#F7FAF9",
    ink = "#0B1E24",
    mist = "#5B7A80"
  )
}

#' Where each SeaTable column type sits on the scale
#'
#' Types are grouped by what they *are* - text, quantity, time, choice,
#' attachment, relationship, machine-maintained - and each group takes one
#' colour. Reading a schema then means reading a pattern rather than
#' twenty-eight labels.
#'
#' @return A tibble with columns `seatable` (chr), `family` (chr) and
#'   `colour` (chr).
#' @keywords internal
#' @noRd
.hb_type_families <- function() {
  pal <- .hb_palette()
  families <- c(
    text = unname(pal[["mist"]]),
    quantity = unname(pal[["tide"]]),
    time = unname(pal[["teal"]]),
    choice = unname(pal[["kelp"]]),
    attachment = unname(pal[["foam"]]),
    relationship = unname(pal[["beacon"]]),
    automatic = unname(pal[["deep"]])
  )
  family_of <- c(
    text = "text", `long-text` = "text", email = "text", url = "text",
    number = "quantity", percent = "quantity", dollar = "quantity",
    euro = "quantity", duration = "quantity", rate = "quantity",
    checkbox = "choice", `single-select` = "choice",
    `multiple-select` = "choice",
    date = "time", ctime = "time", mtime = "time",
    image = "attachment", file = "attachment", geolocation = "attachment",
    `digital-sign` = "attachment",
    link = "relationship", `link-formula` = "relationship",
    collaborator = "relationship",
    formula = "automatic", `auto-number` = "automatic",
    button = "automatic", creator = "automatic",
    `last-modifier` = "automatic"
  )
  types <- hb_column_types()$seatable
  family <- unname(family_of[types])
  family[is.na(family)] <- "text"
  tibble::tibble(
    seatable = types,
    family = family,
    colour = unname(families[family])
  )
}

#' The colour for one column type
#'
#' @param type A SeaTable column type.
#' @return A single hex colour.
#' @keywords internal
#' @noRd
.hb_type_colour <- function(type) {
  families <- .hb_type_families()
  hit <- match(type, families$seatable)
  ifelse(is.na(hit), .hb_palette()[["mist"]], families$colour[hit])
}

#' The explorer's bslib theme
#'
#' @return A `bs_theme` object.
#' @keywords internal
#' @noRd
.hb_theme <- function() {
  pal <- .hb_palette()
  bslib::bs_theme(
    version = 5,
    bg = unname(pal[["paper"]]),
    fg = unname(pal[["ink"]]),
    primary = unname(pal[["kelp"]]),
    secondary = unname(pal[["mist"]]),
    success = unname(pal[["tide"]]),
    info = unname(pal[["teal"]]),
    warning = unname(pal[["beacon"]]),
    # System stacks only: the app must work with no network, and a
    # package that ships a font is a package that ships a licence problem.
    base_font = bslib::font_collection(
      "Inter", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"
    ),
    code_font = bslib::font_collection(
      "JetBrains Mono", "SFMono-Regular", "Menlo", "Consolas", "monospace"
    ),
    "border-radius" = "0.25rem",
    "navbar-brand-font-size" = "1.05rem"
  )
}

#' The explorer's stylesheet
#'
#' Kept as a string rather than a file under `inst/` so it moves with the
#' code it styles, and so `R CMD check` and `covr` can see it.
#'
#' @return A `shiny::tags$style` element.
#' @keywords internal
#' @noRd
.hb_styles <- function() {
  pal <- .hb_palette()
  css <- sprintf(
    "
:root {
  --hb-abyss: %s; --hb-deep: %s; --hb-kelp: %s; --hb-tide: %s;
  --hb-teal: %s; --hb-foam: %s; --hb-beacon: %s;
  --hb-paper: %s; --hb-ink: %s; --hb-mist: %s;
}
body { background: var(--hb-paper); }

/* The masthead reads as the waterline the logo is built on. */
.hb-masthead {
  background: linear-gradient(160deg, var(--hb-abyss), var(--hb-deep));
  color: #fff;
  padding: 0.55rem 1rem;
  display: flex; align-items: center; gap: 0.65rem;
  border-bottom: 2px solid var(--hb-tide);
}
.hb-masthead .hb-wordmark {
  font-weight: 600; letter-spacing: -0.01em; font-size: 1.05rem;
}
.hb-masthead .hb-wordmark span { color: var(--hb-foam); }

/* Identifiers are machine-generated, so they are set in the machine face.
   Labels people wrote are set in the reading face. The distinction is the
   type system doing work. */
.hb-key, .hb-type, code, pre { font-family: var(--bs-font-monospace); }
.hb-key { color: var(--hb-mist); font-size: 0.8rem; }

.hb-chip {
  display: inline-block; padding: 0.05rem 0.4rem; border-radius: 999px;
  font-size: 0.72rem; font-weight: 500; line-height: 1.5;
  border: 1px solid rgba(2, 24, 32, 0.12);
  color: var(--hb-ink);
}

/* The signature: a table's columns as a band of type-coloured segments,
   so the shape of a 66-column table is legible before you open it. */
.hb-sounding {
  display: flex; height: 8px; width: 100%%; gap: 1px;
  border-radius: 2px; overflow: hidden; margin-top: 0.3rem;
  background: rgba(2, 24, 32, 0.06);
}
.hb-sounding i { display: block; flex: 1 1 auto; min-width: 2px; }

.hb-table-card {
  border: 1px solid rgba(2, 24, 32, 0.1); border-radius: 0.25rem;
  padding: 0.6rem 0.75rem; margin-bottom: 0.45rem; cursor: pointer;
  background: #fff; transition: border-color 0.12s, transform 0.12s;
}
.hb-table-card:hover, .hb-table-card:focus-visible {
  border-color: var(--hb-tide); transform: translateX(2px);
}
.hb-table-card.hb-active {
  border-color: var(--hb-kelp);
  box-shadow: inset 3px 0 0 var(--hb-kelp);
}
.hb-table-card .hb-name { font-weight: 600; font-size: 0.92rem; }
.hb-table-card .hb-meta { color: var(--hb-mist); font-size: 0.78rem; }

.hb-empty {
  border: 1px dashed rgba(2, 24, 32, 0.2); border-radius: 0.25rem;
  padding: 2rem; text-align: center; color: var(--hb-mist);
}

.hb-source {
  display: inline-flex; align-items: center; gap: 0.35rem;
  font-size: 0.78rem; padding: 0.1rem 0.5rem; border-radius: 999px;
  background: rgba(29, 158, 117, 0.14); color: var(--hb-deep);
  font-weight: 500;
}
.hb-source.hb-file { background: rgba(128, 203, 196, 0.28); }
.hb-source.hb-demo { background: rgba(253, 231, 37, 0.35); }

:focus-visible { outline: 2px solid var(--hb-tide); outline-offset: 2px; }

@media (prefers-reduced-motion: reduce) {
  .hb-table-card { transition: none; }
}
",
    pal[["abyss"]], pal[["deep"]], pal[["kelp"]], pal[["tide"]],
    pal[["teal"]], pal[["foam"]], pal[["beacon"]],
    pal[["paper"]], pal[["ink"]], pal[["mist"]]
  )
  shiny::tags$style(shiny::HTML(css))
}

#' Render a table's column types as a band of segments
#'
#' @param types A character vector of SeaTable column types.
#' @return An HTML string.
#' @keywords internal
#' @noRd
.hb_sounding <- function(types) {
  if (length(types) == 0L) {
    return("")
  }
  segments <- paste0(
    '<i style="background:', .hb_type_colour(types), '"></i>',
    collapse = ""
  )
  paste0('<div class="hb-sounding" aria-hidden="true">', segments, "</div>")
}

#' Render a column type as a labelled chip
#'
#' @param type A SeaTable column type.
#' @return An HTML string.
#' @keywords internal
#' @noRd
.hb_type_chip <- function(type) {
  colour <- .hb_type_colour(type)
  # The family colour tints the chip; the text stays dark ink. Using the
  # family colour for the text fails contrast on the lighter families -
  # mint and beacon are unreadable at 4.5:1 on their own tint.
  paste0(
    '<span class="hb-chip hb-type" style="background:', colour, "2E",
    ";border-color:", colour, '99">', type, "</span>"
  )
}
