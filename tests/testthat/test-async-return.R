async_return_acceptance <- function() {
  for (package in c('promises', 'later', 'httpuv', 'callr', 'withr')) {
    if (!requireNamespace(package, quietly = TRUE)) {
      skip(paste0('Skipping promise return: ', package, ' is not installed'))
    }
  }
  root <- tempfile('async-client-')
  schema <- tempfile(fileext = '.json')
  ready <- tempfile()
  on.exit(unlink(c(root, schema, ready), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(ready) {
      port <- httpuv::randomPort()
      httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          id <- sub('^/(items|plain)/', '', req$PATH_INFO)
          # The server answers late, so a blocked caller is measurable.
          Sys.sleep(1)
          list(
            status = if (id == 'bad') 404L else 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(list(id = id), auto_unbox = TRUE)
          )
        })
      )
      writeLines(as.character(port), ready)
      repeat {
        httpuv::service(100)
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
  get <- function(id) {
    list(
      get = list(
        operationId = id,
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
    )
  }
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Async', version = '1'),
      servers = list(list(url = origin)),
      paths = list('/items/{id}' = get('item'), '/plain/{id}' = get('plain'))
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'asyncclient',
    title = 'Async Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT'
  )
  stopifnot(grepl(
    'later, promises',
    read.dcf(file.path(root, 'DESCRIPTION'))[1L, 'Suggests'],
    fixed = TRUE
  ))
  path <- file.path(root, 'apis/default.yml')
  original <- yaml::read_yaml(path, handlers = list(seq = function(x) x))
  original$operations[['GET /items/{id}']] <- list(async = TRUE)
  original$hooks <- list(item = list(post_response = list('record')))
  writeLines(
    c(
      'record <- function(state) state',
      'run_hook <- function(fn_name, hook_type, state) {',
      '  state$result$hooked <- TRUE',
      '  state$result',
      '}'
    ),
    file.path(root, 'R/hooks.R')
  )
  generate <- function(service = original) {
    yaml::write_yaml(service, path)
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'apply',
      validation = FALSE
    )
  }
  generate()
  runtime <- new.env(parent = baseenv())
  files <- list.files(file.path(root, 'R'), full.names = TRUE)
  for (file in files) {
    sys.source(file, runtime)
  }
  stopifnot(any(grepl(
    'HTTP and transport failures reject the promise',
    unlist(lapply(files, readLines)),
    fixed = TRUE
  )))
  capture <- function(expr) tryCatch(force(expr), error = identity)
  settle <- function(promise) {
    out <- NULL
    promises::then(
      promise,
      function(value) out <<- list(value = value),
      function(error) out <<- list(error = error)
    )
    deadline <- Sys.time() + 10
    while (is.null(out) && Sys.time() < deadline) {
      later::run_now(0.05)
    }
    out
  }
  # Without the session flag the reviewed operation is an ordinary call.
  expected <- runtime$item('a')
  stopifnot(identical(expected, list(id = 'a', hooked = TRUE)))
  withr::local_options(asyncclient.request = list(async = TRUE))
  # The first promise pays a one-time load cost, so measure the second.
  notices <- character()
  noted <- function(expr) {
    withCallingHandlers(expr, message = function(m) {
      notices <<- c(notices, conditionMessage(m))
      invokeRestart('muffleMessage')
    })
  }
  stopifnot(identical(settle(noted(runtime$item('a')))$value, expected))
  # The skipped throttle is announced on the first promise only.
  stopifnot(
    length(notices) == 1L,
    grepl('not throttled or retried', notices),
    identical(settle(noted(runtime$item('a')))$value, expected),
    length(notices) == 1L
  )
  started <- Sys.time()
  promise <- runtime$item('a')
  returned <- as.numeric(Sys.time() - started, units = 'secs')
  stopifnot(
    promises::is.promise(promise),
    # The server needs 1 s; the call came back before it answered.
    returned < 0.5,
    identical(settle(promise)$value, expected)
  )
  # Only reviewed operations change; the rest still return their value.
  stopifnot(identical(runtime$plain('a'), list(id = 'a')))
  # HTTP and transport failures reject; errors before the request still throw.
  stopifnot(
    grepl('404', conditionMessage(settle(runtime$item('bad'))$error)),
    inherits(capture(runtime$item()), 'error')
  )
  withr::with_options(
    list(
      asyncclient.request = list(async = TRUE, base_url = 'http://127.0.0.1:1')
    ),
    stopifnot(grepl(
      'before a response was received',
      conditionMessage(settle(runtime$item('a'))$error)
    ))
  )
  withr::with_options(
    list(asyncclient.dry_run = TRUE),
    stopifnot(inherits(runtime$item('a'), 'httr2_request'))
  )
  withr::with_options(
    list(asyncclient.request = list(async = 'yes')),
    stopifnot(inherits(capture(runtime$item('a')), 'specmill_call_error'))
  )
  # Generation rejects shapes a promise cannot honour and helpers without support.
  service <- original
  service$defaults$async <- TRUE
  stopifnot(grepl(
    'belongs under operations',
    conditionMessage(capture(generate(service)))
  ))
  service <- original
  service$operations[['GET /items/{id}']]$batch <- list(fan_out = 'id')
  stopifnot(grepl(
    'async requires',
    conditionMessage(capture(generate(service)))
  ))
  service <- original
  service$operations[['GET /items/{id}']]$async <- 'yes'
  stopifnot(grepl(
    'async must be true or false',
    conditionMessage(capture(generate(service)))
  ))
  helper <- file.path(root, 'R/api_request.R')
  before <- readLines(helper)
  writeLines(
    sub('.async = FALSE', '.old = FALSE', before, fixed = TRUE),
    helper
  )
  stopifnot(grepl(
    'current client helper',
    conditionMessage(capture(generate()))
  ))
  writeLines(before, helper)
  generate()
  cat(
    'Promise return: opt-in, non-blocking, parity, failures, dry run and generation checks passed.\n'
  )
}
test_that('reviewed operations return promises under the session flag', {
  async_return_acceptance()
  succeed()
})
