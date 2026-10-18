# ─────────────────────────────────────────────────────────────────────────────
# API lock — do not edit to make a build pass.
#
# This package is FROZEN: it underpins manuscripts written or in press, so its
# observable behaviour must not change. This file pins the public surface: the
# signature of every export, the registered S3 methods, the signature of each
# of those methods, and the declared dependencies. The method signatures
# matter as much as the exports': the arguments a user passes to
# hb_read_table() or the hb_list_*() verbs - view, n_max, refresh - are
# formals of the methods, not of the exported generics.
#
# If a snapshot here fails, the correct response is almost always to revert the
# source change, NOT to accept the snapshot. Accepting a snapshot in this file
# is a decision to change what a published analysis referred to.
#
# Legitimate reasons to accept a new snapshot:
#   * a NEW export was added (additive; existing lines must be untouched)
#
# Everything else — a changed signature, a changed default, a removed export,
# a changed return type — is a breaking change to a frozen package.
# ─────────────────────────────────────────────────────────────────────────────

# testing_package() is the supported way to learn which package is under
# test; packageName() returns NULL from inside a testthat test file.
pkg <- testthat::testing_package()

# All sorting uses method = "radix", which forces C-locale collation. Default
# sort() is locale-dependent, so the snapshot would otherwise differ between
# ubuntu, macOS and Windows runners and produce spurious lock failures.

# Render one formal as `name = default`, with defaults deparsed stably.
.fmt_formal <- function(nm, val) {
  if (identical(val, quote(expr = ))) {
    return(nm)
  }
  d <- paste(deparse(val, width.cutoff = 500L), collapse = " ")
  d <- gsub("\\s+", " ", d)
  paste0(nm, " = ", d)
}

.signature_of <- function(nm, ns) {
  obj <- tryCatch(get(nm, envir = ns), error = function(e) NULL)
  if (is.null(obj)) {
    return(paste0(nm, "  <unresolvable>"))
  }
  if (!is.function(obj)) {
    return(paste0(nm, "  <", paste(class(obj), collapse = "/"), ">"))
  }
  fm <- formals(obj)
  if (is.null(fm) || length(fm) == 0L) {
    return(paste0(nm, "()"))
  }
  args <- vapply(
    seq_along(fm),
    function(i) .fmt_formal(names(fm)[i], fm[[i]]),
    character(1)
  )
  paste0(nm, "(", paste(args, collapse = ", "), ")")
}

test_that("exported API surface is unchanged", {
  ns <- asNamespace(pkg)
  exports <- sort(getNamespaceExports(ns), method = "radix")
  sigs <- vapply(exports, .signature_of, character(1), ns = ns)
  expect_snapshot(cat(sigs, sep = "\n"))
})

test_that("registered S3 methods are unchanged", {
  ns <- asNamespace(pkg)
  # getNamespaceInfo() reflects the S3method() directives in NAMESPACE.
  # .__S3MethodsTable__. is NOT equivalent — it holds only methods for
  # generics owned by other packages, and reads empty for many packages.
  s3 <- getNamespaceInfo(ns, "S3methods")
  methods <- if (length(s3)) {
    sort(paste0(s3[, 1], ".", s3[, 2]), method = "radix")
  } else {
    character(0)
  }
  expect_snapshot(cat(methods, sep = "\n"))
})

test_that("registered S3 method signatures are unchanged", {
  ns <- asNamespace(pkg)
  s3 <- getNamespaceInfo(ns, "S3methods")
  sigs <- character(0)
  if (length(s3)) {
    # Column 3 names the function that implements the method. It is
    # usually generic.class, but S3method(generic, class, fun) may name any
    # function, so the formals are looked up from it and the line is
    # labelled generic.class.
    labels <- paste0(s3[, 1], ".", s3[, 2])
    sigs <- vapply(
      seq_along(labels),
      function(i) {
        sig <- .signature_of(s3[i, 3], ns)
        paste0(labels[[i]], substring(sig, nchar(s3[i, 3]) + 1L))
      },
      character(1)
    )
    sigs <- sigs[order(labels, method = "radix")]
  }
  expect_snapshot(cat(sigs, sep = "\n"))
})

test_that("declared dependencies are unchanged", {
  d <- read.dcf(system.file("DESCRIPTION", package = pkg))
  fields <- c("Depends", "Imports", "LinkingTo")
  out <- character(0)
  for (f in fields) {
    if (f %in% colnames(d)) {
      deps <- strsplit(d[, f], ",\\s*")[[1]]
      deps <- sort(trimws(deps), method = "radix")
      out <- c(out, paste0(f, ":"), paste0("  ", deps))
    }
  }
  expect_snapshot(cat(out, sep = "\n"))
})
