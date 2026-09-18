request_controls_acceptance <- function() {
  root <- tempfile('request-controls-')
  port_file <- tempfile('request-controls-port-')
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(c(root, port_file, schema), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      counts <- new.env(parent = emptyenv())
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(request) {
          path <- request$PATH_INFO
          count <- counts[[path]]
          if (is.null(count)) {
            count <- 0L
          }
          counts[[path]] <- count <- count + 1L
          response <- function(status = 200L, retry_after = NULL) {
            headers <- list('Content-Type' = 'application/json')
            if (!is.null(retry_after)) {
              headers[['Retry-After']] <- retry_after
            }
            list(
              status = status,
              headers = headers,
              body = jsonlite::toJSON(list(count = count), auto_unbox = TRUE)
            )
          }
          if (path == '/slow') {
            Sys.sleep(2)
          }
          if (path == '/retry' && count < 3L) {
            return(response(503L, '0'))
          }
          if (path == '/rate-limit' && count < 2L) {
            return(response(429L, '0'))
          }
          if (path == '/exhaust') {
            return(response(503L, '0'))
          }
          if (path == '/write') {
            return(response(503L, '0'))
          }
          if (path == '/unsafe' && count < 2L) {
            return(response(503L, '0'))
          }
          if (path == '/counts') {
            values <- as.list.environment(counts, all.names = TRUE)
            return(list(
              status = 200L,
              headers = list('Content-Type' = 'application/json'),
              body = jsonlite::toJSON(values, auto_unbox = TRUE)
            ))
          }
          response()
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file = port_file),
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
  paths <- setNames(
    lapply(
      c('retry', 'rate-limit', 'exhaust', 'slow', 'counts'),
      function(name) {
        list(
          get = list(
            operationId = gsub('-', '_', name),
            responses = list('200' = list(description = 'OK'))
          )
        )
      }
    ),
    paste0('/', c('retry', 'rate-limit', 'exhaust', 'slow', 'counts'))
  )
  paths[['/write']] <- list(
    post = list(
      operationId = 'write',
      responses = list('200' = list(description = 'OK'))
    )
  )
  paths[['/unsafe']] <- list(
    post = list(
      operationId = 'unsafe',
      responses = list('200' = list(description = 'OK'))
    )
  )
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Request controls', version = '1'),
      paths = paths
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'requestclient',
    title = 'Request Controls Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = paste0('http://127.0.0.1:', readLines(port_file))
  )
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  old <- options(
    requestclient.request = list(
      timeout = 1,
      max_tries = 3L,
      retry_non_idempotent = FALSE
    )
  )
  on.exit(options(old), add = TRUE)
  stopifnot(
    runtime$retry()$count == 3L,
    runtime$rate_limit()$count == 2L
  )
  exhausted <- tryCatch(runtime$exhaust(), error = identity)
  write <- tryCatch(runtime$write(), error = identity)
  counts <- runtime$counts()
  stopifnot(
    inherits(exhausted, 'error'),
    grepl('503', conditionMessage(exhausted), fixed = TRUE),
    counts[['/exhaust']] == 3L,
    inherits(write, 'error'),
    counts[['/write']] == 1L
  )
  options(
    requestclient.request = list(
      timeout = 1,
      max_tries = 2L,
      retry_non_idempotent = TRUE
    )
  )
  stopifnot(runtime$unsafe()$count == 2L)
  options(requestclient.request = list(timeout = 0.05, max_tries = 1L))
  started <- Sys.time()
  timeout <- tryCatch(runtime$slow(), error = identity)
  stopifnot(
    inherits(timeout, 'error'),
    as.numeric(difftime(Sys.time(), started, units = 'secs')) < 1
  )
  cat(
    'Request controls: timeout, bounded retries, Retry-After, exhaustion and explicit write replay passed.\n'
  )
}
if (sys.nframe() == 0L) {
  request_controls_acceptance()
}
