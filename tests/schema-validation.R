schema_validation_acceptance <- function() {
  workspace <- tempfile('schema-validation-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  schema <- file.path(workspace, 'schema.json')
  ok <- list('200' = list(description = 'OK'))
  make_schema <- function(defect = 'none', version = '3.0.3') {
    document <- list(
      openapi = version,
      info = list(title = 'api', version = '1'),
      paths = list(
        '/a.b~' = list(
          get = list(operationId = 'fetch', responses = ok),
          post = list(operationId = 'create', responses = ok)
        ),
        '/safe' = list(get = list(operationId = 'safe', responses = ok))
      )
    )
    if (defect == 'operation') {
      document$paths[['/a.b~']]$get$parameters <- list(list(name = 'q'))
    }
    if (defect == 'path') {
      document$paths[['/a.b~']]$parameters <- list(list(name = 'q'))
    }
    if (defect == 'component') {
      document$components <- list(schemas = list(Shared = list(type = 5L)))
    }
    if (defect == 'root') {
      document$info <- NULL
    }
    if (defect == 'schema_object') {
      document$components <- list(
        schemas = list(Shared = list(type = 'strng'))
      )
    }
    if (version == '2.0') {
      document$swagger <- document$openapi
      document$openapi <- NULL
    }
    jsonlite::write_json(document, schema, auto_unbox = TRUE, pretty = TRUE)
    invisible(document)
  }
  validate <- function() specmill::validate_schema(schema)
  error <- function(expr) {
    result <- tryCatch(force(expr), error = identity)
    stopifnot(inherits(result, 'error'))
    result
  }
  keys <- function(report) {
    unlist(lapply(report$findings, `[[`, 'keys'), use.names = FALSE)
  }
  scopes <- function(report) {
    vapply(report$findings, `[[`, character(1), 'scope')
  }

  for (version in c('2.0', '3.0.3', '3.1.0')) {
    make_schema(version = version)
    passed <- validate()
    stopifnot(
      passed$status == 'passed',
      !length(passed$findings),
      passed$schema_version == version,
      length(passed$operations) == 3L,
      identical(
        passed$source_sha256,
        digest::digest(file = schema, algo = 'sha256')
      )
    )
    make_schema('operation', version)
    operation <- validate()
    stopifnot(
      operation$status == 'invalid',
      all(scopes(operation) == 'operation'),
      identical(unique(keys(operation)), 'GET /a.b~')
    )
    make_schema('path', version)
    path <- validate()
    stopifnot(
      path$status == 'invalid',
      setequal(keys(path), c('GET /a.b~', 'POST /a.b~'))
    )
    make_schema('root', version)
    root_report <- validate()
    stopifnot(
      root_report$status == 'invalid',
      'document' %in% scopes(root_report)
    )
  }
  # Swagger 2.0 parameter errors come only from the location named by `in`.
  document <- make_schema(version = '2.0')
  document$paths[['/safe']]$get$parameters <- list(
    list(name = 'q', `in` = 'query', type = 'dict'),
    list(name = 'c', `in` = 'cookie', type = 'string'),
    list(name = 'b', `in` = 'body')
  )
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  located <- vapply(validate()$findings, `[[`, character(1), 'message')
  stopifnot(
    length(located) == 3L,
    any(grepl('parameters/0/type .*: string', located)),
    any(grepl(
      'parameters/1/in .*: body, header, formData, query, path',
      located
    )),
    any(grepl("parameters/2 must have required property 'schema'", located))
  )
  make_schema('component')
  stopifnot(all(scopes(validate()) == 'document'))
  stopifnot(length(validate()$findings) == 1L)
  # OAS 3.1 Schema Objects are checked against the JSON Schema 2020-12 dialect.
  make_schema('schema_object', '3.1.0')
  stopifnot(validate()$status == 'invalid')
  make_schema(version = '3.2.0')
  stopifnot(validate()$status == 'unsupported')

  document <- make_schema()
  document$components <- list(
    schemas = list(External = list('$ref' = 'sibling.json#/Value'))
  )
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  stopifnot(validate()$status == 'unsupported')
  writeLines('{', schema)
  stopifnot(validate()$status == 'invalid')
  writeLines('{"openapi": "3.0.3", "openapi": "3.0.3"}', schema)
  stopifnot(validate()$status == 'invalid')

  # Empty YAML maps and arrays must reach the validator as {} and [].
  yaml_file <- file.path(workspace, 'schema.yaml')
  writeLines(
    c(
      'openapi: 3.0.3',
      'info: {title: api, version: "1"}',
      'paths: {}',
      'tags: []',
      'x-map: {}'
    ),
    yaml_file
  )
  stopifnot(specmill::validate_schema(yaml_file)$status == 'passed')
  writeLines(
    c(
      'openapi: 3.0.3',
      'info: {title: api, version: "1"}',
      'paths: []'
    ),
    yaml_file
  )
  stopifnot(specmill::validate_schema(yaml_file)$status == 'invalid')

  root <- file.path(workspace, 'client')
  dir.create(root)
  dir.create(file.path(root, 'R'))
  writeLines('helper <- function(...) NULL', file.path(root, 'R/helper.R'))
  spec <- list(files = schema, helper = 'helper', documentation = FALSE)
  snapshot <- function() {
    tools::md5sum(list.files(
      root,
      full.names = TRUE,
      recursive = TRUE,
      all.files = TRUE
    ))
  }
  plan <- function(spec, validation = TRUE) {
    specmill::generate_client(
      root,
      spec,
      mode = 'plan',
      validation = validation
    )
  }
  make_schema()
  applied <- specmill::generate_client(root, spec, mode = 'apply')
  stopifnot(length(applied$operations) == 3L)
  specmill::generate_client(root, spec, mode = 'check')
  make_schema('operation')
  hashes <- snapshot()
  planned <- plan(spec)
  stopifnot(
    length(planned$operations) == 2L,
    any(vapply(
      planned$diagnostics,
      function(x) x$code == 'schema_validation_invalid',
      logical(1)
    )),
    identical(hashes, snapshot())
  )
  error(specmill::generate_client(root, spec, mode = 'apply'))
  stopifnot(identical(hashes, snapshot()))
  make_schema('path')
  stopifnot(length(plan(spec)$operations) == 1L)
  for (defect in c('component', 'root')) {
    make_schema(defect)
    blocked <- plan(spec)
    stopifnot(!length(blocked$operations), length(blocked$inventory) == 3L)
  }
  make_schema('schema_object', '3.1.0')
  stopifnot(!length(plan(spec)$operations))
  skipped <- plan(spec, FALSE)
  stopifnot(
    length(skipped$operations) == 3L,
    skipped$validation[[1L]]$status == 'skipped'
  )
  error(plan(spec, list(timeout = 1)))

  make_schema('operation')
  mapped <- spec
  mapped$operations <- list(
    'GET /a.b~' = list(implementation = 'existing', inputs = list())
  )
  mapped$policy <- list(names = list('GET /a.b~' = 'fetch'))
  stopifnot(!'fetch' %in% names(plan(mapped)$operations))
  mapped$policy$include <- 'GET /safe'
  mapped$policy$routes_overrides <- list(
    'GET /safe' = list(list(key = 'GET /a.b~', source = basename(schema)))
  )
  routed <- plan(mapped)
  stopifnot(!length(routed$operations), length(routed$diagnostics) > 0L)
  mapped$policy$routes_overrides <- NULL
  selected <- plan(mapped)
  stopifnot(!length(selected$diagnostics), length(selected$operations) == 1L)
  make_schema('component')
  stopifnot(length(plan(mapped)$diagnostics) > 0L)

  # Project configuration drives the default gate without a call-site opt-in.
  make_schema('operation')
  file.copy(schema, file.path(root, 'schema.json'))
  writeLines(
    c('config_version: 1', 'services: [api.yml]'),
    file.path(root, 'specmill.yml')
  )
  writeLines(
    c(
      'id: api',
      'schemas: {files: [schema.json]}',
      'helper: helper',
      'documentation: false'
    ),
    file.path(root, 'api.yml')
  )
  configured <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(
    configured$validation[[1L]]$status == 'invalid',
    length(configured$operations) == 2L,
    isTRUE(specmill::load_project(root)$validation)
  )
  writeLines(
    c('config_version: 1', 'services: [api.yml]', 'validation: false'),
    file.path(root, 'specmill.yml')
  )
  disabled <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  enabled <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan',
    validation = TRUE
  )
  stopifnot(
    disabled$validation[[1L]]$status == 'skipped',
    enabled$validation[[1L]]$status == 'invalid'
  )
  writeLines(
    c(
      'config_version: 1',
      'services: [api.yml]',
      'validation: {cache_dir: .cache}'
    ),
    file.path(root, 'specmill.yml')
  )
  error(specmill::load_project(root))
  cat(
    'Schema validation: Swagger 2.0, OpenAPI 3.0 and 3.1 findings, YAML and generation gate passed.\n'
  )
}
if (sys.nframe() == 0L) {
  schema_validation_acceptance()
}
