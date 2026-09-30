#' Call a function in batches
#'
#' Splits items into requests of at most `size` and calls `fn` once per batch.
#' Input values and order are preserved unless an explicit policy changes them.
#'
#' @param fn Function called with each batch as its first argument.
#' @param items Vector or list of items to split.
#' @param size Positive integer maximum number of items per batch.
#' @param ... Additional arguments passed to `fn` on every call.
#' @param policy Named list of explicit client choices. `normalize(items)` runs
#'   before splitting; `build(chunk, index)` constructs the argument for `fn`;
#'   `merge(results)` formats the collected results after all calls. These are
#'   functions, and default to preserving their inputs. `on_error` is `"stop"`
#'   by default; `"drop"` warns and discards failures, and `"keep"` warns and
#'   retains `error_result` (default NULL) in the failed chunk's position.
#'   Errors in normalization, construction, and merging always propagate.
#'   `first_batch_only = TRUE` sends only the first chunk, for explicit legacy
#'   first-batch pagination compatibility. The default sends every chunk.
#' @return A list of unmerged results, one per batch, unless `merge` is selected.
#' @details The companion performs no HTTP or response decoding itself. Every
#'   chunk calls the supplied single-request function with the same fixed
#'   arguments, preserving its authentication, query, retry, and response policy.
#'   Client normalization may explicitly use `unique()` and remove missing or
#'   empty values. Client construction may retain singleton JSON arrays with
#'   `as.list(chunk)` or explicitly join raw text with `paste(chunk, collapse)`.
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
