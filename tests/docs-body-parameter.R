# Regression for issue 221: docs.parameters can document the body argument.

docs_body_parameter_acceptance <- function() {
  op <- list(summary = 'Post records', parameters = list(), body = list())
  docs <- specmill:::operation_documentation(
    op,
    list(parameters = list(body = 'Named list with records and options.'))
  )
  stopifnot(grepl(
    '@param body Named list with records and options.',
    docs,
    fixed = TRUE
  ))
  # docs.parameters wins over the operation-level body description.
  op$body_description <- 'Schema body.'
  docs <- specmill:::operation_documentation(
    op,
    list(parameters = list(body = 'Docs body.'))
  )
  stopifnot(grepl('@param body Docs body.', docs, fixed = TRUE))
  # Renamed body arguments are documented under their public name.
  op$body_name <- 'records'
  docs <- specmill:::operation_documentation(
    op,
    list(parameters = list(records = 'Records to send.'))
  )
  stopifnot(grepl('@param records Records to send.', docs, fixed = TRUE))
  failed <- tryCatch(
    specmill:::operation_documentation(
      op,
      list(parameters = list(body = 'Stale name.'))
    ),
    error = conditionMessage
  )
  stopifnot(identical(
    failed,
    'Documentation references missing public parameter'
  ))
  # Operations without a body still reject `body`.
  failed <- tryCatch(
    specmill:::operation_documentation(
      list(summary = 'Get', parameters = list()),
      list(parameters = list(body = 'No body.'))
    ),
    error = conditionMessage
  )
  stopifnot(identical(
    failed,
    'Documentation references missing public parameter'
  ))
}

if (sys.nframe() == 0L) {
  docs_body_parameter_acceptance()
}
