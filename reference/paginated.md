# Retrieve bounded pages from a single-request function

Configure each operation explicitly in a client-owned companion
function. No parameter names or response metadata are used to infer
pagination.

## Usage

``` r
paginated(
  fn,
  ...,
  mode,
  parameter,
  size_parameter = NULL,
  page_size = NULL,
  start = NULL,
  items,
  max_pages = 100,
  max_items = 10000,
  next_cursor = NULL
)
```

## Arguments

- fn:

  Single-request function to call.

- ...:

  Named, fixed arguments passed to `fn` on every request.

- mode:

  One of `"page"`, `"offset"`, or `"cursor"`.

- parameter:

  Exact public argument name for the page, offset, or cursor.

- size_parameter:

  Exact public argument name for the requested page size. May be NULL in
  cursor mode if the size is fixed by the caller.

- page_size:

  Positive integer requested page size; NULL with no size argument.

- start:

  Nonnegative integer first page number or offset. Required because APIs
  differ on whether numbering starts at zero or one. In cursor mode, an
  opaque string or NULL for the initial call. NULL is passed explicitly.

- items:

  Function extracting a list, atomic vector, or data frame of items from
  each response. Use `identity` for a top-level collection. NULL is an
  error; return an empty collection for an empty page.

- max_pages:

  Positive integer maximum number of calls. Default 100.

- max_items:

  Positive integer maximum number of retained items. Default 10000. The
  last page is sliced if necessary; the request size stays fixed.

- next_cursor:

  Cursor-mode function extracting the next opaque string from a
  response. NULL or an empty string means completion. Repeated tokens
  error.

## Value

A list with `pages` (extracted, unmerged collections), `requests`,
`item_count`, and `stop_reason` (`empty_page`, `max_pages`, `max_items`,
or `no_next_cursor`). Empty pages are not retained. An item limit takes
precedence over a page limit. Reaching a limit does not imply that the
API has no more items.

## Details

Page numbers advance by one; offsets advance by `page_size`. Only an
empty collection signals completion; short pages do not. Servers must
honor the configured offset stride. Repeated nonempty pages terminate at
the limits, without deduplication. Request and extraction errors
propagate immediately, with no partial result returned. Transport
retries still apply independently to each call. Cursor tokens are never
interpreted as URLs. Use
[`paginated_links()`](https://seanthimons.github.io/specmill/reference/paginated_links.md)
for same-origin next-link retrieval. Empty pages and limits stop before
extracting another cursor. Single-request functions are unchanged. A
finite call limit still bounds servers returning unique tokens.

## Examples

``` r
one_page <- function(page, limit) {
  if (page > 2) integer() else seq_len(limit) + (page - 1) * limit
}
paginated(one_page, mode = 'page', parameter = 'page',
  size_parameter = 'limit', page_size = 2, start = 1, items = identity)
#> $pages
#> $pages[[1]]
#> [1] 1 2
#> 
#> $pages[[2]]
#> [1] 3 4
#> 
#> 
#> $requests
#> [1] 3
#> 
#> $item_count
#> [1] 4
#> 
#> $stop_reason
#> [1] "empty_page"
#> 
```
