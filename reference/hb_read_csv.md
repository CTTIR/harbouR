# Read tables into a new base from CSV files

Builds a fresh `harbour_dtable` from CSV files, one table per file. This
is **not** the inverse of
[`hb_write_csv()`](https://cttir.github.io/harbouR/reference/hb_write_csv.md):
it produces a new base with new identifiers, and only text, number and
checkbox columns. Nothing that a CSV cannot carry is recovered.

## Usage

``` r
hb_read_csv(files, ..., base_name = "harbouR base")
```

## Arguments

- files:

  Paths to `.csv` files. Table names come from the file names unless
  `files` is named.

- ...:

  These dots are for future extensions and must be empty.

- base_name:

  Name recorded for the new base.

## Value

A `harbour_dtable`, with the components
[`hb_read_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_dtable.md)
describes, holding one table per file.

## Details

Columns are typed the way
[`utils::read.csv()`](https://rdrr.io/r/utils/read.table.html) types
them, and quoting a value does not change that:

- A column of numbers becomes `number`, and one holding only `T`, `F`,
  `TRUE` or `FALSE` becomes `checkbox`.

- A value written `NA` is read as missing.

- Dates and date-times arrive as text.

Two exceptions avoid losing data. A column holding an integer with a
leading zero, such as `"0001"`, or an integer of more than 15 digits
stays text, rather than losing the zeros or having its digits rounded,
and so does one holding a code such as `"12E"`, which
[`utils::read.csv()`](https://rdrr.io/r/utils/read.table.html) reads as
`12` in R before 4.4.1. A column with no values at all is text, not a
checkbox column that would read `FALSE` in every row.

The files must be UTF-8, with or without a byte-order mark. A file in
another encoding is refused, naming the first line that is not valid
UTF-8. In a multibyte session that is not UTF-8, such as Shift-JIS or
GBK, the text goes through that session's encoding, so characters it
lacks are lost; read such files in a UTF-8 session. A column named
`_id`, such as the one
[`hb_write_csv()`](https://cttir.github.io/harbouR/reference/hb_write_csv.md)
writes, is dropped: SeaTable keeps that name for the row identifier, and
the new base has identifiers of its own. One that holds anything but
SeaTable row ids, such as a database's keys, is dropped with a warning.

## See also

Other dtable:
[`as_tibble.harbour_dtable()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_dtable.md),
[`hb_asset_path()`](https://cttir.github.io/harbouR/reference/hb_asset_path.md),
[`hb_dtable()`](https://cttir.github.io/harbouR/reference/hb_dtable.md),
[`hb_read_dtable()`](https://cttir.github.io/harbouR/reference/hb_read_dtable.md),
[`hb_read_xlsx()`](https://cttir.github.io/harbouR/reference/hb_read_xlsx.md),
[`hb_validate_dtable()`](https://cttir.github.io/harbouR/reference/hb_validate_dtable.md),
[`hb_write_csv()`](https://cttir.github.io/harbouR/reference/hb_write_csv.md),
[`hb_write_dtable()`](https://cttir.github.io/harbouR/reference/hb_write_dtable.md),
[`hb_write_xlsx()`](https://cttir.github.io/harbouR/reference/hb_write_xlsx.md),
[`is_harbour_dtable()`](https://cttir.github.io/harbouR/reference/is_harbour_dtable.md),
[`length.harbour_dtable()`](https://cttir.github.io/harbouR/reference/length.harbour_dtable.md),
[`names.harbour_dtable()`](https://cttir.github.io/harbouR/reference/names.harbour_dtable.md),
[`print.harbour_dtable()`](https://cttir.github.io/harbouR/reference/print.harbour_dtable.md),
[`summary.harbour_dtable()`](https://cttir.github.io/harbouR/reference/summary.harbour_dtable.md)

## Examples

``` r
csv <- tempfile(fileext = ".csv")
utils::write.csv(data.frame(x = 1:2, y = c("a", "b")), csv,
                 row.names = FALSE)
hb_read_csv(c(Measurements = csv))
#> 
#> ── <harbour_dtable> ────────────────────────────────────────────────────────────
#> • base : "harbouR base"
#> • tables : 1
#> • rows : 2
#> • assets : 0
#> 
#> - Measurements (2 cols, 2 rows)
```
