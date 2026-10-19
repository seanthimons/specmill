duplicate_response_overrides_acceptance <- function() {
  root <- tempfile('duplicate-responses-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  fixture <- system.file('catalogue', package = 'specmill', mustWork = TRUE)
  stopifnot(all(file.copy(
    list.files(fixture, full.names = TRUE),
    root,
    recursive = TRUE
  )))
  document <- function(media, parameter = 'id') {
    list(
      openapi = '3.0.3',
      info = list(title = 'Render', version = '1'),
      servers = list(list(url = 'https://render.invalid')),
      paths = list(
        '/render' = list(
          get = list(
            operationId = 'render',
            parameters = list(list(
              name = parameter,
              `in` = 'query',
              schema = list(type = 'string')
            )),
            responses = list(
              '200' = list(
                description = 'OK',
                content = stats::setNames(
                  list(
                    if (media == '*/*') {
                      list(schema = list(type = 'string'))
                    } else {
                      list(schema = list(type = 'string', format = 'binary'))
                    }
                  ),
                  media
                )
              )
            )
          )
        )
      )
    )
  }
  write_schema <- function(media, file, parameter = 'id') {
    jsonlite::write_json(
      document(media, parameter),
      file.path(root, file),
      auto_unbox = TRUE
    )
  }
  write_schema('image/png', 'alerts.json')
  write_schema('*/*', 'safety.json')
  files <- file.path(root, c('safety.json', 'alerts.json'))
  policy <- list(service = 'render', include = 'GET /render')
  fails <- function(expr, text) {
    error <- tryCatch(force(expr), error = identity)
    stopifnot(
      inherits(error, 'error'),
      grepl(text, conditionMessage(error), fixed = TRUE)
    )
  }
  fails(
    specmill::read_operations(files, policy),
    'Conflicting duplicate operation'
  )
  reviewed <- list(
    source = 'alerts.json',
    reason = 'Reviewed binary response declaration for the same request'
  )
  policy$duplicate_response_overrides <- list('GET /render' = reviewed)
  parsed <- specmill::read_operations(files, policy)
  selected <- parsed$operations[[1L]]
  stopifnot(
    length(parsed$operations) == 1L,
    selected$content_type == 'image/png',
    selected$response_schema_type == 'binary',
    basename(selected$source) == 'alerts.json',
    length(selected$response_sources$sources) == 2L,
    all(vapply(
      parsed$inventory,
      function(x) identical(x$response_sources, selected$response_sources),
      logical(1)
    ))
  )
  reverse <- specmill::read_operations(rev(files), policy)
  stopifnot(identical(reverse$operations[[1L]]$response, selected$response))
  policy$duplicate_response_overrides[['GET /render']]$source <- 'missing.json'
  fails(specmill::read_operations(files, policy), 'one loaded duplicate')
  policy$duplicate_response_overrides[['GET /render']] <- reviewed
  fails(
    specmill::read_operations(files[1L], policy),
    'requires a loaded duplicate'
  )
  policy$duplicate_response_overrides[['GET /render']]$reason <- ''
  fails(specmill::read_operations(files, policy), 'duplicate_response.reason')
  policy$duplicate_response_overrides[['GET /render']] <- reviewed
  write_schema('*/*', 'safety.json', 'other')
  fails(
    specmill::read_operations(files, policy),
    'Conflicting duplicate operation'
  )
  write_schema('*/*', 'safety.json')
  dir.create(file.path(root, 'schema'))
  stopifnot(all(file.copy(files, file.path(root, 'schema'))))
  writeLines(
    'api_request <- function(method, path, ...) list(method = method, path = path)',
    file.path(root, 'R/request.R')
  )
  writeLines(
    c('config_version: 1', 'services: [service.yml]'),
    file.path(root, 'specmill.yml')
  )
  writeLines(
    c(
      'id: render',
      'schemas: {files: [schema/safety.json, schema/alerts.json]}',
      'helper: api_request',
      'selection: {include: [GET /render]}',
      'operations:',
      '  GET /render:',
      '    duplicate_response:',
      '      source: alerts.json',
      '      reason: Reviewed binary response declaration for the same request'
    ),
    file.path(root, 'service.yml')
  )
  specmill::generate_client(
    validation = TRUE,
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  manifest <- jsonlite::read_json(file.path(root, '.specmill/manifest.json'))
  proof <- manifest$files[['R/render.R']]$response_sources[[
    'render GET /render'
  ]]
  stopifnot(
    identical(proof$selected, 'schema/alerts.json'),
    identical(
      vapply(proof$sources, `[[`, character(1), 'source'),
      c('schema/safety.json', 'schema/alerts.json')
    ),
    length(proof$sources) == 2L,
    identical(proof$reason, reviewed$reason)
  )
  specmill::generate_client(
    validation = TRUE,
    root,
    config = 'specmill.yml',
    mode = 'check'
  )
  relocated <- tempfile('duplicate-responses-relocated-')
  dir.create(relocated)
  on.exit(unlink(relocated, recursive = TRUE), add = TRUE)
  stopifnot(all(file.copy(
    list.files(root, all.files = TRUE, no.. = TRUE, full.names = TRUE),
    relocated,
    recursive = TRUE
  )))
  specmill::generate_client(
    validation = TRUE,
    relocated,
    config = 'specmill.yml',
    mode = 'check'
  )
  stopifnot(identical(
    readBin(file.path(root, '.specmill/manifest.json'), 'raw', n = 1e7),
    readBin(file.path(relocated, '.specmill/manifest.json'), 'raw', n = 1e7)
  ))
  cat(
    'Duplicate responses: explicit reviewed source, both source contracts/provenance, stable selection, request conflicts, missing source and validated freshness across checkout roots passed.\n'
  )
}
if (sys.nframe() == 0L) {
  duplicate_response_overrides_acceptance()
}
