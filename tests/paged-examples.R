paged_examples_acceptance <- function() {
  document <- getFromNamespace('operation_documentation', 'specmill')
  op <- list(
    name = 'get_items',
    parameters = list(list(
      name = 'cursor',
      location = 'query',
      schema = list(type = 'string')
    )),
    paginate = list(
      parameter = 'cursor',
      location = 'query',
      completed = 'empty',
      metadata = FALSE
    )
  )
  policy <- list(examples = list(list(all_pages = FALSE, max_pages = 2L)))
  docs <- document(op, policy)
  stopifnot(grepl(
    'get_items(all_pages = FALSE, max_pages = 2L)',
    docs,
    fixed = TRUE
  ))
  op$paginate <- NULL
  error <- tryCatch(document(op, policy), error = identity)
  stopifnot(
    inherits(error, 'error'),
    identical(
      conditionMessage(error),
      'Example references missing public parameter'
    )
  )
  cat(
    'Paged examples accept generated controls; unpaged examples still reject them.\n'
  )
}
if (sys.nframe() == 0L) {
  paged_examples_acceptance()
}
