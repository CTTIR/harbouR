## Submission

This is a new submission: harbouR 1.0.0.

## Test environments

* Local: macOS 27 on Apple silicon, R 4.6.1 (aarch64-apple-darwin),
  `R CMD check --as-cran --no-manual` on the built tarball, with
  `NOT_CRAN` unset. The PDF manual was built locally with TinyTeX (TeX Live
  2026) via `R CMD Rd2pdf` without errors; the check run itself used
  `--no-manual`.
* GitHub Actions (r-lib/actions v2, `--as-cran`): macOS-latest (R
  release), windows-latest (R release), ubuntu-latest (R devel, R
  release, R oldrel-1).

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

CRAN's incoming spell check may also list GmbH and SeaTable as possibly
misspelled words in DESCRIPTION. Both belong to SeaTable GmbH, the
German company behind the 'SeaTable' software; GmbH is the German
abbreviation for a limited company. The software name is in single
quotes throughout the Description; the company name is not, because it
is not software.

## Notes

* Examples that need a SeaTable server and an API token are wrapped in
  `\dontrun{}`, because they need credentials and many of them would
  change that base. Each such block starts with a comment saying so.
  Offline examples, ordinary tests and vignettes use the bundled
  synthetic `.dtable` fixture or mocked HTTP responses and run on CRAN.
* No test, example or vignette contacts a server. Tests that open a
  local socket skip on CRAN. Live integration tests run only outside
  CRAN when `HARBOUR_TEST_SERVER` and `HARBOUR_TEST_TOKEN` name a
  disposable test base.
* SeaTable is a trademark of SeaTable GmbH. This package is independent
  and unofficial, and is not affiliated with or endorsed by that
  company; the Description says so.
