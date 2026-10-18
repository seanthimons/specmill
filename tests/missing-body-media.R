missing_body_media_acceptance <- function() {
  workspace <- tempfile('missing-media-')
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
                type = req$CONTENT_TYPE,
                body = rawToChar(req$rook.input$read())
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
  op <- list(
    operationId = 'dtxsids',
    parameters = list(list(
      name = 'body',
      `in` = 'body',
      schema = list(
        type = 'object',
        properties = list(
          dtxsids = list(type = 'array', items = list(type = 'string'))
        )
      )
    )),
    responses = list('200' = list(description = 'OK'))
  )
  declared <- op
  declared$operationId <- 'declared'
  declared$consumes <- list('application/json')
  document <- list(
    swagger = '2.0',
    info = list(title = 'Reviewed media', version = '1'),
    paths = list(
      '/dtxsids/' = list(post = op),
      '/declared' = list(post = declared)
    )
  )
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  unreviewed <- specmill::read_operations(schema)
  stopifnot(any(vapply(
    unreviewed$diagnostics,
    function(d) grepl('Ambiguous body media type', d$reason),
    logical(1)
  )))
  correction <- list(
    from = NULL,
    to = 'application/json',
    reason = 'Reviewed production JSON capture and staging declaration.'
  )
  policy <- list(
    include = 'POST /dtxsids/',
    body_media_corrections = list('POST /dtxsids/' = correction)
  )
  root <- file.path(workspace, 'client')
  specmill::initialize_client(
    root,
    schema,
    package = 'reviewedmedia',
    title = 'Reviewed media',
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
  service$operations[['POST /dtxsids/']] <- list(
    body_media_correction = correction,
    body = list(name = 'query')
  )
  yaml::write_yaml(service, path)
  plan <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    validation = FALSE,
    mode = 'apply'
  )
  reviewed <- Filter(function(x) x$name == 'dtxsids', plan$operations)[[1L]]
  stopifnot(
    !length(plan$diagnostics),
    identical(reviewed$body_media_correction, correction),
    is.null(reviewed$source_operation$consumes),
    identical(reviewed$source_hash, unname(tools::md5sum(reviewed$source)))
  )
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  input <- list(dtxsids = 'DTXSID7020182')
  result <- runtime$dtxsids(input)
  stopifnot(
    identical(result, runtime$dtxsids(query = input)),
    identical(result$method, 'POST'),
    identical(result$path, '/dtxsids/'),
    identical(result$type, 'application/json'),
    identical(result$body, '{"dtxsids":["DTXSID7020182"]}'),
    identical(runtime$declared(input)$type, 'application/json')
  )
  specmill::generate_client(
    root,
    config = 'specmill.yml',
    validation = FALSE,
    mode = 'check'
  )
  rejected <- function(doc, selected_policy = policy) {
    jsonlite::write_json(doc, schema, auto_unbox = TRUE)
    parsed <- specmill::read_operations(schema, selected_policy)
    stopifnot(any(vapply(
      parsed$diagnostics,
      function(d) identical(d$code, 'body_media_correction'),
      logical(1)
    )))
  }
  for (media in c('application/json', 'text/plain')) {
    existing <- document
    existing$paths[['/dtxsids/']]$post$consumes <- list(media)
    rejected(existing)
  }
  inherited <- document
  inherited$consumes <- list('application/json')
  rejected(inherited)
  absent <- document
  absent$paths[['/dtxsids/']]$post$parameters <- NULL
  rejected(absent)
  conflict <- policy
  conflict$body_media_overrides <- list('POST /dtxsids/' = 'text/plain')
  rejected(document, conflict)
  modern <- list(
    openapi = '3.1.0',
    info = document$info,
    paths = list(
      '/dtxsids/' = list(
        post = list(
          operationId = 'modern',
          responses = op$responses,
          requestBody = list(
            content = list(
              'application/json' = list(schema = list(type = 'string'))
            )
          )
        )
      )
    )
  )
  rejected(modern)
  service$operations[['POST /dtxsids/']]$body_media_correction$from <- NULL
  # Removing the key differs from explicitly selecting a missing declaration.
  service$operations[['POST /dtxsids/']]$body_media_correction <- correction[c(
    'to',
    'reason'
  )]
  yaml::write_yaml(service, path)
  stopifnot(inherits(
    try(specmill::load_project(root), silent = TRUE),
    'try-error'
  ))
  cat(
    'Missing Swagger media: reviewed JSON bytes, singleton arrays, siblings, provenance, freshness and existing/conflicting declarations passed.\n'
  )
}
if (sys.nframe() == 0L) {
  missing_body_media_acceptance()
}
