# Build inst/extdata/example.dtable, the fixture the .dtable tests run
# against. Hand-built rather than exported from a real base: a real export
# carries real people's e-mail addresses in its collaborators block.
#
# The content is deliberately awkward, because every awkward case here is
# one that broke something during development:
#   * one column of every type harbouR documents,
#   * a long-text cell in both its string and its object form,
#   * a single-element multiple-select, which auto_unbox would flatten to
#     a scalar,
#   * a 17-significant-digit float, which the default digits = 4 destroys,
#   * an absent cell, which is how SeaTable writes an empty one,
#   * a non-ASCII, non-syntactic column name,
#   * select cells holding option ids rather than names.
#
# Run with: Rscript data-raw/make-dtable-fixture.R
pkgload::load_all(quiet = TRUE)

empty_object <- harbouR:::.hb_empty_object()
empty_array <- harbouR:::.hb_empty_array()

column <- function(key, name, type, data = NULL) {
  list(
    key = key, type = type, name = name, editable = TRUE, width = 200L,
    resizable = TRUE, draggable = TRUE, data = data,
    permission_type = "", permitted_users = empty_array,
    permitted_group = empty_array
  )
}

select_options <- list(
  list(id = "opt1", name = "draft", color = "#aaa"),
  list(id = "opt2", name = "ready", color = "#bbb"),
  list(id = "opt3", name = "shipped", color = "#ccc")
)

columns <- list(
  column("0000", "Name", "text"),
  column("Lt01", "Notes", "long-text"),
  column("Nm01", "Concentration", "number"),
  column("Pc01", "Share", "percent"),
  column("Dl01", "Cost", "dollar"),
  column("Eu01", "Preis", "euro"),
  column("Du01", "Runtime", "duration",
         data = list(duration_format = "h:mm:ss")),
  column("Rt01", "Rating", "rate"),
  column("Cb01", "Consented", "checkbox"),
  column("Dt01", "Collected", "date", data = list(format = "YYYY-MM-DD")),
  column("Ss01", "Status", "single-select",
         data = list(options = select_options)),
  column("Ms01", "Tags", "multiple-select",
         data = list(options = list(
           list(id = "tag1", name = "urgent", color = "#ddd"),
           list(id = "tag2", name = "blood", color = "#eee")
         ))),
  column("Cl01", "Collaborators", "collaborator"),
  column("Im01", "Photos", "image"),
  column("Fl01", "Reports", "file"),
  column("Gl01", "Where", "geolocation",
         data = list(geo_format = "lng_lat")),
  column("Ur01", "Homepage", "url"),
  column("Em01", "Contact", "email"),
  column("Tc01", "Temperatur (°C)", "number"),
  column("Fm01", "Doubled", "formula",
         data = list(formula = "{Concentration} * 2", result_type = "number")),
  column("An01", "Ref", "auto-number"),
  column("Cr01", "Created by", "creator"),
  column("Lm01", "Changed by", "last-modifier"),
  column("Ct01", "Created", "ctime"),
  column("Mt01", "Changed", "mtime"),
  column("Bt01", "Action", "button"),
  column("Ds01", "Signature", "digital-sign")
)

stamp <- "2026-07-27T12:00:00.000+00:00"

