# Normalize only encodings whose flat wire representation is defined.
parameter_shape <- function(
  p,
  schema,
  version,
  at,
  query_array_style = 'schema'
) {
  fail <- function(code, message, classification = 'capability_gap') {
    schema_problem(code, classification, message, at)
  }
  location <- p[['in']]
  if (any(c('oneOf', 'anyOf', 'allOf') %in% names(schema))) {
    fail('parameter_composition', 'Unsupported parameter composition')
  }
  scalar <- function(s) {
    if (identical(s$format, 'binary')) {
      fail(
        'binary_parameter',
        'Binary parameter requires source contract review (#16)',
        'review_required'
      )
    }
    !any(c('oneOf', 'anyOf', 'allOf') %in% names(s)) &&
      length(s$type) >= 1L &&
      all(s$type %in% c('string', 'integer', 'number', 'boolean'))
  }
  if (identical(schema$type, 'array')) {
    if (!scalar(schema$items)) {
      fail('parameter_shape', 'Unsupported parameter array items')
    }
  } else if (identical(schema$type, 'object')) {
    children <- schema$properties
    if (is.list(schema$additionalProperties)) {
      children <- c(children, list(schema$additionalProperties))
    }
    if (
      any(vapply(children, function(s) length(s) && !scalar(s), logical(1)))
    ) {
      fail('nested_parameter', 'Unsupported nested parameter object')
    }
  } else if (!scalar(schema)) {
    fail('parameter_shape', 'Unsupported parameter type')
  }
  if (!location %in% c('path', 'query', 'header', 'cookie')) {
    fail('parameter_location', 'Unsupported parameter location')
  }
  if (!is.null(p$content) || isTRUE(p$allowReserved)) {
    fail('parameter_encoding', 'Unsupported parameter serialization')
  }
  query_array_style <- match.arg(query_array_style, c('schema', 'brackets'))
  if (
    identical(query_array_style, 'brackets') &&
      identical(location, 'query') &&
      identical(schema$type, 'array')
  ) {
    return(list(style = 'brackets', explode = TRUE, collection_format = NULL))
  }
  if (identical(version, '2.0')) {
    if (location == 'cookie' || identical(schema$type, 'object')) {
      fail(
        'parameter_location',
        'Unsupported Swagger parameter location or type',
        'schema_defect'
      )
    }
    collection <- p$collectionFormat %or% 'csv'
    if (
      identical(schema$type, 'array') &&
        (!collection %in% c('csv', 'ssv', 'tsv', 'pipes', 'multi') ||
          (collection == 'multi' && location != 'query'))
    ) {
      fail(
        'collection_format',
        'Invalid Swagger collectionFormat for parameter location',
        'schema_defect'
      )
    }
    style <- if (location == 'query') 'form' else 'simple'
    explode <- identical(schema$type, 'array') && collection == 'multi'
  } else {
    collection <- NULL
    style <- p$style %or%
      if (location %in% c('path', 'header')) 'simple' else 'form'
    explode <- p$explode %or% (style == 'form')
    allowed <- switch(
      location,
      path = c('simple', 'label', 'matrix'),
      query = c('form', 'spaceDelimited', 'pipeDelimited', 'deepObject'),
      header = 'simple',
      cookie = 'form'
    )
    if (
      length(style) != 1L ||
        !style %in% allowed ||
        !is.logical(explode) ||
        length(explode) != 1L ||
        is.na(explode) ||
        (style %in%
          c('spaceDelimited', 'pipeDelimited') &&
          !identical(schema$type, 'array')) ||
        (style == 'deepObject' &&
          (!identical(schema$type, 'object') || !explode))
    ) {
      fail('parameter_encoding', 'Unsupported parameter serialization')
    }
  }
  list(
    style = style,
    explode = explode,
    collection_format = if (identical(schema$type, 'array')) {
      collection
    } else {
      NULL
    }
  )
}

