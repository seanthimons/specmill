path_diagnostics_acceptance <- function() {
  root <- tempfile('path-diagnostics-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  file <- file.path(root, 'schema.json')
  path <- '/api/amos/get_similar_structures/{identifier_type}/{identifier}'
  key <- paste('GET', path)
  pointer <- '#/paths/~1api~1amos~1get_similar_structures~1{identifier_type}~1{identifier}'
  parameter <- function(name) {
    list(name = name, 'in' = 'path', required = TRUE, type = 'string')
  }
  # Minimal AMOS declaration, without inventing the handler's contract.
  document <- list(
    swagger = '2.0',
    info = list(title = 'Path diagnostics', version = '1'),
    paths = setNames(
      list(list(
        get = list(
          operationId = 'similar',
          parameters = list(parameter('dtxsid')),
          responses = list('200' = list(description = 'OK'))
        )
      )),
      path
    )
  )
  document$paths[['/items/{id}']] <- list(
    get = list(
      operationId = 'item',
      parameters = list(parameter('id')),
      responses = list('200' = list(description = 'OK'))
    )
  )
  jsonlite::write_json(document, file, auto_unbox = TRUE)
  parsed <- specmill::read_operations(file, list(service = 'amos'))
  diagnostics <- parsed$diagnostics
  stopifnot(
    length(diagnostics) == 3L,
    identical(
      vapply(diagnostics, `[[`, '', 'code'),
      c(
        'unmatched_path_parameter',
        'missing_path_parameter',
        'missing_path_parameter'
      )
    ),
    identical(
      vapply(diagnostics, `[[`, '', 'reason'),
      c(
        'Unmatched path parameter: dtxsid',
        'Missing path parameter: identifier_type',
        'Missing path parameter: identifier'
      )
    ),
    identical(
      vapply(diagnostics, `[[`, '', 'source_location'),
      c(
        paste0(pointer, '/get/parameters/0'),
        pointer,
        pointer
      )
    ),
    all(vapply(
      diagnostics,
      function(x) {
        x$key == key &&
          x$id == paste('amos', key) &&
          x$source == file &&
          x$status == 'unsupported' &&
          x$classification == 'schema_defect'
      },
      logical(1)
    )),
    identical(names(parsed$operations), 'item'),
    !length(parsed$unsupported_operations),
    length(parsed$inventory) == 2L,
    parsed$inventory[[1L]]$reason == diagnostics[[1L]]$reason,
    parsed$inventory[[2L]]$status == 'selected'
  )
  # Reference targets, inherited parameters, and operation overrides keep locations.
  inherited <- document
  inherited$parameters <- list(Wrong = parameter('dtxsid'))
  inherited$paths[[path]]$parameters <- list(list(
    '$ref' = '#/parameters/Wrong'
  ))
  inherited$paths[[path]]$get$parameters <- NULL
  jsonlite::write_json(inherited, file, auto_unbox = TRUE)
  inherited_result <- specmill::read_operations(file)
  stopifnot(
    length(inherited_result$diagnostics) == 3L,
    inherited_result$diagnostics[[1L]]$source_location == '#/parameters/Wrong'
  )
  inherited$paths[[path]]$get$parameters <- list(
    parameter('dtxsid'),
    parameter('other')
  )
  jsonlite::write_json(inherited, file, auto_unbox = TRUE)
  overridden <- specmill::read_operations(file)$diagnostics
  stopifnot(
    length(overridden) == 4L,
    overridden[[1L]]$source_location == paste0(pointer, '/get/parameters/0'),
    overridden[[2L]]$reason == 'Unmatched path parameter: other',
    overridden[[2L]]$source_location == paste0(pointer, '/get/parameters/1')
  )
  # The same name consistency checks apply to OpenAPI 3 parameters.
  newer <- document
  newer$swagger <- NULL
  newer$openapi <- '3.0.3'
  for (route in names(newer$paths)) {
    p <- newer$paths[[route]]$get$parameters[[1L]]
    p$schema <- list(type = p$type)
    p$type <- NULL
    newer$paths[[route]]$get$parameters <- list(p)
  }
  jsonlite::write_json(newer, file, auto_unbox = TRUE)
  stopifnot(identical(
    specmill::read_operations(file, list(service = 'amos'))$diagnostics,
    diagnostics
  ))
  jsonlite::write_json(document, file, auto_unbox = TRUE)
  # Use existing generation APIs. A mixed selection must never partially apply.
  dir.create(file.path(root, 'R'))
  writeLines(
    'api_request <- function(method, path, path_params, query, body, server) NULL',
    file.path(root, 'R/api_request.R')
  )
  writeLines(
    c('config_version: 1', 'services: [amos.yml]'),
    file.path(root, 'specmill.yml')
  )
  service <- list(
    id = 'amos',
    schemas = list(files = list('schema.json')),
    helper = 'api_request'
  )
  yaml::write_yaml(service, file.path(root, 'amos.yml'))
  snapshot <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  before <- snapshot()
  plan <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(
    length(plan$diagnostics) == 3L,
    length(plan$operations) == 1L,
    identical(before, snapshot())
  )
  for (mode in c('check', 'apply')) {
    error <- tryCatch(
      specmill::generate_client(root, config = 'specmill.yml', mode = mode),
      error = identity
    )
    stopifnot(
      inherits(error, 'error'),
      grepl('Unsupported selected operations', conditionMessage(error)),
      identical(before, snapshot())
    )
  }
  service$selection <- list(include = list('GET /items/{id}'))
  yaml::write_yaml(service, file.path(root, 'amos.yml'))
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  checked <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'check'
  )
  stopifnot(
    !length(checked$diagnostics),
    file.exists(file.path(root, 'R/item.R')),
    !file.exists(file.path(root, 'R/similar.R'))
  )
  # Restoring the blocked selection preserves previously generated files too.
  service$selection <- NULL
  yaml::write_yaml(service, file.path(root, 'amos.yml'))
  before <- snapshot()
  error <- tryCatch(
    specmill::generate_client(root, config = 'specmill.yml', mode = 'apply'),
    error = identity
  )
  stopifnot(inherits(error, 'error'), identical(before, snapshot()))
  cat(
    'Path diagnostics: all contradictions, source pointers, valid route and atomic selection passed.\n'
  )
}
if (sys.nframe() == 0L) {
  path_diagnostics_acceptance()
}
