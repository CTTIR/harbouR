## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Test environments

* Local: Ubuntu 26.04 LTS, x86_64-pc-linux-gnu, R 4.6.1 (2026-06-24).
* R CMD check --as-cran, including remote incoming checks, completed on
  2026-10-07. Examples, tests, all three vignettes and the PDF manual passed.
* The public API snapshot checks and the full local test suite passed.

## Notes

* Examples, tests and vignettes use the bundled synthetic example base or
  mocked HTTP responses. They do not require a running SeaTable service.
* Live integration tests are skipped on CRAN and additionally require
  HARBOUR_TEST_SERVER and HARBOUR_TEST_TOKEN to be explicitly configured.
* SeaTable is a trademark of SeaTable GmbH. This package is an independent,
  unofficial client and is not affiliated with or endorsed by SeaTable GmbH.
* Repository-only citation metadata and local development records are
  excluded from the source archive. The package citation uses the public
  repository URL; an unpublished archival identifier is not included.

## Additional checks

* win-builder R-oldrelease: R 4.5.3 (2026-03-11 ucrt), Windows Server 2022
  x64, checked on 2026-10-07: 0 errors, 0 warnings, 1 NOTE.
* Its incoming NOTE reports a new submission and flags SeaTable and GmbH
  as possibly misspelled. SeaTable is the software/company name; GmbH is
  the German company legal-form abbreviation. Both spellings are intentional.
* GitHub Actions for package-source commit cf3f2c1 passed Linux release,
  devel, oldrel-1 and oldrel-3, Windows release and macOS release checks.
  The API lock, coverage, lint and pkgdown workflows also passed.
* Separate win-builder R-release and R-devel checks were resubmitted on
  2026-10-12; their reports have not yet been reviewed.
