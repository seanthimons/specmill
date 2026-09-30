#' Retrieve bounded pages from a single-request function
#'
#' Configure each operation explicitly in a client-owned companion function.
#' No parameter names or response metadata are used to infer pagination.
#'
#' @param fn Single-request function to call.
#' @param ... Named, fixed arguments passed to `fn` on every request.
#' @param mode One of `"page"`, `"offset"`, or `"cursor"`.
#' @param parameter Exact argument name or character-vector nested argument path
#'   for the page, offset, or cursor. For example `c('body', 'pagination', 'cursor')`.
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
#'   10000. NULL removes the item cap. The last page is sliced if necessary;
#'   the request size stays fixed.
#' @param next_cursor Cursor-mode function extracting the next opaque string from
#'   a response. NULL or an empty string means completion. Repeated tokens error.
#' @param completed Optional function of `(response, state)` returning one logical
#'   value. State contains position, requests, item_count, and page_size. Select
#'   total/last-page or nested hasNext metadata explicitly in this function.
#' @param advance Optional function of `(response, position, page_size)` returning
#'   the next numeric position for page/offset mode. It must advance strictly.
#' @param stop_on_short Stop on a page shorter than page_size, default FALSE.
#' @param error_policy One of stop, partial, or empty. Partial/empty recover only
#'   request errors, warn, and respectively retain or discard successful pages.
#' @param warn_limits Warn when a page or item limit truncates retrieval.
#' @param format Optional function applied to the completed result after metadata
#'   iteration. Response decoding remains the single-request function's responsibility.
#' @param policy Named list of shared pagination defaults. Explicit arguments
#'   override policy. Callbacks allow service defaults and operation exceptions.
#' @return A list with `pages` (extracted, unmerged collections), `requests`,
#'   `item_count`, and `stop_reason` (`empty_page`, `max_pages`, `max_items`, or
#'   `no_next_cursor`, `completed`, `short_page`, or `request_error`).
#'   Empty pages are not retained. An item limit takes precedence over a page
#'   limit. Reaching a limit does not imply that the API has no more items.
#' @details Page numbers advance by one; offsets advance by `page_size`.
#'   Only an empty collection signals completion; short pages do not. Servers
#'   must honor the configured offset stride. Repeated nonempty pages terminate
#'   at the limits, without deduplication. Request and extraction errors propagate
#'   immediately by default. Selected request-error recovery warns and returns
#'   partial or empty results. Extraction and metadata-policy errors always abort.
#'   Transport retries still apply
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
  next_cursor = NULL,
  completed = NULL,
  advance = NULL,
  stop_on_short = FALSE,
  error_policy = 'stop',
  warn_limits = FALSE,
  format = NULL,
  policy = list()
) {
  allowed <- setdiff(names(formals(sys.function())), c('fn', '...', 'policy'))
  if (
    !is.list(policy) ||
      (length(policy) &&
        (is.null(names(policy)) ||
          anyNA(names(policy)) ||
          !all(nzchar(names(policy))) ||
          anyDuplicated(names(policy)) ||
          !all(names(policy) %in% allowed)))
  ) {
    stop('policy must be a named list of pagination defaults')
  }
  supplied <- names(match.call(expand.dots = FALSE))
  for (name in setdiff(names(policy), supplied)) {
    assign(name, policy[[name]])
  }
  for (value in list(completed, advance, format)) {
    if (!is.null(value) && !is.function(value)) {
      stop('Pagination callbacks must be functions')
    }
  }
  for (value in list(stop_on_short, warn_limits)) {
    if (!is.logical(value) || length(value) != 1L || is.na(value)) {
      stop('Pagination flags must be logical')
    }
  }
  if (
    !is.character(error_policy) ||
      length(error_policy) != 1L ||
      is.na(error_policy) ||
      !error_policy %in% c('stop', 'partial', 'empty')
  ) {
    stop('error_policy must be stop, partial, or empty')
  }
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
    if (
      !is.character(name) || !length(name) || anyNA(name) || !all(nzchar(name))
    ) {
      stop('pagination argument path must contain nonempty names')
    }
    if (!name[[1L]] %in% names(formals(fn)) && !'...' %in% names(formals(fn))) {
      stop('Unknown pagination argument: ', name)
    }
  }
  overlaps <- function(x, y) {
    !is.null(y) &&
      identical(
        x[seq_len(min(length(x), length(y)))],
        y[seq_len(min(length(x), length(y)))]
      )
  }
  if (overlaps(parameter, size_parameter)) {
    stop('Pagination arguments must be distinct')
  }
  numbers <- list(
    page_size = page_size,
    start = start,
    max_pages = max_pages,
    max_items = max_items
  )
  if (is.null(max_items)) {
    numbers$max_items <- NULL
  }
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
        !all(nzchar(names(args))) ||
        anyDuplicated(names(args)) ||
        any(
          names(args) %in%
            c(
              if (length(parameter) == 1L) parameter,
              if (length(size_parameter) == 1L) size_parameter
            )
        ))
  ) {
    stop(
      'Fixed arguments must have unique names and exclude pagination arguments'
    )
  }
  set_path <- function(x, path, value) {
    if (is.null(x)) {
      x <- list()
    }
    if (!is.list(x)) {
      stop('Nested pagination state must be a list')
    }
    key <- path[[1L]]
    if (length(path) == 1L) {
      x[key] <- list(value)
    } else {
      x[key] <- list(set_path(x[[key]], path[-1L], value))
    }
    x
  }
  # Validate nested containers before the first HTTP call.
  args <- set_path(args, parameter, start)
  if (!is.null(size_parameter)) {
    args <- set_path(args, size_parameter, page_size)
  }
  item_limit <- if (is.null(max_items)) Inf else max_items
  pages <- list()
  count <- 0
  requests <- 0
  position <- start
  seen <- new.env(hash = TRUE, parent = emptyenv())
  if (cursor && !is.null(start) && nzchar(start)) {
    seen[[digest::digest(start, algo = 'sha256')]] <- TRUE
  }
  repeat {
    args <- set_path(args, parameter, position)
    if (!is.null(size_parameter)) {
      args <- set_path(args, size_parameter, page_size)
    }
    requests <- requests + 1
    response <- tryCatch(do.call(fn, args), error = function(e) {
      if (error_policy == 'stop' || inherits(e, 'pagination_security_error')) {
        stop(e)
      }
      e
    })
    if (inherits(response, 'error')) {
      warning(
        'Pagination request failed; returning ',
        error_policy,
        ' results',
        call. = FALSE
      )
      if (error_policy == 'empty') {
        pages <- list()
        count <- 0
      }
      reason <- 'request_error'
      break
    }
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
    keep <- min(n, item_limit - count)
    pages[[length(pages) + 1L]] <- if (is.data.frame(page)) {
      page[seq_len(keep), , drop = FALSE]
    } else {
      page[seq_len(keep)]
    }
    count <- count + keep
    if (count == item_limit) {
      reason <- 'max_items'
      if (warn_limits) {
        warning('Pagination truncated at ', reason, call. = FALSE)
      }
      break
    }
    if (!is.null(completed)) {
      done <- completed(
        response,
        list(
          position = position,
          requests = requests,
          item_count = count,
          page_size = page_size
        )
      )
      if (!is.logical(done) || length(done) != 1L || is.na(done)) {
        stop('completed must return one nonmissing logical value')
      }
      if (done) {
        reason <- 'completed'
        break
      }
    }
    if (stop_on_short && !is.null(page_size) && n < page_size) {
      reason <- 'short_page'
      break
    }
    if (requests == max_pages) {
      reason <- 'max_pages'
      if (warn_limits) {
        warning('Pagination truncated at ', reason, call. = FALSE)
      }
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
      next_position <- if (is.null(advance)) {
        position + step
      } else {
        advance(response, position, page_size)
      }
      if (
        !is.numeric(next_position) ||
          length(next_position) != 1L ||
          is.na(next_position) ||
          !is.finite(next_position) ||
          next_position != floor(next_position) ||
          next_position <= position ||
          next_position > 2^53 - 1
      ) {
        stop('advance must return a larger exact integer position')
      }
      position <- next_position
    }
  }
  result <- list(
    pages = pages,
    requests = requests,
    item_count = count,
    stop_reason = reason
  )
  if (is.null(format)) result else format(result)
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