# Reduce a composed or nullable parameter schema to the shape its encoding
# needs: one container kind, or a union of scalar types. Validation keeps the
# original schema. JSON null has no parameter encoding, so it means omission.
# A scalar encodes like a one-element array, so scalar | array unions encode as
# arrays; object | non-object unions have no unambiguous encoding.
parameter_wire_schema <- function(schema, at) {
  composition <- c('oneOf', 'anyOf', 'allOf')
  fail <- function(message) {
    schema_problem('parameter_composition', 'capability_gap', message, at)
  }
  # wire() leaves one container type or only scalar types.
  kind <- function(s) {
    type <- s$type
    if (!length(type)) {
      NA_character_
    } else if (identical(type, 'object')) {
      'object'
    } else if (identical(type, 'array')) {
      'array'
    } else {
      'scalar'
    }
  }
  # allOf: every branch applies.
  merge <- function(a, b) {
    if (length(a$type) && length(b$type)) {
      type <- intersect(a$type, b$type)
      if ('integer' %in% a$type && 'number' %in% b$type) {
        type <- union(type, 'integer')
      }
      if ('number' %in% a$type && 'integer' %in% b$type) {
        type <- union(type, 'integer')
      }
      if (!length(type)) {
        fail('allOf parameter branches share no type')
      }
      a$type <- type
    }
    for (field in c('items', 'additionalProperties')) {
      if (is.list(a[[field]]) && is.list(b[[field]])) {
        a[[field]] <- merge(a[[field]], b[[field]])
      }
    }
    if (isFALSE(b$additionalProperties)) {
      a$additionalProperties <- FALSE
    }
    for (name in intersect(names(a$properties), names(b$properties))) {
      a$properties[[name]] <- merge(a$properties[[name]], b$properties[[name]])
    }
    a$properties <- c(
      a$properties,
      b$properties[setdiff(names(b$properties), names(a$properties))]
    )
    required <- union(unlist(a$required), unlist(b$required))
    if (length(required)) {
      a$required <- required
    }
    if (identical(b$format, 'binary')) {
      a$format <- 'binary'
    }
    for (field in setdiff(names(b), names(a))) {
      a[[field]] <- b[[field]]
    }
    a
  }
  # anyOf/oneOf: any branch may apply, so keep only shared structure.
  union_of <- function(a, b) {
    kinds <- c(kind(a), kind(b))
    if (anyNA(kinds)) {
      return(list())
    }
    if ('object' %in% kinds && !all(kinds == 'object')) {
      fail('Parameter composition mixes object and non-object branches')
    }
    if (all(kinds == 'object')) {
      properties <- a$properties
      for (name in names(b$properties)) {
        properties[[name]] <- if (name %in% names(properties)) {
          union_of(properties[[name]], b$properties[[name]])
        } else {
          b$properties[[name]]
        }
      }
      extra <- list(a$additionalProperties, b$additionalProperties)
      required <- intersect(unlist(a$required), unlist(b$required))
      return(c(
        list(type = 'object', properties = properties),
        if (length(required)) list(required = required),
        if (all(vapply(extra, isFALSE, logical(1)))) {
          list(additionalProperties = FALSE)
        } else if (all(vapply(extra, is.list, logical(1)))) {
          list(additionalProperties = union_of(extra[[1L]], extra[[2L]]))
        }
      ))
    }
    if (all(kinds == 'scalar')) {
      return(c(
        list(type = union(a$type, b$type)),
        if (identical(a$format, b$format)) list(format = a$format)
      ))
    }
    items <- function(s) if (kind(s) == 'array') s$items %or% list() else s
    list(type = 'array', items = union_of(items(a), items(b)))
  }
  # Returns NULL for a schema that only admits null.
  wire <- function(s) {
    if (!is.list(s)) {
      return(s)
    }
    out <- s[setdiff(names(s), composition)]
    if ('type' %in% names(s)) {
      type <- setdiff(unlist(s$type), 'null')
      if (!length(type)) {
        return(NULL)
      }
      out$type <- type
    }
    if (is.list(out$items)) {
      out$items <- wire(out$items) %or% list()
    }
    if (is.list(out$additionalProperties)) {
      out$additionalProperties <- wire(out$additionalProperties) %or% list()
    }
    if (length(out$properties)) {
      out$properties <- lapply(out$properties, function(p) wire(p) %or% list())
    }
    # A JSON Schema 2020-12 type list such as [string, array].
    if (length(out$type) > 1L && any(out$type %in% c('array', 'object'))) {
      if ('object' %in% out$type) {
        fail('Parameter type mixes object and non-object values')
      }
      out <- c(
        out[setdiff(names(out), c('type', 'items'))],
        union_of(
          list(type = setdiff(out$type, 'array')),
          list(type = 'array', items = out$items %or% list())
        )
      )
    }
    for (branch in s$allOf) {
      branch <- wire(branch)
      if (is.null(branch)) {
        fail('allOf parameter branch only admits null')
      }
      out <- merge(out, branch)
    }
    for (field in intersect(c('anyOf', 'oneOf'), names(s))) {
      branches <- Filter(Negate(is.null), lapply(s[[field]], wire))
      if (!length(branches)) {
        return(NULL)
      }
      out <- merge(out, Reduce(union_of, branches))
    }
    out
  }
  wire(schema) %or% fail('Parameter schema only admits null')
}

# Composition or a JSON null type anywhere means the encoding schema differs.
parameter_composed <- function(schema) {
  if (!is.list(schema)) {
    return(FALSE)
  }
  any(c('oneOf', 'anyOf', 'allOf') %in% names(schema)) ||
    (length(schema$type) > 1L && 'null' %in% schema$type) ||
    any(vapply(
      c(
        list(schema$items, schema$additionalProperties),
        unname(schema$properties)
      ),
      parameter_composed,
      logical(1)
    ))
}

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
      p$location %in% c('query', 'path', 'header', 'cookie')
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

# Preserve existing helper calls for the previously supported subset.
extended_parameter <- function(p) {
  if (!p$location %in% c('query', 'path', 'header', 'cookie')) {
    return(FALSE)
  }
  p$location == 'cookie' ||
    identical(p$schema$type, 'object') ||
    !is.null(p$collection_format) ||
    (!is.null(p$style) && !p$style %in% c('simple', 'form')) ||
    (identical(p$schema$type, 'array') &&
      !(p$location == 'query' && identical(p$schema$items$type, 'string')))
}
