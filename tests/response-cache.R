response_cache_acceptance <- function() {
  for (package in c('cachem', 'rlang', 'httpuv', 'callr', 'withr', 'httr2')) {
    if (!requireNamespace(package, quietly = TRUE)) {
      message('Skipping response cache: ', package, ' is not installed')
      return(invisible())
    }
  }
  internal <- function(name) utils::getFromNamespace(name, 'specmill')
  workspace <- tempfile('response-cache-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
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
          if (path == '/graphql') {
            return(json(list(data = list(version = counts[[path]]))))
          }
          if (path == '/v1/readings:list') {
            page <- if (grepl('pageToken=p2', req$QUERY_STRING, fixed = TRUE)) {
              list(readings = list(list(station = 's2')))
            } else {
              list(
                readings = list(list(station = 's1')),
                nextPageToken = 'p2'
              )
            }
            return(json(page))
          }
          json(list(
            n = counts[[path]],
            query = req$QUERY_STRING,
            key = req$HTTP_X_KEY,
            body = rawToChar(req$rook.input$read())
          ))
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
  on.exit(server$kill(), add = TRUE)
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
  operation <- function(id, ...) {
    c(list(operationId = id, responses = ok), list(...))
  }
  text <- list(name = 'q', `in` = 'query', schema = list(type = 'string'))
  body <- list(
    content = list(
      'application/json' = list(
        schema = list(
          type = 'object',
          properties = list(term = list(type = 'string'))
        )
      )
    )
  )
  schema <- file.path(workspace, 'schema.json')
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Cached', version = '1'),
      servers = list(list(url = base)),
      security = list(list(key = list())),
      paths = list(
        '/items' = list(get = operation('list_items', parameters = list(text))),
        '/short' = list(
          get = operation('short_lived', parameters = list(text))
        ),
        '/disk' = list(get = operation('on_disk', parameters = list(text))),
        '/plain' = list(
          get = operation('uncached_read', parameters = list(text))
        ),
        '/fail' = list(get = operation('failing')),
        '/search' = list(post = operation('search', requestBody = body)),
        '/write' = list(post = operation('write', requestBody = body))
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
  metadata <- list(
    schema = schema,
    package = 'cacheclient',
    title = 'Cached client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT'
  )
  read_yaml <- function(path) {
    yaml::read_yaml(path, handlers = list(seq = function(x) x))
  }
  failure <- function(expr) tryCatch(expr, error = identity)
  generate <- function(root, mode = 'apply') {
    specmill::generate_client(root, config = 'specmill.yml', mode = mode)
  }
  # The setting needs the client-owned companion.
  bare <- file.path(workspace, 'bare')
  invisible(do.call(
    specmill::initialize_client,
    c(list(root = bare), metadata)
  ))
  bare_project <- read_yaml(file.path(bare, 'specmill.yml'))
  bare_project$defaults$response_cache <- list(store = 'memory')
  yaml::write_yaml(bare_project, file.path(bare, 'specmill.yml'))
  missing_companion <- failure(generate(bare, 'plan'))
  stopifnot(
    inherits(missing_companion, 'error'),
    grepl('cache companion', conditionMessage(missing_companion), fixed = TRUE),
    !grepl(
      'cachem',
      paste(readLines(file.path(bare, 'DESCRIPTION')), collapse = ' ')
    )
  )
  root <- file.path(workspace, 'client')
  invisible(do.call(
    specmill::initialize_client,
    c(list(root = root, companions = 'cache'), metadata)
  ))
  project_path <- file.path(root, 'specmill.yml')
  project <- read_yaml(project_path)
  variable <- project$authentication$key
  service_path <- list.files(file.path(root, 'apis'), full.names = TRUE)[[1L]]
  service <- read_yaml(service_path)
  # Defaults cover reads; any other operation names the setting itself.
  project$defaults$response_cache <- list(store = 'memory', max_age = 3600)
  # An operation block inherits the lifetime it does not name; null removes it.
  service$operations[['POST /search']]$response_cache <- list(
    store = 'memory',
    max_age = NULL
  )
  service$operations[['GET /short']]$response_cache <- list(
    store = 'memory',
    max_age = 1
  )
  service$operations[['GET /disk']]$response_cache <- list(store = 'disk')
  service$operations[['GET /plain']]['response_cache'] <- list(NULL)
  yaml::write_yaml(project, project_path)
  yaml::write_yaml(service, service_path)
  generated <- generate(root)
  code <- function(name) {
    paste(readLines(file.path(root, 'R', paste0(name, '.R'))), collapse = '\n')
  }
  stopifnot(
    grepl(
      'cachem, rlang',
      paste(readLines(file.path(root, 'DESCRIPTION')), collapse = ' ')
    ),
    length(generated$operations) == 7L,
    grepl(
      paste0(
        'api_request_cached(.operation = "',
        service$id,
        ' GET /items", .settings = list(store = "memory", max_age = 3600), method = "GET"'
      ),
      code('list_items'),
      fixed = TRUE
    ),
    grepl(
      '.settings = list(store = "memory"), method',
      code('search'),
      fixed = TRUE
    ),
    grepl(
      '.settings = list(store = "disk", max_age = 3600)',
      code('on_disk'),
      fixed = TRUE
    ),
    grepl(
      '.settings = list(store = "memory", max_age = 1)',
      code('short_lived'),
      fixed = TRUE
    ),
    # A write is cached only by name, and null opts a read out.
    !grepl('_cached(', code('write'), fixed = TRUE),
    !grepl('_cached(', code('uncached_read'), fixed = TRUE)
  )
  load_client <- function(root) {
    env <- new.env(parent = baseenv())
    for (file in list.files(
      file.path(root, 'R'),
      pattern = '\\.R$',
      full.names = TRUE
    )) {
      sys.source(file, env)
    }
    env
  }
  env <- load_client(root)
  with_key <- function(value, expr) {
    withr::with_envvar(stats::setNames(value, variable), expr)
  }
  first <- with_key('alpha', env$list_items(q = 'a'))
  again <- with_key('alpha', env$list_items(q = 'a'))
  other <- with_key('alpha', env$list_items(q = 'b'))
  # Another credential never reads the first one's entry.
  second <- with_key('beta', env$list_items(q = 'a'))
  searched <- with_key('alpha', env$search(body = list(term = 'x')))
  searched_again <- with_key('alpha', env$search(body = list(term = 'x')))
  written <- with_key('alpha', env$write(body = list(term = 'x')))
  written_again <- with_key('alpha', env$write(body = list(term = 'x')))
  plain <- with_key('alpha', env$uncached_read(q = 'a'))
  plain_again <- with_key('alpha', env$uncached_read(q = 'a'))
  failed <- with_key('alpha', failure(env$failing()))
  failed_again <- with_key('alpha', failure(env$failing()))
  seen <- counts()
  stopifnot(
    identical(first, again),
    first$key == 'alpha',
    other$n == 2L,
    second$n == 3L,
    second$key == 'beta',
    seen[['/items']] == 3L,
    identical(searched, searched_again),
    seen[['/search']] == 1L,
    written_again$n == written$n + 1L,
    plain_again$n == plain$n + 1L,
    # A failed request stores nothing.
    inherits(failed, 'error'),
    inherits(failed_again, 'error'),
    seen[['/fail']] == 2L
  )
  # The package option bypasses the cache, and a dry run neither reads nor
  # writes it.
  bypassed <- withr::with_options(
    list(cacheclient.response_cache = FALSE),
    with_key('alpha', env$list_items(q = 'a'))
  )
  dry <- withr::with_options(
    list(cacheclient.dry_run = TRUE),
    with_key('alpha', env$list_items(q = 'dry'))
  )
  dry_stored <- withr::with_options(
    list(cacheclient.dry_run = TRUE),
    with_key('alpha', env$list_items(q = 'a'))
  )
  after_dry <- with_key('alpha', env$list_items(q = 'dry'))
  # A result that holds the raw response is not stored: its URL and headers
  # can carry a credential.
  keep <- function(response, context, decode) {
    list(response = response, result = decode())
  }
  kept <- withr::with_options(
    list(cacheclient.response_policy = keep),
    list(
      with_key('alpha', env$list_items(q = 'raw')),
      with_key('alpha', env$list_items(q = 'raw'))
    )
  )
  # The same holds for a response attached as an attribute.
  tagged <- function(response, context, decode) {
    structure(decode(), response = response)
  }
  attached <- withr::with_options(
    list(cacheclient.response_policy = tagged),
    list(
      with_key('alpha', env$list_items(q = 'attribute')),
      with_key('alpha', env$list_items(q = 'attribute'))
    )
  )
  # And for one held in a list-column of a data frame.
  framed <- function(response, context, decode) {
    frame <- data.frame(n = decode()$n)
    frame$response <- list(response)
    frame
  }
  in_frame <- withr::with_options(
    list(cacheclient.response_policy = framed),
    list(
      with_key('alpha', env$list_items(q = 'frame')),
      with_key('alpha', env$list_items(q = 'frame'))
    )
  )
  # A malformed request option still gets the helper's own error.
  malformed <- withr::with_options(
    list(cacheclient.request = 'not a list'),
    with_key('alpha', failure(env$list_items(q = 'a')))
  )
  stopifnot(
    attached[[1L]]$n == 8L,
    attached[[2L]]$n == 9L,
    in_frame[[1L]]$n == 10L,
    in_frame[[2L]]$n == 11L,
    inherits(malformed, 'specmill_call_error'),
    bypassed$n == 4L,
    inherits(dry, 'httr2_request'),
    inherits(dry_stored, 'httr2_request'),
    after_dry$n == 5L,
    inherits(kept[[1L]]$response, 'httr2_response'),
    kept[[1L]]$result$n == 6L,
    kept[[2L]]$result$n == 7L,
    identical(with_key('alpha', env$list_items(q = 'a')), first)
  )
  # Entries expire after max_age seconds.
  short <- with_key('alpha', env$short_lived(q = 'a'))
  stopifnot(identical(with_key('alpha', env$short_lived(q = 'a')), short))
  Sys.sleep(1.3)
  stopifnot(with_key('alpha', env$short_lived(q = 'a'))$n == short$n + 1L)
  # A disk entry answers a fresh R process; clearing removes it everywhere.
  stored <- with_key('alpha', env$on_disk(q = 'a'))
  fresh <- callr::r(
    function(root, variable) {
      env <- new.env(parent = baseenv())
      for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
        sys.source(file, env)
      }
      do.call(Sys.setenv, stats::setNames(list('alpha'), variable))
      env$on_disk(q = 'a')
    },
    list(root = root, variable = variable)
  )
  cache_dir <- env$api_request_cache_dir()
  stopifnot(
    identical(fresh, stored),
    counts()[['/disk']] == 1L,
    startsWith(
      normalizePath(cache_dir, winslash = '/'),
      normalizePath(workspace, winslash = '/')
    ),
    length(list.files(cache_dir, recursive = TRUE)) > 0L
  )
  env$api_request_cache_clear()
  stopifnot(
    !dir.exists(cache_dir),
    with_key('alpha', env$on_disk(q = 'a'))$n == 2L,
    with_key('alpha', env$list_items(q = 'a'))$n == first$n + 11L
  )
  check <- generate(root, 'check')
  stopifnot(all(vapply(
    check$files,
    function(x) x$action == 'unchanged',
    logical(1)
  )))
  # A named setting cannot sit on a call the cache does not wrap; an inherited
  # one is left out with a warning.
  named_with <- function(setting) {
    blocked <- service
    blocked$operations[['GET /items']]$response_cache <- list(store = 'memory')
    blocked$operations[['GET /items']][[setting]] <- TRUE
    yaml::write_yaml(blocked, service_path)
    failure(generate(root, 'plan'))
  }
  named <- named_with('preserve_visibility')
  guarded <- named_with('route_guard')
  service$operations[['GET /items']]$preserve_visibility <- TRUE
  yaml::write_yaml(service, service_path)
  warned <- character()
  inherited <- withCallingHandlers(
    generate(root),
    warning = function(w) {
      warned <<- c(warned, conditionMessage(w))
      invokeRestart('muffleWarning')
    }
  )
  stopifnot(
    inherits(named, 'error'),
    grepl(
      'response_cache cannot be combined with preserve_visibility',
      conditionMessage(named),
      fixed = TRUE
    ),
    inherits(guarded, 'error'),
    grepl(
      'response_cache cannot be combined with route_guard',
      conditionMessage(guarded),
      fixed = TRUE
    ),
    any(grepl(
      'was not applied to .*GET /items \\(preserve_visibility\\)',
      warned
    )),
    !grepl('_cached(', code('list_items'), fixed = TRUE),
    grepl('list_items <- function', code('list_items'), fixed = TRUE)
  )
  # The skipped read still works, without the cache.
  uncached <- load_client(root)
  stopifnot(
    with_key('alpha', uncached$list_items(q = 'a'))$n + 1L ==
      with_key('alpha', uncached$list_items(q = 'a'))$n
  )
  invalid <- function(setting, pattern) {
    project$defaults$response_cache <- setting
    yaml::write_yaml(project, project_path)
    error <- failure(generate(root, 'plan'))
    inherits(error, 'error') && grepl(pattern, conditionMessage(error))
  }
  stopifnot(
    invalid(list(store = 'redis'), 'memory or disk'),
    invalid(list(store = 'memory', max_age = 0), 'positive number'),
    invalid(list(store = 'memory', path = 'x'), 'response_cache')
  )
  # Under pagination every page request is cached by its own inputs.
  fixtures <- if (dir.exists('tests/fixtures')) 'tests/fixtures' else 'fixtures'
  paged_document <- jsonlite::read_json(
    file.path(fixtures, 'discovery/monitoring.json')
  )
  paged_document$rootUrl <- paste0(base, '/')
  paged_schema <- file.path(workspace, 'monitoring.json')
  jsonlite::write_json(
    paged_document,
    paged_schema,
    auto_unbox = TRUE,
    null = 'null'
  )
  paged_root <- file.path(workspace, 'paged')
  metadata$schema <- paged_schema
  metadata$package <- 'pagedclient'
  invisible(do.call(
    specmill::initialize_client,
    c(list(root = paged_root, companions = 'cache'), metadata)
  ))
  paged_project <- read_yaml(file.path(paged_root, 'specmill.yml'))
  paged_project$defaults$response_cache <- list(store = 'memory')
  yaml::write_yaml(paged_project, file.path(paged_root, 'specmill.yml'))
  generate(paged_root)
  paged <- load_client(paged_root)
  paged_key <- stats::setNames('k', paged_project$authentication$api_key)
  pages <- withr::with_envvar(paged_key, paged$readings_list())
  requested <- counts()[['/v1/readings:list']]
  repeated <- withr::with_envvar(paged_key, paged$readings_list())
  stopifnot(
    length(pages) == 2L,
    requested == 2L,
    identical(repeated, pages),
    counts()[['/v1/readings:list']] == 2L
  )
  # A GraphQL query is a read; a mutation is cached only by name.
  graph_root <- file.path(workspace, 'graph')
  metadata$schema <- file.path(fixtures, 'graphql/monitoring.json')
  metadata$package <- 'graphclient'
  invisible(do.call(
    specmill::initialize_client,
    c(list(root = graph_root, companions = 'cache', base_url = base), metadata)
  ))
  graph_project <- read_yaml(file.path(graph_root, 'specmill.yml'))
  graph_project$defaults$response_cache <- list(store = 'memory')
  yaml::write_yaml(graph_project, file.path(graph_root, 'specmill.yml'))
  graph_service <- read_yaml(file.path(graph_root, 'apis/query.yml'))
  graph_service$operations[['query network']]$fields <- list(
    list(owner = list('code'))
  )
  graph_service$operations[['query latest']]$fields <- list('__typename')
  yaml::write_yaml(graph_service, file.path(graph_root, 'apis/query.yml'))
  generate(graph_root)
  graph_lines <- function(name) {
    readLines(file.path(graph_root, 'R', paste0(name, '.R')))
  }
  calls <- function(lines, helper) {
    sum(grepl(paste0(' <- ', helper, '('), lines, fixed = TRUE))
  }
  graph <- load_client(graph_root)
  stopifnot(
    calls(graph_lines('query'), 'api_request_cached') ==
      length(graph_service$operations),
    calls(graph_lines('query'), 'api_request') == 0L,
    calls(graph_lines('mutation'), 'api_request_cached') == 0L,
    calls(graph_lines('mutation'), 'api_request') == 2L,
    identical(graph$version(), graph$version()),
    counts()[['/graphql']] == 1L
  )
  # Generated request tests switch the cache off so a stored response cannot
  # answer a mocked call.
  cached_operation <- list(
    name = 'list_items',
    key = 'GET /items',
    method = 'GET',
    response_cache = list(store = 'disk')
  )
  switch_line <- '  withr::local_options(list("my_client.response_cache" = FALSE))'
  switched <- function(rendered) {
    switch_line %in% strsplit(rendered, '\n', fixed = TRUE)[[1L]]
  }
  replayed <- internal('render_scenario_test')(
    cached_operation,
    list(package = 'my.client'),
    'service',
    'scenario',
    list(),
    c('method', 'uri'),
    character(),
    list(q = 'a')
  )
  switch_off <- internal('test_cache_off')
  stopifnot(
    # Contract, fixed-contract and hook-integration tests mock the helper.
    switched(internal('render_contract')(
      cached_operation,
      list(
        package = 'my.client',
        helper = 'api_request',
        response_fixture = 'x'
      ),
      list(inputs = list(q = 'a'), request = list(), result = list())
    )),
    switched(internal('render_fixed_contract')(
      cached_operation,
      list(
        package = 'my.client',
        helper = 'api_request',
        contracts_file = 'tests/testthat/fixtures/fixed.yml'
      ),
      list(
        inputs = list(q = 'a'),
        calls = list(list(
          helper = 'api_request',
          arguments = list(method = 'GET', path = '/items'),
          response = list(count = 0)
        )),
        result = list(count = 0)
      )
    )),
    switched(internal('render_hook_integration')(
      cached_operation,
      list(package = 'my.client'),
      'service',
      'case',
      list(inputs = list(q = 'a'), calls = list(), result = list()),
      list(helpers = 'api_request', hooks = character())
    )),
    # A replayed scenario must read its recording, not a stored response.
    grepl(
      'withr::local_options(list("my_client.response_cache" = FALSE))\n  result <- my.client::list_items(',
      replayed,
      fixed = TRUE
    ),
    identical(
      switch_off(list(response_cache = list(store = 'disk')), 'my.client'),
      '  withr::local_options(list("my_client.response_cache" = FALSE))'
    ),
    is.null(switch_off(list(), 'my.client'))
  )
  cat(
    'Response cache: memory and disk stores, expiry, credentials, writes by name, opt-out, failures, dry run, option, clearing, pagination, GraphQL and policy errors passed.\n'
  )
}
if (sys.nframe() == 0L) {
  response_cache_acceptance()
}
