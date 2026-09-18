dry_run_acceptance <- function() {
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
  cat(
    'Dry run: per-package env flag returns the unexecuted request without hitting the server.\n'
  )
}
if (sys.nframe() == 0L) {
  dry_run_acceptance()
}
