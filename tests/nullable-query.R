nullable_query_acceptance <- function() {
  source(
    if (file.exists('tests/native-transport.R')) {
      'tests/native-transport.R'
    } else {
      'native-transport.R'
    },
    local = TRUE
  )
  native_transport_acceptance(function(runtime, root) {
    file <- file.path(root, 'nullable.json')
    union <- function(scalar) list(anyOf = list(scalar, list(type = 'null')))
    document <- function(
      schema,
      required = FALSE,
      location = 'query',
      version = '3.1.0'
    ) {
      list(
        openapi = version,
        info = list(title = 'Nullable', version = '1'),
        paths = list(
          '/nullable' = list(
            get = list(
              operationId = 'nullable',
              parameters = list(list(
                name = 'q',
                'in' = location,
                required = required,
                schema = schema
              )),
              responses = list('200' = list(description = 'OK'))
            )
          )
        )
      )
    }
    parse_document <- function(doc) {
      jsonlite::write_json(doc, file, auto_unbox = TRUE, null = 'null')
      specmill::read_operations(file)
    }
    install <- function(schema, required = FALSE) {
      parsed <- parse_document(document(schema, required))
      stopifnot(!length(parsed$diagnostics), length(parsed$operations) == 1L)
      op <- parsed$operations[[1L]]
      # Preserve the union instead of dropping constraints during normalization.
      stopifnot(identical(
        op$parameters[[1L]]$validation_schema$anyOf,
        schema$anyOf
      ))
      eval(
        parse(
          text = specmill::render_operation(op, list(helper = 'api_request'))
        ),
        runtime
      )
      fixture <- specmill::operation_fixtures(parsed$operations)[[1L]]
      stopifnot(!is.null(fixture$q))
      do.call(runtime$nullable, fixture)
      invisible(parsed)
    }
    fails <- function(expr) {
      stopifnot(inherits(
        tryCatch(force(expr), error = identity),
        'error'
      ))
    }
    schema <- union(list(type = 'string', minLength = 2L, pattern = '^a'))
    schema$maxLength <- 5L
    schema$example <- 'abc'
    install(schema)
    stopifnot(
      runtime$nullable('a b')$query == '?q=a%20b',
      runtime$nullable()$query == '',
      runtime$nullable(NULL)$query == ''
    )
    before <- runtime$api_request('GET', '/probe', list(), list(), NULL)
    for (value in list(
      1L,
      TRUE,
      NA_character_,
      c('ab', 'ac'),
      '',
      'a',
      'bad',
      'abcdef'
    )) {
      fails(runtime$nullable(value))
    }
    after <- runtime$api_request('GET', '/probe', list(), list(), NULL)
    stopifnot(after$request_number == before$request_number + 1L)
    install(schema, required = TRUE)
    fails(runtime$nullable())
    fails(runtime$nullable(NULL))
    stopifnot(runtime$nullable('abc')$query == '?q=abc')
    schema$default <- 'abc'
    install(schema)
    stopifnot(
      runtime$nullable()$query == '?q=abc',
      runtime$nullable(NULL)$query == ''
    )
    plain <- union(list(type = 'string'))
    install(plain)
    fails(runtime$nullable(''))
    stopifnot(runtime$nullable('null')$query == '?q=null')
    empty <- document(plain)
    empty$paths[['/nullable']]$get$parameters[[1L]]$allowEmptyValue <- TRUE
    parsed <- parse_document(empty)
    eval(
      parse(
        text = specmill::render_operation(
          parsed$operations[[1L]],
          list(helper = 'api_request')
        )
      ),
      runtime
    )
    stopifnot(runtime$nullable('')$query == '?q=')
    for (case in list(
      list(
        schema = union(list(type = 'integer', minimum = 2L)),
        good = 2L,
        bad = 1L,
        wire = '?q=2'
      ),
      list(
        schema = union(list(type = 'number', maximum = 0.5)),
        good = 0.5,
        bad = 1,
        wire = '?q=0.5'
      ),
      list(
        schema = union(list(type = 'boolean')),
        good = TRUE,
        bad = 'true',
        wire = '?q=TRUE'
      ),
      list(
        schema = union(list(type = 'string', enum = list('abc'))),
        good = 'abc',
        bad = 'abd',
        wire = '?q=abc'
      )
    )) {
      install(case$schema)
      stopifnot(runtime$nullable(case$good)$query == case$wire)
      fails(runtime$nullable(case$bad))
    }
    reversed <- plain
    reversed$anyOf <- rev(reversed$anyOf)
    install(reversed)
    null_default <- plain
    null_default['default'] <- list(NULL)
    parsed <- install(null_default)
    stopifnot(runtime$nullable()$query == '')
    omitted_fixture <- specmill::operation_fixtures(
      parsed$operations,
      overrides = list(nullable = list(q = NULL))
    )[[1L]]
    stopifnot(is.null(omitted_fixture$q))
    referenced <- document(plain)
    referenced$components <- list(schemas = list(Nullable = plain))
    referenced$paths[['/nullable']]$get$parameters[[1L]]$schema <-
      list('$ref' = '#/components/schemas/Nullable')
    stopifnot(!length(parse_document(referenced)$diagnostics))
    # Other compositions are covered by tests/parameter-composition.R.
    for (doc in list(
      document(c(list(type = 'null'), plain)),
      document(plain, version = '3.0.3')
    )) {
      parsed <- parse_document(doc)
      stopifnot(
        length(parsed$operations) == 0L,
        length(parsed$diagnostics) > 0L
      )
    }
    unsupported <- plain
    unsupported$not <- list(type = 'string')
    parsed <- parse_document(document(unsupported))
    stopifnot(
      parsed$diagnostics[[1L]]$classification == 'capability_gap',
      grepl('/schema/not$', parsed$diagnostics[[1L]]$source_location)
    )
    cat(
      'Nullable queries: scalar constraints, defaults, omission, required inputs, fixtures and diagnostics passed.\n'
    )
  })
}

if (sys.nframe() == 0L) {
  nullable_query_acceptance()
}
