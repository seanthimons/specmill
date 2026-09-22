fixture_type_matches <- function(value, schema) {
  if (is.null(value)) {
    return(isTRUE(schema$nullable) || 'null' %in% schema$type)
  }
  any(vapply(
    schema$type,
    function(type) {
      switch(
        type,
        string = is.character(value) && length(value) == 1L && !is.na(value),
        integer = is.numeric(value) &&
          length(value) == 1L &&
          is.finite(value) &&
          value == trunc(value),
        number = is.numeric(value) && length(value) == 1L && is.finite(value),
        boolean = is.logical(value) && length(value) == 1L && !is.na(value),
        object = is.list(value) && !is.null(names(value)),
        array = is.list(value) && is.null(names(value)),
        FALSE
      )
    },
    logical(1)
  ))
}

fixture_diagnostics <- function(op) {
  inspect <- function(schema, name, location, required) {
    result <- list()
    at <- attr(schema, 'specmill_enum_location')
    if (!is.null(at)) {
      result <- list(list(
        key = op$key,
        source = op$source,
        parameter = name,
        location = location,
        classification = 'schema_defect',
        code = 'type_enum_contradiction',
        source_location = at,
        required = required,
        reason = paste(
          'Enum has no value matching declared type;',
          if (required) {
            'required input is unsatisfiable'
          } else {
            'optional input may be omitted'
          }
        )
      ))
    }
    for (child in names(schema$properties)) {
      result <- c(
        result,
        inspect(
          schema$properties[[child]],
          child,
          location,
          required && child %in% unlist(schema$required)
        )
      )
    }
    result
  }
  result <- unlist(
    lapply(op$parameters, function(p) {
      inspect(p$schema, p$name, p$location, p$required)
    }),
    recursive = FALSE
  )
  c(result, inspect(op$body, 'body', 'body', isTRUE(op$body_required)))
}

fixture_value <- function(schema, override = NULL) {
  if (identical(schema$type, 'object')) {
    if (
      missing(override) &&
        !any(c('example', 'default', 'enum') %in% names(schema))
    ) {
      keys <- union(names(schema$properties), unlist(schema$required))
      if (!length(keys) && !isFALSE(schema$additionalProperties)) {
        keys <- 'example'
      }
      override <- setNames(
        lapply(keys, function(name) {
          child <- schema$properties[[name]] %or%
            if (is.list(schema$additionalProperties)) {
              schema$additionalProperties
            } else {
              list()
            }
          if (is.null(child$type)) {
            child$type <- 'string'
          }
          fixture_value(child)
        }),
        keys
      )
    }
    value <- if (missing(override)) {
      body_fixture(schema)
    } else {
      body_fixture(schema, override)
    }
    if (
      !length(value) ||
        any(vapply(
          value,
          function(x) is.list(x) || length(x) != 1L,
          logical(1)
        ))
    ) {
      stop('Parameter fixture must be a nonempty flat object')
    }
    return(value)
  }
  if (identical(schema$type, 'array')) {
    value <- if (missing(override)) {
      body_fixture(schema)
    } else {
      body_fixture(schema, as.list(override))
    }
    value <- unlist(value, use.names = FALSE)
    if (!length(value)) {
      stop('Parameter fixture must be a nonempty array')
    }
    return(switch(
      schema$items$type,
      string = as.character(value),
      integer = as.integer(value),
      number = as.numeric(value),
      boolean = as.logical(value)
    ))
  }
  selected <- intersect(c('example', 'default', 'enum'), names(schema))
  if (missing(override) && length(selected)) {
    value <- schema[[selected[[1L]]]]
    if (selected[[1L]] == 'enum') {
      candidates <- Filter(function(x) fixture_type_matches(x, schema), value)
      value <- if (length(candidates)) candidates[[1L]] else value[[1L]]
    }
    override <- value
  }
  if (!missing(override) && is.null(override)) {
    if (
      (isTRUE(schema$nullable) || 'null' %in% schema$type) &&
        (is.null(schema$enum) || any(vapply(schema$enum, is.null, logical(1))))
    ) {
      return(NULL)
    }
    stop('Explicit null fixture is not nullable')
  }
  value <- if (!missing(override)) {
    override
  } else {
    schema$example %or%
      schema$default %or%
      schema$enum[[1L]]
  }
  if (is.null(value)) {
    value <- switch(
      schema$type,
      string = 'example',
      integer = 1L,
      number = 1,
      boolean = TRUE
    )
    if (schema$type %in% c('integer', 'number')) {
      lower <- schema$minimum %or% -Inf
      upper <- schema$maximum %or% Inf
      if (schema$type == 'integer') {
        lower <- ceiling(lower)
        upper <- floor(upper)
      }
      if (lower > upper) {
        stop(
          'No valid fixture: numeric interval has no solution',
          call. = FALSE
        )
      }
      if (value < lower) {
        value <- lower
      }
      if (value > upper) value <- upper
    }
  }
  valid <- length(value) == 1L &&
    !is.na(value) &&
    switch(
      schema$type,
      string = is.character(value),
      integer = is.numeric(value) && value == trunc(value),
      number = is.numeric(value) && is.finite(value),
      boolean = is.logical(value),
      FALSE
    )
  if (valid && !is.null(schema$enum)) {
    valid <- any(vapply(
      schema$enum,
      function(candidate) {
        fixture_type_matches(candidate, schema) &&
          isTRUE(all.equal(value, candidate, check.attributes = FALSE))
      },
      logical(1)
    ))
  }
  if (valid && !is.null(schema$minimum)) {
    valid <- value >= schema$minimum
  }
  if (valid && !is.null(schema$maximum)) {
    valid <- value <= schema$maximum
  }
  if (valid && !is.null(schema$minLength)) {
    valid <- nchar(value) >= schema$minLength
  }
  if (valid && !is.null(schema$maxLength)) {
    valid <- nchar(value) <= schema$maxLength
  }
  if (valid && !is.null(schema$pattern)) {
    valid <- grepl(schema$pattern, value, perl = TRUE)
  }
  if (!isTRUE(valid)) {
    stop('No valid fixture: supply a reviewed override', call. = FALSE)
  }
  value
}

