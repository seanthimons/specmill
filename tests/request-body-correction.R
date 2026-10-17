request_body_correction_acceptance <- function() {
  workspace <- tempfile('bodyless-review-')
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
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(
              list(
                method = req$REQUEST_METHOD,
                path = req$PATH_INFO,
                bytes = length(req$rook.input$read())
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
  schema <- file.path(workspace, 'schema.json')
  body <- list(
    content = list('application/json' = list(schema = list(type = 'object')))
  )
  get <- list(
    operationId = 'counts',
    requestBody = body,
    responses = list('200' = list(description = 'OK'))
  )
  post <- get
  post$operationId <- 'search'
  post$requestBody$required <- TRUE
  document <- list(
    openapi = '3.1.0',
    info = list(title = 'Bodyless subset', version = '1'),
    paths = list(
      '/counts' = list(get = get, post = post),
      '/public' = list(
        get = list(operationId = 'public', responses = get$responses)
      )
    )
  )
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  before <- tools::md5sum(schema)
  uncorrected <- specmill::read_operations(schema)
  stopifnot(any(vapply(
    uncorrected$diagnostics,
    function(d) identical(d$code, 'request_body_method'),
    logical(1)
  )))
  root <- file.path(workspace, 'client')
  specmill::initialize_client(
    root,
    schema,
    package = 'bodylessclient',
    title = 'Bodyless subset',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = paste0('http://127.0.0.1:', readLines(port_file))
  )
  path <- file.path(root, 'apis', 'default.yml')
  service <- yaml::read_yaml(path, handlers = list(seq = identity))
  correction <- list(
    omit = TRUE,
    reason = 'Reviewed optional bodyless GET subset.'
  )
  service$operations[['GET /counts']] <- list(
    request_body_correction = correction
  )
  yaml::write_yaml(service, path)
  plan <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    validation = FALSE,
    mode = 'apply'
  )
  stopifnot(!length(plan$diagnostics), identical(before, tools::md5sum(schema)))
  counts <- Filter(function(op) op$name == 'counts', plan$operations)[[1L]]
  stopifnot(
    is.null(counts$body),
    !is.null(counts$source_operation$requestBody),
    identical(counts$request_body_correction, correction)
  )
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  result <- runtime$counts()
  stopifnot(
    identical(result$method, 'GET'),
    identical(result$path, '/counts'),
    identical(result$bytes, 0L),
    !length(formals(runtime$counts)),
    identical(runtime$public()$bytes, 0L),
    identical(runtime$search(list())$method, 'POST')
  )
  specmill::generate_client(
    root,
    config = 'specmill.yml',
    validation = FALSE,
    mode = 'check'
  )
  for (key in c('POST /counts', 'GET /public')) {
    rejected <- specmill::read_operations(
      schema,
      list(
        include = key,
        request_body_corrections = setNames(list(correction), key)
      )
    )
    stopifnot(any(vapply(
      rejected$diagnostics,
      function(d) identical(d$code, 'request_body_correction'),
      logical(1)
    )))
  }
  conflict <- specmill::read_operations(
    schema,
    list(
      include = 'GET /counts',
      request_body_corrections = list('GET /counts' = correction),
      body_media_overrides = list('GET /counts' = 'application/json')
    )
  )
  stopifnot(any(vapply(
    conflict$diagnostics,
    function(d) identical(d$code, 'request_body_correction'),
    logical(1)
  )))
  document$paths[['/counts']]$get$requestBody$required <- TRUE
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  rejected <- specmill::read_operations(
    schema,
    list(
      include = 'GET /counts',
      request_body_corrections = list('GET /counts' = correction)
    )
  )
  stopifnot(any(vapply(
    rejected$diagnostics,
    function(d) identical(d$code, 'request_body_correction'),
    logical(1)
  )))
  service$defaults$request_body_correction <- correction
  yaml::write_yaml(service, path)
  stopifnot(inherits(
    try(specmill::load_project(root), silent = TRUE),
    'try-error'
  ))
  cat(
    'Reviewed optional GET subset: no public body, zero wire bytes, siblings, provenance, freshness and invalid corrections passed.\n'
  )
}
if (sys.nframe() == 0L) {
  request_body_correction_acceptance()
}
