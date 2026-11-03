## Integrated source validation, 3 November 2026

* The merge of upstream `cee3580` and maintenance `845512a` passes 2,431
  source assertions on macOS arm64 with R 4.6.1: no failures or warnings,
  12 unconfigured live-server skips and two source-only citation skips.
  The API lock and golden offline checks pass without changed expectations.
* A local HTTP fixture receives an upload body, delays its response, and
  confirms that the finite request deadline interrupts the wait without
  an automatic retry or a change to the local file. The error explains
  that the server may have accepted the upload before the timeout.
* This integrated source has not been submitted, checked on a live server,
  or qualified by a new hosted platform matrix. The archive checks below
  are historical; they do not describe a new package built from this merge.

## Earlier source archive R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
* Possibly misspelled words in DESCRIPTION: GmbH and SeaTable. Both
  belong to SeaTable GmbH, the German company behind the 'SeaTable'
  software; GmbH is the German abbreviation for a limited company. The
  software name is in single quotes throughout the Description; the
  company name is not, because it is not software.

The note comes from CRAN's incoming checks. Locally, with no spell
checker installed, the only note was the new submission.

## Earlier upstream qualification (`cee3580`)

* Local: Ubuntu 26.04 LTS, R 4.6.1. The tarball was built from the
  submitted commit and checked with `R CMD check --as-cran`:
  * with `NOT_CRAN` unset, as on CRAN: 1 NOTE, the new submission;
  * with `_R_CHECK_DEPENDS_ONLY_=true`, as in CRAN's noSuggests check,
    and `--ignore-vignettes`, since the vignettes need `rmarkdown`:
    Status OK, and the tests that need the missing packages skip.
* The tests were also run against a SeaTable 6.2.1 server, with the
  opt-in live tests switched on: all pass.

## Earlier maintenance qualification (`845512a`)

* Local: macOS 27.0.1 on Apple silicon, R 4.6.1
  (aarch64-apple-darwin27.0.0).
* The source archive was built from a clean source export and checked with
  `R CMD check --as-cran`, including remote incoming checks, rebuilt
  vignettes and PDF/HTML manuals: 0 errors, 0 warnings, 1 new-submission note.
  Installed tests: 2,193 passing assertions, no failures or warnings,
  32 deliberate skips in CRAN mode.
* The same archive passed the dependency-only check with
  `_R_CHECK_DEPENDS_ONLY_=true` and `_R_CHECK_FORCE_SUGGESTS_=false`:
  0 errors, 0 warnings, 1 new-submission note; 2,033 passing assertions,
  79 deliberate skips for optional dependencies or CRAN mode.
* With `NOT_CRAN=true`, the source suite passes 2,222 assertions with no
  failures or warnings. Its eight skips are six unconfigured live-server
  checks and two citation tests requiring installed DESCRIPTION metadata.
  The frozen API and golden offline outputs are unchanged.
* A fresh installation of this exact archive preserves the bundled base
  content, table values and attachment hashes on an offline round trip.
  CSV and Excel conversions and rejected unsafe extraction were exercised.
* No current Windows, Linux, R-devel or hosted CI result is claimed for
  these local maintenance commits. No live SeaTable server was modified.

## Notes

* Examples that need a SeaTable server and an API token are wrapped in
  `\dontrun{}` because many would change that base. Offline examples,
  ordinary tests and vignettes use the bundled synthetic fixture or
  mocked responses. Tests opening a local socket skip on CRAN.
  Live integration tests run only outside CRAN when HARBOUR_TEST_SERVER
  and HARBOUR_TEST_TOKEN name a disposable test base.
* SeaTable is a trademark of SeaTable GmbH. This package is independent
  and unofficial, and is not affiliated with or endorsed by that company.
* Repository-only citation metadata and local development records are
  excluded from the source archive. The package citation uses the public
  repository URL. Existing source authors and maintainer metadata remain
  unchanged.