minimal_fixture_schema <- function(schema) {
  if (length(schema$properties)) {
    schema$properties <- lapply(
      schema$properties[intersect(
        names(schema$properties),
        unlist(schema$required)
      )],
      minimal_fixture_schema
    )
  }
  if (is.list(schema$items)) {
    schema$items <- minimal_fixture_schema(schema$items)
  }
  schema
}

operation_fixtures <- function(
  operations,
  overrides = list(),
  mode = c('default', 'minimal')
) {
  mode <- match.arg(mode)
  lapply(operations, function(op) {
    omitted <- character()
    parameters <- Filter(
      function(p) {
        keep <- mode != 'minimal' ||
          p$required ||
          p$name %in% names(overrides[[op$name]])
        if (!keep) {
          omitted <<- c(omitted, p$name)
        }
        keep
      },
      op$parameters
    )
    inputs <- setNames(
      lapply(parameters, function(p) {
        tryCatch(
          {
            if (p$name %in% names(overrides[[op$name]])) {
              fixture_value(p$schema, overrides[[op$name]][[p$name]])
            } else if ('example' %in% names(p$example)) {
              fixture_value(p$schema, p$example$example)
            } else {
              fixture_value(p$schema)
            }
          },
          error = function(e) {
            problem <- Filter(
              function(d) {
                identical(d$parameter, p$name) &&
                  identical(d$location, p$location)
              },
              fixture_diagnostics(op)
            )
            classification <- if (length(problem)) {
              'schema_defect'
            } else {
              'review_required'
            }
            code <- if (length(problem)) {
              'type_enum_contradiction'
            } else {
              'fixture_synthesis'
            }
            at <- if (length(problem)) {
              problem[[1L]]$source_location
            } else {
              p$source_location
            }
            schema_problem(
              code,
              classification,
              paste(
                op$key,
                p$location,
                p$name,
                if (p$required) {
                  '(required input)'
                } else {
                  '(optional input; minimal mode reduces coverage)'
                },
                if (length(problem)) {
                  problem[[1L]]$reason
                } else {
                  conditionMessage(e)
                }
              ),
              at
            )
          }
        )
      }),
      parameter_names(parameters)
    )
    if (
      mode == 'minimal' &&
        !isTRUE(op$body_required) &&
        !'body' %in% names(overrides[[op$name]]) &&
        !is.null(op$body)
    ) {
      omitted <- c(omitted, 'body')
    } else if (!is.null(op$body)) {
      tryCatch(
        {
          if (
            mode == 'minimal' &&
              !'body' %in% names(overrides[[op$name]]) &&
              !any(c('example', 'default', 'enum') %in% names(op$body)) &&
              !length(op$body_example)
          ) {
            omitted <- c(
              omitted,
              paste0(
                'body.',
                setdiff(names(op$body$properties), unlist(op$body$required))
              )
            )
            op$body <- minimal_fixture_schema(op$body)
          }
          if (
            !'body' %in% names(overrides[[op$name]]) &&
              'example' %in% names(op$body_example)
          ) {
            overrides[[op$name]]['body'] <- list(op$body_example$example)
          }
          if (form_media(op$body_media)) {
            allow_empty <- identical(
              op$body_media,
              'application/x-www-form-urlencoded'
            )
            inputs['body'] <- list(
              if ('body' %in% names(overrides[[op$name]])) {
                form_value(
                  overrides[[op$name]]$body,
                  op$body,
                  body_value,
                  allow_empty
                )
              } else {
                form_fixture(op$body, allow_empty)
              }
            )
          } else if (identical(op$body_media, 'application/octet-stream')) {
            value <- if ('body' %in% names(overrides[[op$name]])) {
              overrides[[op$name]]$body
            } else {
              as.raw(0L)
            }
            if (!is.raw(value)) {
              stop('Binary fixture must be a raw vector')
            }
            inputs['body'] <- list(value)
          } else {
            inputs['body'] <- list(
              if ('body' %in% names(overrides[[op$name]])) {
                body_fixture(op$body, overrides[[op$name]]$body)
              } else {
                body_fixture(op$body)
              }
            )
          }
        },
        error = function(e) {
          problem <- Filter(
            function(d) identical(d$location, 'body'),
            fixture_diagnostics(op)
          )
          if (length(problem)) {
            d <- problem[[1L]]
            schema_problem(
              d$code,
              d$classification,
              paste(
                op$key,
                d$location,
                d$parameter,
                d$reason,
                conditionMessage(e)
              ),
              d$source_location
            )
          }
          schema_problem(
            'fixture_synthesis',
            'review_required',
            paste(
              op$key,
              if (op$body_required) '(required body)' else '(optional body)',
              conditionMessage(e)
            ),
            '#/requestBody'
          )
        }
      )
    }
    if (mode == 'minimal') {
      attr(inputs, 'omitted_inputs') <- omitted
    }
    inputs
  })
}
