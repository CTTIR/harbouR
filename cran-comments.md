## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
* Possibly misspelled words in DESCRIPTION: GmbH and SeaTable. Both
  belong to SeaTable GmbH, the German company behind the 'SeaTable'
  software; GmbH is the German abbreviation for a limited company. The
  software name is in single quotes throughout the Description; the
  company name is not, because it is not software.

The note comes from CRAN's incoming checks. The local runs below had
their remote part turned off and no spell checker installed, and gave
Status OK.

## Test environments

* Local: macOS 27.0.1 on Apple silicon. The tarball was built from the
  submitted commit with R 4.6.1 (aarch64-apple-darwin27.0.0) and checked
  with `R CMD check --as-cran --no-manual` (this machine has no LaTeX):
  * R 4.6.1, and R 4.5.3 (aarch64-apple-darwin20.0.0), with `NOT_CRAN`
    unset, as on CRAN: Status OK.
    The remote incoming checks were turned off because this machine's
    network timed out on them; the URL check, run on its own, found no
    problems;
  * every example runs in well under 1 s, and the tests in about 20 s;
  * R 4.6.1 with `_R_CHECK_DEPENDS_ONLY_=true`, as in CRAN's noSuggests
    check: Status OK, and the tests that need the missing packages skip.
* The test suite also passes in C, Shift-JIS, Big5 and GBK sessions and
  under several time zones.

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
