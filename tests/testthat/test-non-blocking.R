non_blocking_acceptance <- function() {
  for (package in c(
    'mirai',
    'promises',
    'later',
    'cachem',
    'rlang',
    'httpuv',
    'callr',
    'withr',
    'httr2'
  )) {
    if (!requireNamespace(package, quietly = TRUE)) {
      skip(paste0('Skipping non-blocking calls: ', package, ' is not installed'))
    }
  }
  workspace <- tempfile('non-blocking-')
  dir.create(workspace)
  # Deferred cleanups run newest first, so the workspace goes last, after the
  # workers and the server that use it have stopped.
  withr::defer(unlink(workspace, recursive = TRUE))
  # Disk entries go to a private directory, never the user's real cache.
  withr::local_envvar(c(R_USER_CACHE_DIR = file.path(workspace, 'user-cache')))
  port_file <- file.path(workspace, 'port')
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      counts <- list()
      httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          json <- function(value, status = 200L) {
            list(
              status = status,
              headers = list('Content-Type' = 'application/json'),
              body = jsonlite::toJSON(value, auto_unbox = TRUE, null = 'null')
            )
          }
          if (req$PATH_INFO == '/counts') {
            return(json(counts))
          }
          path <- req$PATH_INFO
          counts[[path]] <<- (if (is.null(counts[[path]])) {
            0L
          } else {
            counts[[path]]
          }) +
            1L
          if (path == '/fail') {
            return(json(list(message = 'unavailable'), 503L))
          }
          if (path == '/slow') {
            Sys.sleep(0.5)
          }
          json(list(n = counts[[path]], key = req$HTTP_X_KEY))
        })
      )
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    args = list(port_file = port_file),
    supervise = TRUE
  )
  withr::defer(server$kill())
  for (i in seq_len(200L)) {
    if (file.exists(port_file)) {
      break
    }
    if (!server$is_alive()) {
      stop(server$get_error())
    }
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  base <- paste0('http://127.0.0.1:', readLines(port_file))
  counts <- function() {
    httr2::resp_body_json(
      httr2::req_perform(httr2::request(paste0(base, '/counts'))),
      simplifyVector = FALSE
    )
  }
  ok <- list('200' = list(description = 'OK'))
  text <- list(name = 'q', `in` = 'query', schema = list(type = 'string'))
  read <- function(id, ...) {
    list(get = c(list(operationId = id, responses = ok), list(...)))
  }
  schema <- file.path(workspace, 'schema.json')
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Non-blocking', version = '1'),
      servers = list(list(url = base)),
      security = list(list(key = list())),
      paths = list(
        '/slow' = read('slow_read'),
        '/disk' = read('on_disk', parameters = list(text)),
        '/memory' = read('in_memory', parameters = list(text)),
        '/fail' = read('failing')
      ),
      components = list(
        securitySchemes = list(
          key = list(type = 'apiKey', `in` = 'header', name = 'X-Key')
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  root <- file.path(workspace, 'client')
  invisible(specmill::initialize_client(
    root = root,
    schema = schema,
    package = 'noblockclient',
    title = 'Non-blocking client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT',
    companions = 'cache'
  ))
  read_yaml <- function(path) {
    yaml::read_yaml(path, handlers = list(seq = function(x) x))
  }
  variable <- read_yaml(file.path(root, 'specmill.yml'))$authentication$key
  service_path <- list.files(file.path(root, 'apis'), full.names = TRUE)[[1L]]
  service <- read_yaml(service_path)
  service$operations[['GET /disk']]$response_cache <- list(store = 'disk')
  service$operations[['GET /memory']]$response_cache <- list(store = 'memory')
  yaml::write_yaml(service, service_path)
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  stopifnot(
    'export(slow_read)' %in% readLines(file.path(root, 'NAMESPACE'))
  )
  # A worker is a fresh R process, so it needs the client installed.
  library <- file.path(workspace, 'library')
  install_log <- file.path(workspace, 'install.log')
  dir.create(library)
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
  # Local workers inherit the environment that exists when they start: the
  # library path, the cache directory and the credential. A user .Renviron
  # would override those at worker startup, so the workers read an empty one.
  environ <- file.path(workspace, 'Renviron')
  file.create(environ)
  withr::local_envvar(c(
    stats::setNames('alpha', variable),
    R_LIBS = paste(c(library, .libPaths()), collapse = .Platform$path.sep),
    R_ENVIRON_USER = environ
  ))
  withr::local_libpaths(library, action = 'prefix')
  withr::defer(unloadNamespace('noblockclient'))
  profile <- 'specmill-non-blocking'
  mirai::daemons(1L, .compute = profile)
  withr::defer(mirai::daemons(0L, .compute = profile))
  # Runs the event loop until the promise settles, as Shiny does between events.
  settle <- function(promise) {
    state <- new.env()
    promises::then(
      promise,
      onFulfilled = function(value) {
        state$value <- value
        state$done <- TRUE
      },
      onRejected = function(error) {
        state$error <- error
        state$done <- TRUE
      }
    )
    state$ticks <- 0L
    while (!isTRUE(state$done) && state$ticks < 3000L) {
      later::run_now(0.02)
      state$ticks <- state$ticks + 1L
    }
    stopifnot(isTRUE(state$done))
    state
  }
  # The call returns at once and the session keeps running while the worker
  # waits for the service.
  task <- mirai::mirai(noblockclient::slow_read(), .compute = profile)
  pending <- mirai::unresolved(task)
  slow <- settle(task)
  stopifnot(
    pending,
    slow$ticks > 1L,
    is.null(slow$error),
    slow$value$n == 1L
  )
  # The worker is another process and sends the credential it inherited.
  remote <- settle(mirai::mirai(
    list(
      result = noblockclient::in_memory(q = 'a'),
      pid = Sys.getpid(),
      cache = tools::R_user_dir('noblockclient', 'cache')
    ),
    .compute = profile
  ))
  stopifnot(
    remote$value$pid != Sys.getpid(),
    # The worker's disk store is inside the workspace, not a real user cache.
    startsWith(
      normalizePath(remote$value$cache, winslash = '/', mustWork = FALSE),
      normalizePath(workspace, winslash = '/')
    ),
    identical(remote$value$result$key, 'alpha'),
    remote$value$result$n == 1L
  )
  # A failed request rejects the promise with an error that carries the
  # wrapper's message.
  failed <- settle(mirai::mirai(noblockclient::failing(), .compute = profile))
  stopifnot(
    is.null(failed$value),
    inherits(failed$error, 'error'),
    grepl('503', conditionMessage(failed$error), fixed = TRUE)
  )
  # A disk store is shared between the worker and the session.
  stored <- settle(mirai::mirai(
    noblockclient::on_disk(q = 'a'),
    .compute = profile
  ))
  stopifnot(
    identical(noblockclient::on_disk(q = 'a'), stored$value),
    counts()[['/disk']] == 1L
  )
  # A memory store belongs to one process: the session asks again, the worker
  # still has its own entry.
  local_again <- noblockclient::in_memory(q = 'a')
  remote_again <- settle(mirai::mirai(
    noblockclient::in_memory(q = 'a'),
    .compute = profile
  ))
  stopifnot(
    local_again$n == 2L,
    identical(remote_again$value, remote$value$result),
    counts()[['/memory']] == 2L
  )
  # Shiny's ExtendedTask takes the same call and reports its progress.
  if (requireNamespace('shiny', quietly = TRUE)) {
    extended <- shiny::ExtendedTask$new(function(q) {
      mirai::mirai(noblockclient::on_disk(q = q), q = q, .compute = profile)
    })
    extended$invoke('b')
    running <- shiny::isolate(extended$status())
    ticks <- 0L
    while (shiny::isolate(extended$status()) == 'running' && ticks < 3000L) {
      later::run_now(0.02)
      ticks <- ticks + 1L
    }
    stopifnot(
      running == 'running',
      shiny::isolate(extended$status()) == 'success',
      shiny::isolate(extended$result())$n == 2L,
      identical(shiny::isolate(extended$result())$key, 'alpha')
    )
  }
  cat(
    'Non-blocking calls: worker promise, inherited credential, rejection, shared disk store, private memory store and ExtendedTask passed.\n'
  )
}
test_that('non-blocking calls use workers, shared stores and ExtendedTask', {
  non_blocking_acceptance()
  succeed()
})
