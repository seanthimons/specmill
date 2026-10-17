security_correction_acceptance <- function() {
  workspace <- tempfile('security-correction-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  port_file <- file.path(workspace, 'port')
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          public <- identical(req$PATH_INFO, '/public')
          authorized <- public || identical(req$HTTP_X_API_KEY, 'fixture-key')
          list(
            status = if (authorized) 200L else 401L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(
              list(key = req$HTTP_X_API_KEY, path = req$PATH_INFO),
              auto_unbox = TRUE,
              null = 'null'
            )
          )
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file),
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
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  for (version in c('3.0.3', '3.1.0', '2.0')) {
    schema <- file.path(workspace, paste0(version, '.json'))
    operation <- list(
      operationId = 'lookup',
      parameters = list(list(name = 'dtxsid', `in` = 'path', required = TRUE)),
      responses = list('200' = list(description = 'OK'))
    )
    if (version == '2.0') {
      operation$parameters[[1L]]$type <- 'string'
    } else {
      operation$parameters[[1L]]$schema <- list(type = 'string')
    }
    public <- list(
      operationId = 'public',
      security = list(),
      responses = operation$responses
    )
    declared <- public
    declared$operationId <- 'declared'
    declared$security <- list(list(api_key = list()))
    document <- list(
      info = list(title = 'Reviewed security', version = '1'),
      paths = list(
        '/lookup/{dtxsid}' = list(get = operation),
        '/public' = list(get = public),
        '/declared' = list(get = declared)
      )
    )
    schemes <- list(
      api_key = list(type = 'apiKey', name = 'x-api-key', `in` = 'header')
    )
    if (version == '2.0') {
      document$swagger <- version
      document$securityDefinitions <- schemes
    } else {
      document$openapi <- version
      document$components <- list(securitySchemes = schemes)
    }
    jsonlite::write_json(document, schema, auto_unbox = TRUE)
    schema_hash <- tools::md5sum(schema)
    root <- file.path(workspace, paste0('client-', version))
    specmill::initialize_client(
      root,
      schema,
      package = 'correctedauth',
      title = 'Reviewed security',
      author = list(
        given = 'Test',
        family = 'Maintainer',
        email = 'test@example.org'
      ),
      license = 'MIT + file LICENSE',
      base_url = paste0('http://127.0.0.1:', readLines(port_file))
    )
    project <- yaml::read_yaml(file.path(root, 'specmill.yml'))
    withr::local_envvar(setNames('fixture-key', project$authentication$api_key))
    run <- function(mode = 'apply') {
      specmill::generate_client(
        root,
        config = 'specmill.yml',
        validation = FALSE,
        mode = mode
      )
    }
    load_runtime <- function() {
      runtime <- new.env(parent = baseenv())
      for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
        sys.source(file, runtime)
      }
      runtime
    }
    suppressWarnings(run())
    error <- tryCatch(load_runtime()$lookup('DTXSID7020182'), error = identity)
    stopifnot(inherits(error, 'error'), grepl('401', conditionMessage(error)))
    path <- file.path(root, 'apis', 'default.yml')
    service <- yaml::read_yaml(path, handlers = list(seq = identity))
    correction <- list(
      requirements = list(list(api_key = list())),
      reason = 'Reviewed endpoint requires the declared x-api-key credential.'
    )
    service$operations[['GET /lookup/{dtxsid}']] <- list(
      security_correction = correction
    )
    yaml::write_yaml(service, path)
    warnings <- character()
    plan <- withCallingHandlers(run(), warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart('muffleWarning')
    })
    runtime <- load_runtime()
    stopifnot(
      !length(warnings),
      !length(plan$diagnostics),
      identical(runtime$lookup('DTXSID7020182')$key, 'fixture-key'),
      identical(runtime$lookup('DTXSID7020182')$path, '/lookup/DTXSID7020182'),
      identical(runtime$declared()$key, 'fixture-key'),
      is.null(runtime$public()$key),
      identical(schema_hash, tools::md5sum(schema))
    )
    corrected <- Filter(
      function(op) identical(op$name, 'lookup'),
      plan$operations
    )[[1L]]
    stopifnot(
      identical(corrected$security_correction, correction),
      is.null(corrected$source_operation$security)
    )
    run('check')
    for (bad in list(
      list(
        requirements = list(list(unknown = list())),
        reason = 'Unknown scheme'
      ),
      list(requirements = list(list(api_key = list()))),
      list(
        requirements = list(api_key = list()),
        reason = 'Map instead of sequence'
      )
    )) {
      invalid <- service
      invalid$operations[['GET /lookup/{dtxsid}']]$security_correction <- bad
      yaml::write_yaml(invalid, path)
      stopifnot(inherits(try(run('plan'), silent = TRUE), 'try-error'))
    }
    service$defaults$security_correction <- correction
    yaml::write_yaml(service, path)
    stopifnot(inherits(try(run('plan'), silent = TRUE), 'try-error'))
  }
  cat(
    'Reviewed security: missing-schema 401 reproduced; corrected credentials, public sibling, provenance, freshness and invalid policy checks passed.\n'
  )
}
if (sys.nframe() == 0L) {
  security_correction_acceptance()
}
