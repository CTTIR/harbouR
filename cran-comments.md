## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Test environments

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
