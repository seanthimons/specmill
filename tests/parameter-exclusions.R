parameter_exclusions_acceptance <- function() {
  # GH #59: Springdoc folds the multipart upload variant into JSON operations
  # as binary/object query parameters. Service config drops them per operation.
  folded <- function(operation_id) {
    list(
      operationId = operation_id,
      parameters = list(
        list(
          name = 'files[]',
          `in` = 'query',
          schema = list(
            type = 'array',
            items = list(type = 'string', format = 'binary')
          )
        ),
        list(name = 'request', `in` = 'query', schema = list(type = 'object')),
        list(name = 'mode', `in` = 'query', schema = list(type = 'string'))
      ),
      requestBody = list(
        required = TRUE,
        content = list(
          'application/json' = list(
            schema = list(
              type = 'object',
              properties = list(
                chemicals = list(
                  type = 'array',
                  items = list(type = 'string')
                )
              )
            )
          )
        )
      ),
      responses = list('200' = list(description = 'OK'))
    )
  }
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'Springdoc', version = '1'),
    paths = list(
      '/api/hazard' = list(post = folded('hazard')),
      '/api/alerts' = list(post = folded('alerts')),
      '/api/upload' = list(
        post = list(
          operationId = 'upload',
          requestBody = list(
            content = list(
              'multipart/form-data' = list(
                schema = list(
                  type = 'object',
                  properties = list(
                    file = list(type = 'string', format = 'binary')
                  )
                )
              )
            )
          ),
          responses = list('200' = list(description = 'OK'))
        )
      )
    )
  )
  root <- tempfile('parameter-exclusions-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  schema <- file.path(root, 'schema.json')
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  read <- function(exclusions = list()) {
    specmill::read_operations(
      schema,
      list(exclude_parameters_overrides = exclusions)
    )
  }
  `%or%` <- function(x, y) if (is.null(x)) y else x
  codes <- function(parsed) {
    stats::setNames(
      vapply(parsed$diagnostics, function(x) x$code %or% '', character(1)),
      vapply(parsed$diagnostics, `[[`, character(1), 'key')
    )
  }

  # Without an exclusion the audit still blocks the folded parameters.
  stopifnot(identical(
    codes(read())[c('POST /api/hazard', 'POST /api/alerts')],
    c(
      'POST /api/hazard' = 'binary_parameter',
      'POST /api/alerts' = 'binary_parameter'
    )
  ))

  parsed <- read(list('POST /api/hazard' = c('files[]', 'request')))
  hazard <- Filter(function(x) x$key == 'POST /api/hazard', parsed$operations)
  record <- Filter(function(x) x$key == 'POST /api/hazard', parsed$inventory)
  upload <- Filter(function(x) x$key == 'POST /api/upload', parsed$operations)
  stopifnot(
    length(hazard) == 1L,
    identical(
      vapply(hazard[[1L]]$parameters, `[[`, character(1), 'name'),
      'mode'
    ),
    identical(hazard[[1L]]$excluded_parameters, c('files[]', 'request')),
    identical(record[[1L]]$excluded_parameters, c('files[]', 'request')),
    # Only listed operations change; unlisted folded parameters stay blocked.
    identical(codes(parsed)[['POST /api/alerts']], 'binary_parameter'),
    # Real uploads are request bodies and never need an exclusion.
    length(upload) == 1L,
    identical(upload[[1L]]$body_media, 'multipart/form-data')
  )

  fails <- function(exclusions, pattern) {
    error <- tryCatch(read(exclusions), error = identity)
    stopifnot(
      inherits(error, 'error'),
      grepl(pattern, conditionMessage(error), fixed = TRUE)
    )
  }
  # A typo must not silently leave (or hide) a parameter.
  fails(
    list('POST /api/hazard' = c('files', 'request')),
    'POST /api/hazard: no schema parameter files'
  )
  fails(list('POST /api/nothing' = 'files[]'), 'Unknown operation override')

  # Service config: generated wrapper keeps the JSON body and drops the variant.
  file.copy(
    list.files(
      system.file('catalogue', package = 'specmill', mustWork = TRUE),
      full.names = TRUE
    ),
    root,
    recursive = TRUE,
    overwrite = FALSE
  )
  writeLines(
    c('config_version: 1', 'services: [service.yml]'),
    file.path(root, 'specmill.yml')
  )
  service <- function(settings) {
    writeLines(
      c(
        'id: s',
        'schemas: {files: [schema.json]}',
        'helper: catalogue_request',
        'selection: {include: [POST /api/hazard]}',
        settings
      ),
      file.path(root, 'service.yml')
    )
  }
  service('defaults: {exclude_parameters: [request]}')
  error <- tryCatch(specmill::load_project(root), error = identity)
  stopifnot(grepl(
    'exclude_parameters belongs under operations',
    conditionMessage(error)
  ))
  service(c(
    'operations:',
    '  POST /api/hazard:',
    '    exclude_parameters: ["files[]", request]'
  ))
  specmill::generate_client(
    validation = FALSE,
    root,
    config = 'specmill.yml',
    mode = 'apply',
    artifacts = 'wrappers'
  )
  env <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, env)
  }
  stopifnot(identical(names(formals(env$hazard)), c('mode', 'body')))
  env$hazard(body = list(chemicals = list('water')), mode = 'fast')
  call <- env$captured()[[1L]]
  stopifnot(
    identical(call$query, list(mode = 'fast')),
    identical(call$body, list(chemicals = list('water')))
  )
  cat(
    'Parameter exclusions: listed folded upload parameters dropped and recorded; others stay blocked.\n'
  )
}
if (sys.nframe() == 0L) {
  parameter_exclusions_acceptance()
}
