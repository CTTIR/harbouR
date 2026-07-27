## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Test environments

* local: x86_64-pc-linux-gnu (Ubuntu 24.04), R 4.6.1
* GitHub Actions: ubuntu (release, devel, oldrel-1), macOS, windows

## Notes

* All tests, examples and vignettes run fully offline. HTTP traffic is
  replaced at the package's internal request seam, and the bundled
  offline fixtures under `inst/extdata/` supply the example base. No
  check-time code contacts a network service.
