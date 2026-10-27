# Summary of harbour metadata

Summary of harbour metadata

## Usage

``` r
# S3 method for class 'harbour_metadata'
summary(object, ...)
```

## Arguments

- object:

  A `harbour_metadata` object.

- ...:

  These dots are for future extensions and must be empty.

## Value

A tibble with one row per column across all tables, suitable for
inspecting the SeaTable schema. Columns: `table` (chr), `column` (chr),
`type` (chr).

## See also

Other metadata:
[`as_tibble.harbour_metadata()`](https://cttir.github.io/harbouR/reference/as_tibble.harbour_metadata.md),
[`hb_column_types()`](https://cttir.github.io/harbouR/reference/hb_column_types.md),
[`hb_list_collaborators()`](https://cttir.github.io/harbouR/reference/hb_list_collaborators.md),
[`hb_list_tables()`](https://cttir.github.io/harbouR/reference/hb_list_tables.md),
[`hb_metadata()`](https://cttir.github.io/harbouR/reference/hb_metadata.md),
[`is_harbour_metadata()`](https://cttir.github.io/harbouR/reference/is_harbour_metadata.md),
[`print.harbour_metadata()`](https://cttir.github.io/harbouR/reference/print.harbour_metadata.md)

## Examples

``` r
summary(hb_example_metadata())
#> # A tibble: 11 × 3
#>    table    column        type           
#>    <chr>    <chr>         <chr>          
#>  1 Samples  Name          text           
#>  2 Samples  Concentration number         
#>  3 Samples  Status        single-select  
#>  4 Samples  Tags          multiple-select
#>  5 Samples  Collected     date           
#>  6 Samples  Collaborators collaborator   
#>  7 Samples  Reports       file           
#>  8 Patients Patient ID    text           
#>  9 Patients Age           number         
#> 10 Patients Consented     checkbox       
#> 11 Patients Last visit    date           
```
