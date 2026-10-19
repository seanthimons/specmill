scalar_query_booleans_acceptance <- function() {
  workspace <- tempfile('scalar-query-booleans-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  port_file <- file.path(workspace, 'port')
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      sent <- 0L
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          sent <<- sent + 1L
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(
              list(
                method = req$REQUEST_METHOD,
                path = req$PATH_INFO,
                query = req$QUERY_STRING,
                sent = sent
              ),
              auto_unbox = TRUE
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
  origin <- paste0('http://127.0.0.1:', readLines(port_file))
  scaffold <- getFromNamespace('request_helper_scaffold', 'specmill')(
    'api_request',
    origin,
    NULL,
    'BOOLEAN_DRY_RUN'
  )
  runtime <- new.env(parent = baseenv())
  eval(parse(text = scaffold$code), runtime)
  eval(
    parse(text = getFromNamespace('validation_runtime', 'specmill')()),
    runtime
  )
  count <- 0L
  for (version in c('2.0', '3.0.3', '3.1.0')) {
    parameter <- function(name, type, required = FALSE) {
      value <- list(
        name = name,
        'in' = if (name == 'id') 'path' else 'query',
        required = required,
        schema = list(type = type)
      )
      if (type == 'boolean') {
        value$schema$default <- name == 'freeze'
      }
      if (version == '2.0') {
        value$schema <- NULL
        value$type <- type
        if (type == 'boolean') value$default <- name == 'freeze'
      }
      value
    }
    document <- list(
      info = list(title = 'Scalar query', version = '1'),
      paths = list(
        '/api/alerts/groups/{id}/freeze' = list(
          patch = list(
            operationId = 'freeze',
            parameters = list(
              parameter('id', 'string', TRUE),
              parameter('freeze', 'boolean'),
              parameter('hierarchically', 'boolean'),
              parameter('label', 'string'),
              parameter('count', 'integer')
            ),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    )
    if (version == '2.0') {
      document$swagger <- version
      document$schemes <- list('http')
      document$host <- sub('http://', '', origin, fixed = TRUE)
    } else {
      document$openapi <- version
      document$servers <- list(list(url = origin))
    }
    schema <- file.path(workspace, 'schema.json')
    jsonlite::write_json(document, schema, auto_unbox = TRUE)
    parsed <- specmill::read_operations(schema)
    stopifnot(!length(parsed$diagnostics))
    eval(
      parse(
        text = specmill::render_operation(
          parsed$operations[[1L]],
          list(helper = 'api_request')
        )
      ),
      runtime
    )
    for (flags in list(
      c(FALSE, TRUE),
      c(TRUE, FALSE),
      c(FALSE, FALSE),
      c(TRUE, TRUE)
    )) {
      result <- runtime$freeze(
        'report-123',
        flags[[1L]],
        flags[[2L]]
      )
      count <- count + 1L
      stopifnot(
        result$method == 'PATCH',
        result$path == '/api/alerts/groups/report-123/freeze',
        result$query ==
          paste0(
            '?freeze=',
            tolower(flags[[1L]]),
            '&hierarchically=',
            tolower(flags[[2L]])
          ),
        result$sent == count
      )
    }
    result <- runtime$freeze('report-123')
    count <- count + 1L
    stopifnot(
      result$query == '?freeze=true&hierarchically=false',
      result$sent == count
    )
    result <- runtime$freeze('report-123', NULL, NULL)
    count <- count + 1L
    stopifnot(result$query == '', result$sent == count)
    result <- runtime$freeze(
      'report-123',
      NULL,
      NULL,
      label = 'TRUE',
      count = 2L
    )
    count <- count + 1L
    stopifnot(result$query == '?label=TRUE&count=2', result$sent == count)
    error <- tryCatch(runtime$freeze('report-123', NA), error = identity)
    stopifnot(inherits(error, 'error'))
  }
  # Explicit facade mappings still own their scalar lowering without native metadata.
  direct <- runtime$api_request(
    'PATCH',
    '/facade',
    list(),
    list(flag = TRUE),
    NULL
  )
  stopifnot(direct$query == '?flag=TRUE')
  cat(
    'Scalar query booleans: exact lowercase PATCH wire, all flag combinations, omitted NULLs, pre-send invalid values, unchanged strings/numbers across Swagger2 and OpenAPI3 passed.\n'
  )
}
if (sys.nframe() == 0L) {
  scalar_query_booleans_acceptance()
}
