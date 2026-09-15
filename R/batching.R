#' Call a function in batches
#'
#' Splits items into requests of at most `size` and calls `fn` once per batch.
#'
#' @param fn Function called with each batch as its first argument.
#' @param items Vector or list of items to split.
#' @param size Positive integer maximum number of items per batch.
#' @param ... Additional arguments passed to `fn`.
#' @return A list of unmerged results, one per batch. Errors from `fn` propagate.
#' @examples
#' batched(sum, 1:5, 2)
#' @export
batched <- function(fn, items, size, ...) {
  if (
    !is.numeric(size) || length(size) != 1L || is.na(size) ||
      !is.finite(size) || size < 1 || size != floor(size)
  ) {
    stop('size must be a positive integer')
  }
  lapply(split(items, ceiling(seq_along(items) / size)), fn, ...)
}
