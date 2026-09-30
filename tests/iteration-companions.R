iteration_companions_acceptance <- function() {
  root <- tempfile('iteration-client-')
  library <- tempfile('iteration-library-')
  port_file <- tempfile('iteration-port-')
  schema <- tempfile(fileext = '.json')
  dir.create(library)
  on.exit(
    unlink(c(root, library, port_file, schema), recursive = TRUE),
    add = TRUE
  )
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      calls <- list()
      attempts <- new.env(parent = emptyenv())
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          response <- function(body, status = 200L) {
            list(
              status = status,
              headers = list('Content-Type' = 'application/json'),
              body = jsonlite::toJSON(body, auto_unbox = TRUE)
            )
          }
          if (req$PATH_INFO == '/calls') {
            return(response(calls))
          }
          if (req$PATH_INFO == '/reset') {
            calls <<- list()
            return(response(list()))
          }
          body <- rawToChar(req$rook.input$read())
          page <- as.integer(sub('.*page=([0-9]+).*', '\\1', req$QUERY_STRING))
          calls[[length(calls) + 1L]] <<- list(
            body = body,
            query = req$QUERY_STRING,
            key = req$HTTP_X_API_KEY,
            page = page
          )
          id <- paste(body, page)
          n <- attempts[[id]]
          attempts[[id]] <- if (is.null(n)) 1L else n + 1L
          if (page == 1L && is.null(n)) {
            return(response(list(), 503L))
          }
          response(list(
            records = list(list(body = body, page = page)),
            last = page == 2L,
            totalPages = 2L
          ))
        })
      )
      on.exit(server$stop())
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file),
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
  param <- function(name, type) {
    list(
      name = name,
      `in` = 'query',
      required = TRUE,
      schema = list(type = type)
    )
  }
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'Iteration', version = '1'),
    servers = list(list(url = origin)),
    components = list(
      securitySchemes = list(
        key = list(type = 'apiKey', `in` = 'header', name = 'X-API-Key')
      )
    ),
    security = list(list(key = list())),
    paths = list(
      '/items' = list(
        post = list(
          operationId = 'fetch',
          parameters = list(
            param('page', 'integer'),
            param('size', 'integer'),
            param('filter', 'string')
          ),
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
  )
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  initialize <- function(root, companions = character()) {
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
      license = 'MIT + file LICENSE',
      companions = companions
    )
  }
  initialize(root, c('pagination', 'batching'))
  helper <- file.path(root, 'R/api_request.R')
  baseline <- file.path(root, '.specmill/helpers/api_request.json')
  code <- paste(readLines(helper), collapse = '\n')
  stopifnot(
    !grepl('specmill::', code, fixed = TRUE),
    !grepl('config_string', code, fixed = TRUE),
    !grepl('%or%', code, fixed = TRUE),
    'digest' %in%
      trimws(strsplit(
        read.dcf(file.path(root, 'DESCRIPTION'))[1, 'Imports'],
        ','
      )[[1]])
  )
  same <- getFromNamespace('request_helper_scaffold', 'specmill')(
    'api_request',
    origin,
    NULL,
    'ITERATIONCLIENT_DRY_RUN',
    c('batching', 'pagination')
  )
  stopifnot(identical(code, same$code))
  renamed <- getFromNamespace('request_helper_scaffold', 'specmill')(
    'other_request',
    origin,
    NULL,
    'ITERATIONCLIENT_DRY_RUN',
    c('pagination', 'batching')
  )
  other <- new.env(parent = baseenv())
  eval(parse(text = renamed$code), other)
  stopifnot(
    all(
      c(
        'other_request_batched',
        'other_request_paginated',
        'other_request_pagination_token',
        'other_request_paginated_links'
      ) %in%
        ls(other)
    ),
    !'api_request_paginated' %in% ls(other)
  )
  # Wrappers may legitimately shadow base constructors.
  other$list <- function(...) stop('shadowed list')
  other$c <- function(...) stop('shadowed c')
  stopifnot(identical(
    other$other_request_batched(identity, 1:3, 2),
    list('1' = 1:2, '2' = 3L)
  ))
  page <- other$other_request_paginated(
    function(page, size) if (page == 1L) 1L else integer(),
    mode = 'page',
    parameter = 'page',
    size_parameter = 'size',
    page_size = 1,
    start = 1L,
    items = identity
  )
  stopifnot(page$stop_reason == 'empty_page')
  # Multi-service initialization shares emission but keeps helper policy separate.
  multi <- tempfile('multi-iteration-')
  dir.create(multi)
  on.exit(unlink(multi, recursive = TRUE), add = TRUE)
  file.copy(schema, file.path(multi, 'one.json'))
  file.copy(schema, file.path(multi, 'two.json'))
  apis <- data.frame(
    schema = c('one.json', 'two.json'),
    api = c('one', 'two'),
    base_url = c(origin, origin),
    include = c(TRUE, TRUE)
  )
  specmill::initialize_client(
    multi,
    apis,
    package = 'multiteration',
    title = 'Multiple Iteration',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    companions = c('batching', 'pagination')
  )
  for (mode in c('apply', 'check')) {
    specmill::generate_client(validation = FALSE, multi, config = 'specmill.yml', mode = mode)
  }
  multi_runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(multi, 'R'), full.names = TRUE)) {
    sys.source(file, multi_runtime)
  }
  previous_options <- options(
    multiteration.one_request.batching = list(first_batch_only = TRUE)
  )
  on.exit(options(previous_options), add = TRUE)
  stopifnot(
    length(multi_runtime$one_request_batched(identity, 1:3, 2)) == 1L,
    length(multi_runtime$two_request_batched(identity, 1:3, 2)) == 2L,
    all(vapply(
      specmill::inspect_client(multi)$helpers,
      function(x) x$baseline == 'known' && !x$customized,
      logical(1)
    ))
  )
  # Native initialization emits no companions, and invalid selections write nothing.
  plain <- tempfile('plain-client-')
  bad <- tempfile('bad-client-')
  on.exit(unlink(c(plain, bad), recursive = TRUE), add = TRUE)
  initialize(plain)
  stopifnot(
    !grepl(
      'api_request_batched <-',
      paste(readLines(file.path(plain, 'R/api_request.R')), collapse = '\n'),
      fixed = TRUE
    )
  )
  error <- tryCatch(
    initialize(bad, c('batching', 'batching')),
    error = identity
  )
  stopifnot(inherits(error, 'error'), !dir.exists(bad))
  writeLines(
    c(
      'retain_metadata <- function(response, context, decode) {',
      '  options(iterationclient.observed = getOption("iterationclient.observed", 0L) + 1L)',
      '  list(response = response, result = decode())',
      '}'
    ),
    file.path(root, 'R/response_policy.R')
  )
  settings_file <- file.path(root, 'apis/default.yml')
  settings <- yaml::read_yaml(
    settings_file,
    handlers = list(seq = function(x) x)
  )
  settings$defaults$response_policy <- 'retain_metadata'
  settings$defaults$request_controls <- list(
    max_retries = 1L,
    retry_writes = TRUE
  )
  yaml::write_yaml(settings, settings_file)
  run <- function(mode) {
    specmill::generate_client(validation = FALSE, root, config = 'specmill.yml', mode = mode)
  }
  run('apply')
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  before <- hashes()
  run('apply')
  run('check')
  stopifnot(identical(before, hashes()))
  # Helper-owned companion names cannot become generated wrapper names.
  for (name in c(
    'api_request_batched',
    'api_request_paginated',
    'api_request_pagination_token',
    'api_request_paginated_links'
  )) {
    settings$names[['POST /items']] <- name
    yaml::write_yaml(settings, settings_file)
    error <- tryCatch(run('apply'), error = identity)
    stopifnot(
      inherits(error, 'error'),
      grepl('collides', conditionMessage(error))
    )
  }
  settings$names[['POST /items']] <- 'fetch'
  yaml::write_yaml(settings, settings_file)
  write('# retained iteration customization', helper, append = TRUE)
  retained <- tools::md5sum(c(helper, baseline))
  run('apply')
  run('check')
  stopifnot(
    identical(retained, tools::md5sum(c(helper, baseline))),
    specmill::inspect_client(root)$helpers$api_request$customized
  )
  installed <- system2(
    file.path(R.home('bin'), 'R'),
    c('CMD', 'INSTALL', '-l', shQuote(library), shQuote(root)),
    stdout = TRUE,
    stderr = TRUE
  )
  if (!is.null(attr(installed, 'status'))) {
    stop(paste(installed, collapse = '\n'))
  }
  callr::r(
    function(library, origin) {
      .libPaths(c(library, .libPaths()))
      ns <- loadNamespace('iterationclient')
      stopifnot(!'specmill' %in% loadedNamespaces())
      Sys.setenv(ITERATIONCLIENT_KEY = 'local-test-key')
      batch <- get('api_request_batched', ns)
      paginate <- get('api_request_paginated', ns)
      fetch <- get('fetch', ns)
      calls <- function() {
        httr2::resp_body_json(
          httr2::req_perform(httr2::request(paste0(origin, '/calls'))),
          simplifyVector = FALSE
        )
      }
      reset <- function() {
        httr2::req_perform(httr2::request(paste0(origin, '/reset')))
      }
      options(iterationclient.observed = 0L)
      options(
        iterationclient.api_request.batching = list(build = function(
          chunk,
          index
        ) {
          as.list(chunk)
        })
      )
      options(
        iterationclient.api_request.pagination = list(
          mode = 'page',
          parameter = 'page',
          size_parameter = 'size',
          page_size = 1L,
          start = 1L,
          items = function(x) x$result$records,
          completed = function(x, state) x$result$last,
          format = function(x) {
            stopifnot(x$stop_reason == 'completed', x$requests == 2L)
            x$pages
          }
        )
      )
      retrieve <- function(body) paginate(fetch, body = body, filter = 'fixed')
      results <- batch(retrieve, c('a', 'b', 'c'), 2L)
      sent <- calls()
      stopifnot(
        length(results) == 2L,
        all(lengths(results) == 2L),
        length(sent) == 6L,
        identical(
          vapply(sent, `[[`, integer(1), 'page'),
          c(1L, 1L, 2L, 1L, 1L, 2L)
        ),
        identical(
          vapply(sent, `[[`, character(1), 'body'),
          c(rep('["a","b"]', 3L), rep('["c"]', 3L))
        ),
        all(vapply(
          sent,
          function(x) {
            x$key == 'local-test-key' &&
              grepl('filter=fixed', x$query, fixed = TRUE)
          },
          logical(1)
        )),
        getOption('iterationclient.observed') == 4L
      )
      reset()
      compatibility <- batch(
        retrieve,
        c('a', 'b', 'c'),
        2L,
        policy = list(first_batch_only = TRUE, build = function(chunk, index) {
          as.list(chunk)
        })
      )
      stopifnot(length(compatibility) == 1L, length(calls()) == 2L)
      reset()
      # Default composition still visits every chunk after compatibility was used.
      batch(retrieve, c('a', 'b', 'c'), 2L)
      stopifnot(length(calls()) == 4L, !'specmill' %in% loadedNamespaces())
      reset()
      # The toolkit's former 10,000-item cap is absent from emitted companions.
      large <- paginate(
        function(page, size) seq_len(size),
        mode = 'page',
        parameter = 'page',
        size_parameter = 'size',
        start = 1,
        page_size = 10001,
        items = identity,
        completed = function(response, state) TRUE,
        format = NULL,
        policy = list()
      )
      stopifnot(large$item_count == 10001)
    },
    list(library = library, origin = origin)
  )
  cat(
    'Iteration companions: deterministic emission, names, provenance, installed runtime and batching/pagination/response/retry composition passed.\n'
  )
}
if (sys.nframe() == 0L) {
  iteration_companions_acceptance()
}
