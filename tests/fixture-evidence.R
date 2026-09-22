fixture_evidence_acceptance <- function() {
  file <- tempfile(fileext = '.json')
  on.exit(unlink(file))
  parameter <- list(
    name = 'range',
    'in' = 'path',
    required = TRUE,
    example = '0:10',
    schema = list(type = 'string', pattern = '^[0-9]+:[0-9]+$', example = '1:2')
  )
  read <- function(p = parameter, version = '3.0.3', ref = FALSE) {
    document <- list(
      openapi = version,
      info = list(title = 'Evidence', version = '1'),
      paths = list(
        '/{range}' = list(
          get = list(
            operationId = 'sample',
            parameters = list(p),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    )
    if (p[['in']] != 'path') {
      names(document$paths) <- '/sample'
    }
    if (ref) {
      document$components <- list(parameters = list(Range = p))
      document$paths[[1L]]$get$parameters <- list(list(
        '$ref' = '#/components/parameters/Range'
      ))
    }
    jsonlite::write_json(document, file, auto_unbox = TRUE, null = 'null')
    specmill::read_operations(file)
  }
  inputs <- function(parsed, ...) {
    specmill::operation_fixtures(parsed$operations, ...)[[1L]]
  }
  fails <- function(expr, code = 'fixture_synthesis') {
    e <- tryCatch(expr, error = identity)
    stopifnot(inherits(e, 'error'), identical(e$code, code))
    e
  }
  parsed <- read()
  stopifnot(
    inputs(parsed)$range == '0:10',
    inputs(parsed, list(sample = list(range = '3:4')))$range == '3:4'
  )
  runtime <- new.env(parent = baseenv())
  runtime$request <- function(...) list(...)
  eval(
    parse(
      text = specmill::render_operation(
        parsed$operations[[1L]],
        list(helper = 'request')
      )
    ),
    runtime
  )
  stopifnot(identical(formals(runtime$sample)$range, quote(expr = )))
  parameter$example <- 'invalid'
  fails(inputs(read()))
  fails(inputs(read(), list(sample = list(range = 'invalid'))))
  parameter$example <- NULL
  stopifnot(inputs(read())$range == '1:2')
  parameter <- list(
    name = 'value',
    'in' = 'query',
    required = FALSE,
    schema = list(type = 'number', enum = list('2', '3'))
  )
  parsed <- read(parameter, ref = TRUE)
  stopifnot(
    length(parsed$operations) == 1L,
    !length(parsed$diagnostics),
    parsed$fixture_diagnostics[[1L]]$source_location ==
      '#/components/parameters/Range/schema/enum',
    !parsed$fixture_diagnostics[[1L]]$required
  )
  fails(inputs(parsed), 'type_enum_contradiction')
  minimal <- inputs(parsed, mode = 'minimal')
  stopifnot(
    !length(minimal),
    identical(attr(minimal, 'omitted_inputs'), 'value')
  )
  fails(
    inputs(parsed, list(sample = list(value = 2)), mode = 'minimal'),
    'type_enum_contradiction'
  )
  parameter$schema$enum <- list('2', 3)
  stopifnot(inputs(read(parameter))$value == 3)
  for (value in list(FALSE, 0, '')) {
    parameter$schema <- list(
      type = if (is.logical(value)) {
        'boolean'
      } else if (is.numeric(value)) {
        'number'
      } else {
        'string'
      }
    )
    parameter['example'] <- list(value)
    stopifnot(isTRUE(all.equal(inputs(read(parameter))$value, value)))
  }
  parameter$schema <- list(type = 'string', nullable = TRUE)
  parameter['example'] <- list(NULL)
  stopifnot(
    'value' %in% names(inputs(read(parameter))),
    is.null(inputs(read(parameter))$value)
  )
  fails(inputs(read(parameter, version = '3.1.0')))
  # Swagger reference and inline contradictions retain their source location.
  for (ref in c(FALSE, TRUE)) {
    p <- list(
      name = 'value',
      'in' = 'query',
      required = TRUE,
      type = 'number',
      enum = list('2')
    )
    document <- list(
      swagger = '2.0',
      info = list(title = 'Swagger', version = '1'),
      parameters = list(Value = p),
      paths = list(
        '/sample' = list(
          get = list(
            operationId = 'sample',
            parameters = list(
              if (ref) list('$ref' = '#/parameters/Value') else p
            ),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    )
    jsonlite::write_json(document, file, auto_unbox = TRUE)
    parsed <- specmill::read_operations(file)
    stopifnot(
      parsed$fixture_diagnostics[[1L]]$required,
      parsed$fixture_diagnostics[[1L]]$source_location ==
        if (ref) {
          '#/parameters/Value/enum'
        } else {
          '#/paths/~1sample/get/parameters/0/enum'
        }
    )
    fails(inputs(parsed), 'type_enum_contradiction')
  }
  # Media evidence outranks schema evidence and is validated without fallback.
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'Media', version = '1'),
    paths = list(
      '/sample' = list(
        post = list(
          operationId = 'sample',
          requestBody = list(
            required = TRUE,
            content = list(
              'application/json' = list(
                example = 'media',
                schema = list(type = 'string', example = 'schema')
              )
            )
          ),
          responses = list('200' = list(description = 'OK'))
        )
      )
    )
  )
  jsonlite::write_json(document, file, auto_unbox = TRUE)
  stopifnot(inputs(specmill::read_operations(file))$body == 'media')
  document$paths[[1L]]$post$requestBody$content[[1L]]$example <- 2
  jsonlite::write_json(document, file, auto_unbox = TRUE)
  fails(inputs(specmill::read_operations(file)))
  document$paths[[1L]]$post$requestBody$content[[1L]] <- list(
    schema = list(
      type = 'object',
      required = list('needed'),
      properties = list(
        needed = list(type = 'string'),
        optional = list(type = 'number', enum = list('2'))
      )
    )
  )
  jsonlite::write_json(document, file, auto_unbox = TRUE)
  parsed <- specmill::read_operations(file)
  fails(inputs(parsed), 'type_enum_contradiction')
  minimal <- inputs(parsed, mode = 'minimal')
  stopifnot(
    identical(names(minimal$body), 'needed'),
    'body.optional' %in% attr(minimal, 'omitted_inputs')
  )
  cat(
    'Fixture evidence precedence, contradictions, minimal coverage and public defaults passed.\n'
  )
}
if (sys.nframe() == 0L) {
  fixture_evidence_acceptance()
}
