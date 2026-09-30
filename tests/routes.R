routes_acceptance <- function() {
  root <- tempfile('routes-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  fixture <- system.file('catalogue', package = 'specmill', mustWork = TRUE)
  stopifnot(all(file.copy(
    list.files(fixture, full.names = TRUE),
    root,
    recursive = TRUE
  )))
  dir.create(file.path(root, 'schemas'))
  schema <- function(
    path,
    id,
    server = 'https://routes.invalid',
    media = NULL,
    method = 'get'
  ) {
    operation <- list(
      operationId = id,
      responses = list('200' = list(description = 'OK'))
    )
    if (!is.null(media)) {
      operation$requestBody <- list(
        content = stats::setNames(
          list(list(schema = list(type = 'string'))),
          media
        )
      )
    }
    list(
      openapi = '3.0.3',
      info = list(title = 'Routes', version = '1'),
      servers = list(list(url = server)),
      paths = stats::setNames(
        list(stats::setNames(list(operation), method)),
        path
      )
    )
  }
  write_schema <- function(document, file) {
    jsonlite::write_json(document, file.path(root, file), auto_unbox = TRUE)
  }
  write_schema(schema('/api/descriptors', 'descriptors'), 'schema.json')
  write_schema(schema('/api/rdkit', 'rdkit'), 'schemas/rdkit.json')
  writeLines(
    c('config_version: 1', 'services: [service.yml]'),
    file.path(root, 'specmill.yml')
  )
  writeLines(
    c(
      'route_request <- function(method, endpoint, server) list(method = method, endpoint = endpoint, server = server)',
      'other_request <- route_request',
      'choose_route <- function(state) {',
      '  state$request <- list(method = "GET", endpoint = if (state$params$fallback) "/api/rdkit" else "/api/descriptors",',
      '    server = "https://routes.invalid")',
      '  state',
      '}',
      'hook_config <- list(descriptors = list(pre_request = "choose_route"))',
      'run_hook <- function(fn, stage, state) {',
      '  for (name in hook_config[[fn]][[stage]]) state <- get(name, envir = environment(run_hook))(state)',
      '  state',
      '}'
    ),
    file.path(root, 'R/helper.R')
  )
  service <- function(
    routes = "      - 'rdkit.json GET /api/rdkit'",
    extra = character(),
    files = 'schema.json, schemas/rdkit.json'
  ) {
    writeLines(
      c(
        'id: s',
        paste0('schemas: {files: [', files, ']}'),
        'helper: route_request',
        'documentation: true',
        'selection: {include: [GET /api/descriptors]}',
        'hooks: {descriptors: {pre_request: [choose_route]}}',
        'operations:',
        '  GET /api/descriptors:',
        '    extra_parameters: {fallback: {type: logical, default: false}}',
        '    request:',
        '      arguments:',
        '        endpoint: {from: [hook_state, request, endpoint]}',
        '        method: {from: [hook_state, request, method]}',
        '        server: {from: [hook_state, request, server]}',
        if (length(routes)) c('    routes:', routes),
        extra
      ),
      file.path(root, 'service.yml')
    )
  }
  fails <- function(pattern) {
    error <- tryCatch(specmill::load_project(root), error = identity)
    stopifnot(
      inherits(error, 'error'),
      grepl(pattern, conditionMessage(error), fixed = TRUE)
    )
  }
  service()
  project <- specmill::load_project(root)
  parsed <- specmill::read_operations(
    project$services$s$files,
    project$services$s[['policy']]
  )
  routes <- parsed$operations[[1L]]$routes
  stopifnot(
    length(routes) == 2L,
    identical(
      vapply(routes, `[[`, character(1), 'key'),
      c('GET /api/descriptors', 'GET /api/rdkit')
    ),
    identical(
      vapply(routes, `[[`, character(1), 'source'),
      c('schema.json', 'schemas/rdkit.json')
    ),
    identical(parsed$inventory[[1L]]$routes, routes),
    is.null(parsed$inventory[[2L]]$routes)
  )
  plan <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  manifest <- jsonlite::read_json(file.path(root, '.specmill/manifest.json'))
  stopifnot(
    identical(
      manifest$files[['R/descriptors.R']]$routes[['s GET /api/descriptors']],
      routes
    ),
    identical(
      manifest$files[['man/descriptors.Rd']]$routes[['s GET /api/descriptors']],
      routes
    ),
    identical(
      manifest$files[['R/descriptors.R']]$operations,
      's GET /api/descriptors'
    ),
    identical(plan$inventory[[1L]]$routes, routes)
  )
  env <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, env)
  }
  stopifnot(
    identical(env$descriptors()$endpoint, '/api/descriptors'),
    identical(env$descriptors(fallback = TRUE)$endpoint, '/api/rdkit')
  )
  specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
  # Explicit root-relative references resolve to the same record.
  service("      - 'schemas/rdkit.json GET /api/rdkit'")
  stopifnot(identical(
    specmill::load_project(root)$services$s[['policy']][['routes_overrides']][[
      1L
    ]],
    routes
  ))
  service("      - 'rdkit.json GET /api/unknown'")
  fails('unknown or unparseable route')
  service("      - 'missing.json GET /api/rdkit'")
  fails('one loaded service file')
  service(extra = c('  GET /api/rdkit:', '    helper: other_request'))
  fails('helper')
  service()
  write_schema(
    schema('/api/rdkit', 'rdkit', server = 'https://other.invalid'),
    'schemas/rdkit.json'
  )
  fails('server')
  write_schema(
    schema('/api/rdkit', 'rdkit', server = '/'),
    'schemas/rdkit.json'
  )
  fails('server')
  service("      - 'rdkit.json POST /api/rdkit'")
  write_schema(
    schema('/api/rdkit', 'rdkit', media = 'application/json', method = 'post'),
    'schemas/rdkit.json'
  )
  fails('body_media')
  service()
  write_schema(schema('/api/rdkit', 'rdkit'), 'schemas/rdkit.json')
  service(c(
    "      - 'rdkit.json GET /api/rdkit'",
    "      - 'rdkit.json GET /api/rdkit'"
  ))
  fails('unique schema-file')
  service('      - GET /api/rdkit')
  fails('unique schema-file')
  service(extra = 'defaults: {routes: []}')
  fails('routes belongs under operations')
  dir.create(file.path(root, 'duplicate'))
  write_schema(schema('/api/rdkit', 'rdkit'), 'duplicate/rdkit.json')
  service(files = 'schema.json, schemas/rdkit.json, duplicate/rdkit.json')
  fails('one loaded service file')
  service(
    "      - 'schemas/rdkit.json GET /api/rdkit'",
    files = 'schema.json, schemas/rdkit.json, duplicate/rdkit.json'
  )
  specmill::load_project(root)
  # Loaded in another service is insufficient.
  service(files = 'schema.json')
  writeLines(
    c(
      'id: other',
      'schemas: {files: [schemas/rdkit.json]}',
      'helper: route_request'
    ),
    file.path(root, 'other.yml')
  )
  writeLines(
    c('config_version: 1', 'services: [service.yml, other.yml]'),
    file.path(root, 'specmill.yml')
  )
  fails('one loaded service file')
  writeLines(
    c('config_version: 1', 'services: [service.yml]'),
    file.path(root, 'specmill.yml')
  )
  service(routes = character())
  warnings <- character()
  project <- withCallingHandlers(
    specmill::load_project(root),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart('muffleWarning')
    }
  )
  stopifnot(
    length(warnings) == 1L,
    grepl(
      'hook-bound endpoint or method has no declared routes',
      warnings,
      fixed = TRUE
    )
  )
  parsed <- specmill::read_operations(
    project$services$s$files,
    project$services$s[['policy']]
  )
  stopifnot(
    is.null(parsed$operations[[1L]]$routes),
    is.null(parsed$inventory[[1L]]$routes)
  )
  # Removing declarations clears provenance only for the artifacts being applied.
  suppressWarnings(specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply',
    artifacts = 'wrappers'
  ))
  manifest <- jsonlite::read_json(file.path(root, '.specmill/manifest.json'))
  stopifnot(
    is.null(manifest$files[['R/descriptors.R']]$routes),
    identical(
      manifest$files[['man/descriptors.Rd']]$routes[['s GET /api/descriptors']],
      routes
    )
  )
  # Either route selector alone still requires a declaration; server alone does not.
  for (field in c('endpoint', 'method', 'server')) {
    service(routes = character())
    file <- file.path(root, 'service.yml')
    lines <- readLines(file)
    bindings <- c(
      '        endpoint: {value: /api/descriptors}',
      '        method: {value: GET}',
      '        server: {value: https://routes.invalid}'
    )
    for (binding in bindings[
      !startsWith(trimws(bindings), paste0(field, ':'))
    ]) {
      name <- sub(':.*$', '', trimws(binding))
      lines[startsWith(trimws(lines), paste0(name, ':'))] <- binding
    }
    writeLines(lines, file)
    warnings <- character()
    withCallingHandlers(specmill::load_project(root), warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart('muffleWarning')
    })
    stopifnot(length(warnings) == as.integer(field != 'server'))
  }
  cat(
    'Declared routes: cross-schema inventory, provenance, compatibility and warnings passed.\n'
  )
}
if (sys.nframe() == 0L) {
  routes_acceptance()
}
