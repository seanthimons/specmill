#' Call a function in batches
#'
#' Splits items into requests of at most `size` and calls `fn` once per batch.
#'
#' @param fn Function called with each batch as its first argument.
#' @param items Vector or list of items to split.
#' @param size Positive integer maximum number of items per batch.
#' @param ... Additional arguments passed unchanged to `fn`.
#' @param policy Named list of explicit client choices: `normalize(items)`,
#'   `build(chunk, index)`, and `merge(results)` functions; `on_error` set to
#'   `stop` by default, or `drop`/`keep` for recovery with warnings;
#'   `error_result` retained by keep; and `first_batch_only = TRUE` for explicit
#'   legacy pagination compatibility. Normalization, construction and merging
#'   errors always propagate.
#' @return A named list of unmerged results, one per batch, unless a merge
#'   function is selected.
#' @details Inputs and order are preserved by default. Every chunk calls the
#'   supplied function through its existing authentication, query, retry and
#'   response policy. The companion performs no HTTP or response decoding.
#'   Optional normalization may remove duplicates, missing and empty values.
#'   Optional construction may preserve singleton JSON arrays with as.list or
#'   join raw text explicitly.
#' @examples
#' batched(sum, 1:5, 2)
#' batched(identity, c('a', 'a', NA, ''), 2,
#'   policy = list(normalize = function(x) unique(x[!is.na(x) & nzchar(x)])))
#' @export
batched <- function(fn, items, size, ..., policy = list()) {
  if (
    !is.numeric(size) ||
      length(size) != 1L ||
      is.na(size) ||
      !is.finite(size) ||
      size < 1 ||
      size != floor(size)
  ) {
    stop('size must be a positive integer')
  }
  if (!is.function(fn)) {
    stop('fn must be a function')
  }
  allowed <- c(
    'normalize',
    'build',
    'merge',
    'on_error',
    'error_result',
    'first_batch_only'
  )
  if (
    !is.list(policy) ||
      (length(policy) &&
        (is.null(names(policy)) ||
          anyNA(names(policy)) ||
          anyDuplicated(names(policy)))) ||
      length(setdiff(names(policy), allowed))
  ) {
    stop(
      'policy must be a named list of normalize, build, merge, on_error, error_result, first_batch_only'
    )
  }
  for (name in c('normalize', 'build', 'merge')) {
    if (!is.null(policy[[name]]) && !is.function(policy[[name]])) {
      stop(name, ' must be a function')
    }
  }
  on_error <- if (is.null(policy$on_error)) 'stop' else policy$on_error
  if (
    length(on_error) != 1L ||
      is.na(on_error) ||
      !on_error %in% c('stop', 'drop', 'keep')
  ) {
    stop('on_error must be stop, drop, or keep')
  }
  if (
    !is.null(policy$first_batch_only) &&
      !identical(policy$first_batch_only, TRUE) &&
      !identical(policy$first_batch_only, FALSE)
  ) {
    stop('first_batch_only must be TRUE or FALSE')
  }
  if (!is.null(policy$normalize)) {
    items <- policy$normalize(items)
  }
  chunks <- split(items, ceiling(seq_along(items) / size))
  if (isTRUE(policy$first_batch_only) && length(chunks)) {
    chunks <- chunks[1L]
  }
  results <- list()
  for (index in seq_along(chunks)) {
    chunk <- chunks[[index]]
    if (!is.null(policy$build)) {
      chunk <- policy$build(chunk, index)
    }
    result <- if (on_error == 'stop') {
      list(value = fn(chunk, ...), failed = FALSE)
    } else {
      tryCatch(
        list(value = fn(chunk, ...), failed = FALSE),
        error = function(error) {
          warning(
            'Batch ',
            index,
            ' failed: ',
            conditionMessage(error),
            call. = FALSE
          )
          list(value = policy$error_result, failed = TRUE)
        }
      )
    }
    if (!result$failed || on_error == 'keep') {
      results[names(chunks)[index]] <- list(result$value)
    }
  }
  if (is.null(policy$merge)) results else policy$merge(results)
}
