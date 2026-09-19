#' Retrieve bounded pages from a single-request function
#'
#' Configure each operation explicitly in a client-owned companion function.
#' No parameter names or response metadata are used to infer pagination.
#'
#' @param fn Single-request function to call.
#' @param ... Named, fixed arguments passed to `fn` on every request.
#' @param mode One of `"page"`, `"offset"`, or `"cursor"`.
#' @param parameter Exact public argument name for the page, offset, or cursor.
#' @param size_parameter Exact public argument name for the requested page size.
#'   May be NULL in cursor mode if the size is fixed by the caller.
#' @param page_size Positive integer requested page size; NULL with no size argument.
#' @param start Nonnegative integer first page number or offset. Required because
#'   APIs differ on whether numbering starts at zero or one. In cursor mode, an
#'   opaque string or NULL for the initial call. NULL is passed explicitly.
#' @param items Function extracting a list, atomic vector, or data frame of items
#'   from each response. Use `identity` for a top-level collection. NULL is an
#'   error; return an empty collection for an empty page.
#' @param max_pages Positive integer maximum number of calls. Default 100.
#' @param max_items Positive integer maximum number of retained items. Default
#'   10000. The last page is sliced if necessary; the request size stays fixed.
#' @param next_cursor Cursor-mode function extracting the next opaque string from
#'   a response. NULL or an empty string means completion. Repeated tokens error.
#' @return A list with `pages` (extracted, unmerged collections), `requests`,
#'   `item_count`, and `stop_reason` (`empty_page`, `max_pages`, `max_items`, or
#'   `no_next_cursor`).
#'   Empty pages are not retained. An item limit takes precedence over a page
#'   limit. Reaching a limit does not imply that the API has no more items.
#' @details Page numbers advance by one; offsets advance by `page_size`.
#'   Only an empty collection signals completion; short pages do not. Servers
#'   must honor the configured offset stride. Repeated nonempty pages terminate
#'   at the limits, without deduplication. Request and extraction errors propagate
#'   immediately, with no partial result returned. Transport retries still apply
#'   independently to each call. Cursor tokens are never interpreted as URLs.
#'   Use [paginated_links()] for same-origin next-link retrieval. Empty pages and
#'   limits stop before extracting another cursor. Single-request functions are
#'   unchanged. A finite call limit still bounds servers returning unique tokens.
#' @examples
#' one_page <- function(page, limit) {
#'   if (page > 2) integer() else seq_len(limit) + (page - 1) * limit
#' }
#' paginated(one_page, mode = 'page', parameter = 'page',
#'   size_parameter = 'limit', page_size = 2, start = 1, items = identity)
#' @md
#' @export
paginated <- function(
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
) {
  if (!is.function(fn) || !is.function(items)) {
    stop('fn and items must be functions')
  }
  if (
    !is.character(mode) ||
      length(mode) != 1L ||
      is.na(mode) ||
      !mode %in% c('page', 'offset', 'cursor')
  ) {
    stop('mode must be page, offset, or cursor')
  }
  cursor <- mode == 'cursor'
  if (cursor) {
    if (!is.function(next_cursor)) {
      stop('cursor mode requires next_cursor')
    }
    pagination_token(start)
    if (is.null(size_parameter) != is.null(page_size)) {
      stop('Supply size_parameter and page_size together')
    }
  } else if (is.null(size_parameter) || is.null(page_size) || is.null(start)) {
    stop('page/offset mode requires size_parameter, page_size, and start')
  }
  for (name in c(
    list(parameter),
    if (!is.null(size_parameter)) list(size_parameter)
  )) {
    config_string(name, 'pagination argument name')
    if (!name %in% names(formals(fn)) && !'...' %in% names(formals(fn))) {
      stop('Unknown pagination argument: ', name)
    }
  }
  if (identical(parameter, size_parameter)) {
    stop('Pagination arguments must be distinct')
  }
  numbers <- list(
    page_size = page_size,
    start = start,
    max_pages = max_pages,
    max_items = max_items
  )
  if (cursor) {
    numbers$start <- NULL
  }
  if (cursor && is.null(page_size)) {
    numbers$page_size <- NULL
  }
  for (name in names(numbers)) {
    value <- numbers[[name]]
    if (
      !is.numeric(value) ||
        length(value) != 1L ||
        is.na(value) ||
        !is.finite(value) ||
        value != floor(value) ||
        value < (if (name == 'start') 0 else 1) ||
        value > 2^53 - 1
    ) {
      stop(name, ' must be a finite integer within the supported range')
    }
  }
  step <- if (mode == 'page') 1 else page_size
  if (!cursor && max_pages - 1 > (2^53 - 1 - start) / step) {
    stop('Pagination positions exceed the exact integer range')
  }
  args <- list(...)
  if (
    length(args) &&
      (is.null(names(args)) ||
        anyNA(names(args)) ||
        any(!nzchar(names(args))) ||
        anyDuplicated(names(args)) ||
        any(names(args) %in% c(parameter, size_parameter)))
  ) {
    stop(
      'Fixed arguments must have unique names and exclude pagination arguments'
    )
  }
  pages <- list()
  count <- 0
  requests <- 0
  position <- start
  seen <- new.env(hash = TRUE, parent = emptyenv())
  if (cursor && !is.null(start) && nzchar(start)) {
    seen[[digest::digest(start, algo = 'sha256')]] <- TRUE
  }
  repeat {
    args[parameter] <- list(position)
    if (!is.null(size_parameter)) {
      args[[size_parameter]] <- page_size
    }
    response <- do.call(fn, args)
    requests <- requests + 1
    page <- items(response)
    if (
      is.null(page) ||
        !(is.data.frame(page) ||
          (is.null(dim(page)) && (is.list(page) || is.atomic(page))))
    ) {
      stop('items must return a list, atomic vector, or data frame')
    }
    n <- if (is.data.frame(page)) nrow(page) else length(page)
    if (!n) {
      reason <- 'empty_page'
      break
    }
    keep <- min(n, max_items - count)
    pages[[length(pages) + 1L]] <- if (is.data.frame(page)) {
      page[seq_len(keep), , drop = FALSE]
    } else {
      page[seq_len(keep)]
    }
    count <- count + keep
    if (count == max_items || requests == max_pages) {
      reason <- if (count == max_items) 'max_items' else 'max_pages'
      break
    }
    if (cursor) {
      position <- next_cursor(response)
      pagination_token(position)
      if (is.null(position) || !nzchar(position)) {
        reason <- 'no_next_cursor'
        break
      }
      key <- digest::digest(position, algo = 'sha256')
      if (exists(key, envir = seen, inherits = FALSE)) {
        stop('Repeated pagination cursor or link')
      }
      seen[[key]] <- TRUE
    } else {
      position <- position + step
    }
  }
  list(
    pages = pages,
    requests = requests,
    item_count = count,
    stop_reason = reason
  )
}

# Tokens are opaque strings. Do not coerce numbers or print their values in errors.
pagination_token <- function(value) {
  if (
    !is.null(value) &&
      (!is.character(value) || length(value) != 1L || is.na(value))
  ) {
    stop(
      'Pagination cursor or link must be NULL or a single non-missing string'
    )
  }
  invisible(value)
}
