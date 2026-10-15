body_name_acceptance <- function() {
  root <- tempfile('body-name-client-')
  port_file <- tempfile('body-name-port-')
  on.exit(unlink(c(root, port_file), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      history <- list()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          json <- function(value) {
            list(
              status = 200L,
              headers = list('Content-Type' = 'application/json'),
              body = jsonlite::toJSON(value, auto_unbox = TRUE)
            )
          }
          if (req$PATH_INFO == '/history') {
            return(json(history))
          }
          body <- rawToChar(req$rook.input$read())
          history[[length(history) + 1L]] <<- list(
            path = req$PATH_INFO,
            body = body
          )
          items <- jsonlite::fromJSON(body, simplifyVector = FALSE)
          json(lapply(items, function(x) list(item = x)))
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
  origin <- paste0('http://127.0.0.1:', readLines(port_file))
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(schema), add = TRUE)
  string <- list(type = 'string')
  operation <- function(name, parameters = list(), body = NULL) {
    x <- list(
      operationId = name,
      parameters = parameters,
      responses = list('200' = list(description = 'OK'))
    )
    if (!is.null(body)) {
      x$requestBody <- list(
        required = TRUE,
        content = list('application/json' = list(schema = body))
      )
    }
    x
  }
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Body name', version = '1'),
      servers = list(list(url = origin)),
      paths = list(
        '/bulk' = list(
          post = operation(
            'bulk',
            body = list(type = 'array', items = string, maxItems = 2L)
          )
        ),
        '/object' = list(
          post = operation(
            'object_body',
            list(list(name = 'body', `in` = 'query', schema = string)),
            body = list(type = 'object', properties = list(a = string))
          )
        ),
        '/status' = list(get = operation('status'))
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'bodynameclient',
    title = 'Body Name Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  service_path <- file.path(root, 'apis/default.yml')
  original <- yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
  run <- function(mode = 'apply') {
    specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = mode
    )
  }
  fails <- function(service, pattern) {
    yaml::write_yaml(service, service_path)
    error <- tryCatch(run(), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  with_body <- function(key, body, defaults = NULL) {
    service <- original
    service$defaults$batch <- list(max_items = 2L, split = TRUE)
    if (!is.null(defaults)) {
      service$defaults$body <- defaults
    }
    service$operations[[key]] <- list(body = body)
    service
  }
  # Configuration errors name the operation and the fix.
  fails(
    with_body('POST /object', list(name = 'body')),
    'Body name collides with parameter "body": .*POST /object'
  )
  fails(
    with_body('GET /status', list(name = 'ids')),
    'requires an operation with a request body'
  )
  for (name in c('not valid', '..1', '...', 'params', 'if')) {
    fails(with_body('POST /bulk', list(name = name)), 'body name must be')
  }
  fails(
    with_body('POST /bulk', setNames(list(), character())),
    'needs a name or description'
  )
  fails(with_body('POST /bulk', list(title = 'x')), 'unknown field title')
  fails(
    with_body('POST /bulk', list(name = 'ids'), defaults = list(name = 'ids')),
    'belongs under operations, not defaults'
  )
  service <- with_body('POST /bulk', list(name = 'ids'))
  service$operations[['POST /bulk']]$inputs <- list(
    ids = list(type = 'character')
  )
  fails(service, 'cannot be combined with explicit inputs')

  # Without the setting nothing changes: a colliding parameter still yields body.1.
  service <- original
  service$defaults$batch <- list(max_items = 2L, split = TRUE)
  yaml::write_yaml(service, service_path)
  run()
  code <- function(name) {
    paste(readLines(file.path(root, 'R', paste0(name, '.R'))), collapse = '\n')
  }
  stopifnot(
    grepl('bulk <- function(body)', code('bulk'), fixed = TRUE),
    grepl('@param body Request body. Arrays longer than 2', code('bulk'), fixed = TRUE),
    grepl('object_body <- function(body = NULL, body.1)', code('object_body'), fixed = TRUE),
    # Documentation names the real argument, once each.
    grepl('@param body.1 Request body.', code('object_body'), fixed = TRUE),
    lengths(regmatches(
      code('object_body'),
      gregexpr('@param body ', code('object_body'), fixed = TRUE)
    )) == 1L
  )
  default_hashes <- tools::md5sum(list.files(file.path(root, 'R'), full.names = TRUE))

  # The override renames the formal, every reference to it, and the documentation.
  yaml::write_yaml(
    with_body(
      'POST /bulk',
      list(name = 'dtxsid', description = 'DSSTox substance identifiers.')
    ) |>
      (\(x) {
        x$operations[['POST /bulk']]$docs <- list(
          examples = list(list(dtxsid = list('DTXSID7020182', 'DTXSID2021315')))
        )
        x
      })(),
    service_path
  )
  run()
  before <- tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE))
  run()
  run('check')
  stopifnot(identical(before, tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE))))
  bulk <- code('bulk')
  stopifnot(
    grepl('bulk <- function(dtxsid)', bulk, fixed = TRUE),
    grepl(
      '@param dtxsid DSSTox substance identifiers. Arrays longer than 2 items are sent in chunks of that size and the results are combined.',
      bulk,
      fixed = TRUE
    ),
    grepl('bulk(dtxsid = ', bulk, fixed = TRUE),
    grepl('params[["dtxsid"]], 2L', bulk, fixed = TRUE),
    !grepl('missing(body)', bulk, fixed = TRUE),
    !grepl('"body"', bulk, fixed = TRUE),
    grepl('body = params[["dtxsid"]]', bulk, fixed = TRUE)
  )
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  stopifnot(identical(names(formals(runtime$bulk)), 'dtxsid'))
  history <- function() {
    httr2::resp_body_json(
      httr2::req_perform(httr2::request(paste0(origin, '/history'))),
      simplifyVector = FALSE
    )
  }
  # Named and positional calls send the renamed argument as the body, in chunks.
  result <- runtime$bulk(dtxsid = letters[1:5])
  runtime$bulk('z')
  wire <- vapply(history(), `[[`, character(1), 'body')
  stopifnot(
    identical(wire, c('["a","b"]', '["c","d"]', '["e"]', '["z"]')),
    identical(vapply(result, `[[`, character(1), 'item'), letters[1:5])
  )
  error <- tryCatch(runtime$bulk(), error = identity)
  stopifnot(inherits(error, 'error'), grepl('Required body', conditionMessage(error)))
  error <- tryCatch(runtime$bulk(body = 'a'), error = identity)
  stopifnot(inherits(error, 'error'))

  # A description alone keeps the default name and an unrenamed sibling is untouched.
  yaml::write_yaml(
    with_body('POST /bulk', list(description = 'Identifiers to look up.')),
    service_path
  )
  run()
  stopifnot(
    grepl('bulk <- function(body)', code('bulk'), fixed = TRUE),
    grepl('@param body Identifiers to look up. Arrays longer than 2', code('bulk'), fixed = TRUE)
  )

  # Removing the override restores the default output.
  service <- original
  service$defaults$batch <- list(max_items = 2L, split = TRUE)
  yaml::write_yaml(service, service_path)
  run()
  stopifnot(identical(
    default_hashes,
    tools::md5sum(list.files(file.path(root, 'R'), full.names = TRUE))
  ))

  # Fixed-contract inputs use the renamed argument.
  operations <- specmill::read_operations(schema)$operations
  operations$bulk$body_name <- 'dtxsid'
  fixtures <- specmill:::operation_fixtures(list(operations$bulk))
  stopifnot(identical(names(fixtures[[1L]]), 'dtxsid'))
  # Without an override a colliding parameter makes the body argument body.1.
  fixtures <- specmill:::operation_fixtures(list(operations$object_body))
  stopifnot(identical(names(fixtures[[1L]]), c('body', 'body.1')))
  # Minimal mode keeps the wrapper's real argument names when duplicates exist: the
  # optional query `x` is left out, but the required header `x` stays `x.1`.
  duplicates <- tempfile(fileext = '.json')
  on.exit(unlink(duplicates), add = TRUE)
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Duplicates', version = '1'),
      servers = list(list(url = origin)),
      paths = list('/dup' = list(get = operation(
        'dup',
        list(
          list(name = 'x', `in` = 'query', schema = string),
          list(name = 'x', `in` = 'header', required = TRUE, schema = string)
        )
      )))
    ),
    duplicates,
    auto_unbox = TRUE
  )
  dup <- specmill::read_operations(duplicates)$operations
  stopifnot(
    identical(names(specmill:::operation_fixtures(dup)[[1L]]), c('x', 'x.1')),
    identical(
      names(specmill:::operation_fixtures(dup, mode = 'minimal')[[1L]]),
      'x.1'
    )
  )
  cat(
    'Body name: rename, description, split chunking, documentation, fixtures, collisions and unchanged default output passed.\n'
  )
}

if (sys.nframe() == 0L) {
  body_name_acceptance()
}
