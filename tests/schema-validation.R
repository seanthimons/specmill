schema_validation_acceptance <- function() {
  workspace <- tempfile('schema-validation-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  port_file <- file.path(workspace, 'port')
  log_file <- file.path(workspace, 'requests')
  server <- callr::r_bg(
    function(port_file, log_file) {
      port <- httpuv::randomPort()
      http <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(request) {
          response <- function(text, status = 200L, headers = list()) {
            list(
              status = status,
              headers = c(list('Content-Type' = 'application/json'), headers),
              body = text
            )
          }
          if (endsWith(request$PATH_INFO, '/openapi.json')) {
            cat('metadata\n', file = log_file, append = TRUE)
            return(response('{"info":{"version":"2.1.9"}}'))
          }
          bytes <- request$rook.input$read()
          cat(
            request$CONTENT_TYPE,
            digest::digest(bytes, algo = 'sha256', serialize = FALSE),
            '\n',
            file = log_file,
            append = TRUE
          )
          document <- if (grepl('yaml', request$CONTENT_TYPE)) {
            yaml::yaml.load(rawToChar(bytes))
          } else {
            jsonlite::fromJSON(rawToChar(bytes), simplifyVector = FALSE)
          }
          title <- document$info$title
          legacy <- grepl(
            'legacyJsonSchemaValidation=true',
            request$QUERY_STRING
          )
          if (title == 'unavailable') {
            return(response('{"error":"sensitive upstream body"}', 503L))
          }
          if (title == 'redirect') {
            return(response(
              '{"schemaValidationMessages":[]}',
              302L,
              list(Location = '/other/debug')
            ))
          }
          if (title == 'timeout') {
            Sys.sleep(1)
          }
          if (title == 'malformed') {
            return(response('{}'))
          }
          if (title == 'bad-array') {
            return(response('{"schemaValidationMessages":{}}'))
          }
          if (title == 'unknown-level') {
            return(response(
              '{"schemaValidationMessages":[{"level":"fatal","message":"oops"}]}'
            ))
          }
          if (title == 'semantic') {
            return(response(
              '{"messages":["schema needs review"],"schemaValidationMessages":[]}'
            ))
          }
          if (title == 'modern' && !legacy) {
            return(response(
              '{"schemaValidationMessages":[{"level":"error","message":"unlocated error"}]}'
            ))
          }
          if (
            title %in% c('structured', 'path', 'component', 'root') && legacy
          ) {
            pointer <- switch(
              title,
              structured = '/paths/~1a.b~0/get/parameters/0',
              path = '/paths/~1a.b~0/parameters',
              component = '/components/schemas/Shared',
              root = ''
            )
            return(response(jsonlite::toJSON(
              list(
                schemaValidationMessages = list(list(
                  level = 'error',
                  message = 'invalid declaration',
                  instance = list(pointer = pointer)
                ))
              ),
              auto_unbox = TRUE
            )))
          }
          response('{"schemaValidationMessages":[]}')
        })
      )
      on.exit(http$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(50)
      }
    },
    list(port_file, log_file),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  for (i in seq_len(200L)) {
    if (file.exists(port_file)) {
      break
    }
    if (!server$is_alive()) {
      server$get_result()
    }
    Sys.sleep(0.025)
  }
  stopifnot(file.exists(port_file))
  url <- paste0('http://127.0.0.1:', readLines(port_file))
  cache <- file.path(workspace, 'cache')
  schema <- file.path(workspace, 'schema.json')
  make_schema <- function(title, version = '3.0.3') {
    document <- list(
      openapi = version,
      info = list(title = title, version = '1'),
      paths = list(
        '/a.b~' = list(
          get = list(
            operationId = 'fetch',
            responses = list('200' = list(description = 'OK'))
          ),
          post = list(
            operationId = 'create',
            responses = list('200' = list(description = 'OK'))
          )
        ),
        '/safe' = list(
          get = list(
            operationId = 'safe',
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    )
    jsonlite::write_json(document, schema, auto_unbox = TRUE, pretty = TRUE)
    invisible(document)
  }
  validate <- function(...) specmill::validate_schema(schema, url, cache, ...)
  requests <- function() {
    if (file.exists(log_file)) length(readLines(log_file)) else 0L
  }
  error <- function(expr) {
    result <- tryCatch(force(expr), error = identity)
    stopifnot(inherits(result, 'error'))
    result
  }
  make_schema('passed')
  first <- validate()
  stopifnot(
    first$status == 'passed',
    !first$cached,
    requests() == 3L,
    identical(
      first$source_sha256,
      digest::digest(file = schema, algo = 'sha256')
    )
  )
  stopifnot(validate()$cached, requests() == 3L)
  validate(refresh = TRUE)
  stopifnot(requests() == 6L)
  different <- specmill::validate_schema(schema, paste0(url, '/other'), cache)
  stopifnot(different$status == 'passed', !different$cached, requests() == 9L)
  cache_file <- file.path(cache, paste0(first$identity, '.json'))
  cached <- jsonlite::read_json(cache_file)
  cached$responses$modern <- list(
    messages = list('cached error'),
    schemaValidationMessages = list()
  )
  cached$status <- 'passed'
  jsonlite::write_json(cached, cache_file, auto_unbox = TRUE, null = 'null')
  stopifnot(validate()$status == 'invalid', requests() == 9L)
  writeLines('{', cache_file)
  stopifnot(validate()$status == 'passed', requests() == 12L)
  make_schema('semantic')
  semantic <- validate()
  stopifnot(
    semantic$status == 'invalid',
    semantic$findings[[1L]]$scope == 'document'
  )
  make_schema('structured')
  structured <- validate()
  stopifnot(
    structured$status == 'invalid',
    identical(structured$findings[[1L]]$keys, list('GET /a.b~'))
  )
  make_schema('root')
  stopifnot(validate()$findings[[1L]]$scope == 'document')
  make_schema('passed', '3.1.0')
  stopifnot(validate()$status == 'unsupported')
  make_schema('passed', '2.0')
  document <- jsonlite::read_json(schema)
  document$swagger <- document$openapi
  document$openapi <- NULL
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  swagger <- validate()
  stopifnot(
    swagger$status == 'passed',
    identical(names(swagger$responses), 'modern')
  )
  for (title in c(
    'unavailable',
    'malformed',
    'bad-array',
    'unknown-level',
    'redirect'
  )) {
    make_schema(title)
    count <- requests()
    failed <- validate()
    stopifnot(
      failed$status == 'unverified',
      !grepl('sensitive', failed$reason),
      !file.exists(file.path(cache, paste0(failed$identity, '.json')))
    )
    validate()
    stopifnot(requests() > count)
  }
  make_schema('timeout')
  stopifnot(validate(timeout = 0.1)$status == 'unverified')
  before <- requests()
  writeLines('{', schema)
  stopifnot(validate()$status == 'invalid', requests() == before)
  document <- make_schema('passed')
  document$components <- list(
    schemas = list(External = list('$ref' = 'sibling.json#/Value'))
  )
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  stopifnot(validate()$status == 'unsupported', requests() == before)
  document$components <- list(
    schemas = list(
      Value = list(
        type = 'object',
        properties = list(example = list('$ref' = 'sibling.json#/Value'))
      )
    )
  )
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  stopifnot(validate()$status == 'unsupported', requests() == before)
  error(specmill::validate_schema(
    schema,
    'https://user:password@example.org/validator'
  ))
  error(validate(timeout = Inf))

  # The transport must preserve YAML bytes, including empty maps and arrays.
  yaml_file <- file.path(workspace, 'schema.yaml')
  writeLines(
    c(
      'openapi: 3.0.3',
      'info: {title: passed, version: "1"}',
      'paths: {}',
      'x-map: {}',
      'x-array: []'
    ),
    yaml_file
  )
  yaml_report <- specmill::validate_schema(yaml_file, url, cache)
  stopifnot(
    yaml_report$status == 'passed',
    any(grepl(
      paste0('application/yaml ', yaml_report$source_sha256),
      readLines(log_file),
      fixed = TRUE
    ))
  )

  root <- file.path(workspace, 'client')
  dir.create(root)
  dir.create(file.path(root, 'R'))
  writeLines('helper <- function(...) NULL', file.path(root, 'R/helper.R'))
  spec <- list(files = schema, helper = 'helper', documentation = FALSE)
  policy <- list(validator_url = url, cache_dir = cache)
  document <- make_schema('passed')
  document[['x-generation-check']] <- TRUE
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  before <- requests()
  applied <- specmill::generate_client(
    root,
    spec,
    mode = 'apply',
    validation = policy
  )
  stopifnot(length(applied$operations) == 3L)
  count <- requests()
  specmill::generate_client(root, spec, mode = 'check', validation = policy)
  stopifnot(count > before, requests() == count)
  make_schema('structured')
  hashes <- tools::md5sum(list.files(
    root,
    full.names = TRUE,
    recursive = TRUE,
    all.files = TRUE
  ))
  plan <- specmill::generate_client(
    root,
    spec,
    mode = 'plan',
    validation = policy
  )
  stopifnot(
    length(plan$operations) == 2L,
    any(vapply(
      plan$diagnostics,
      function(x) x$code == 'schema_validation_invalid',
      logical(1)
    )),
    identical(
      hashes,
      tools::md5sum(list.files(
        root,
        full.names = TRUE,
        recursive = TRUE,
        all.files = TRUE
      ))
    )
  )
  error(specmill::generate_client(
    root,
    spec,
    mode = 'apply',
    validation = policy
  ))
  stopifnot(identical(
    hashes,
    tools::md5sum(list.files(
      root,
      full.names = TRUE,
      recursive = TRUE,
      all.files = TRUE
    ))
  ))
  make_schema('path')
  stopifnot(
    length(
      specmill::generate_client(
        root,
        spec,
        mode = 'plan',
        validation = policy
      )$operations
    ) ==
      1L
  )
  for (title in c('component', 'modern', 'semantic')) {
    make_schema(title)
    plan <- specmill::generate_client(
      root,
      spec,
      mode = 'plan',
      validation = policy
    )
    stopifnot(!length(plan$operations), length(plan$inventory) == 3L)
  }
  make_schema('passed', '3.1.0')
  stopifnot(
    !length(
      specmill::generate_client(
        root,
        spec,
        mode = 'plan',
        validation = policy
      )$operations
    )
  )
  count <- requests()
  skipped <- specmill::generate_client(
    root,
    spec,
    mode = 'plan',
    validation = FALSE
  )
  stopifnot(
    length(skipped$operations) == 3L,
    skipped$validation[[1L]]$status == 'skipped',
    requests() == count
  )
  make_schema('structured')
  mapped <- spec
  mapped$operations <- list(
    'GET /a.b~' = list(implementation = 'existing', inputs = list())
  )
  mapped$policy <- list(names = list('GET /a.b~' = 'fetch'))
  stopifnot(
    !'fetch' %in%
      names(
        specmill::generate_client(
          root,
          mapped,
          mode = 'plan',
          validation = policy
        )$operations
      )
  )
  mapped$policy$include <- 'GET /safe'
  mapped$policy$routes_overrides <- list(
    'GET /safe' = list(list(
      key = 'GET /a.b~',
      source = basename(schema)
    ))
  )
  routed <- specmill::generate_client(
    root,
    mapped,
    mode = 'plan',
    validation = policy
  )
  stopifnot(!length(routed$operations), length(routed$diagnostics) > 0L)
  mapped$policy$routes_overrides <- NULL
  selected <- specmill::generate_client(
    root,
    mapped,
    mode = 'plan',
    validation = policy
  )
  stopifnot(!length(selected$diagnostics), length(selected$operations) == 1L)
  make_schema('semantic')
  stopifnot(
    length(
      specmill::generate_client(
        root,
        mapped,
        mode = 'plan',
        validation = policy
      )$diagnostics
    ) >
      0L
  )

  # Project configuration drives the default gate without a call-site opt-in.
  make_schema('passed')
  file.copy(schema, file.path(root, 'schema.json'))
  writeLines(
    c(
      'config_version: 1',
      'services: [api.yml]',
      'validation:',
      paste0('  validator_url: ', url),
      paste0('  cache_dir: ', cache)
    ),
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
    configured$validation[[1L]]$status == 'passed',
    length(configured$operations) == 3L
  )
  count <- requests()
  enabled <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan',
    validation = TRUE
  )
  override <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan',
    validation = list(timeout = 1)
  )
  stopifnot(
    enabled$validation[[1L]]$validator_url == url,
    override$validation[[1L]]$validator_url == url,
    requests() == count
  )
  writeLines(
    c('config_version: 1', 'services: [api.yml]', 'validation: false'),
    file.path(root, 'specmill.yml')
  )
  stopifnot(
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'plan'
    )$validation[[1L]]$status ==
      'skipped'
  )
  writeLines(
    c(
      'config_version: 1',
      'services: [api.yml]',
      'validation: {unknown: true}'
    ),
    file.path(root, 'specmill.yml')
  )
  error(specmill::load_project(root))
  writeLines(
    c(
      'config_version: 1',
      'services: [api.yml]',
      'validation: {cache_dir: .cache}'
    ),
    file.path(root, 'specmill.yml')
  )
  stopifnot(identical(
    specmill::load_project(root)$validation$cache_dir,
    file.path(root, '.cache')
  ))
  cat(
    'Schema validation: cache, failures, coverage, exact bytes and generation gate passed.\n'
  )
}
if (sys.nframe() == 0L) {
  schema_validation_acceptance()
}
