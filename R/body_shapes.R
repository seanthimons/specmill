body_fixture <- function(schema, override = NULL) {
  if (missing(override)) {
    body_fixture_sourced(schema)$value
  } else {
    body_fixture_sourced(schema, override)$value
  }
}

body_fixture_sourced <- function(schema, override = NULL) {
  if (!missing(override)) {
    return(list(value = body_value(override, schema), source = 'override'))
  }
  selected <- intersect(c('example', 'default'), names(schema))
  if (length(selected)) {
    return(list(
      value = body_value(schema[[selected[[1L]]]], schema),
      source = paste0('schema_', selected[[1L]])
    ))
  }
  candidates <- if ('enum' %in% names(schema)) {
    structure(
      as.list(schema$enum),
      sources = rep('schema_enum', length(schema$enum))
    )
  } else {
    body_fixture_candidates(schema)
  }
  sources <- attr(candidates, 'sources')
  for (i in seq_along(candidates)) {
    result <- tryCatch(
      list(ok = TRUE, value = body_value(candidates[[i]], schema)),
      error = function(e) list(ok = FALSE)
    )
    if (result$ok) {
      return(list(value = result$value, source = sources[[i]]))
    }
  }
  stop('No valid body fixture: supply a reviewed override', call. = FALSE)
}

# Candidate values carry a parallel `sources` attribute: schema-provided values
# keep their field, and type-built values are `synthesized`.
body_fixture_candidates <- function(schema) {
  sourced <- function(values, sources) {
    structure(values, sources = rep_len(sources, length(values)))
  }
  selected <- intersect(c('example', 'default', 'enum'), names(schema))
  if (length(selected)) {
    value <- schema[[selected[[1L]]]]
    return(sourced(
      if (selected[[1L]] == 'enum') as.list(value) else list(value),
      paste0('schema_', selected[[1L]])
    ))
  }
  direct <- c(
    if ('const' %in% names(schema)) list(schema$const),
    if ('example' %in% names(schema)) list(schema$example),
    if ('default' %in% names(schema)) list(schema$default),
    if (length(schema$enum)) as.list(schema$enum)
  )
  direct_sources <- c(
    if ('const' %in% names(schema)) 'schema_const',
    if ('example' %in% names(schema)) 'schema_example',
    if ('default' %in% names(schema)) 'schema_default',
    rep('schema_enum', length(schema$enum))
  )
  plain <- tryCatch(body_fixture_plain(schema), error = function(e) list())
  fields <- intersect(names(schema), c('oneOf', 'anyOf', 'allOf'))
  if (!length(fields)) {
    return(sourced(
      c(direct, plain),
      c(direct_sources, attr(plain, 'sources') %or% character())
    ))
  }
  by_field <- lapply(schema[fields], function(branches) {
    lapply(branches, body_fixture_candidates)
  })
  branches <- unlist(by_field, recursive = FALSE)
  candidates <- unlist(branches, recursive = FALSE)
  candidate_sources <- unlist(
    lapply(branches, attr, 'sources'),
    use.names = FALSE
  )
  if ('allOf' %in% fields) {
    first <- lapply(by_field$allOf, function(values) {
      if (length(values)) values[[1L]] else NULL
    })
    if (
      all(vapply(
        first,
        function(x) is.list(x) && !is.null(names(x)),
        logical(1)
      ))
    ) {
      merged <- stats::setNames(list(), character())
      for (value in first) {
        merged <- utils::modifyList(merged, value, keep.null = TRUE)
      }
      # A merge is schema-provided only when every branch's value is.
      merged_source <- if (
        all(vapply(
          by_field$allOf,
          function(values) {
            length(values) > 0L &&
              startsWith(attr(values, 'sources')[[1L]], 'schema_')
          },
          logical(1)
        ))
      ) {
        'schema_example'
      } else {
        'synthesized'
      }
      candidates <- c(list(merged), candidates)
      candidate_sources <- c(merged_source, candidate_sources)
    }
  }
  sourced(
    c(direct, candidates, plain),
    c(
      direct_sources,
      candidate_sources,
      attr(plain, 'sources') %or% character()
    )
  )
}

