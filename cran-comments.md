## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Test environments

* local: x86_64-pc-linux-gnu (Ubuntu 24.04), R 4.6.1
* GitHub Actions: ubuntu (release, devel, oldrel-1), macOS, windows
* GitHub Actions: ubuntu release with `_R_CHECK_FORCE_SUGGESTS_=false`
* GitHub Actions: ubuntu release with CRAN incoming checks enabled

## Notes

* All examples, tests and vignettes run offline. HTTP is replaced at the
  package's own request seam, and the bundled `inst/extdata/example.dtable`
  supplies a complete example base. Nothing in the check contacts a network
  service.

* `tests/testthat/test-live.R` is the only file that would talk to a
  SeaTable server. It calls `skip_on_cran()` and additionally skips unless
  `HARBOUR_TEST_SERVER` and `HARBOUR_TEST_TOKEN` are set, so it never runs
  during a CRAN check.

* SeaTable is a trademark of SeaTable GmbH. This package is an independent,
  unofficial client and is not affiliated with or endorsed by SeaTable
  GmbH; the DESCRIPTION says so.
