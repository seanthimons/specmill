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
            if (id == 'denied') {
              return(json(list(error = 'no key'), 401L))
            }
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
  bad <- original
  bad$operations[['GET /items/{id}']] <- list(
    batch = list(fan_out = 'id', on_error = 'drop', empty = 'no_such_empty')
  )
  fails(bad, 'Missing client batch.empty function')
  bad <- original
  bad$operations[['GET /items/{id}']] <- list(
    batch = list(fan_out = 'id', empty = 'no_such_empty')
  )
  fails(bad, 'batch.empty requires batch.on_error: drop')
  bad <- original
  bad$operations[['GET /search']] <- list(batch = list(empty = 'no_such_empty'))
  fails(bad, 'batch.empty requires batch.fan_out or batch.split')
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
  # on_error: drop covers per-item failures only. A call-level error (here an invalid
  # runtime option) stops the call once: no warnings, no requests, no partial result (#97).
  sent <- length(history())
  warnings <- character()
  error <- withr::with_options(
    list(iterationclient.request = list(timeout = -1)),
    withCallingHandlers(
      tryCatch(runtime$get_item(c('a', 'b')), error = identity),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart('muffleWarning')
      }
    )
  )
  stopifnot(
    inherits(error, 'specmill_call_error'),
    grepl('timeout must be', conditionMessage(error)),
    !length(warnings),
    length(history()) == sent
  )
  # Missing credentials raise the same class from the authentication template, once.
  auth <- new.env(parent = runtime)
  auth$AUTH_ENVVARS <- c(key = 'ITERATION_TEST_MISSING_KEY')
  sys.source(
    if (file.exists('inst/templates/authentication.R')) {
      'inst/templates/authentication.R'
    } else {
      system.file(
        'templates/authentication.R',
        package = 'specmill',
        mustWork = TRUE
      )
    },
    auth
  )
  requirements <- list(list(list(
    scheme = 'key',
    type = 'apiKey',
    envvar = 'ITERATION_TEST_MISSING_KEY',
    location = 'header',
    name = 'x-api-key'
  )))
  calls <- 0L
  withr::local_envvar(ITERATION_TEST_MISSING_KEY = NA)
  warnings <- character()
  error <- withCallingHandlers(
    tryCatch(
      runtime$api_request_each(
        function(chunk) {
          calls <<- calls + 1L
          auth$api_auth(httr2::request('http://127.0.0.1'), requirements)
        },
        c('a', 'b', 'c'),
        1L,
        on_error = 'drop'
      ),
      error = identity
    ),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart('muffleWarning')
    }
  )
  stopifnot(
    inherits(error, 'specmill_call_error'),
    grepl('scheme = "key"', conditionMessage(error), fixed = TRUE),
    calls == 1L,
    !length(warnings)
  )
  # Other failures in the same wrapper are still dropped and recorded.
  dropped <- suppressWarnings(runtime$api_request_each(
    function(chunk) {
      if (identical(chunk, 'b')) {
        stop('item failed')
      }
      list(chunk)
    },
    c('a', 'b'),
    1L,
    on_error = 'drop'
  ))
  stopifnot(identical(attr(dropped, 'failed'), c(b = 'item failed')))
  # When drop leaves nothing, `empty` supplies the result; failures are still recorded. Without it the result stays list().
  all_failed <- function(...) {
    suppressWarnings(runtime$api_request_each(
      function(chunk) stop('item failed'),
      c('a', 'b'),
      1L,
      on_error = 'drop',
      ...
    ))
  }
  nothing <- all_failed()
  stopifnot(
    identical(length(nothing), 0L),
    is.list(nothing),
    identical(names(attr(nothing, 'failed')), c('a', 'b'))
  )
  table <- all_failed(empty = function() data.frame())
  stopifnot(
    is.data.frame(table),
    identical(nrow(table), 0L),
    identical(names(attr(table, 'failed')), c('a', 'b'))
  )
  # A partial failure is not empty.
  partial <- suppressWarnings(runtime$api_request_each(
    function(chunk) if (identical(chunk, 'b')) stop('x') else list(chunk),
    c('a', 'b'),
    1L,
    on_error = 'drop',
    empty = function() data.frame()
  ))
  stopifnot(is.list(partial), !is.data.frame(partial), length(partial) == 1L)
  # A rejected credential (401) stops the call once; a 404 is still dropped.
  warnings <- character()
  error <- withCallingHandlers(
    tryCatch(runtime$get_item(c('a', 'denied', 'b')), error = identity),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart('muffleWarning')
    }
  )
  stopifnot(
    inherits(error, 'specmill_call_error'),
    grepl('HTTP 401', conditionMessage(error)),
    !length(warnings)
  )
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
  # The runtime max_items lowers the split chunk size, never above the generated cap.
  withr::with_options(
    list(iterationclient.api_request.batching = list(max_items = 1L)),
    {
      sent <- length(history())
      runtime$bulk(letters[1:3])
      stopifnot(
        identical(
          vapply(history()[-seq_len(sent)], `[[`, character(1), 'body'),
          c('["a"]', '["b"]', '["c"]')
        )
      )
      # Fan-out still sends one item per request.
      sent <- length(history())
      runtime$search(c('x', 'y'))
      stopifnot(length(history()) - sent == 2L)
    }
  )
  for (bad in list(3L, 0L, 1.5, NA_real_, 'two', c(1L, 2L))) {
    withr::with_options(
      list(iterationclient.api_request.batching = list(max_items = bad)),
      {
        sent <- length(history())
        error <- tryCatch(runtime$bulk(letters[1:3]), error = identity)
        stopifnot(
          grepl(
            'max_items must be a whole number from 1 to 2',
            conditionMessage(error)
          ),
          length(history()) == sent
        )
      }
    )
  }
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
  # A reviewed policy uses actual request count after effective chunk sizing.
  counted_service <- original
  counted_service$operations[['GET /items/{id}']] <- list(
    batch = list(
      fan_out = 'id',
      on_error = list(single = 'stop', multiple = 'drop'),
      empty = 'empty_result'
    )
  )
  counted_service$operations[['GET /items/{id}']]$normalize_inputs <- list(
    id = 'normalize_ids'
  )
  counted_service$operations[['POST /bulk']] <- list(
    batch = list(
      max_items = 2L,
      split = TRUE,
      on_error = list(single = 'stop', multiple = 'drop'),
      empty = 'empty_result'
    )
  )
  writeLines(
    c(
      'empty_result <- function() list()',
      'normalize_ids <- function(x) unique(x)'
    ),
    file.path(root, 'R/hooks.R')
  )
  yaml::write_yaml(counted_service, service_path)
  run()
  run('check')
  counted <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, counted)
  }
  # Actual received HTTP failures follow the same choice unless a client response
  # policy has already handled them before decoding.
  error <- tryCatch(counted$get_item('bad'), error = identity)
  stopifnot(inherits(error, 'error'))
  partial <- suppressWarnings(counted$get_item(c('a', 'bad')))
  stopifnot(length(partial) == 1L, identical(partial[[1L]]$id, 'a'))
  original_request <- counted$api_request
  counted$api_request <- function(...) stop('transport sentinel')
  for (invoke in list(counted$get_item, counted$bulk)) {
    error <- tryCatch(invoke('one'), error = identity)
    stopifnot(
      inherits(error, 'error'),
      identical(conditionMessage(error), 'transport sentinel')
    )
  }
  error <- tryCatch(counted$get_item(c('one', 'one')), error = identity)
  stopifnot(
    inherits(error, 'error'),
    identical(conditionMessage(error), 'transport sentinel')
  )
  # Two entries in one array request still abort; lowering the session limit
  # creates two requests and switches to the reviewed multiple-request branch.
  error <- tryCatch(counted$bulk(c('a', 'b')), error = identity)
  stopifnot(inherits(error, 'error'))
  result <- withr::with_options(
    list(iterationclient.api_request.batching = list(max_items = 1L)),
    suppressWarnings(counted$bulk(c('a', 'b')))
  )
  stopifnot(identical(names(attr(result, 'failed')), c('a', 'b')))
  counted$api_request <- function(...) {
    stop(errorCondition('credential sentinel', class = 'specmill_call_error'))
  }
  for (input in list('a', c('a', 'b'))) {
    error <- tryCatch(counted$get_item(input), error = identity)
    stopifnot(inherits(error, 'specmill_call_error'))
  }
  counted$api_request <- original_request
  # Session literal policies still override the operation choice.
  result <- withr::with_options(
    list(iterationclient.api_request.batching = list(on_error = 'drop')),
    suppressWarnings(counted$get_item('bad'))
  )
  stopifnot(identical(names(attr(result, 'failed')), 'bad'))
  for (policy in list(
    list(single = 'stop'),
    list(single = 'ignore', multiple = 'drop'),
    list(single = 'stop', multiple = 'drop', other = 'stop')
  )) {
    bad <- counted_service
    bad$operations[['GET /items/{id}']]$batch$on_error <- policy
    fails(bad, 'batch.on_error')
  }
  # Operation warning formatters see the original dropped condition and chunk.
  warning_service <- counted_service
  warning_service$operations[[
    'GET /items/{id}'
  ]]$batch$warning <- 'failure_warning'
  warning_service$operations[['POST /bulk']]$batch$warning <- 'failure_warning'
  cat(
    '\nfailure_warning <- function(error, items) paste0("Legacy ", paste(items, collapse = ", "), ": ", conditionMessage(error))\n',
    file = file.path(root, 'R/hooks.R'),
    append = TRUE
  )
  yaml::write_yaml(warning_service, service_path)
  run()
  run('check')
  formatted <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, formatted)
  }
  capture <- function(expr) {
    warnings <- character()
    value <- withCallingHandlers(
      tryCatch(expr, error = identity),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart('muffleWarning')
      }
    )
    list(value = value, warnings = warnings)
  }
  get <- capture(formatted$get_item(c('a', 'bad')))
  post <- capture(formatted$bulk(c('a', 'b', 'bad')))
  stopifnot(
    length(get$warnings) == 1L,
    startsWith(get$warnings, 'Legacy bad: '),
    length(post$warnings) == 1L,
    startsWith(post$warnings, 'Legacy bad: '),
    identical(get$value[[1L]]$id, 'a'),
    length(post$value) == 2L,
    inherits(capture(formatted$get_item('bad'))$value, 'error'),
    !length(capture(formatted$get_item('bad'))$warnings)
  )
  denied <- capture(formatted$get_item(c('a', 'denied')))
  stopifnot(
    inherits(denied$value, 'specmill_call_error'),
    !length(denied$warnings)
  )
  formatted$failure_warning <- function(error, items) {
    sprintf(
      'API request to "bulk" failed for "%s" with status %s',
      paste(items, collapse = ', '),
      error$status
    )
  }
  exact <- withr::with_options(
    list(iterationclient.response_policy = function(response, context, decode) {
      if (context$status >= 400L && context$status != 401L) {
        stop(errorCondition(
          'request failed',
          status = context$status,
          class = 'client_http_error'
        ))
      }
      decode()
    }),
    capture(formatted$bulk(c('a', 'b', 'bad')))
  )
  stopifnot(identical(
    exact$warnings,
    'API request to "bulk" failed for "bad" with status 500'
  ))
  formatted$failure_warning <- function(error, items) NULL
  stopifnot(!length(capture(formatted$get_item(c('a', 'bad')))$warnings))
  for (invalid in list(NA_character_, '', c('one', 'two'), FALSE)) {
    formatted$failure_warning <- function(error, items) invalid
    stopifnot(inherits(
      capture(formatted$get_item(c('a', 'bad')))$value,
      'specmill_call_error'
    ))
  }
  formatted$failure_warning <- function(error, items) stop('formatter sentinel')
  stopifnot(inherits(
    capture(formatted$get_item(c('a', 'bad')))$value,
    'specmill_call_error'
  ))
  # Structured client errors retain status and chunk data without parsing messages.
  seen <- NULL
  result <- formatted$api_request_each(
    function(items) {
      stop(errorCondition(
        'HTTP failure',
        status = 500L,
        class = 'client_http_error'
      ))
    },
    c('one', 'two'),
    1L,
    on_error = 'drop',
    warning = function(error, items) {
      seen <<- c(seen, error$status)
      NULL
    }
  )
  stopifnot(
    identical(seen, c(500L, 500L)),
    length(attr(result, 'failed')) == 2L
  )
  warning_service$operations[['GET /items/{id}']]$batch$warning <- FALSE
  yaml::write_yaml(warning_service, service_path)
  run()
  silent <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, silent)
  }
  stopifnot(!length(capture(silent$get_item(c('a', 'bad')))$warnings))
  for (choice in list(
    TRUE,
    1L,
    list('failure_warning'),
    'missing_warning',
    'get_item'
  )) {
    bad <- warning_service
    bad$operations[['GET /items/{id}']]$batch$warning <- choice
    fails(bad, 'batch.warning')
  }
  bad <- original
  bad$operations[['GET /items/{id}']] <- list(batch = list(warning = FALSE))
  fails(bad, 'batch.warning requires batch.fan_out or batch.split')
  bad$operations[['GET /items/{id}']]$batch$fan_out <- 'id'
  fails(bad, 'batch.warning requires batch.on_error: drop')
  bad <- warning_service
  bad$defaults$batch$warning <- FALSE
  fails(bad, 'batch.warning belongs under operations')
  # A pre-policy runner must be explicitly adopted before the wrapper uses it.
  yaml::write_yaml(warning_service, service_path)
  helper <- file.path(root, 'R/api_request.R')
  helper_text <- readLines(helper)
  writeLines(sub(', warning = NULL)', ')', helper_text, fixed = TRUE), helper)
  error <- tryCatch(run(), error = identity)
  stopifnot(
    inherits(error, 'error'),
    grepl('helper with a warning argument', conditionMessage(error))
  )
  writeLines(helper_text, helper)
  yaml::write_yaml(counted_service, service_path)
  run()
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