# A value built from the schema's structure. Its `sources` attribute is
# schema-provided when every item or property value is, otherwise synthesized.
body_fixture_plain <- function(schema) {
  if (!is.null(attr(schema, 'specmill_ref'))) {
    stop('Recursive fixture requires a finite value')
  }
  built <- function(children) {
    sources <- vapply(children, `[[`, character(1), 'source')
    source <- if (length(sources) && all(startsWith(sources, 'schema_'))) {
      sources[[1L]]
    } else {
      'synthesized'
    }
    list(value = lapply(children, `[[`, 'value'), source = source)
  }
  type <- unlist(schema$type, use.names = FALSE)
  if (!length(type)) {
    return(structure(list(list()), sources = 'synthesized'))
  }
  if ('null' %in% type) {
    return(structure(list(NULL), sources = 'synthesized'))
  }
  if ('array' %in% type) {
    items <- built(lapply(seq_len(schema$minItems %or% 1L), function(i) {
      body_fixture_sourced(schema$items)
    }))
    return(structure(list(items$value), sources = items$source))
  }
  if ('object' %in% type) {
    properties <- names(schema$properties)
    properties <- properties[
      !vapply(
        schema$properties,
        function(property) {
          isTRUE(property$readOnly) ||
            !is.null(attr(property, 'specmill_ref'))
        },
        logical(1)
      )
    ]
    keys <- union(properties, unlist(schema$required)) %or% character()
    fields <- built(lapply(keys, function(name) {
      body_fixture_sourced(
        schema$properties[[name]] %or%
          if (is.list(schema$additionalProperties)) {
            schema$additionalProperties
          } else {
            list()
          }
      )
    }))
    return(structure(
      list(stats::setNames(fields$value, keys)),
      sources = fields$source
    ))
  }
  fixture <- fixture_value_sourced(schema)
  structure(list(fixture$value), sources = fixture$source)
}

body_fixture_value <- function(schema, override = NULL) {
  if (!missing(override)) {
    return(override)
  }
  body_fixture(schema)
}

