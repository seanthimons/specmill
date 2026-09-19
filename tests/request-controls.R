request_controls_acceptance <- function() {
  root <- tempfile('controls-client-')
  schema <- tempfile(fileext = '.json')
  port_file <- tempfile('controls-port-')
  on.exit(unlink(c(root, schema, port_file), recursive = TRUE), add = TRUE)
  process <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      counts <- list()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          path <- req$PATH_INFO
          if (path == '/counts') {
            return(list(
              status = 200L,
              headers = list('Content-Type' = 'application/json'),
              body = jsonlite::toJSON(counts, auto_unbox = TRUE)
            ))
          }
          key <- paste(req$REQUEST_METHOD, path)
          counts[[key]] <<- if (is.null(counts[[key]])) {
            1L
          } else {
            counts[[key]] + 1L
          }
          n <- counts[[key]]
          if (path == '/timeout') {
            Sys.sleep(0.3)
          }
          status <- if (
            grepl('exhaust|decode', path) ||
              path == '/write' ||
              (grepl('recover|rate|after', path) && n < 3L)
          ) {
            if (grepl('rate', path)) 429L else 503L
          } else if (path == '/permanent') {
            400L
          } else {
            200L
          }
          if (path == '/decode' && n == 3L) {
            status <- 200L
          }
          headers <- list('Content-Type' = 'application/json')
          if (grepl('after', path)) {
            headers[['Retry-After']] <- '7'
          }
          body <- if (path == '/decode' && n == 3L) {
            '{"secret":"body-secret"'
          } else {
            jsonlite::toJSON(
              list(
                method = req$REQUEST_METHOD,
                path = path,
                query = req$QUERY_STRING,
                body = rawToChar(req$rook.input$read()),
                count = n,
                secret = 'body-secret'
              ),
              auto_unbox = TRUE
            )
          }
          list(status = status, headers = headers, body = body)
        })
      )
      on.exit(server$stop())
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file),
    supervise = TRUE
  )
  on.exit(process$kill(), add = TRUE)
  for (i in seq_len(200L)) {
    if (file.exists(port_file)) {
      break
    }
    if (!process$is_alive()) {
      process$get_result()
    }
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  origin <- paste0('http://127.0.0.1:', readLines(port_file))
  server <- function(url) list(list(url = url))
  op <- function(name) {
    list(operationId = name, responses = list('200' = list(description = 'OK')))
  }
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'Controls', version = '1'),
    servers = server(paste0(origin, '/root')),
    paths = list(
      '/root' = list(get = op('root_call')),
      '/path' = list(
        servers = server(paste0(origin, '/path')),
        get = op('path_call')
      ),
      '/operation' = list(
        servers = server('https://wrong.invalid'),
        get = c(
          op('operation_call'),
          list(servers = server(paste0(origin, '/operation')))
        )
      )
    )
  )
  document$paths[['/variable']] <- list(
    get = c(
      op('variable_call'),
      list(
        servers = list(list(
          url = paste0(origin, '/{version}'),
          variables = list(version = list(default = 'v2'))
        ))
      )
    )
  )
  write_schema <- function(x) {
    jsonlite::write_json(x, schema, auto_unbox = TRUE, null = 'null')
  }
  write_schema(document)
  parsed <- specmill::read_operations(schema)
  stopifnot(
    !length(parsed$server_diagnostics),
    identical(
      vapply(parsed$operations, function(x) x$server$url, ''),
      c(
        root_call = paste0(origin, '/root'),
        path_call = paste0(origin, '/path'),
        operation_call = paste0(origin, '/operation'),
        variable_call = paste0(origin, '/v2')
      )
    )
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'controlsclient',
    title = 'Controls Client',
    author = list(given = 'Test', family = 'User', email = 'test@example.org'),
    license = 'MIT'
  )
  helper <- file.path(root, 'R/api_request.R')
  hash <- tools::md5sum(helper)
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
  stopifnot(identical(hash, tools::md5sum(helper)))
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  for (name in names(parsed$operations)) {
    stopifnot(length(formals(runtime[[name]])) == 0L)
  }
  stopifnot(
    runtime$root_call()$path == '/root/root',
    runtime$path_call()$path == '/path/path',
    runtime$operation_call()$path == '/operation/operation',
    runtime$variable_call()$path == '/v2/variable'
  )
  override_root <- tempfile('controls-override-')
  on.exit(unlink(override_root, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    override_root,
    schema,
    package = 'overrideclient',
    title = 'Override Client',
    author = list(given = 'Test', family = 'User', email = 'test@example.org'),
    license = 'MIT',
    base_url = paste0(origin, '/initial')
  )
  override_runtime <- new.env(parent = baseenv())
  sys.source(file.path(override_root, 'R/api_request.R'), override_runtime)
  eval(
    parse(
      text = specmill::render_operation(
        parsed$operations$operation_call,
        list(helper = 'api_request')
      )
    ),
    override_runtime
  )
  stopifnot(override_runtime$operation_call()$path == '/initial/operation')
  previous_override <- options(
    overrideclient.request = list(base_url = paste0(origin, '/runtime'))
  )
  on.exit(options(previous_override), add = TRUE)
  stopifnot(override_runtime$operation_call()$path == '/runtime/operation')
  options(previous_override)
  old <- options(controlsclient.request = list(base_url = origin))
  on.exit(options(old), add = TRUE)
  stopifnot(runtime$operation_call()$path == '/operation')
  request <- function(path, method = 'GET', ...) {
    runtime$api_request(
      method,
      path,
      list(),
      list(api_key = 'query-secret'),
      if (method == 'POST') list(value = 1L) else NULL,
      headers = list(Authorization = 'Bearer header-secret'),
      ...
    )
  }
  error <- function(expr, pattern) {
    value <- tryCatch(force(expr), error = identity)
    stopifnot(
      inherits(value, 'error'),
      grepl(pattern, conditionMessage(value)),
      !grepl('query-secret|header-secret|body-secret', conditionMessage(value))
    )
    invisible(value)
  }
  counts <- function() {
    httr2::resp_body_json(httr2::req_perform(httr2::request(paste0(
      origin,
      '/counts'
    ))))
  }
  before <- counts()
  for (value in list(
    '',
    '/relative',
    'ftp://host',
    'http://',
    'http://host:0',
    'http://host:65536',
    'http://[dead]/',
    'http://[::::]/',
    'https://user:query-secret@host',
    'https://host?key=query-secret',
    'https://host/#fragment',
    'https://host/{x}',
    'https://host/a b',
    NA_character_,
    c(origin, origin)
  )) {
    options(controlsclient.request = list(base_url = value))
    error(request('/invalid'), 'base_url')
  }
  for (value in list(0, -1, Inf, NaN, NA_real_, '1', c(1, 2))) {
    options(controlsclient.request = list(base_url = origin, timeout = value))
    error(request('/invalid'), 'timeout')
  }
  for (value in list(
    -1,
    1.5,
    Inf,
    NA_real_,
    '1',
    c(1, 2),
    .Machine$integer.max
  )) {
    options(
      controlsclient.request = list(base_url = origin, max_retries = value)
    )
    error(request('/invalid'), 'max_retries')
  }
  options(controlsclient.request = list(base_url = origin, retry_writes = NA))
  error(request('/invalid'), 'retry_writes')
  options(controlsclient.request = list(unknown = TRUE))
  error(request('/invalid'), 'controls')
  stopifnot(identical(before, counts()))
  options(controlsclient.request = list(base_url = origin, timeout = 0.05))
  error(request('/timeout'), 'timeout')
  stopifnot(counts()[['GET /timeout']] == 1L)
  # Intercept only httr2's wait; HTTP and retry decisions remain real.
  waits <- numeric()
  testthat::local_mocked_bindings(
    sys_sleep = function(seconds, ...) {
      if (seconds > 0) waits <<- c(waits, seconds)
    },
    .package = 'httr2'
  )
  options(controlsclient.request = list(base_url = origin, max_retries = 2))
  result <- request('/recover')
  stopifnot(
    result$count == 3L,
    result$method == 'GET',
    result$path == '/recover',
    result$query == '?api_key=query-secret',
    length(waits) == 2L
  )
  waits <- numeric()
  stopifnot(request('/after')$count == 3L, identical(waits, c(7, 7)))
  stopifnot(request('/rate')$count == 3L)
  error(request('/exhaust'), 'HTTP 503 application/json')
  error(request('/rate-exhaust'), 'HTTP 429 application/json')
  error(request('/permanent'), 'HTTP 400')
  error(request('/decode'), 'Cannot decode HTTP 200 application/json')
  for (method in c('POST', 'PATCH')) {
    error(request('/write', method), 'HTTP 503')
  }
  options(
    controlsclient.request = list(
      base_url = origin,
      max_retries = 2,
      retry_writes = TRUE
    )
  )
  result <- request('/write-recover', 'POST')
  stopifnot(
    result$count == 3L,
    result$method == 'POST',
    result$body == '{"value":1}'
  )
  options(controlsclient.request = list(base_url = origin))
  error(request('/default-exhaust'), 'HTTP 503')
  totals <- counts()
  expected <- c(
    'GET /recover' = 3L,
    'GET /after' = 3L,
    'GET /rate' = 3L,
    'GET /exhaust' = 3L,
    'GET /rate-exhaust' = 3L,
    'GET /permanent' = 1L,
    'GET /decode' = 3L,
    'POST /write' = 1L,
    'PATCH /write' = 1L,
    'POST /write-recover' = 3L,
    'GET /default-exhaust' = 1L
  )
  stopifnot(identical(unlist(totals[names(expected)]), expected))
  Sys.setenv(CONTROLSCLIENT_DRY_RUN = 'true')
  on.exit(Sys.unsetenv('CONTROLSCLIENT_DRY_RUN'), add = TRUE)
  options(controlsclient.request = list(base_url = origin, max_retries = 2))
  for (method in c('GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE')) {
    req <- request('/dry', method)
    stopifnot(
      req$policies$retry_max_tries == 3,
      req$options$timeout_ms == 30000
    )
  }
  for (method in c('POST', 'PATCH', 'TRACE')) {
    stopifnot(is.null(request('/dry', method)$policies$retry_max_tries))
  }
  Sys.unsetenv('CONTROLSCLIENT_DRY_RUN')
  # Every selected operation keeps either a URL or a specific runtime diagnostic.
  cases <- list(
    list(value = server('/relative'), pattern = 'Relative'),
    list(value = server('https://{region}.invalid'), pattern = 'Unresolved'),
    list(
      value = c(server(origin), server('https://other.invalid')),
      pattern = 'Ambiguous'
    ),
    list(value = server('ftp://host'), pattern = 'Unsupported'),
    list(value = list(), pattern = 'Relative'),
    list(
      value = list(list(url = origin, variables = list(x = list(default = 1)))),
      pattern = 'default'
    )
  )
  options(controlsclient.request = NULL)
  for (case in cases) {
    changed <- document
    changed$paths[['/operation']]$get$servers <- case$value
    write_schema(changed)
    parsed_case <- specmill::read_operations(schema)
    selected <- parsed_case$operations$operation_call
    stopifnot(
      length(parsed_case$server_diagnostics) == 1L,
      grepl(case$pattern, selected$server$diagnostic)
    )
    eval(
      parse(
        text = specmill::render_operation(
          selected,
          list(helper = 'api_request')
        )
      ),
      runtime
    )
    before <- counts()
    error(runtime$operation_call(), case$pattern)
    stopifnot(identical(before, counts()))
    options(controlsclient.request = list(base_url = origin))
    stopifnot(runtime$operation_call()$path == '/operation')
    options(controlsclient.request = NULL)
  }
  # Missing metadata and empty overrides mean relative '/', never the parent host.
  stopifnot(grepl(
    'Relative',
    specmill:::effective_server(list(openapi = '3.0.3'))$diagnostic
  ))
  stopifnot(
    specmill:::schema_server(list(
      swagger = '2.0',
      schemes = list('https'),
      host = 'example.org',
      basePath = '/v1'
    )) ==
      'https://example.org/v1',
    specmill:::schema_server(
      list(openapi = '3.0.3', servers = server('/v1')),
      'https://example.org/schema.json'
    ) ==
      'https://example.org/v1',
    specmill:::schema_server(list(
      openapi = '3.0.3',
      servers = c(server(origin), server('https://other.invalid'))
    )) ==
      '',
    grepl(
      'Ambiguous',
      specmill:::effective_server(list(
        swagger = '2.0',
        schemes = list('http', 'https'),
        host = 'example.org'
      ))$diagnostic
    )
  )
  stopifnot(
    specmill:::schema_server(
      list(swagger = '2.0', host = 'example.org', basePath = '/v1'),
      'http://source.org/spec.json'
    ) ==
      'http://example.org/v1',
    specmill:::schema_server(
      list(swagger = '2.0', schemes = list('https'), basePath = '/v1'),
      'http://source.org/spec.json'
    ) ==
      'https://source.org/v1',
    grepl(
      'origin',
      specmill:::effective_server(list(
        swagger = '2.0',
        host = 'example.org'
      ))$diagnostic
    ),
    specmill:::valid_server_url('http://[::1]:8080/a:0')
  )
  # Server-only changes participate in schema drift review.
  changed <- parsed
  changed$operations$operation_call$server$url <- paste0(origin, '/changed')
  stopifnot(any(vapply(
    specmill::compare_operations(parsed, changed),
    function(x) identical(x$reason, 'Effective server changed'),
    logical(1)
  )))
  # YAML defaults are generated into calls, never written into the owned helper.
  project_file <- file.path(root, 'specmill.yml')
  project <- yaml::read_yaml(project_file, handlers = list(seq = function(x) x))
  stopifnot(identical(
    project$defaults$request_controls,
    list(timeout = 30L, max_retries = 0L, retry_writes = FALSE)
  ))
  project$defaults$request_controls <- list(
    timeout = 9,
    max_retries = 1L,
    retry_writes = FALSE
  )
  yaml::write_yaml(project, project_file)
  service_file <- file.path(root, project$services[[1L]])
  service <- yaml::read_yaml(service_file, handlers = list(seq = function(x) x))
  service$defaults$request_controls <- list(max_retries = 2L)
  service$operations[['GET /root']] <- list(
    request_controls = list(timeout = 4, retry_writes = TRUE)
  )
  yaml::write_yaml(service, service_file)
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
  stopifnot(identical(hash, tools::md5sum(helper)))
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  Sys.setenv(CONTROLSCLIENT_DRY_RUN = 'true')
  options(controlsclient.request = NULL)
  root_request <- runtime$root_call()
  path_request <- runtime$path_call()
  stopifnot(
    root_request$options$timeout_ms == 4000,
    path_request$options$timeout_ms == 9000,
    root_request$policies$retry_max_tries == 3,
    path_request$policies$retry_max_tries == 3,
    length(formals(runtime$root_call)) == 0L
  )
  # Runtime options can disable inherited retries and override timeout per field.
  options(controlsclient.request = list(timeout = 2, max_retries = 0))
  stopifnot(
    runtime$root_call()$options$timeout_ms == 2000,
    is.null(runtime$root_call()$policies$retry_max_tries)
  )
  options(controlsclient.request = NULL)
  Sys.unsetenv('CONTROLSCLIENT_DRY_RUN')
  for (bad in list(
    list(timeout = 0),
    list(timeout = Inf),
    list(timeout = '30'),
    list(max_retries = -1),
    list(max_retries = 0.5),
    list(max_retries = Inf),
    list(retry_writes = 'yes'),
    list(max_tries = 2),
    list(timeout = NULL)
  )) {
    invalid <- project
    invalid$defaults$request_controls <- bad
    yaml::write_yaml(invalid, project_file)
    error(specmill::load_project(root), 'request_controls')
  }
  yaml::write_yaml(project, project_file)
  # Generation exposes diagnostics; an old helper must explicitly adopt server metadata.
  write_schema(document)
  writeLines(
    'api_request <- function(method, path, path_params, query, body) NULL',
    helper
  )
  error(
    specmill::generate_client(root, config = 'specmill.yml', mode = 'plan'),
    'Unknown helper arguments.*server'
  )
  writeLines(
    'api_request <- function(method, path, path_params, query, body, server = NULL) NULL',
    helper
  )
  error(
    specmill::generate_client(root, config = 'specmill.yml', mode = 'plan'),
    'Unknown helper arguments.*request_controls'
  )
  cat(
    'Request controls: server precedence, overrides, diagnostics, validation, timeouts, bounded retries, write safety, redaction, and helper ownership passed.\n'
  )
}
if (sys.nframe() == 0L) {
  request_controls_acceptance()
}