rows <- list(
  list(
    `_id` = "S6zTWoOyQBeUyxsMzhAmWA",
    `_ctime` = stamp, `_mtime` = stamp,
    `_creator` = "demo@auth.local", `_last_modifier` = "demo@auth.local",
    `0000` = "S-001",
    Lt01 = "A plain **markdown** string.",
    # The precision case: digits = 4 would write 0.0006.
    Nm01 = 0.00058747474747474751,
    Pc01 = 0.42,
    Dl01 = 19.99,
    Eu01 = 17.5,
    Du01 = 3661,
    Rt01 = 4L,
    Cb01 = TRUE,
    Dt01 = "2026-04-01",
    # Select cells hold option ids on disk, names over the API.
    Ss01 = "opt2",
    Ms01 = list("tag1", "tag2"),
    Cl01 = list("demo@auth.local"),
    Im01 = list("file://dtable-bundle/asset/images/2026-07/plot.png"),
    Fl01 = list(list(
      name = "readme.txt", size = 12L, type = "file",
      url = "file://dtable-bundle/asset/files/2026-07/readme.txt"
    )),
    Gl01 = list(lng = 11.5761, lat = 48.1371),
    Ur01 = "https://example.org",
    Em01 = "demo@example.org",
    Tc01 = 20.7,
    Fm01 = 0.0011749494949494950,
    An01 = "0001",
    Cr01 = "demo@auth.local",
    Lm01 = "demo@auth.local",
    Ct01 = stamp,
    Mt01 = stamp,
    Ds01 = list(list(
      username = "demo@auth.local", sign_time = stamp,
      sign_image_url = "file://dtable-bundle/asset/images/sign.png"
    ))
  ),
  list(
    `_id` = "CwD7tBAETtSXLQKQXhaR6A",
    `_ctime` = stamp, `_mtime` = stamp,
    `0000` = "S-002",
    # long-text in its object form.
    Lt01 = list(
      text = "Rendered elsewhere.", preview = "Rendered elsewhere.",
      images = empty_array, links = empty_array, checklist = empty_object
    ),
    Nm01 = 8.1,
    Ss01 = "opt1",
    # A single-element array: auto_unbox would collapse this to a scalar.
    Ms01 = list("tag1"),
    Cb01 = FALSE,
    Dt01 = "2026-04-03"
    # Every other cell is absent, which is how SeaTable records an empty
    # one - not as null, and not as "".
  )
)

reference <- list(
  `_id` = "ref1",
  name = "Reference",
  rows = list(
    list(`_id` = "NK6Qu-77Qbqc7Q0lnPrBkw", `0000` = "Aspergillus",
         Kd01 = "yes"),
    list(`_id` = "PL8Ru-88Rcrd8R1moQsClx", `0000` = "Penicillium",
         Kd01 = "no")
  ),
  columns = list(
    column("0000", "Genus", "text"),
    column("Kd01", "Toxin former", "text")
  ),
  view_structure = list(folders = empty_array, view_ids = list("0000")),
  views = list(harbouR:::.hb_default_view()),
  id_row_map = empty_object,
  summary_configs = empty_object,
  is_header_locked = FALSE,
  header_settings = empty_object
)

samples <- list(
  `_id` = "smp1",
  name = "Samples",
  rows = rows,
  columns = columns,
  view_structure = list(folders = empty_array, view_ids = list("0000")),
  views = list(harbouR:::.hb_default_view()),
  id_row_map = empty_object,
  summary_configs = empty_object,
  is_header_locked = FALSE,
  header_settings = empty_object
)

content <- list(
  version = 42L,
  format_version = 9L,
  statistics = empty_array,
  links = empty_array,
  tables = list(samples, reference),
  collaborators = list(list(
    email = "demo@auth.local", name = "Demo User",
    contact_email = "demo@example.org", is_admin = FALSE
  )),
  # A field harbouR does not model, to prove the round trip keeps it.
  plugin_settings = empty_object
)

staging <- tempfile("fixture-")
dir.create(file.path(staging, "asset", "files", "2026-07"), recursive = TRUE)
dir.create(file.path(staging, "asset", "images", "2026-07"), recursive = TRUE)
writeLines("hello world", file.path(staging, "asset", "files", "2026-07",
                                    "readme.txt"))
png_path <- file.path(staging, "asset", "images", "2026-07", "plot.png")
grDevices::png(png_path, width = 16, height = 16)
graphics::par(mar = c(0, 0, 0, 0))
graphics::plot.new()
grDevices::dev.off()

json <- harbouR:::.hb_dtable_to_json(content)
writeBin(charToRaw(as.character(json)), file.path(staging, "content.json"))

out <- file.path("inst", "extdata", "example.dtable")
unlink(out)
zip::zip(
  zipfile = file.path(getwd(), out),
  files = c("content.json", "asset"),
  root = staging,
  mode = "cherry-pick"
)

cat(sprintf("wrote %s (%d bytes)\n", out, file.info(out)$size))
check <- harbouR::hb_read_dtable(out)
print(check)

# The meaningful property is that reading and writing is a fixed point.
# Comparing against the R source above would fail for an uninteresting
# reason: JSON has no integer/double distinction, so 3661 comes back as an
# integer however it was written.
again <- tempfile(fileext = ".dtable")
harbouR::hb_write_dtable(check, again)
stopifnot(identical(harbouR::hb_read_dtable(again)$content, check$content))
cat("round-trips identically\n")
