dry_run_acceptance <- function() {
  withr::local_options(list(requestclient.dry_run = NULL, requestclient.run_verbose = NULL,
                           unrelatedclient.dry_run = TRUE))
  port_file <- tempfile('dry-run-port-')
  root <- tempfile('dry-run-client-')
  on.exit(unlink(c(root, port_file), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      request_number <- 0L
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          request_number <<- request_number + 1L
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(
              list(
                method = req$REQUEST_METHOD,
                path = req$PATH_INFO,
                request_number = request_number
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
  base_url <- paste0('http://127.0.0.1:', readLines(port_file))
  schema <- system.file(
    'catalogue/schema.json',
    package = 'specmill',
    mustWork = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'requestclient',
    title = 'Request Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'maintainer@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = base_url
  )
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  # The generated wrapper bakes in the per-package variable name.
  stopifnot(any(grepl(
    'REQUESTCLIENT_DRY_RUN',
    readLines(file.path(root, 'R', 'api_request.R')),
    fixed = TRUE
  )))
  Sys.unsetenv('REQUESTCLIENT_DRY_RUN')
  on.exit(Sys.unsetenv('REQUESTCLIENT_DRY_RUN'), add = TRUE)
  performed <- runtime$get_item('widget', 'fr')
  stopifnot(
    is.list(performed),
    identical(performed$method, 'GET'),
    identical(performed$path, '/items/widget'),
    identical(performed$request_number, 1L)
  )
  for (flag in c('true', '1', 'yes', 'TRUE', 'Yes')) {
    Sys.setenv(REQUESTCLIENT_DRY_RUN = flag)
    req <- runtime$get_item('widget', 'fr')
    stopifnot(
      inherits(req, 'httr2_request'),
      identical(req$method, 'GET'),
      grepl('/items/widget', req$url, fixed = TRUE),
      grepl('language=fr', req$url, fixed = TRUE)
    )
  }
  # Falsy or unrecognized values still perform.
  for (flag in c('', 'false', '0', 'no', 'maybe')) {
    Sys.setenv(REQUESTCLIENT_DRY_RUN = flag)
    stopifnot(!inherits(runtime$get_item('widget', 'fr'), 'httr2_request'))
  }
  Sys.unsetenv('REQUESTCLIENT_DRY_RUN')
  # Only performing calls reached the server: the 5 truthy dry-runs added nothing.
  # 1 initial + 5 falsy + this final = 7.
  final <- runtime$get_item('widget', 'fr')
  stopifnot(identical(final$request_number, 7L))
  stopifnot(all(c('export(requestclient_dry_run)', 'export(requestclient_run_verbose)') %in%
                  readLines(file.path(root, 'NAMESPACE'))))
  stopifnot(!any(c('export(dry_run)', 'export(run_verbose)') %in%
                  readLines(file.path(root, 'NAMESPACE'))))
  # The explicit session option overrides even a truthy legacy environment flag.
  runtime$requestclient_dry_run(TRUE)
  stopifnot(inherits(runtime$get_item('widget'), 'httr2_request'))
  Sys.setenv(REQUESTCLIENT_DRY_RUN = 'true')
  runtime$requestclient_dry_run(FALSE)
  stopifnot(identical(runtime$get_item('widget')$request_number, 8L))
  options(requestclient.dry_run = NULL)
  stopifnot(inherits(runtime$get_item('widget'), 'httr2_request'))
  Sys.unsetenv('REQUESTCLIENT_DRY_RUN')
  # Logging must not expose path, query, or header credential values.
  runtime$requestclient_run_verbose(TRUE)
  messages <- character()
  capture <- function(expr) withCallingHandlers(expr, message = function(m) {
    messages <<- c(messages, conditionMessage(m))
    invokeRestart('muffleMessage')
  })
  result <- capture(runtime$api_request('GET', '/private-path-secret', list(),
    list(key = 'query-secret'), NULL, headers = list(Authorization = 'Bearer header-secret')))
  stopifnot(identical(result$request_number, 9L),
            identical(trimws(messages), c('GET request', 'HTTP 200')))
  runtime$requestclient_dry_run(TRUE)
  messages <- character()
  stopifnot(inherits(capture(runtime$get_item('widget')), 'httr2_request'),
            identical(trimws(messages), 'GET request (dry run)'))
  for (invalid in list(NA, NULL, 'true', c(TRUE, FALSE))) {
    stopifnot(inherits(tryCatch(runtime$requestclient_dry_run(invalid), error = identity), 'error'),
              inherits(tryCatch(runtime$requestclient_run_verbose(invalid), error = identity), 'error'))
  }
  stopifnot(isTRUE(getOption('requestclient.dry_run')),
            isTRUE(getOption('requestclient.run_verbose')),
            isTRUE(getOption('unrelatedclient.dry_run')))
  options(requestclient.dry_run = 'true')
  stopifnot(inherits(tryCatch(runtime$get_item('widget'), error = identity), 'error'))
  runtime$requestclient_dry_run(FALSE)
  options(requestclient.run_verbose = NA)
  stopifnot(inherits(tryCatch(runtime$get_item('widget'), error = identity), 'error'))
  runtime$requestclient_run_verbose(FALSE)
  messages <- character()
  stopifnot(identical(capture(runtime$get_item('widget'))$request_number, 10L), !length(messages))
  # Two attached clients have distinct controls, preserving package case and dots.
  other_root <- tempfile('other-client-')
  on.exit(unlink(other_root, recursive = TRUE), add = TRUE)
  specmill::initialize_client(other_root, schema, package = 'Other.Client',
    title = 'Other Client', author = list(given = 'Test', family = 'Maintainer',
    email = 'maintainer@example.org'), license = 'MIT + file LICENSE', base_url = base_url)
  other <- new.env(parent = baseenv())
  for (file in list.files(file.path(other_root, 'R'), full.names = TRUE)) sys.source(file, other)
  withr::local_options(list(other_client.dry_run = NULL, other_client.run_verbose = NULL))
  attach(mget(c('requestclient_dry_run', 'requestclient_run_verbose'), runtime), name = 'test:requestclient')
  on.exit(detach('test:requestclient'), add = TRUE)
  attach(mget(c('Other.Client_dry_run', 'Other.Client_run_verbose'), other), name = 'test:Other.Client')
  on.exit(detach('test:Other.Client'), add = TRUE)
  requestclient_dry_run(TRUE)
  Other.Client_dry_run(FALSE)
  stopifnot(inherits(runtime$get_item('widget'), 'httr2_request'),
    identical(other$api_request('GET', '/other', list(), list(), NULL)$request_number, 11L))
  requestclient_dry_run(FALSE)
  Other.Client_dry_run(TRUE)
  stopifnot(identical(runtime$get_item('widget')$request_number, 12L),
    inherits(other$api_request('GET', '/other', list(), list(), NULL), 'httr2_request'))
  service_file <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_file, handlers = list(seq = function(x) x))
  service$names[['GET /items/{item_id}']] <- 'requestclient_dry_run'
  yaml::write_yaml(service, service_file)
  collision <- tryCatch(specmill::generate_client(root, config = 'specmill.yml', mode = 'plan'), error = identity)
  stopifnot(inherits(collision, 'error'), grepl('session control', conditionMessage(collision)))
  cat(
    'Session controls: exported setters, option precedence, legacy flags, private logging and no-network dry runs passed.\n'
  )
}
if (sys.nframe() == 0L) {
  dry_run_acceptance()
}
