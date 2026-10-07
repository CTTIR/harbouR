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
