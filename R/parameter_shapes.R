query_array_style <- function(style, label = 'query_array_style') {
  style <- style %or% 'schema'
  config_string(style, label)
  if (!style %in% c('schema', 'brackets')) {
    stop(label, ' must be schema or brackets')
  }
  style
}

# Validate public schema inputs before client-owned request transformations.
# Parameters retain their vector representation; JSON validation uses lists.
parameter_values <- function(values, schemas, validate, locations) {
  for (name in names(values)) {
    value <- values[[name]]
    if (is.null(value)) {
      next
    } # Optional NULL means omission on parameter transports.
    schema <- schemas[[name]]
    vector <- is.atomic(value) &&
      !is.object(value) &&
      is.null(dim(value)) &&
      is.null(names(value))
    # A composed schema may accept a scalar or an array, and a length-one
    # vector is either; try the scalar first.
    composed <- length(schema$type) > 1L ||
      any(c('oneOf', 'anyOf', 'allOf') %in% names(schema))
    candidates <- if (
      vector &&
        (identical(schema$type, 'array') || (composed && length(value) != 1L))
    ) {
      list(as.list(value))
    } else if (vector && composed) {
      list(value, as.list(value))
    } else {
      list(value)
    }
    problem <- NULL
    for (candidate in candidates) {
      message <- tryCatch(
        {
          validate(candidate, schema)
          NULL
        },
        error = conditionMessage
      )
      if (is.null(message)) {
        problem <- NULL
        break
      }
      if (is.null(problem)) problem <- message
    }
    if (!is.null(problem)) {
      stop(
        'Invalid ',
        locations[[name]],
        ' parameter ',
        name,
        ': ',
        problem,
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}

parameter_checks <- function(params, formal_names) {
  selected <- which(vapply(
    params,
    function(p) {
      p$location %in%
        c('query', 'path', 'header', 'cookie') ||
        # Client inputs are checked only where a constraint was declared.
        (p$location == 'client' && isTRUE(p$constrained))
    },
    logical(1)
  ))
  if (!length(selected)) {
    return(character())
  }
  paste0(
    '  .api_validation$parameter_values(',
    'base::list(',
    paste(
      vapply(
        selected,
        function(i) {
          paste0(r_literal(formal_names[[i]]), ' = ', formal_names[[i]])
        },
        character(1)
      ),
      collapse = ', '
    ),
    '), ',
    r_literal(setNames(
      lapply(params[selected], function(p) p$validation_schema %or% p$schema),
      formal_names[selected]
    )),
    ', .api_validation$body_value, ',
    r_literal(setNames(
      vapply(params[selected], `[[`, character(1), 'location'),
      formal_names[selected]
    )),
    ')'
  )
}

# Use schema serialization where the helper's default wire lowering differs.
extended_parameter <- function(p) {
  if (!p$location %in% c('query', 'path', 'header', 'cookie')) {
    return(FALSE)
  }
  p$location == 'cookie' ||
    (p$location == 'query' && identical(p$schema$type, 'boolean')) ||
    identical(p$schema$type, 'object') ||
    !is.null(p$collection_format) ||
    (!is.null(p$style) && !p$style %in% c('simple', 'form')) ||
    (identical(p$schema$type, 'array') &&
      !(p$location == 'query' && identical(p$schema$items$type, 'string')))
}
