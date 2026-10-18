validate_response_correction <- function(correction) {
  config_fields(
    correction,
    c('status', 'media_type', 'description', 'reason'),
    'response_correction'
  )
  for (field in c('status', 'media_type', 'description', 'reason')) {
    config_string(correction[[field]], paste('response_correction', field))
  }
  if (
    !grepl('^[1-5][0-9]{2}$', correction$status) ||
      !identical(correction$media_type, 'application/json')
  ) {
    stop(
      'response_correction requires an HTTP status and application/json media'
    )
  }
}

response_corrected_operation <- function(
  operation,
  correction,
  version,
  at,
  produces = NULL
) {
  if (is.null(correction)) {
    return(operation)
  }
  validate_response_correction(correction)
  if (
    !is.list(operation$responses) ||
      length(operation$responses) ||
      is.null(names(operation$responses))
  ) {
    schema_problem(
      'response_correction',
      'review_required',
      'Response correction requires an explicitly empty responses object',
      at
    )
  }
  response <- list(description = correction$description)
  if (startsWith(version, '2.')) {
    media <- operation$produces %or% produces
    if (
      length(media) &&
        !correction$media_type %in% unlist(media, use.names = FALSE)
    ) {
      schema_problem(
        'response_correction',
        'review_required',
        'Response correction conflicts with declared media',
        at
      )
    }
    if (!length(media)) operation$produces <- list(correction$media_type)
  } else {
    response$content <- setNames(
      list(structure(list(), names = character())),
      correction$media_type
    )
  }
  operation$responses <- setNames(list(response), correction$status)
  operation
}

reviewed_response_validation <- function(service, reports) {
  corrections <- Filter(
    Negate(is.null),
    service$policy$response_corrections %or% list()
  )
  views <- list()
  for (file in names(reports)) {
    if (!length(corrections)) {
      next
    }
    document <- tryCatch(
      read_schema_document(file, resolve_references = FALSE),
      error = identity
    )
    if (inherits(document, 'error')) {
      next
    }
    applied <- list()
    for (key in names(corrections)) {
      method <- tolower(sub(' .*', '', key))
      path <- sub('^[^ ]+ ', '', key)
      if (
        is.null(document$paths[[path]][[method]]) ||
          length(operation_selection_reason(
            key,
            path,
            toupper(method),
            service$policy
          ))
      ) {
        next
      }
      at <- schema_location(schema_location('#/paths', path), method)
      corrected <- tryCatch(
        response_corrected_operation(
          document$paths[[path]][[method]],
          corrections[[key]],
          document$openapi %or% document$swagger,
          at,
          document$produces
        ),
        error = identity
      )
      # Leave a rejected correction to the normal parser's operation diagnostic.
      if (inherits(corrected, 'error')) {
        next
      }
      document$paths[[path]][[method]] <- corrected
      applied[[key]] <- corrections[[key]]
    }
    if (!length(applied)) {
      next
    }
    report <- schema_validation_report(file, document)
    report$service <- service$id %or% 'default'
    report$response_corrections <- config_data(applied)
    views[[file]] <- report
    reports[[file]] <- report
  }
  list(reports = reports, views = views)
}
