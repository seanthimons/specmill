http_methods_acceptance <- function() {
  root <- tempfile('methods-client-')
  schema <- tempfile(fileext = '.json')
  port_file <- tempfile('methods-port-')
  on.exit(unlink(c(root, schema, port_file), recursive = TRUE), add = TRUE)
  process <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      received <- list()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          if (req$PATH_INFO == '/received') {
            return(list(
              status = 200L,
              headers = list('Content-Type' = 'application/json'),
              body = jsonlite::toJSON(received, auto_unbox = TRUE)
            ))
          }
          record <- list(
            method = req$REQUEST_METHOD,
            path = req$PATH_INFO,
            query = req$QUERY_STRING,
            body = rawToChar(req$rook.input$read())
          )
          received[[length(received) + 1L]] <<- record
          # HEAD advertises a JSON representation but sends no response body.
          # Disable httpuv compression so it cannot append gzip chunks to HEAD.
          body <- jsonlite::toJSON(record, auto_unbox = TRUE)
          list(
            status = if (req$PATH_INFO == '/failure') 503L else 200L,
            headers = list(
              'Content-Type' = 'application/json',
              'Content-Encoding' = 'identity',
              'Content-Length' = as.character(nchar(body, type = 'bytes'))
            ),
            body = if (req$REQUEST_METHOD == 'HEAD') NULL else body
          )
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
  methods <- c(
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'HEAD',
    'OPTIONS',
    'TRACE'
  )
  item <- list(
    parameters = list(
      list(
        name = 'id',
        'in' = 'path',
        required = TRUE,
        schema = list(type = 'string')
      ),
      list(name = 'q', 'in' = 'query', schema = list(type = 'string'))
    )
  )
  for (method in methods) {
    op <- list(
      operationId = paste0('call_', tolower(method)),
      responses = list('200' = list(description = 'OK'))
    )
    if (method %in% c('POST', 'PUT', 'PATCH')) {
      op$requestBody <- list(
        required = TRUE,
        content = list(
          'application/json' = list(
            schema = list(
              type = 'object',
              required = list('value'),
              properties = list(value = list(type = 'string'))
            )
          )
        )
      )
    }
    item[[tolower(method)]] <- op
  }
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'Methods', version = '1'),
    servers = list(list(url = origin)),
    paths = list(
      '/items/{id}' = item,
      '/failure' = list(
        head = list(
          operationId = 'head_failure',
          responses = list('503' = list(description = 'Unavailable'))
        )
      )
    )
  )
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  parsed <- specmill::read_operations(schema)
  stopifnot(
    !length(parsed$diagnostics),
    length(parsed$operations) == 9L,
    setequal(vapply(parsed$operations, `[[`, '', 'method'), methods)
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'methodsclient',
    title = 'Methods Client',
    author = list(given = 'Test', family = 'User', email = 'test@example.org'),
    license = 'MIT'
  )
  project_file <- file.path(root, 'specmill.yml')
  project <- yaml::read_yaml(project_file, handlers = list(seq = function(x) x))
  service_file <- file.path(root, project$services[[1L]])
  service <- yaml::read_yaml(service_file, handlers = list(seq = function(x) x))
  stopifnot(
    identical(unlist(project$selection$methods), methods),
    identical(unlist(service$selection$methods), methods)
  )
  run <- function(mode) {
    specmill::generate_client(root, config = 'specmill.yml', mode = mode)
  }
  generated <- run('apply')
  stopifnot(length(generated$operations) == 9L, !length(generated$diagnostics))
  run('check')
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  expected <- list()
  for (method in methods) {
    args <- list(id = 'item-1', q = 'a b')
    body <- ''
    if (method %in% c('POST', 'PUT', 'PATCH')) {
      args$body <- list(value = method)
      body <- paste0('{"value":"', method, '"}')
    }
    result <- do.call(runtime[[paste0('call_', tolower(method))]], args)
    record <- list(
      method = method,
      path = '/items/item-1',
      query = '?q=a%20b',
      body = body
    )
    expected[[length(expected) + 1L]] <- record
    if (method == 'HEAD') {
      stopifnot(is.null(result))
    } else {
      stopifnot(identical(result, record))
    }
  }
  failure <- tryCatch(runtime$head_failure(), error = identity)
  stopifnot(
    inherits(failure, 'error'),
    grepl('HTTP 503', conditionMessage(failure))
  )
  expected[[length(expected) + 1L]] <- list(
    method = 'HEAD',
    path = '/failure',
    query = '',
    body = ''
  )
  received <- httr2::resp_body_json(httr2::req_perform(httr2::request(paste0(
    origin,
    '/received'
  ))))
  stopifnot(identical(received, expected))
  # Service settings cannot re-enable TRACE prohibited by the project.
  project$selection$methods <- as.list(setdiff(methods, 'TRACE'))
  service$selection$methods <- as.list(c('PUT', 'HEAD', 'OPTIONS', 'TRACE'))
  yaml::write_yaml(project, project_file)
  yaml::write_yaml(service, service_file)
  selected <- run('apply')
  stopifnot(setequal(
    vapply(selected$operations, `[[`, '', 'method'),
    c('PUT', 'HEAD', 'OPTIONS')
  ))
  run('check')
  project$selection$methods <- as.list(methods)
  service$selection$methods <- list('TRACE')
  yaml::write_yaml(project, project_file)
  yaml::write_yaml(service, service_file)
  selected <- run('apply')
  stopifnot(
    length(selected$operations) == 1L,
    selected$operations[[1L]]$method == 'TRACE',
    identical(
      grep('^export\\(', readLines(file.path(root, 'NAMESPACE')), value = TRUE),
      c(
        'export(call_trace)',
        'export(methodsclient_dry_run)',
        'export(methodsclient_run_verbose)'
      )
    )
  )
  run('check')
  cat(
    'HTTP methods: all advertised methods reach the wire, PUT/PATCH bodies, HEAD responses, and selection precedence passed.\n'
  )
}
if (sys.nframe() == 0L) {
  http_methods_acceptance()
}
