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
    specmill::batched(
      function(items) {
        calls <<- c(calls, items[[1L]])
        if (items[[1L]] == 3L) {
          stop('middle batch failed')
        }
        items
      },
      1:5,
      2
    ),
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

  for (size in list(0, -1, 1.5, NA_real_, Inf, '2', numeric(), c(1, 2))) {
    calls <- 0L
    error <- tryCatch(
      specmill::batched(
        function(x) {
          calls <<- calls + 1L
          x
        },
        1:3,
        size
      ),
      error = identity
    )
    stopifnot(inherits(error, 'error'), calls == 0L)
  }
  values <- list('001', '001', NA_character_, '', NULL, list(nested = 1))
  stopifnot(identical(
    specmill::batched(identity, values, 2),
    list('1' = values[1:2], '2' = values[3:4], '3' = values[5:6])
  ))
  normalized <- specmill::batched(
    identity,
    c('b', 'a', 'b', NA, ''),
    1,
    policy = list(normalize = function(x) unique(x[!is.na(x) & nzchar(x)]))
  )
  stopifnot(identical(normalized, list('1' = 'b', '2' = 'a')))
  built <- specmill::batched(
    identity,
    1:3,
    2,
    policy = list(
      build = function(x, index) list(values = x, index = index),
      merge = unname
    )
  )
  stopifnot(identical(
    built,
    list(list(values = 1:2, index = 1L), list(values = 3L, index = 2L))
  ))
  for (mode in c('drop', 'keep')) {
    warnings <- character()
    result <- withCallingHandlers(
      specmill::batched(
        function(x) {
          if (x[[1L]] == 3L) {
            stop('middle failure')
          }
          x
        },
        1:5,
        2,
        policy = list(on_error = mode)
      ),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart('muffleWarning')
      }
    )
    expected <- if (mode == 'keep') {
      list('1' = 1:2, '2' = NULL, '3' = 5L)
    } else {
      list('1' = 1:2, '3' = 5L)
    }
    stopifnot(
      identical(result, expected),
      identical(warnings, 'Batch 2 failed: middle failure')
    )
  }
  stopifnot(identical(
    specmill::batched(identity, 1:5, 2, policy = list(first_batch_only = TRUE)),
    list('1' = 1:2)
  ))
  stopifnot(identical(
    specmill::batched(identity, 1:5, 2),
    list('1' = 1:2, '2' = 3:4, '3' = 5L)
  ))
  cat('Batching: boundaries, values, policy and error propagation passed.\n')
}
if (sys.nframe() == 0L) {
  batching_acceptance()
}
