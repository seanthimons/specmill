batch_iteration_acceptance <- function() {
  root <- tempfile('iteration-client-')
  port_file <- tempfile('iteration-port-')
  on.exit(unlink(c(root, port_file), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      history <- list()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          json <- function(value, status = 200L) {
            list(
              status = status,
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
            query = req$QUERY_STRING,
            body = body
          )
          query <- httr2::url_parse(
            paste0('http://x/?', sub('^[?]', '', req$QUERY_STRING))
          )$query
          if (startsWith(req$PATH_INFO, '/items/')) {
            id <- sub('^/items/', '', req$PATH_INFO)
            if (id == 'bad') {
              return(json(list(error = 'missing'), 404L))
            }
            return(json(list(id = id)))
          }
          if (req$PATH_INFO == '/search') {
            if (identical(query$name, 'bad')) {
              return(json(list(error = 'missing'), 404L))
            }
            return(json(list(list(name = query$name), list(name = 'related'))))
          }
          items <- jsonlite::fromJSON(body, simplifyVector = FALSE)
          if ('bad' %in% unlist(items)) {
            return(json(list(error = 'rejected'), 500L))
          }
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
  string <- list(type = 'string')
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Iteration', version = '1'),
      servers = list(list(url = origin)),
      paths = list(
        '/items/{id}' = list(
          get = operation(
            'get_item',
            list(
              list(
                name = 'id',
                `in` = 'path',
                required = TRUE,
                schema = string
              ),
              list(name = 'projection', `in` = 'query', schema = string)
            )
          )
        ),
        '/search' = list(
          get = operation(
            'search',
            list(
              list(
                name = 'name',
                `in` = 'query',
                required = TRUE,
                schema = string
              )
            )
          )
        ),
        '/bulk' = list(
          post = operation(
            'bulk',
            body = list(type = 'array', items = string, maxItems = 2L)
          )
        ),
        '/object' = list(
          post = operation(
            'object_body',
            body = list(type = 'object', properties = list(a = string))
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
    package = 'iterationclient',
    title = 'Iteration Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  service_path <- file.path(root, 'apis/default.yml')
  read_service <- function() {
    yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
  }
  original <- read_service()
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
  # Configuration errors name the operation and the fix.
  bad <- original
  bad$operations[['GET /items/{id}']] <- list(batch = list(fan_out = 'missing'))
  fails(bad, 'fan_out must name a scalar path or query parameter')
  bad <- original
  bad$operations[['POST /object']] <- list(batch = list(split = TRUE))
  fails(bad, 'split requires batch.max_items')
  bad <- original
  bad$operations[['GET /search']] <- list(batch = list(on_error = 'drop'))
  fails(bad, 'on_error requires batch.fan_out or batch.split')
  bad <- original
  bad$operations[['GET /search']] <- list(
    batch = list(fan_out = 'name', on_error = 'keep')
  )
  fails(bad, 'on_error must be stop or drop')
  # One per-API item limit; split opts in to chunking with it.
  service <- original
  service$defaults$batch <- list(max_items = 2L, split = TRUE)
  service$operations[['GET /items/{id}']] <- list(
    batch = list(fan_out = 'id', on_error = 'drop')
  )
  service$operations[['GET /search']] <- list(batch = list(fan_out = 'name'))
  service$hooks <- list(
    get_item = list(
      pre_request = list('log_hook'),
      post_response = list('log_hook')
    )
  )
  service$defaults$response_policy <- 'attributed'
  yaml::write_yaml(service, service_path)
  writeLines(
    c(
      'attributed <- function(response, context, decode) {',
      '  result <- decode()',
      '  if (!is.null(names(result))) result$query <- context$query',
      '  result',
      '}',
      'log_hook <- function(state) state',
      'run_hook <- function(fn_name, hook_type, state) {',
      '  key <- paste(hook_type, state$params$id)',
      '  options(iterationclient.hooks = c(getOption("iterationclient.hooks"), key))',
      '  if (hook_type == "pre_request") state else state$result',
      '}'
    ),
    file.path(root, 'R/hooks.R')
  )
  run()
  hashes <- function() {
    tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE))
  }
  before <- hashes()
  run()
  run('check')
  stopifnot(identical(before, hashes()))
  code <- function(name) {
    paste(readLines(file.path(root, 'R', paste0(name, '.R'))), collapse = '\n')
  }
  stopifnot(
    grepl('api_request_each(', code('get_item'), fixed = TRUE),
    grepl('on_error = "drop"', code('get_item'), fixed = TRUE),
    grepl('params[["body"]], 2L', code('bulk'), fixed = TRUE),
    !grepl('api_request_each', code('object_body'), fixed = TRUE),
    grepl('Accepts a vector', code('get_item'), fixed = TRUE)
  )
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  history <- function() {
    httr2::resp_body_json(
      httr2::req_perform(httr2::request(paste0(origin, '/history'))),
      simplifyVector = FALSE
    )
  }
  withr::local_options(iterationclient.hooks = NULL)
  # Fan-out: one request per element, hooks per request, failures dropped and recorded.
  sent <- length(history())
  warnings <- character()
  items <- withCallingHandlers(
    runtime$get_item(c('a', 'bad', 'c')),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart('muffleWarning')
    }
  )
  stopifnot(
    length(history()) - sent == 3L,
    identical(
      lapply(items, `[[`, 'id'),
      list('a', 'c')
    ),
    identical(lapply(items, `[[`, 'query'), list('a', 'c')),
    identical(
      warnings,
      'Request for bad failed: HTTP 404 application/json response'
    ),
    identical(
      attr(items, 'failed'),
      c(bad = 'HTTP 404 application/json response')
    ),
    identical(
      getOption('iterationclient.hooks'),
      c(
        'pre_request a',
        'post_response a',
        'pre_request bad',
        'pre_request c',
        'post_response c'
      )
    )
  )
  # One input returns the same shape as many.
  single <- runtime$get_item('a')
  stopifnot(
    identical(length(single), 1L),
    identical(single[[1L]]$id, 'a'),
    is.null(attr(single, 'failed'))
  )
  # Every element is validated before any request.
  sent <- length(history())
  error <- tryCatch(runtime$get_item(c('a', NA)), error = identity)
  stopifnot(inherits(error, 'error'), length(history()) == sent)
  # The runtime option overrides the generated on_error default.
  withr::with_options(
    list(iterationclient.api_request.batching = list(on_error = 'stop')),
    {
      error <- tryCatch(runtime$get_item(c('a', 'bad')), error = identity)
      stopifnot(
        inherits(error, 'error'),
        grepl('HTTP 404', conditionMessage(error))
      )
    }
  )
  # Query fan-out concatenates array responses; on_error defaults to stop.
  sent <- length(history())
  found <- runtime$search(c('x', 'y'))
  stopifnot(
    length(history()) - sent == 2L,
    identical(
      vapply(found, `[[`, character(1), 'name'),
      c('x', 'related', 'y', 'related')
    )
  )
  error <- tryCatch(runtime$search(c('x', 'bad')), error = identity)
  stopifnot(inherits(error, 'error'))
  # Split: an array body larger than max_items is sent in chunks of max_items.
  sent <- length(history())
  bulk <- runtime$bulk(letters[1:5])
  wire <- history()
  stopifnot(
    identical(
      vapply(wire[-seq_len(sent)], `[[`, character(1), 'body'),
      c('["a","b"]', '["c","d"]', '["e"]')
    ),
    identical(vapply(bulk, `[[`, character(1), 'item'), letters[1:5])
  )
  error <- tryCatch(runtime$bulk(c('a', 'b', 'bad')), error = identity)
  stopifnot(inherits(error, 'error'))
  # Data frames from hooks or policies are stacked, filling missing columns.
  stacked <- runtime$api_request_combine(list(
    data.frame(a = 1L),
    NULL,
    data.frame(a = 2L, b = 'x')
  ))
  stopifnot(
    identical(stacked$a, 1:2),
    identical(stacked$b, c(NA, 'x')),
    identical(runtime$api_request_combine(list()), list())
  )
  # A helper without the runner fails generation with a clear message.
  helper <- file.path(root, 'R/api_request.R')
  text <- readLines(helper)
  start <- grep('^api_request_each <- ', text)
  writeLines(text[seq_len(start - 2L)], helper)
  error <- tryCatch(run(), error = identity)
  stopifnot(
    inherits(error, 'error'),
    grepl(
      'api_request_each() and api_request_combine()',
      conditionMessage(error),
      fixed = TRUE
    )
  )
  cat(
    'Batch iteration: fan-out, split, per-request hooks, attribution, failure records, option precedence and helper adoption passed.\n'
  )
}

if (sys.nframe() == 0L) {
  batch_iteration_acceptance()
}