# Self-contained: generated clients need no specmill runtime or new helper argument.
body_value <- function(value, schema) {
  # Check all supplied content, including unconstrained fields, before equality
  # or schema validation can recurse. R environments are not JSON objects.
  nodes <- 0L
  check_json <- function(value, depth = 0L) {
    nodes <<- nodes + 1L
    if (depth > 32L) {
      stop('Depth limit exceeded (32); possible cycle')
    }
    if (nodes > 20000L) {
      stop('Node limit exceeded (20000)')
    }
    if (is.environment(value)) {
      stop('Value contains an environment or cycle')
    }
    if (is.list(value)) {
      for (child in value) {
        check_json(child, depth + 1L)
      }
    }
  }
  check_json(value)
  definitions <- list()
  collect <- function(node) {
    id <- attr(node, 'specmill_id')
    if (!is.null(id)) {
      definitions[[id]] <<- node
    }
    for (child in node$properties) {
      collect(child)
    }
    for (field in c('items', 'additionalProperties')) {
      if (is.list(node[[field]])) collect(node[[field]])
    }
    for (field in c('allOf', 'anyOf', 'oneOf')) {
      for (child in node[[field]]) {
        collect(child)
      }
    }
  }
  collect(schema)
  validations <- 0L

  equal_json <- function(x, y) {
    if (is.list(x) || is.list(y)) {
      if (
        !is.list(x) ||
          !is.list(y) ||
          !identical(is.null(names(x)), is.null(names(y)))
      ) {
        return(FALSE)
      }
      if (is.null(names(x))) {
        return(length(x) == length(y) && all(mapply(equal_json, x, y)))
      }
      if (!setequal(names(x), names(y))) {
        return(FALSE)
      }
      return(all(vapply(
        sort(names(x)),
        function(name) equal_json(x[[name]], y[[name]]),
        logical(1)
      )))
    }
    if (is.numeric(x) && is.numeric(y)) {
      return(
        length(x) == 1L && length(y) == 1L && !is.na(x) && !is.na(y) && x == y
      )
    }
    identical(x, y)
  }
  validate <- function(value, schema, strict = FALSE) {
    validations <<- validations + 1L
    if (validations > 20000L) {
      stop('Validation node limit exceeded (20000)')
    }
    ref <- attr(schema, 'specmill_ref')
    if (!is.null(ref)) {
      schema <- definitions[[ref]]
      if (is.null(schema)) stop('Missing recursive schema definition')
    }
    type <- unlist(schema$type, use.names = FALSE)
    strict <- strict ||
      length(type) > 1L ||
      any(c('oneOf', 'anyOf', 'allOf') %in% names(schema))
    if (is.object(value) || !is.null(dim(value))) {
      stop('Value must contain plain JSON values')
    }
    # A list survives auto_unbox, so c('x') still sends ['x']. Union and
    # composed schemas (strict) keep rejecting vectors as ambiguous.
    if (
      !strict &&
        identical(type, 'array') &&
        is.atomic(value) &&
        !is.null(value) &&
        is.null(names(value))
    ) {
      value <- as.list(value)
    }
    scalar <- is.atomic(value) &&
      length(value) == 1L &&
      !anyNA(value) &&
      is.null(names(value))
    shape <- if (is.null(value)) {
      'null'
    } else if (is.list(value)) {
      if (is.null(names(value))) 'array' else 'object'
    } else if (!scalar) {
      ''
    } else if (is.character(value)) {
      'string'
    } else if (is.logical(value)) {
      'boolean'
    } else if (is.numeric(value) && is.finite(value) && value == trunc(value)) {
      'integer'
    } else if (is.numeric(value) && is.finite(value)) {
      'number'
    } else {
      ''
    }
    if (!nzchar(shape)) {
      stop('Invalid scalar type')
    }
    legacy_empty_object <- !strict &&
      identical(shape, 'array') &&
      !length(value) &&
      identical(type, 'object')
    if (
      shape != 'null' &&
        length(type) &&
        !legacy_empty_object &&
        !(shape %in% type || (shape == 'integer' && 'number' %in% type))
    ) {
      stop('Invalid scalar type')
    }
    if (shape == 'null') {
      if (length(type) && !('null' %in% type) && !isTRUE(schema$nullable)) {
        stop('Explicit null is not nullable')
      }
    } else if (shape == 'object' || legacy_empty_object) {
      keys <- names(value)
      if (is.null(keys)) {
        keys <- character()
      }
      if (anyNA(keys) || anyDuplicated(keys) || any(!nzchar(keys))) {
        stop('Invalid object names')
      }
      if (!all(unlist(schema$required) %in% keys)) {
        stop('Missing required fields')
      }
      if (
        any(vapply(
          schema$properties[intersect(keys, names(schema$properties))],
          function(property) isTRUE(property$readOnly),
          logical(1)
        ))
      ) {
        stop('Read-only fields are not allowed')
      }
      unknown <- setdiff(keys, names(schema$properties))
      if (length(unknown) && isFALSE(schema$additionalProperties)) {
        stop('Unknown fields')
      }
      value <- lapply(seq_along(value), function(i) {
        child <- schema$properties[[keys[[i]]]]
        if (is.null(child)) {
          child <- if (is.list(schema$additionalProperties)) {
            schema$additionalProperties
          } else {
            list()
          }
        }
        validate(value[[i]], child, strict)
      })
      names(value) <- keys
    } else if (shape == 'array') {
      if (
        (!is.null(schema$minItems) && length(value) < schema$minItems) ||
          (!is.null(schema$maxItems) && length(value) > schema$maxItems)
      ) {
        stop('Invalid array length')
      }
      value <- lapply(value, validate, schema = schema$items, strict = strict)
    }
    numeric_value <- shape %in% c('integer', 'number')
    if (
      numeric_value &&
        ((!is.null(schema$minimum) && value < schema$minimum) ||
          (!is.null(schema$maximum) && value > schema$maximum) ||
          (isTRUE(schema$exclusiveMinimum) &&
            !is.null(schema$minimum) &&
            value <= schema$minimum) ||
          (isTRUE(schema$exclusiveMaximum) &&
            !is.null(schema$maximum) &&
            value >= schema$maximum) ||
          (!is.null(schema$exclusiveMinimum) &&
            is.numeric(schema$exclusiveMinimum) &&
            value <= schema$exclusiveMinimum) ||
          (!is.null(schema$exclusiveMaximum) &&
            is.numeric(schema$exclusiveMaximum) &&
            value >= schema$exclusiveMaximum))
    ) {
      stop('Invalid numeric bounds')
    }
    if (
      numeric_value &&
        !is.null(schema$multipleOf) &&
        abs(value / schema$multipleOf - round(value / schema$multipleOf)) >
          sqrt(.Machine$double.eps)
    ) {
      stop('Invalid multipleOf')
    }
    if (
      shape == 'string' &&
        ((!is.null(schema$minLength) && nchar(value) < schema$minLength) ||
          (!is.null(schema$maxLength) && nchar(value) > schema$maxLength) ||
          (!is.null(schema$pattern) &&
            !grepl(schema$pattern, value, perl = TRUE)))
    ) {
      stop('Invalid string')
    }
    if (
      !is.null(schema$enum) &&
        !any(vapply(schema$enum, equal_json, logical(1), y = value))
    ) {
      stop('Invalid enum')
    }
    if ('const' %in% names(schema) && !equal_json(value, schema$const)) {
      stop('Invalid const')
    }
    if (
      ((!is.null(schema$minProperties) &&
        is.list(value) &&
        !is.null(names(value)) &&
        length(value) < schema$minProperties) ||
        (!is.null(schema$maxProperties) &&
          is.list(value) &&
          !is.null(names(value)) &&
          length(value) > schema$maxProperties))
    ) {
      stop('Invalid object size')
    }
    # ponytail: O(n^2) JSON equality; add canonical hashing only if large unique arrays matter.
    if (
      isTRUE(schema$uniqueItems) &&
        shape == 'array' &&
        any(vapply(
          seq_along(value),
          function(i) {
            any(vapply(
              value[seq_len(i - 1L)],
              equal_json,
              logical(1),
              y = value[[i]]
            ))
          },
          logical(1)
        ))
    ) {
      stop('Duplicate array items')
    }
    for (field in c('allOf', 'anyOf', 'oneOf')) {
      if (!field %in% names(schema)) {
        next
      }
      branches <- schema[[field]]
      if (is.null(branches)) {
        branches <- list()
      }
      matches <- vapply(
        branches,
        function(branch) {
          !inherits(
            try(validate(value, branch, TRUE), silent = TRUE),
            'try-error'
          )
        },
        logical(1)
      )
      if (field == 'allOf' && !all(matches)) {
        stop('allOf requires every branch')
      }
      if (field == 'anyOf' && !any(matches)) {
        stop('anyOf matched no branches')
      }
      if (field == 'oneOf' && sum(matches) != 1L) {
        stop(
          'oneOf matched ',
          sum(matches),
          ' branches; expected exactly one'
        )
      }
    }
    value
  }
  validate(value, schema)
}

