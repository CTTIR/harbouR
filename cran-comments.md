## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
* Possibly misspelled words in DESCRIPTION: GmbH and SeaTable. Both
  belong to SeaTable GmbH, the German company behind the 'SeaTable'
  software; GmbH is the German abbreviation for a limited company. The
  software name is in single quotes throughout the Description; the
  company name is not, because it is not software.

The note comes from CRAN's incoming checks. Locally, with no spell
checker installed, the only note was the new submission.

## Test environments

* Local: Ubuntu 26.04 LTS, R 4.6.1. The tarball was built from the
  submitted commit and checked with `R CMD check --as-cran`:
  * with `NOT_CRAN` unset, as on CRAN: 1 NOTE, the new submission;
  * with `_R_CHECK_DEPENDS_ONLY_=true`, as in CRAN's noSuggests check,
    and `--ignore-vignettes`, since the vignettes need `rmarkdown`:
    Status OK, and the tests that need the missing packages skip.
* The tests were also run against a SeaTable 6.2.1 server, with the
  opt-in live tests switched on: all pass.

## Notes

* Examples that need a SeaTable server and an API token are wrapped in
  `\dontrun{}`: they cannot run without credentials for a live base, and
  many of them would change it. Functions that also work on a local
  `.dtable` file show that use in examples that run. All other examples,
  the tests and the vignettes use the bundled synthetic example base or
  mocked HTTP responses, and need neither a SeaTable server nor internet
  access. The few tests that open a local socket skip on CRAN. Live
  integration tests are skipped on CRAN and run only when
  HARBOUR_TEST_SERVER and HARBOUR_TEST_TOKEN are set.
* SeaTable is a trademark of SeaTable GmbH. This package is an
  independent, unofficial client and is not affiliated with or endorsed
  by SeaTable GmbH.
* Repository-only citation metadata and local development records are
  excluded from the source archive. The package citation uses the public
  repository URL.
