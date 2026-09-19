#' Retrieve bounded pages through same-origin next links
#'
#' @param request An httr2 GET request for the first page. Configure credentials,
#'   query parameters, timeout, and retries on this request beforehand.
#' @param items Function extracting a collection from an httr2 response.
#' @param next_link Function extracting the next URL from an httr2 response.
#'   Defaults to the HTTP Link header's next relation. NULL or an empty string
#'   means completion. Relative links resolve against the current response URL.
#' @param max_pages,max_items Finite positive retrieval limits, as in [paginated()].
#' @return The same structure as [paginated()], with `no_next_link` for completion
#'   without another link. Request, extraction, repeated-link, redirect, and
#'   cross-origin errors abort without returning partial results.
#' @details Requires httr2 1.3.0 or later. Only GET requests without a body are
#'   supported. Every link must use the initial request's scheme, hostname, and
#'   effective port. URL credentials and fragments are rejected. Redirects are
#'   disabled, including same-origin redirects. Headers and authentication remain
#'   on the original request; query arguments come from each next URL. Single-
#'   request generated functions and their decoded response types are unchanged.
#' @md
#' @export
paginated_links <- function(
  request,
  items,
  next_link = function(response) httr2::resp_link_url(response, 'next'),
  max_pages = 100,
  max_items = 10000
) {
  if (
    !requireNamespace('httr2', quietly = TRUE) ||
      utils::packageVersion('httr2') < '1.3.0'
  ) {
    stop('paginated_links requires httr2 >= 1.3.0')
  }
  if (!inherits(request, 'httr2_request') || !is.function(next_link)) {
    stop('Supply an httr2 request and a next_link function')
  }
  if (
    (!is.null(request$method) && request$method != 'GET') ||
      !is.null(request$body)
  ) {
    stop('Next-link pagination requires a bodyless GET request')
  }
  parse_url <- function(url, base_url = NULL) {
    pagination_token(url)
    if (is.null(url) || !nzchar(url) || grepl('[[:space:]\\\\]', url)) {
      stop('Invalid pagination URL')
    }
    parsed <- tryCatch(httr2::url_parse(url, base_url), error = function(e) {
      stop('Invalid pagination URL', call. = FALSE)
    })
    if (
      !parsed$scheme %in% c('http', 'https') ||
        is.null(parsed$hostname) ||
        !nzchar(parsed$hostname) ||
        !is.null(parsed$username) ||
        !is.null(parsed$password) ||
        !is.null(parsed$fragment)
    ) {
      stop('Pagination URL must be HTTP(S) without userinfo or a fragment')
    }
    parsed
  }
  origin <- function(parsed) {
    list(
      tolower(parsed$scheme),
      tolower(parsed$hostname),
      as.character(parsed$port %or% if (parsed$scheme == 'https') 443 else 80)
    )
  }
  initial <- parse_url(httr2::req_get_url(request))
  trusted <- origin(initial)
  checked_url <- function(url, base_url = NULL) {
    parsed <- parse_url(url, base_url)
    if (!identical(origin(parsed), trusted)) {
      stop('Cross-origin pagination link refused')
    }
    # Normalize default ports and hostname case for repeated-link detection.
    parsed$scheme <- tolower(parsed$scheme)
    parsed$hostname <- tolower(parsed$hostname)
    if (
      identical(
        as.character(parsed$port),
        if (parsed$scheme == 'https') '443' else '80'
      )
    ) {
      parsed$port <- NULL
    }
    httr2::url_build(parsed)
  }
  fetch <- function(url) {
    req <- httr2::req_url(request, checked_url(url))
    req <- httr2::req_options(req, followlocation = FALSE)
    # Even caller-supplied error policies cannot make a redirect acceptable.
    response <- httr2::req_perform(req)
    if (
      httr2::resp_status(response) >= 300 && httr2::resp_status(response) < 400
    ) {
      stop('Pagination redirect refused')
    }
    httr2::resp_check_status(response)
    response
  }
  result <- paginated(
    fetch,
    mode = 'cursor',
    parameter = 'url',
    start = checked_url(httr2::req_get_url(request)),
    items = items,
    next_cursor = function(response) {
      link <- next_link(response)
      pagination_token(link)
      if (is.null(link) || !nzchar(link)) {
        return(NULL)
      }
      checked_url(link, httr2::resp_url(response))
    },
    max_pages = max_pages,
    max_items = max_items
  )
  if (result$stop_reason == 'no_next_cursor') {
    result$stop_reason <- 'no_next_link'
  }
  result
}