batch_limit <- function(env, default, cap = NULL) {
  value <- suppressWarnings(as.numeric(Sys.getenv(
    env,
    unset = as.character(default)
  )))
  if (
    length(value) != 1L ||
      is.na(value) ||
      !is.finite(value) ||
      value < 1 ||
      value != floor(value) ||
      value > .Machine$integer.max
  ) {
    stop(
      'batch.max_items from ',
      env,
      ' must resolve to a positive R integer',
      call. = FALSE
    )
  }
  if (is.null(cap)) value else min(value, cap)
}

# One specmill-owned copy serves every wrapper and API in the client. The
# closures resolve names through a private environment whose parent is
# baseenv(), so package functions named list or c cannot shadow them.
validation_runtime <- function() {
  validators <- list(
    body_value = body_value,
    parameter_values = parameter_values,
    form_value = form_value,
    text_input = text_input,
    batch_limit = batch_limit,
    text_value = text_value
  )
  source <- paste(
    c(
      '# Generated by specmill: shared request validators. Do not edit.',
      '.api_validation <- base::local(envir = base::new.env(parent = base::baseenv()), {',
      paste0(
        names(validators),
        ' <- ',
        vapply(validators, r_literal, character(1), guard = FALSE)
      ),
      '  base::environment()',
      '})'
    ),
    collapse = '\n'
  )
  gsub('[[:blank:]]+(\n|$)', '\\1', source)
}

body_checks <- function(schema, value) {
  paste0(
    value,
    ' <- base::tryCatch(.api_validation$body_value(',
    value,
    ', ',
    r_literal(schema),
    '), error = function(e) base::stop(',
    r_literal(paste0('Invalid ', value, ': ')),
    ', ',
    'base::conditionMessage(e), call. = FALSE))'
  )
}
