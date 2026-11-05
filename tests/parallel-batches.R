parallel_batches_acceptance <- function() {
  root <- tempfile('parallel-client-')
  schema <- tempfile(fileext = '.json')
  ready <- tempfile()
  on.exit(unlink(c(root, schema, ready), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(ready) {
      active <- peak <- 0L
      history <- completed <- character()
      port <- httpuv::randomPort()
      json <- function(x, status = 200L) {
        list(
          status = status,
          headers = list('Content-Type' = 'application/json'),
          body = jsonlite::toJSON(x, auto_unbox = TRUE)
        )
      }
      httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          if (req$PATH_INFO == '/history') {
            return(json(list(
              peak = peak,
              history = history,
              completed = completed
            )))
          }
          if (req$PATH_INFO == '/reset') {
            peak <<- 0L
            history <<- completed <<- character()
            return(json(list()))
          }
          id <- sub('^/items/', '', req$PATH_INFO)
          if (req$PATH_INFO == '/bulk') {
            id <- unlist(jsonlite::fromJSON(rawToChar(req$rook.input$read())))
          }
          label <- paste(id, collapse = ',')
          history <<- c(history, label)
          active <<- active + 1L
          peak <<- max(peak, active)
          promises::promise(function(resolve, reject) {
            later::later(
              function() {
                active <<- active - 1L
                completed <<- c(completed, label)
                status <- if ('denied' %in% id) {
                  401L
                } else if ('bad' %in% id) {
                  404L
                } else if ('rate' %in% id) {
                  429L
                } else {
                  200L
                }
                resolve(json(lapply(id, function(x) list(id = x)), status))
              },
              if ('slow' %in% id) 1 else 0.3
            )
          })
        })
      )
      writeLines(as.character(port), ready)
      repeat {
        httpuv::service(10)
        later::run_now(0)
      }
    },
    list(ready),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  for (i in seq_len(400L)) {
    if (file.exists(ready)) {
      break
    }
    if (!server$is_alive()) {
      server$get_result()
    }
    Sys.sleep(0.025)
  }
  stopifnot(file.exists(ready))
  origin <- paste0('http://127.0.0.1:', readLines(ready))
  # The fixture speaks HTTP/1.1. Avoid curl waiting for HTTP/2 negotiation
  # before opening another connection to a server that delays its headers.
  perform_parallel <- httr2::req_perform_parallel
  testthat::local_mocked_bindings(
    req_perform_parallel = function(reqs, ...) {
      perform_parallel(lapply(reqs, httr2::req_options, http_version = 1L), ...)
    },
    .package = 'httr2'
  )
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Parallel', version = '1'),
      servers = list(list(url = origin)),
      paths = list(
        '/items/{id}' = list(
          get = list(
            operationId = 'item',
            parameters = list(
              list(
                name = 'id',
                `in` = 'path',
                required = TRUE,
                schema = list(type = 'string')
              )
            ),
            responses = list('200' = list(description = 'OK'))
          )
        ),
        '/bulk' = list(
          post = list(
            operationId = 'bulk',
            requestBody = list(
              required = TRUE,
              content = list(
                'application/json' = list(
                  schema = list(type = 'array', items = list(type = 'string'))
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
    package = 'parallelclient',
    title = 'Parallel Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT'
  )
  path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(path, handlers = list(seq = function(x) x))
  service$defaults$request_controls <- list(
    throttle = list(capacity = 100L, fill_time_s = 1)
  )
  service$operations[['GET /items/{id}']] <- list(
    batch = list(fan_out = 'id', concurrency = 2L, on_error = 'drop')
  )
  service$operations[['POST /bulk']] <- list(
    batch = list(split = TRUE, max_items = 2L, concurrency = 2L),
    result_formatter = 'finish_bulk',
    post_response_scope = 'combined'
  )
  service$defaults$response_policy <- 'context_policy'
  service$hooks <- list(
    item = list(pre_request = list('record'), post_response = list('record')),
    bulk = list(post_response = list('record'))
  )
  writeLines(
    c(
      'finish_bulk <- function(data) {',
      '  options(parallelclient.formatted = c(getOption("parallelclient.formatted"), length(data$params$body)))',
      '  data$result',
      '}',
      'context_policy <- function(response, context, decode) {',
      '  result <- decode()',
      '  if (context$method == "GET") for (i in seq_along(result)) result[[i]]$query <- context$query',
      '  result',
      '}',
      'record <- function(state) state',
      'run_hook <- function(fn_name, hook_type, state) {',
      '  if (fn_name == "bulk") { options(parallelclient.combined = c(getOption("parallelclient.combined"), length(state$params$body))); return(state$result) }',
      '  options(parallelclient.events = c(getOption("parallelclient.events"), paste(hook_type, state$params$id)))',
      '  if (hook_type == "pre_request" && identical(state$params$id, "skip")) return(list(skip_request = TRUE, result = list(list(id = "cached"))))',
      '  if (hook_type == "pre_request") state else state$result',
      '}'
    ),
    file.path(root, 'R/hooks.R')
  )
  generate <- function() {
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'apply',
      validation = FALSE
    )
  }
  yaml::write_yaml(service, path)
  generate()
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  fetch <- function(path) {
    httr2::resp_body_json(httr2::req_perform(httr2::request(paste0(
      origin,
      path
    ))))
  }
  history <- function() fetch('/history')
  reset <- function() invisible(fetch('/reset'))
  capture <- function(expr) tryCatch(force(expr), error = identity)
  ids <- function(x) vapply(x, `[[`, character(1), 'id')
  withr::local_options(
    parallelclient.events = NULL,
    parallelclient.formatted = NULL,
    parallelclient.combined = NULL
  )
  input <- c('slow', 'fast', 'fast', 'end')
  result <- runtime$item(input)
  stopifnot(
    identical(unname(ids(result)), unname(input)),
    identical(vapply(result, `[[`, character(1), 'query'), input),
    history()$peak == 2L,
    history()$completed[[1L]] == 'fast',
    identical(
      getOption('parallelclient.events'),
      c(paste('pre_request', input), paste('post_response', input))
    )
  )
  reset()
  stopifnot(
    identical(
      ids(runtime$bulk(c('slow', 'a', 'b', 'c', 'd'))),
      c('slow', 'a', 'b', 'c', 'd')
    ),
    history()$peak == 2L,
    length(history()$history) == 3L,
    identical(getOption('parallelclient.formatted'), 5L),
    identical(getOption('parallelclient.combined'), 5L)
  )
  reset()
  result <- suppressWarnings(runtime$item(c('slow', 'bad', 'fast')))
  stopifnot(
    identical(ids(result), c('slow', 'fast')),
    'bad' %in% names(attr(result, 'failed'))
  )
  stopifnot(inherits(
    capture(suppressWarnings(runtime$item(c('denied', 'fast')))),
    'specmill_call_error'
  ))
  # A hook that replaces its result must not suppress decoding or HTTP failures.
  normal_hook <- runtime$run_hook
  runtime$run_hook <- function(fn_name, hook_type, state) {
    if (hook_type == 'pre_request') state else list(list(id = 'constant'))
  }
  stopifnot(inherits(
    capture(runtime$item(c('denied', 'fast'))),
    'specmill_call_error'
  ))
  runtime$run_hook <- normal_hook
  result <- suppressWarnings(runtime$item(c('rate', 'fast')))
  stopifnot(
    identical(ids(result), 'fast'),
    'rate' %in% names(attr(result, 'failed'))
  )
  reset()
  stopifnot(
    identical(ids(runtime$item(c('skip', 'fast'))), c('cached', 'fast')),
    identical(unlist(history()$history), 'fast')
  )
  withr::with_options(
    list(parallelclient.api_request.batching = list(on_error = 'stop')),
    {
      stopifnot(inherits(capture(runtime$item(c('bad', 'fast'))), 'error'))
    }
  )
  result <- suppressWarnings(runtime$item(c('bad', 'rate')))
  stopifnot(length(result) == 0L, length(attr(result, 'failed')) == 2L)
  # Parallel preflight rejects unsupported controls before sending any request.
  reset()
  withr::with_options(list(parallelclient.request = list(max_retries = 1)), {
    error <- capture(runtime$item(c('a', 'b')))
    stopifnot(
      grepl('max_retries = 0', conditionMessage(error)),
      length(history()$history) == 0L
    )
  })
  withr::with_options(
    list(
      parallelclient.request = list(
        throttle = list(capacity = -1, fill_time_s = 1)
      )
    ),
    {
      stopifnot(
        inherits(capture(runtime$item(c('a', 'b'))), 'specmill_call_error'),
        length(history()$history) == 0L
      )
    }
  )
  stopifnot(
    inherits(capture(runtime$item(c('a', NA_character_))), 'error'),
    length(history()$history) == 0L
  )
  withr::with_options(
    list(parallelclient.api_request.batching = list(on_error = 'stop')),
    {
      stopifnot(
        inherits(capture(runtime$item(character())), 'error'),
        length(history()$history) == 0L
      )
    }
  )
  mixed <- function(chunk, prepare = FALSE) {
    runtime$api_request(
      'GET',
      '/items/fast',
      list(),
      list(),
      NULL,
      server = list(url = if (chunk == 'a') origin else 'http://127.0.0.1:1'),
      request_controls = service$defaults$request_controls,
      .prepare = prepare
    )
  }
  error <- capture(runtime$api_request_each(
    mixed,
    c('a', 'b'),
    1L,
    concurrency = 2L
  ))
  stopifnot(
    grepl('one service origin', conditionMessage(error)),
    length(history()$history) == 0L
  )
  # An interrupted group must prevent submission of later groups.
  local({
    calls <- 0L
    testthat::local_mocked_bindings(
      req_perform_parallel = function(reqs, ...) {
        calls <<- calls + 1L
        vector('list', length(reqs))
      },
      .package = 'httr2'
    )
    error <- capture(runtime$item(c('a', 'b', 'c')))
    stopifnot(
      calls == 1L,
      grepl('interrupted', conditionMessage(error)),
      length(history()$history) == 0L
    )
  })
  # Dry runs return prepared requests without hooks for unreceived responses.
  options(parallelclient.events = NULL)
  withr::with_options(list(parallelclient.dry_run = TRUE), {
    result <- runtime$item(c('a', 'b'))
    stopifnot(
      length(history()$history) == 0L,
      length(getOption('parallelclient.events')) == 2L
    )
  })
  # Preparation preserves decoder and transport error behavior.
  pending <- runtime$api_request(
    'GET',
    '/items/fast',
    list(),
    list(),
    NULL,
    request_controls = service$defaults$request_controls,
    .prepare = TRUE
  )
  error <- capture(pending$complete(simpleError('sentinel')))
  stopifnot(identical(conditionMessage(error), 'sentinel'))
  no_throttle <- capture(runtime$api_request(
    'GET',
    '/items/fast',
    list(),
    list(),
    NULL,
    .prepare = TRUE
  ))
  stopifnot(
    inherits(no_throttle, 'specmill_call_error'),
    grepl('throttle', conditionMessage(no_throttle))
  )
  refused <- runtime$api_request(
    'GET',
    '/items/fast',
    list(),
    list(),
    NULL,
    server = list(url = 'http://127.0.0.1:1'),
    .prepare = TRUE,
    request_controls = service$defaults$request_controls
  )
  failure <- httr2::req_perform_parallel(
    list(refused$request),
    on_error = 'continue',
    progress = FALSE
  )[[1L]]
  stopifnot(
    inherits(failure, 'httr2_failure'),
    grepl(
      'before a response was received',
      conditionMessage(capture(refused$complete(failure)))
    )
  )
  preserved <- runtime$api_request(
    'GET',
    '/items/fast',
    list(),
    list(),
    NULL,
    .prepare = TRUE,
    request_controls = c(
      service$defaults$request_controls,
      list(preserve_errors = TRUE)
    )
  )
  stopifnot(identical(capture(preserved$complete(failure)), failure))
  # Generation rejects invalid settings and incompatible helpers without replacing them.
  original <- service
  for (value in list(0, -1, 1.5, Inf, NA, '2', c(1, 2))) {
    service <- original
    service$operations[['GET /items/{id}']]$batch$concurrency <- value
    yaml::write_yaml(service, path)
    stopifnot(grepl('concurrency', conditionMessage(capture(generate()))))
  }
  service <- original
  service$operations[['GET /items/{id}']]$pagination <- list(parameter = 'id')
  yaml::write_yaml(service, path)
  stopifnot(inherits(capture(generate()), 'error'))
  yaml::write_yaml(original, path)
  helper <- file.path(root, 'R/api_request.R')
  before <- readLines(helper)
  writeLines(
    sub('concurrency = 1L', 'old_concurrency = 1L', before, fixed = TRUE),
    helper
  )
  modified <- readLines(helper)
  stopifnot(
    grepl('current client helper', conditionMessage(capture(generate()))),
    identical(modified, readLines(helper))
  )
  writeLines(before, helper)
  generate()
  specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'check',
    validation = FALSE
  )
  # Exercise the installed client with a library path that cannot load specmill.
  library <- tempfile('parallel-library-')
  install_log <- tempfile()
  dir.create(library)
  on.exit(unlink(c(library, install_log), recursive = TRUE), add = TRUE)
  status <- system2(
    file.path(
      R.home('bin'),
      if (.Platform$OS.type == 'windows') 'R.exe' else 'R'
    ),
    c('CMD', 'INSTALL', paste0('--library=', shQuote(library)), shQuote(root)),
    stdout = install_log,
    stderr = install_log
  )
  if (status != 0L) {
    stop(paste(readLines(install_log), collapse = '\n'))
  }
  libraries <- .libPaths()[!file.exists(file.path(.libPaths(), 'specmill'))]
  runtime_packages <- c('httr2', 'jsonlite', 'curl')
  dependencies <- unique(c(
    runtime_packages,
    unlist(tools::package_dependencies(
      runtime_packages,
      utils::installed.packages(),
      which = c('Depends', 'Imports', 'LinkingTo'),
      recursive = TRUE
    ))
  ))
  for (package in setdiff(dependencies, 'R')) {
    source <- find.package(package)
    if (!dirname(source) %in% libraries) {
      stopifnot(file.copy(source, library, recursive = TRUE))
    }
  }
  callr::r(
    function() {
      stopifnot(!requireNamespace('specmill', quietly = TRUE))
      result <- parallelclient::item(c('a', 'b'))
      stopifnot(identical(
        vapply(result, `[[`, character(1), 'id'),
        c('a', 'b')
      ))
    },
    libpath = c(library, libraries)
  )
  # Explicit concurrency 1 keeps the ordinary interleaved synchronous lifecycle.
  service <- original
  service$operations[['GET /items/{id}']]$batch$concurrency <- 1L
  yaml::write_yaml(service, path)
  generate()
  sequential <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, sequential)
  }
  options(parallelclient.events = NULL)
  stopifnot(
    identical(ids(sequential$item(c('a', 'b'))), c('a', 'b')),
    identical(
      getOption('parallelclient.events'),
      c('pre_request a', 'post_response a', 'pre_request b', 'post_response b')
    )
  )
  # Customized helper names use the same preparation and completion contract.
  service <- original
  service$helper <- '.parallel_request'
  yaml::write_yaml(service, path)
  writeLines(
    gsub('api_request', '.parallel_request', before, fixed = TRUE),
    helper
  )
  generate()
  renamed <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, renamed)
  }
  stopifnot(identical(ids(renamed$item(c('a', 'b'))), c('a', 'b')))
  cat(
    'Parallel batches: overlap, cap, order, split, hooks, errors, preflight, dry runs and helper adoption passed.\n'
  )
}
if (sys.nframe() == 0L) {
  parallel_batches_acceptance()
}
