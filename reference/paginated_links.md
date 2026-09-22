# Retrieve bounded pages through same-origin next links

Retrieve bounded pages through same-origin next links

## Usage

``` r
paginated_links(
  request,
  items,
  next_link = function(response) httr2::resp_link_url(response, "next"),
  max_pages = 100,
  max_items = 10000
)
```

## Arguments

- request:

  An httr2 GET request for the first page. Configure credentials, query
  parameters, timeout, and retries on this request beforehand.

- items:

  Function extracting a collection from an httr2 response.

- next_link:

  Function extracting the next URL from an httr2 response. Defaults to
  the HTTP Link header's next relation. NULL or an empty string means
  completion. Relative links resolve against the current response URL.

- max_pages, max_items:

  Finite positive retrieval limits, as in
  [`paginated()`](https://seanthimons.github.io/specmill/reference/paginated.md).

## Value

The same structure as
[`paginated()`](https://seanthimons.github.io/specmill/reference/paginated.md),
with `no_next_link` for completion without another link. Request,
extraction, repeated-link, redirect, and cross-origin errors abort
without returning partial results.

## Details

Requires httr2 1.3.0 or later. Only GET requests without a body are
supported. Every link must use the initial request's scheme, hostname,
and effective port. URL credentials and fragments are rejected.
Redirects are disabled, including same-origin redirects. Headers and
authentication remain on the original request; query arguments come from
each next URL. Single- request generated functions and their decoded
response types are unchanged.
