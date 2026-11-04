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
  if (missing(override)) {
    fixture_value_sourced(schema)$value
  } else {
    fixture_value_sourced(schema, override)$value
  }
}

# The selected value and where it came from: an override, a schema example,
# default, enum or const, or a synthesized type fixture.
fixture_value_sourced <- function(schema, override = NULL) {
  source <- if (missing(override)) NULL else 'override'
  if (identical(schema$type, 'object')) {
    if (
      missing(override) &&
        !any(c('example', 'default', 'enum') %in% names(schema))
    ) {
      keys <- union(names(schema$properties), unlist(schema$required))
      if (!length(keys) && !isFALSE(schema$additionalProperties)) {
        keys <- 'example'
      }
      children <- lapply(keys, function(name) {
        child <- schema$properties[[name]] %or%
          if (is.list(schema$additionalProperties)) {
            schema$additionalProperties
          } else {
            list()
          }
        if (is.null(child$type)) {
          child$type <- 'string'
        }
        fixture_value_sourced(child)
      })
      override <- setNames(lapply(children, `[[`, 'value'), keys)
      sources <- vapply(children, `[[`, character(1), 'source')
      source <- if (all(startsWith(sources, 'schema_'))) {
        'schema_example'
      } else {
        'synthesized'
      }
    }
    fixture <- if (missing(override)) {
      body_fixture_sourced(schema)
    } else {
      body_fixture_sourced(schema, override)
    }
    value <- fixture$value
    source <- source %or% fixture$source
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
    return(list(value = value, source = source))
  }
  if (identical(schema$type, 'array')) {
    fixture <- if (missing(override)) {
      body_fixture_sourced(schema)
    } else {
      body_fixture_sourced(schema, as.list(override))
    }
    value <- fixture$value
    source <- source %or% fixture$source
    value <- unlist(value, use.names = FALSE)
    if (!length(value)) {
      stop('Parameter fixture must be a nonempty array')
    }
    return(list(
      value = switch(
        schema$items$type,
        string = as.character(value),
        integer = as.integer(value),
        number = as.numeric(value),
        boolean = as.logical(value)
      ),
      source = source
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
    source <- paste0('schema_', selected[[1L]])
  }
  if (!missing(override) && is.null(override)) {
    if (
      (isTRUE(schema$nullable) || 'null' %in% schema$type) &&
        (is.null(schema$enum) || any(vapply(schema$enum, is.null, logical(1))))
    ) {
      return(list(value = NULL, source = source))
    }
    stop('Explicit null fixture is not nullable')
  }
  value <- if (!missing(override)) override else NULL
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
  list(value = value, source = source %or% 'synthesized')
}

# A parameter's value and source. Composed parameters take the first
# wire-shaped candidate the original accepts.
parameter_fixture_sourced <- function(p, override) {
  schema <- p$validation_schema
  if (is.null(schema)) {
    return(
      if (missing(override)) {
        fixture_value_sourced(p$schema)
      } else {
        list(value = fixture_value(p$schema, override), source = 'override')
      }
    )
  }
  check <- function(value) {
    parameter_values(
      list(value = value),
      list(value = schema),
      body_value,
      list(value = p$location)
    )
    value
  }
  if (!missing(override)) {
    return(list(value = check(override), source = 'override'))
  }
  # A null default or example is omission, not a fixture candidate.
  wire <- Filter(Negate(is.null), p$schema)
  wire$type <- wire$type[[1L]]
  first <- tryCatch(list(fixture_value_sourced(wire)), error = function(e) {
    list()
  })
  composed <- body_fixture_candidates(schema)
  values <- c(
    lapply(first, `[[`, 'value'),
    lapply(composed, function(x) {
      if (is.list(x) && is.null(names(x))) unlist(x, use.names = FALSE) else x
    })
  )
  sources <- c(
    vapply(first, `[[`, character(1), 'source'),
    attr(composed, 'sources')
  )
  for (i in seq_along(values)) {
    value <- values[[i]]
    if (
      !is.null(value) &&
        !inherits(try(check(value), silent = TRUE), 'try-error')
    ) {
      return(list(value = value, source = sources[[i]]))
    }
  }
  stop('No valid fixture: supply a reviewed override', call. = FALSE)
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
  lapply(
    operations,
    operation_fixture_inputs,
    overrides = overrides,
    mode = mode
  )
}

# One operation's inputs. `public` holds reviewed values keyed by public R
# name (a docs example), matched positionally so duplicate schema names stay
# distinct. Each input's source is recorded in attr(, 'input_sources').
operation_fixture_inputs <- function(
  op,
  overrides = list(),
  mode = 'default',
  public = list(),
  public_required = FALSE,
  defer_synthesis = FALSE
) {
  {
    omitted <- character()
    sources <- character()
    # Schema-level override keys stay 'body'; the wrapper argument may differ.
    body_argument <- body_argument_name(op)
    # Argument names come from the full list: leaving a parameter out must not
    # renumber duplicates (x, x.1) away from the wrapper's real arguments.
    public_names <- parameter_names(op$parameters)
    kept <- vapply(
      seq_along(op$parameters),
      function(i) {
        p <- op$parameters[[i]]
        # Scenarios follow the wrapper: client-located inputs keep their
        # public requiredness. operation_fixtures() keeps schema requiredness.
        required <- if (public_required) {
          p$public_required %or% p$required
        } else {
          p$required
        }
        keep <- mode != 'minimal' ||
          isTRUE(required) ||
          p$name %in% names(overrides[[op$name]]) ||
          public_names[[i]] %in% names(public)
        if (!keep) {
          omitted <<- c(omitted, p$name)
        }
        keep
      },
      logical(1)
    )
    parameters <- op$parameters[kept]
    inputs <- setNames(
      Map(
        function(p, name) {
          tryCatch(
            {
              fixture <- if (name %in% names(public)) {
                # Name the failed constraint, not only the missing fixture.
                parameter_values(
                  list(value = public[[name]]),
                  list(value = p$validation_schema %or% p$schema),
                  body_value,
                  list(value = p$location)
                )
                utils::modifyList(
                  parameter_fixture_sourced(p, public[[name]]),
                  list(source = 'docs_example')
                )
              } else if (p$name %in% names(overrides[[op$name]])) {
                parameter_fixture_sourced(p, overrides[[op$name]][[p$name]])
              } else if ('example' %in% names(p$example)) {
                utils::modifyList(
                  parameter_fixture_sourced(p, p$example$example),
                  list(source = 'parameter_example')
                )
              } else {
                parameter_fixture_sourced(p)
              }
              value <- fixture$value
              sources[[name]] <<- fixture_source_label(fixture$source, value)
              if (
                p$location == 'query' &&
                  !isTRUE(p$allow_empty_value) &&
                  is.character(value) &&
                  any(!nzchar(value))
              ) {
                stop('Empty query parameter: ', p$name)
              }
              value
            },
            error = function(e) {
              problem <- Filter(
                function(d) {
                  identical(d$parameter, p$name) &&
                    identical(d$location, p$location)
                },
                fixture_diagnostics(op)
              )
              # Scenarios report an input no example could fill as a missing
              # example (including invalid schema examples, which a docs
              # example overrides). A type/enum contradiction still stops.
              if (
                defer_synthesis &&
                  !length(problem) &&
                  !name %in% names(public)
              ) {
                sources[[name]] <<- 'synthesized'
                return(NULL)
              }
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
        },
        parameters,
        public_names[kept]
      ),
      public_names[kept]
    )
    if (
      mode == 'minimal' &&
        !isTRUE(op$body_required) &&
        !'body' %in% names(overrides[[op$name]]) &&
        !body_argument %in% names(public) &&
        !is.null(op$body)
    ) {
      omitted <- c(omitted, 'body')
    } else if (!is.null(op$body)) {
      body_source <- NULL
      if (body_argument %in% names(public)) {
        overrides[[op$name]]['body'] <- list(public[[body_argument]])
        body_source <- 'docs_example'
      } else if ('body' %in% names(overrides[[op$name]])) {
        body_source <- 'override'
      }
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
            body_source <- 'media_example'
          }
          if (form_media(op$body_media)) {
            binary <- vapply(
              op$body$properties,
              function(field) {
                identical(field$format, 'binary') ||
                  identical(field$items$format, 'binary')
              },
              logical(1)
            )
            body_source <- body_source %or%
              if (any(binary)) {
                'synthesized'
              } else {
                body_fixture_sourced(op$body)$source
              }
            allow_empty <- identical(
              op$body_media,
              'application/x-www-form-urlencoded'
            )
            inputs[body_argument] <- list(
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
            body_source <- body_source %or% 'synthesized'
            inputs[body_argument] <- list(value)
          } else if ('body' %in% names(overrides[[op$name]])) {
            value <- overrides[[op$name]]$body
            if (
              identical(op$text_encoding, 'lines') &&
                grepl('^text/', op$body_media %or% '')
            ) {
              # Line bodies take a vector of lines and send them joined.
              body_fixture(
                op$body,
                text_value(value, 'lines', op$batch$max_items)
              )
            } else {
              value <- body_fixture(op$body, value)
            }
            inputs[body_argument] <- list(value)
          } else {
            fixture <- body_fixture_sourced(op$body)
            body_source <- fixture$source
            inputs[body_argument] <- list(fixture$value)
          }
          sources[[body_argument]] <- fixture_source_label(
            body_source,
            inputs[[body_argument]]
          )
        },
        error = function(e) {
          problem <- Filter(
            function(d) identical(d$location, 'body'),
            fixture_diagnostics(op)
          )
          if (
            defer_synthesis &&
              !length(problem) &&
              !body_argument %in% names(public)
          ) {
            sources[[body_argument]] <<- 'synthesized'
            return(invisible())
          }
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
    attr(inputs, 'input_sources') <- sources
    inputs
  }
}

# Swagger UI's 'string' placeholder is not a real example.
fixture_source_label <- function(source, value) {
  provided <- startsWith(source, 'schema_') ||
    source %in% c('parameter_example', 'media_example')
  if (
    provided &&
      is.character(value) &&
      length(value) &&
      all(value == 'string')
  ) {
    'schema_placeholder'
  } else {
    source
  }
}
