# Reproducible build for the harbouR hex sticker.
# Source of truth: harbouR icon.svg (committed at repo root).
# Outputs:
#   man/figures/logo.svg
#   man/figures/logo.png  (480 px wide, transparent)
#   inst/shiny/harbour_explorer/www/logo.png (320 px wide)

src <- "harbouR icon.svg"
stopifnot(file.exists(src))

dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("inst/shiny/harbour_explorer/www", recursive = TRUE,
           showWarnings = FALSE)

file.copy(src, "man/figures/logo.svg", overwrite = TRUE)

if (requireNamespace("rsvg", quietly = TRUE)) {
  rsvg::rsvg_png("man/figures/logo.svg", "man/figures/logo.png",
                 width = 480)
  rsvg::rsvg_png("man/figures/logo.svg",
                 "inst/shiny/harbour_explorer/www/logo.png",
                 width = 320)
  message("Wrote PNGs.")
} else {
  message("rsvg not available; only SVG copied.")
}
