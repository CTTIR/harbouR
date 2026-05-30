# Reproducible build for the harbouR hex sticker.
# Outputs:
#   man/figures/logo.svg  (transparent master)
#   man/figures/logo.png  (240px height, transparent)
#   inst/shiny/harbour_explorer/www/logo.png (160px)

dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("inst/shiny/harbour_explorer/www", recursive = TRUE, showWarnings = FALSE)

svg <- '<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 277" width="240" height="277">
  <defs>
    <clipPath id="hex">
      <polygon points="120,4 233,69 233,208 120,273 7,208 7,69"/>
    </clipPath>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#0c1430"/>
      <stop offset="1" stop-color="#0a3a4a"/>
    </linearGradient>
  </defs>

  <g clip-path="url(#hex)">
    <rect x="0" y="0" width="240" height="277" fill="url(#bg)"/>
    <!-- tide lines / table rows -->
    <line x1="20" y1="180" x2="220" y2="180" stroke="#5E2C8E" stroke-opacity="0.18" stroke-width="1"/>
    <line x1="20" y1="195" x2="220" y2="195" stroke="#5E2C8E" stroke-opacity="0.14" stroke-width="1"/>
    <line x1="20" y1="210" x2="220" y2="210" stroke="#5E2C8E" stroke-opacity="0.10" stroke-width="1"/>
    <!-- breakwaters -->
    <path d="M30,170 L70,170 L78,180 L30,180 Z" fill="#5E2C8E" fill-opacity="0.55"/>
    <path d="M210,170 L170,170 L162,180 L210,180 Z" fill="#5E2C8E" fill-opacity="0.55"/>
    <!-- beacon -->
    <rect x="115" y="110" width="10" height="60" fill="#e8e8e8"/>
    <polygon points="120,90 110,110 130,110" fill="#e8e8e8"/>
    <circle cx="120" cy="100" r="5" fill="#ffb347"/>
    <!-- beacon beam -->
    <path d="M120,100 L60,60 L60,72 Z" fill="#ffb347" fill-opacity="0.18"/>
    <path d="M120,100 L180,60 L180,72 Z" fill="#ffb347" fill-opacity="0.18"/>
  </g>

  <!-- hex border -->
  <polygon points="120,4 233,69 233,208 120,273 7,208 7,69"
           fill="none" stroke="#5E2C8E" stroke-width="6"/>

  <!-- wordmark -->
  <text x="120" y="248" text-anchor="middle"
        font-family="JetBrains Mono, Menlo, monospace"
        font-size="28" font-weight="600" fill="#e8e8e8"
        letter-spacing="2">harbouR</text>
</svg>
'

writeLines(svg, "man/figures/logo.svg")

if (requireNamespace("rsvg", quietly = TRUE)) {
  rsvg::rsvg_png("man/figures/logo.svg", "man/figures/logo.png",
                 width = 480)
  rsvg::rsvg_png("man/figures/logo.svg",
                 "inst/shiny/harbour_explorer/www/logo.png",
                 width = 320)
  message("Wrote PNGs.")
} else {
  message("rsvg not available; only SVG written.")
}
