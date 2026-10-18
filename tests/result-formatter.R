result_formatter_acceptance <- function() {
  root <- tempfile('post-combine-client-')
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(c(root, schema), recursive = TRUE), add = TRUE)
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
      info = list(title = 'Post combine', version = '1'),
      servers = list(list(url = 'http://127.0.0.1:1')),
      paths = list(
        '/items/{id}' = list(
          get = operation(
            'get_item',
            list(list(
              name = 'id',
              `in` = 'path',
              required = TRUE,
              schema = string
            ))
          )
        ),
        '/bulk' = list(
          post = operation(
            'bulk',
            body = list(type = 'array', items = string, maxItems = 2L)
          )
        ),
        '/plain' = list(get = operation('plain'))
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'combineclient',
    title = 'Combine Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  service_path <- file.path(root, 'apis/default.yml')
  original <- yaml::read_yaml(
    service_path,
    handlers = list(seq = function(x) x)
  )
  run <- function(mode = 'apply') {
    specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = mode
    )
  }
  writeLines(
    c(
      'send <- function(data) {',
      '  options(combineclient.final_params = data$params, combineclient.final_hook = attr(data$result, "hook_done"))',
      '  purrr::map(data$result, function(x) jsonlite::fromJSON(x))',
      '}',
      'keep_result <- function(data) data$result',
      'mark_result <- function(data) { attr(data$result, "hook_done") <- TRUE; data$result }',
      'normalize_id <- function(x) trimws(x)'
    ),
    file.path(root, 'R/formatters.R')
  )
  service <- original
  service$operations[['GET /items/{id}']] <- list(
    batch = list(fan_out = 'id', on_error = 'drop', metadata = FALSE),
    normalize_inputs = list(id = 'normalize_id'),
    result_formatter = 'send'
  )
  service$operations[['POST /bulk']] <- list(
    batch = list(max_items = 2L, split = TRUE),
    result_formatter = 'keep_result'
  )
  service$hooks <- list(get_item = list(post_combine = list('mark_result')))
  write <- function() yaml::write_yaml(service, service_path)
  fails <- function(pattern) {
    error <- tryCatch(run(), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  write()
  run()
  run('check')
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  runtime$run_hook <- function(fn_name, stage, state) {
    if (stage == 'post_combine') {
      return(runtime$mark_result(state))
    }
    state
  }
  requests <- character()
  runtime$api_request <- function(method, path, path_params, query, body, ...) {
    requests <<- c(
      requests,
      if (length(path_params)) path_params$id else paste(body, collapse = ',')
    )
    if (length(path_params)) {
      if (path_params$id == 'denied') {
        stop(structure(
          list(message = 'denied', call = NULL),
          class = c('specmill_call_error', 'error', 'condition')
        ))
      }
      return(list(if (path_params$id == 'broken') '{broken' else '{"value":1}'))
    }
    as.list(body)
  }
  # A formatter named send resolves in the client, outside generated locals.
  result <- runtime$get_item(c(' a ', 'b'))
  stopifnot(
    length(result) == 2L,
    identical(requests, c('a', 'b')),
    identical(getOption('combineclient.final_params')$id, c('a', 'b'))
  )
  requests <- character()
  expected <- tryCatch(
    purrr::map(list('{broken'), jsonlite::fromJSON),
    error = identity
  )
  error <- tryCatch(runtime$get_item(c('broken', 'b')), error = identity)
  stopifnot(
    identical(requests, c('broken', 'b')),
    identical(class(error), class(expected)),
    inherits(error, 'purrr_error_indexed'),
    !inherits(error, 'specmill_call_error')
  )
  stopifnot(isTRUE(getOption('combineclient.final_hook')))
  warning_condition <- structure(
    list(message = 'format warning', call = NULL),
    class = c('client_format_warning', 'warning', 'condition')
  )
  seen <- NULL
  runtime$send <- function(data) {
    warning(warning_condition)
    'formatted'
  }
  value <- withCallingHandlers(
    runtime$get_item(c('a', 'b')),
    warning = function(w) {
      seen <<- w
      invokeRestart('muffleWarning')
    }
  )
  stopifnot(identical(seen, warning_condition), identical(value, 'formatted'))
  # Direct propagation retains the exact condition, not merely its class.
  condition <- structure(
    list(message = 'format failed', call = NULL),
    class = c('client_format_error', 'error', 'condition')
  )
  runtime$send <- function(data) stop(condition)
  error <- tryCatch(runtime$get_item(c('a', 'b')), error = identity)
  stopifnot(identical(error, condition))
  runtime$send <- function(data) NULL
  stopifnot(is.null(runtime$get_item(c('a', 'b'))))
  # Credential/call errors stop before final formatting and cannot be dropped.
  runtime$send <- function(data) stop('formatter must not run')
  requests <- character()
  error <- tryCatch(runtime$get_item(c('denied', 'b')), error = identity)
  stopifnot(
    inherits(error, 'specmill_call_error'),
    identical(requests, 'denied')
  )
  requests <- character()
  bulk <- runtime$bulk(c('a', 'b', 'c'))
  stopifnot(length(requests) == 2L, identical(unlist(bulk), c('a', 'b', 'c')))
  service$operations[[
    'GET /items/{id}'
  ]]$result_formatter <- 'missing_formatter'
  write()
  fails('Missing client result_formatter')
  service$operations[['GET /items/{id}']]$result_formatter <- 'get_item'
  write()
  fails('wrapper collision')
  service$operations[['GET /items/{id}']]$result_formatter <- 'not a name'
  write()
  fails('client function name')
  service$operations[['GET /items/{id}']]$result_formatter <- NULL
  service$defaults <- list(result_formatter = 'send')
  write()
  fails('belongs under operations')
  service$defaults <- NULL
  service$operations[['GET /plain']] <- list(result_formatter = 'send')
  write()
  run()
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  sent <- 0L
  runtime$api_request <- function(...) {
    sent <<- sent + 1L
    list('one', 'two')
  }
  seen <- NULL
  runtime$send <- function(data) {
    seen <<- data
    data$result
  }
  value <- runtime$plain()
  stopifnot(
    identical(value, list('one', 'two')),
    sent == 1L,
    identical(seen$params, list())
  )
  runtime$send <- function(data) stop(condition)
  stopifnot(identical(tryCatch(runtime$plain(), error = identity), condition))
  runtime$send <- function(data) NULL
  stopifnot(is.null(runtime$plain()))
  runtime$api_request <- function(...) httr2::request('http://127.0.0.1:1')
  runtime$send <- function(data) stop('must not format dry runs')
  stopifnot(inherits(runtime$plain(), 'httr2_request'))

  service$operations[['GET /plain']] <- list(
    request_controls = list(preserve_errors = TRUE)
  )
  write()
  run()
  generated <- paste(readLines(file.path(root, 'R/plain.R')), collapse = '\n')
  stopifnot(grepl('preserve_errors', generated, fixed = TRUE))
  service$operations[['GET /plain']]$request_controls$preserve_errors <- 'yes'
  write()
  fails('preserve_errors must be true or false')
  service$operations[['GET /plain']]$request_controls$preserve_errors <- TRUE
  helper_path <- file.path(root, 'R/api_request.R')
  helper <- readLines(helper_path)
  writeLines(
    gsub('preserve_errors', 'old_error_flag', helper, fixed = TRUE),
    helper_path
  )
  write()
  fails('needs the current client helper template')
  writeLines(helper, helper_path)
  service$operations[['GET /plain']]$preserve_visibility <- TRUE
  write()
  run()
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  runtime$api_request <- function(...) 'response'
  runtime$send <- function(data) invisible('formatted')
  visibility <- withVisible(runtime$plain())
  stopifnot(identical(visibility$value, 'formatted'), !visibility$visible)
  service$operations[['GET /plain']] <- list(
    implementation = 'existing',
    result_formatter = 'send'
  )
  write()
  fails('requires a generated implementation')
  cat(
    'Result formatter: complete inputs, late original conditions, NULL, split and hard errors passed.\n'
  )
}

if (sys.nframe() == 0L) {
  result_formatter_acceptance()
}
