form_media <- function(media) {
  isTRUE(
    media %in% c('application/x-www-form-urlencoded', 'multipart/form-data')
  )
}

validate_body_media_correction <- function(correction) {
  config_fields(correction, c('from', 'to', 'reason'), 'body_media_correction')
  if (!'from' %in% names(correction)) {
    stop('body_media_correction requires an explicit from field')
  }
  for (field in c('to', 'reason')) {
    config_string(correction[[field]], paste('body_media_correction', field))
  }
  missing_json <- is.null(correction$from) &&
    identical(correction$to, 'application/json')
  text_correction <- identical(correction$from, 'application/json') &&
    identical(correction$to, 'text/plain')
  if (!missing_json && !text_correction) {
    stop(
      'body_media_correction supports missing media to application/json or application/json to text/plain only'
    )
  }
}

request_body_media <- function(
  available,
  preferred = NULL,
  at = '#',
  correction = NULL
) {
  supported <- c(
    'application/json',
    'application/octet-stream',
    'application/x-www-form-urlencoded',
    'multipart/form-data',
    'text/plain'
  )
  available <- unlist(available, use.names = FALSE)
  if (!is.null(correction)) {
    validate_body_media_correction(correction)
    if (
      (if (is.null(correction$from)) {
        length(available) > 0L
      } else {
        !correction$from %in% available
      }) ||
        correction$to %in% available ||
        (!is.null(preferred) && !identical(preferred, correction$to))
    ) {
      schema_problem(
        'body_media_correction',
        'review_required',
        'Body media correction disagrees with declared media or selected body_media',
        at
      )
    }
    return(correction$to)
  }
  selected <- if (is.null(preferred)) {
    intersect(supported, available)[1L]
  } else {
    preferred
  }
  if (
    length(selected) != 1L ||
      is.na(selected) ||
      !selected %in% intersect(supported, available)
  ) {
    schema_problem(
      'body_media_type',
      'capability_gap',
      if (is.null(preferred)) {
        if (length(available)) {
          'Unsupported body media type'
        } else {
          'Ambiguous body media type'
        }
      } else {
        'Requested body media type is unavailable'
      },
      at
    )
  }
  selected
}


# Self-contained except for the supplied JSON validator, which is embedded too.
form_value <- function(value, schema, validate, allow_empty = TRUE) {
  if (
    is.null(value) ||
      !is.list(value) ||
      (length(value) && is.null(names(value)))
  ) {
    stop('Form body must be a named list; omit the body argument to omit it')
  }
  if (!length(value) && !allow_empty) {
    stop('Empty multipart forms cannot be encoded')
  }
  original <- list()
  for (name in names(value)) {
    field <- schema$properties[[name]]
    if (is.null(field) && is.list(schema$additionalProperties)) {
      field <- schema$additionalProperties
    }
    free <- is.null(field) && isTRUE(schema$additionalProperties)
    if (is.null(field$type) && !free) {
      stop('Form field needs a declared schema: ', name)
    }
    if (free) {
      x <- value[[name]]
      if (
        is.object(x) ||
          !is.null(dim(x)) ||
          !is.null(names(x)) ||
          length(x) != 1L ||
          anyNA(x) ||
          !typeof(x) %in% c('character', 'logical', 'integer', 'double') ||
          (is.numeric(x) && !is.finite(x))
      ) {
        stop(
          'Free-form form fields must be finite scalar strings, numbers or booleans: ',
          name
        )
      }
    }
    if (is.null(value[[name]])) {
      stop('Null form fields have no unambiguous encoding: ', name)
    }
    if (identical(field$type, 'array') && !length(value[[name]])) {
      stop('Empty form arrays have no unambiguous encoding: ', name)
    }
    type <- if (identical(field$type, 'array')) field$items else field
    if (identical(type$format, 'binary')) {
      parts <- if (identical(field$type, 'array')) {
        value[[name]]
      } else {
        list(value[[name]])
      }
      if (
        !is.list(parts) ||
          !is.null(names(parts)) ||
          !length(parts) ||
          !all(vapply(
            parts,
            function(x) is.raw(x) || inherits(x, 'form_file'),
            logical(1)
          ))
      ) {
        stop(
          'Binary form fields must be raw vectors or curl::form_file() values'
        )
      }
      original[name] <- value[name]
      value[name] <- list(
        if (identical(field$type, 'array')) rep(list(''), length(parts)) else ''
      )
    }
  }
  value <- tryCatch(validate(value, schema), error = function(e) {
    stop('Invalid body: ', conditionMessage(e), call. = FALSE)
  })
  for (name in names(original)) {
    value[name] <- original[name]
  }
  value
}

form_checks <- function(schema, value, media) {
  paste0(
    value,
    ' <- .api_validation$form_value(',
    value,
    ', ',
    r_literal(schema),
    ', .api_validation$body_value, ',
    r_literal(identical(media, 'application/x-www-form-urlencoded')),
    ')'
  )
}

form_fixture <- function(schema, allow_empty = TRUE) {
  value <- body_fixture_value(schema)
  for (name in names(value)) {
    field <- schema$properties[[name]] %or% schema$additionalProperties
    if (identical(field$format, 'binary')) {
      value[name] <- list(as.raw(c(0, 255)))
    }
    if (
      identical(field$type, 'array') && identical(field$items$format, 'binary')
    ) {
      value[name] <- list(rep(
        list(as.raw(c(0, 255))),
        max(1L, length(value[[name]]))
      ))
    }
    if (identical(field$type, 'array') && !length(value[[name]])) {
      value[name] <- list(list(body_fixture_value(field$items)))
    }
  }
  form_value(value, schema, body_value, allow_empty)
}

text_input <- function(value) {
  if (
    !is.character(value) ||
      is.object(value) ||
      !is.null(dim(value)) ||
      !is.null(names(value)) ||
      anyNA(value)
  ) {
    stop('Text body must be a character value without missing values')
  }
  value
}

# Explicit lines encoding happens before validating the declared scalar schema.
text_value <- function(value, encoding = 'scalar', max_items = NULL) {
  if (
    !is.character(encoding) ||
      length(encoding) != 1L ||
      is.na(encoding) ||
      !encoding %in% c('scalar', 'lines')
  ) {
    stop('Text encoding must be scalar or lines')
  }
  value <- text_input(value)
  if (encoding == 'scalar' && length(value) != 1L) {
    stop('Scalar text body must contain exactly one string')
  }
  if (encoding == 'lines') {
    if (!is.null(max_items) && length(value) > max_items) {
      stop(
        'Batch exceeds max_items (',
        max_items,
        '); split the input into smaller requests'
      )
    }
    value <- paste(value, collapse = '\n')
  }
  value
}

text_checks <- function(operation, value) {
  c(
    paste0(
      value,
      ' <- .api_validation$text_value(',
      value,
      ', ',
      r_literal(operation$text_encoding %or% 'scalar'),
      ', ',
      r_literal(operation$batch$max_items),
      ')'
    ),
    body_checks(operation$body, value)
  )
}
