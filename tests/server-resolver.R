server_resolver_acceptance <- function() {
  root <- tempfile('resolver-client-')
  port_file <- tempfile('resolver-ports-')
  on.exit(unlink(c(root, port_file), recursive = TRUE), add = TRUE)
  # Two listeners stand in for two independently hosted services.
  process <- callr::r_bg(
    function(port_file) {
      ports <- c(httpuv::randomPort(), NA)
      ports[[2L]] <- httpuv::randomPort()
      servers <- lapply(ports, function(port) {
        httpuv::startServer(
          '127.0.0.1',
          port,
          list(call = function(req) {
            list(
              status = 200L,
              headers = list('Content-Type' = 'application/json'),
              body = jsonlite::toJSON(
                list(port = port, path = req$PATH_INFO),
                auto_unbox = TRUE
              )
            )
          })
        )
      })
      on.exit(lapply(servers, function(server) server$stop()), add = TRUE)
      writeLines(as.character(ports), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file = port_file),
    supervise = TRUE
  )
  on.exit(process$kill(), add = TRUE)
  for (i in seq_len(200L)) {
    if (file.exists(port_file) && length(readLines(port_file)) == 2L) {
      break
    }
    if (!process$is_alive()) {
      process$get_result()
    }
    Sys.sleep(0.05)
  }
  ports <- as.integer(readLines(port_file))
  stopifnot(length(ports) == 2L)
  host <- function(i, path = '') paste0('http://127.0.0.1:', ports[[i]], path)
  get_operation <- function(id) {
    list(
      get = list(
        operationId = id,
        responses = list('200' = list(description = 'OK'))
      )
    )
  }
  schemas <- list(
    # A /-rooted server path replaces the resolver's path.
    chet = list(
      openapi = '3.0.3',
      info = list(title = 'Chet', version = '1'),
      servers = list(list(url = '/api/chet')),
      paths = list('/reaction' = get_operation('reaction'))
    ),
    # Swagger 2.0 without host or schemes keeps basePath as the relative server.
    lookup = list(
      swagger = '2.0',
      info = list(title = 'Lookup', version = '1'),
      basePath = '/',
      paths = list('/api/lookup' = get_operation('lookup'))
    ),
    # An empty server keeps the resolver URL unchanged.
    opera = list(
      openapi = '3.0.3',
      info = list(title = 'Opera', version = '1'),
      servers = list(list(url = '')),
      paths = list('/opera' = get_operation('opera'))
    ),
    plain = list(
      openapi = '3.0.3',
      info = list(title = 'Plain', version = '1'),
      servers = list(list(url = host(1L, '/plain'))),
      paths = list('/item' = get_operation('item'))
    )
  )
  staging <- file.path(tempdir(), paste0(basename(root), '-schemas'))
  dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)
  for (name in names(schemas)) {
    jsonlite::write_json(
      schemas[[name]],
      file.path(staging, paste0(name, '.json')),
      auto_unbox = TRUE
    )
  }
  specmill::initialize_client(
    root,
    file.path(staging, 'chet.json'),
    package = 'resolverclient',
    title = 'Resolver Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    # The initialization override must lose to a configured resolver.
    base_url = host(2L, '/override')
  )
  # Initialization copies the first schema to schema/openapi.json.
  for (name in setdiff(names(schemas), 'chet')) {
    file.copy(
      file.path(staging, paste0(name, '.json')),
      file.path(root, 'schema')
    )
  }
  read_yaml <- function(path) {
    yaml::read_yaml(path, handlers = list(seq = function(x) x))
  }
  project_path <- file.path(root, 'specmill.yml')
  project <- read_yaml(project_path)
  project$services <- list(
    'apis/default.yml',
    'apis/chemi.yml',
    'apis/plain.yml'
  )
  yaml::write_yaml(project, project_path)
  default_path <- file.path(root, 'apis/default.yml')
  base_service <- read_yaml(default_path)
  base_service$selection$include <- NULL
  base_service$names <- NULL
  service <- function(id, schema, server = NULL) {
    x <- base_service
    x$id <- id
    x$schemas$files <- list(paste0('schema/', schema, '.json'))
    x$defaults <- if (is.null(server)) list() else list(server = server)
    x
  }
  write_services <- function(resolver = 'server_url') {
    chet <- service(
      'chet',
      'openapi',
      list(resolver = resolver, key = 'chet_burl')
    )
    chemi <- service('chemi', 'lookup', list(resolver = resolver))
    chemi$schemas$files <- list('schema/lookup.json', 'schema/opera.json')
    yaml::write_yaml(chet, default_path)
    yaml::write_yaml(chemi, file.path(root, 'apis/chemi.yml'))
    yaml::write_yaml(
      service('plain', 'plain'),
      file.path(root, 'apis/plain.yml')
    )
  }
  write_services()
  writeLines(
    c(
      'server_url <- function(key, server) {',
      '  getOption(paste0("resolverclient.", key))',
      '}'
    ),
    file.path(root, 'R/server_url.R')
  )
  run <- function(mode) {
    specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = mode
    )
  }
  run('apply')
  run('check')
  code <- function(file) {
    paste(readLines(file.path(root, 'R', file)), collapse = '\n')
  }
  stopifnot(
    grepl(
      'server_resolver = list(name = "server_url", key = "chet_burl", relative = "/api/chet")',
      code('reaction.R'),
      fixed = TRUE
    ),
    # The key defaults to the service id.
    grepl(
      'server_resolver = list(name = "server_url", key = "chemi", relative = "/")',
      code('lookup.R'),
      fixed = TRUE
    ),
    # Services without a resolver keep the previous wrapper shape.
    !grepl('server_resolver', code('item.R'), fixed = TRUE),
    !grepl('relative', code('item.R'), fixed = TRUE)
  )
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  seen <- function(result, i, path) {
    stopifnot(
      identical(result$port, ports[[i]]),
      identical(result$path, path)
    )
  }
  withr::with_options(
    list(
      resolverclient.chet_burl = host(1L, '/api'),
      resolverclient.chemi = host(2L, '/base')
    ),
    {
      seen(runtime$reaction(), 1L, '/api/chet/reaction')
      seen(runtime$lookup(), 2L, '/api/lookup')
      seen(runtime$opera(), 2L, '/base/opera')
      # Without a resolver the initialization override still applies.
      seen(runtime$item(), 2L, '/override/item')
      # Switching one service leaves the other in place.
      options(resolverclient.chemi = host(1L, '/base'))
      seen(runtime$lookup(), 1L, '/api/lookup')
      seen(runtime$reaction(), 1L, '/api/chet/reaction')
      options(resolverclient.chet_burl = host(2L))
      seen(runtime$reaction(), 2L, '/api/chet/reaction')
      seen(runtime$lookup(), 1L, '/api/lookup')
      # The client-wide base_url still wins for tests and dry runs.
      options(resolverclient.request = list(base_url = host(1L, '/forced')))
      seen(runtime$reaction(), 1L, '/forced/reaction')
      options(resolverclient.request = NULL)
    }
  )
  fails <- function(expr, pattern) {
    error <- tryCatch(force(expr), error = identity)
    stopifnot(
      inherits(error, 'error'),
      grepl(pattern, conditionMessage(error), fixed = TRUE)
    )
  }
  withr::with_options(
    list(resolverclient.chet_burl = NULL),
    fails(runtime$reaction(), 'Server resolver must return a base URL')
  )
  withr::with_options(
    list(resolverclient.chet_burl = 'ftp://example.org'),
    fails(runtime$reaction(), 'base_url must be absolute HTTP(S)')
  )
  write_services('missing_resolver')
  fails(run('apply'), 'Missing client server resolver')
  write_services()
  # A helper that predates resolvers is rejected instead of using the wrong host.
  helper_path <- file.path(root, 'R/api_request.R')
  helper <- readLines(helper_path)
  writeLines(
    sub('server_resolver = NULL, ', '', helper, fixed = TRUE),
    helper_path
  )
  fails(run('apply'), 'Unknown helper arguments')
  cat(
    'Server resolver: per-service hosts, relative servers, precedence and generation checks passed.\n'
  )
}
if (sys.nframe() == 0L) {
  server_resolver_acceptance()
}
