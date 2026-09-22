# Call a function in batches

Splits items into requests of at most `size` and calls `fn` once per
batch.

## Usage

``` r
batched(fn, items, size, ...)
```

## Arguments

- fn:

  Function called with each batch as its first argument.

- items:

  Vector or list of items to split.

- size:

  Positive integer maximum number of items per batch.

- ...:

  Additional arguments passed to `fn`.

## Value

A list of unmerged results, one per batch. Errors from `fn` propagate.

## Examples

``` r
batched(sum, 1:5, 2)
#> $`1`
#> [1] 3
#> 
#> $`2`
#> [1] 7
#> 
#> $`3`
#> [1] 5
#> 
```
