batching_acceptance <- function() {
  stopifnot(
    identical(
      specmill::batched(paste, 1:2, 3, collapse = ''),
      list('1' = '12')
    ),
    identical(specmill::batched(identity, 1:3, 3), list('1' = 1:3)),
    identical(
      specmill::batched(identity, 1:4, 3),
      list('1' = 1:3, '2' = 4L)
    ),
    length(specmill::batched(identity, integer(), 3)) == 0L
  )

  calls <- integer()
  error <- tryCatch(
    specmill::batched(function(items) {
      calls <<- c(calls, items[[1L]])
      if (items[[1L]] == 3L) stop('middle batch failed')
      items
    }, 1:5, 2),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    identical(conditionMessage(error), 'middle batch failed'),
    identical(calls, c(1L, 3L))
  )
  size_error <- tryCatch(specmill::batched(identity, 1L, 0), error = identity)
  stopifnot(
    inherits(size_error, 'error'),
    identical(conditionMessage(size_error), 'size must be a positive integer')
  )

  cat('Batching: boundaries, empty input and error propagation passed.\n')
}
if (sys.nframe() == 0L) {
  batching_acceptance()
}
