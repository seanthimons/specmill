client_chunks_acceptance <- function() {
  root <- tempfile('client-chunks-')
  port_file <- tempfile('client-chunks-port-')
  dir.create(root)
  on.exit(unlink(c(root, port_file), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      history <- list()
      port <- httpuv::randomPort()
      app <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          if (req$PATH_INFO == '/history') {
            value <- history
            status <- 200L
          } else {
            value <- jsonlite::fromJSON(
              rawToChar(req$rook.input$read()),
              simplifyVector = FALSE
            )
            history[[length(history) + 1L]] <<- value
            status <- if ('denied' %in% unlist(value$ids)) {
              401L
            } else if ('bad' %in% unlist(value$ids)) {
              500L
            } else {
              200L
            }
          }
          list(
            status = status,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(value, auto_unbox = TRUE)
          )
        })
      )
      on.exit(app$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file = port_file),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  for (i in seq_len(600L)) {
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
  schema <- file.path(root, 'schema.json')
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Chunks', version = '1'),
      servers = list(list(url = origin)),
      paths = list(
        '/bulk' = list(
          post = list(
            operationId = 'bulk_input',
            requestBody = list(
              required = TRUE,
              content = list(
                'application/json' = list(
                  schema = list(
                    type = 'object',
                    required = list('ids'),
                    properties = list(
                      ids = list(type = 'array', items = list(type = 'string'))
                    )
                  )
                )
              )
            ),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'chunkclient',
    title = 'Chunk Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(path, handlers = list(seq = function(x) x))
  original <- service
  writeLines(
    c(
      'clean_query <- function(x) { x <- as.character(unlist(x)); unique(x[!is.na(x) & nzchar(x)]) }',
      'format_chunks <- function(data) { attr(data$result, "full_input") <- data$params$query; data$result }'
    ),
    file.path(root, 'R/chunk-policy.R')
  )
  service$operations[['POST /bulk']] <- list(
    inputs = list(query = list(type = 'any', required = TRUE)),
    normalize_inputs = list(query = 'clean_query'),
    result_formatter = 'format_chunks',
    batch = list(
      input = 'query',
      split = TRUE,
      max_items = list(env = 'SPECMILL_CHUNK_TEST_LIMIT', default = 2L),
      on_error = list(single = 'stop', multiple = 'drop'),
      warning = FALSE
    ),
    request = list(
      arguments = list(
        method = list(value = 'POST'),
        path = list(value = '/bulk'),
        path_params = list(value = list()),
        query = list(value = list()),
        body = list(callback = 'chunk_body')
      )
    )
  )
  write <- function() yaml::write_yaml(service, path)
  write()
  callbacks <- new.env(parent = emptyenv())
  callbacks$chunk_body <- function(operation) {
    quote(base::list(ids = base::as.list(params$query)))
  }
  generate <- function(mode = 'apply') {
    specmill::generate_client(
      validation = TRUE,
      root,
      config = 'specmill.yml',
      mode = mode,
      artifacts = 'wrappers',
      callbacks = callbacks
    )
  }
  generate()
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), '\\.R$', full.names = TRUE)) {
    sys.source(file, runtime)
  }
  history <- function() {
    httr2::request(paste0(origin, '/history')) |>
      httr2::req_perform() |>
      httr2::resp_body_json(simplifyVector = FALSE)
  }
  before <- length(history())
  result <- runtime$bulk_input(c('a', 'b', 'a', NA, '', 'c', 'd', 'e'))
  requests <- history()
  requests <- requests[seq_along(requests) > before]
  stopifnot(
    length(requests) == 3L,
    identical(
      lapply(requests, function(x) unlist(x$ids)),
      list(c('a', 'b'), c('c', 'd'), 'e')
    ),
    identical(attr(result, 'full_input'), letters[1:5])
  )
  old_limit <- Sys.getenv('SPECMILL_CHUNK_TEST_LIMIT', unset = NA_character_)
  on.exit(
    if (is.na(old_limit)) {
      Sys.unsetenv('SPECMILL_CHUNK_TEST_LIMIT')
    } else {
      Sys.setenv(SPECMILL_CHUNK_TEST_LIMIT = old_limit)
    },
    add = TRUE
  )
  Sys.setenv(SPECMILL_CHUNK_TEST_LIMIT = '1')
  before <- length(history())
  runtime$bulk_input(c('a', 'b', 'c'))
  stopifnot(length(history()) - before == 3L)
  Sys.unsetenv('SPECMILL_CHUNK_TEST_LIMIT')
  before <- length(history())
  runtime$bulk_input(character())
  stopifnot(
    length(history()) == before + 1L,
    length(tail(history(), 1L)[[1L]]$ids) == 0L
  )
  error <- tryCatch(runtime$bulk_input(c('denied', 'a', 'b')), error = identity)
  stopifnot(inherits(error, 'specmill_call_error'))
  error <- tryCatch(runtime$bulk_input('bad'), error = identity)
  stopifnot(inherits(error, 'error'))
  before <- length(history())
  runtime$bulk_input(c('bad', 'a', 'b'))
  stopifnot(length(history()) - before == 2L)
  service$operations[['POST /bulk']]$batch$input <- 'missing'
  write()
  stopifnot(inherits(tryCatch(generate('plan'), error = identity), 'error'))
  service$operations[['POST /bulk']]$batch$input <- 'query'
  write()
  generate('check')
  cat(
    'Client chunks: canonical object projection, normalized full params, dynamic limits, empty input, failures, native hard errors and validated freshness passed.\n'
  )
}
if (sys.nframe() == 0L) {
  client_chunks_acceptance()
}
