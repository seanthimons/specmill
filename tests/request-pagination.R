request_pagination_acceptance <- function() {
  root <- tempfile('request-pages-')
  port_file <- tempfile('request-pages-port-')
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(c(root, port_file, schema), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      history <- list()
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
            return(json(history))
          }
          body <- jsonlite::fromJSON(
            rawToChar(req$rook.input$read()),
            simplifyVector = FALSE
          )
          history[[length(history) + 1L]] <<- body
          if (body$query == 'denied') {
            return(json(list(error = 'credential'), 401L))
          }
          if (body$query == 'partial' && body$offset > 0L) {
            return(json(list(error = 'failed'), 500L))
          }
          if (body$query == 'malformed') {
            return(list(
              status = 200L,
              headers = list('Content-Type' = 'application/json'),
              body = '{broken}'
            ))
          }
          json(list(
            records = list(list(id = body$offset + 1L)),
            recordsCount = 1L,
            offset = body$offset,
            totalRecordsCount = 3L
          ))
        })
      )
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
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Search', version = '1'),
      servers = list(list(url = origin)),
      paths = list(
        '/search' = list(
          post = list(
            operationId = 'search',
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
    package = 'searchwrap',
    title = 'Search Wrap',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    companions = c('batching', 'pagination')
  )
  writeLines(
    c(
      'trace <- character(); returned <- NULL; skips <- FALSE; formatted <- 0L; skip_value <- "skipped"; drop_null <- FALSE; override_limit <- NULL',
      'prepare <- function(state) {',
      '  stopifnot(identical(names(state$params), c("query", "limit")))',
      '  returned <<- list(params = list(query = state$params$query, extra = "keep", all_pages = FALSE), marker = "preserved", skip_request = skips, result = skip_value, request = list(body = list(query = state$params$query, offset = 0L, options = list(limit = state$params$limit))))',
      '  if (!is.null(override_limit)) returned$params$limit <<- override_limit',
      '  returned',
      '}',
      'format <- function(state) {',
      '  expected <- returned; if (drop_null) expected$result <- state$result else expected["result"] <- state["result"]',
      '  stopifnot(identical(state, expected)); state$result',
      '}',
      'run_hook <- function(name, stage, state) { trace <<- c(trace, stage); if (stage == "pre_request") prepare(state) else format(state) }',
      'raw_response <- function(response, context, decode) { if (httr2::resp_status(response) >= 400L) return(decode()); response }',
      'page_items <- function(response) list(response)',
      'page_done <- function(response, state) { x <- httr2::resp_body_json(response); x$recordsCount == 0L || x$offset + x$recordsCount >= x$totalRecordsCount }',
      'page_advance <- function(response, position, page_size) { x <- httr2::resp_body_json(response); x$offset + x$recordsCount }',
      'final_result <- function(state) { formatted <<- formatted + 1L; if (!state$params$all_pages()) return(httr2::resp_body_json(state$result, simplifyVector = FALSE)); unlist(lapply(state$result, function(x) httr2::resp_body_json(x, simplifyVector = FALSE)$records), recursive = FALSE) }'
    ),
    file.path(root, 'R/policy.R')
  )
  callbacks <- new.env(parent = baseenv())
  callbacks$paging <- function(operation) quote(params[['all_pages']]())
  service_file <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_file, handlers = list(seq = function(x) x))
  ref <- function(...) list(from = list(...))
  settings <- list(
    inputs = list(
      query = list(type = 'character', default = 'good'),
      limit = list(type = 'numeric', default = 2),
      all_pages = list(type = 'logical', default = FALSE)
    ),
    defer_inputs = list('all_pages'),
    pre_params = list('query', 'limit'),
    post_on_skip = TRUE,
    post_state = 'hook_state',
    post_response_scope = 'combined',
    result_formatter = 'final_result',
    request = list(
      arguments = list(
        method = list(value = 'POST'),
        path = list(value = '/search'),
        path_params = list(value = list()),
        query = list(value = list()),
        body = ref('hook_state', 'request', 'body'),
        body_media = list(value = 'application/json'),
        response_policy = list(value = 'raw_response'),
        request_controls = list(value = list(preserve_errors = TRUE))
      ),
      pagination = list(
        mode = 'offset',
        when = list(callback = 'paging'),
        parameter = list('body', 'offset'),
        size_parameter = list('body', 'options', 'limit'),
        page_size = ref('hook_state', 'request', 'body', 'options', 'limit'),
        start = list(value = 0),
        max_pages = 100,
        items = 'page_items',
        completed = 'page_done',
        advance = 'page_advance',
        metadata = FALSE,
        error_policy = 'partial',
        warn_limits = FALSE,
        warn_errors = FALSE,
        stop_on_empty = FALSE
      )
    )
  )
  service$operations <- setNames(list(settings), 'POST /search')
  service$hooks <- list(
    search = list(pre_request = list('prepare'), post_response = list('format'))
  )
  run <- function(mode = 'apply') {
    yaml::write_yaml(service, service_file)
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      callbacks = callbacks,
      mode = mode,
      artifacts = 'wrappers',
      validation = FALSE
    )
  }
  run()
  stopifnot(nrow(run('check')$diagnostics) == 0L)
  env <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, env)
  }
  history <- function() {
    httr2::resp_body_json(
      httr2::req_perform(httr2::request(paste0(origin, '/history'))),
      simplifyVector = FALSE
    )
  }
  stopifnot(
    identical(names(formals(env$search)), c('query', 'limit', 'all_pages')),
    identical(formals(env$search)$all_pages, FALSE)
  )
  one <- env$search()
  stopifnot(
    length(one$records) == 1L,
    length(history()) == 1L,
    identical(env$trace, c('pre_request', 'post_response'))
  )
  env$trace <- character()
  many <- env$search(all_pages = TRUE)
  wires <- tail(history(), 3L)
  stopifnot(
    identical(vapply(many, `[[`, integer(1), 'id'), 1:3),
    is.null(attributes(many)),
    identical(env$trace, c('pre_request', 'post_response')),
    identical(vapply(wires, `[[`, integer(1), 'offset'), 0:2),
    all(vapply(wires, function(x) identical(x$options$limit, 2L), logical(1)))
  )
  env$skips <- TRUE
  sent <- length(history())
  formatted <- env$formatted
  stopifnot(
    identical(env$search(all_pages = stop('must remain lazy')), 'skipped'),
    length(history()) == sent,
    env$formatted == formatted
  )
  env$skips <- FALSE
  partial <- env$search('partial', all_pages = TRUE)
  stopifnot(length(partial) == 1L, partial[[1L]]$id == 1L)
  denied <- tryCatch(env$search('denied', all_pages = TRUE), error = identity)
  stopifnot(inherits(denied, 'error'))
  sent <- length(history())
  malformed <- tryCatch(
    env$search('malformed', all_pages = TRUE),
    error = identity
  )
  stopifnot(inherits(malformed, 'error'), length(history()) == sent + 1L)
  options(searchwrap.dry_run = TRUE)
  on.exit(options(searchwrap.dry_run = NULL), add = TRUE)
  sent <- length(history())
  formatted <- env$formatted
  stopifnot(
    inherits(env$search(all_pages = TRUE), 'httr2_request'),
    length(history()) == sent,
    env$formatted == formatted
  )
  options(searchwrap.dry_run = FALSE)
  for (field in c('items', 'completed', 'advance')) {
    service$operations[[1L]]$request$pagination[[field]] <- 'missing_callback'
    error <- tryCatch(run('plan'), error = identity)
    stopifnot(
      inherits(error, 'error'),
      grepl(
        'Missing client request.pagination callback',
        conditionMessage(error),
        fixed = TRUE
      )
    )
    service$operations[[1L]]$request$pagination[[
      field
    ]] <- settings$request$pagination[[field]]
  }
  env$skips <- TRUE
  env$skip_value <- NULL
  stopifnot(is.null(env$search(all_pages = stop('must remain lazy'))))
  service$operations[[1L]]$post_result_null <- 'remove'
  service$operations[[1L]]$request$pagination$max_pages <- ref(
    'params',
    'limit'
  )
  run()
  env <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, env)
  }
  env$drop_null <- TRUE
  env$skips <- TRUE
  env$skip_value <- NULL
  stopifnot(is.null(env$search(all_pages = stop('must remain lazy'))))
  env$skips <- FALSE
  sent <- length(history())
  stopifnot(
    length(env$search(limit = 1, all_pages = TRUE)) == 1L,
    length(history()) == sent + 1L
  )
  env$override_limit <- 2
  sent <- length(history())
  stopifnot(
    length(env$search(limit = 1, all_pages = TRUE)) == 2L,
    length(history()) == sent + 2L
  )
  env$override_limit <- NULL
  sent <- length(history())
  stopifnot(
    inherits(
      tryCatch(env$search(limit = 0, all_pages = TRUE), error = identity),
      'error'
    ),
    length(history()) == sent
  )
  stopifnot(
    length(env$search(limit = 0, all_pages = FALSE)$records) == 1L,
    length(history()) == sent + 1L
  )
  callbacks$cap <- function(operation) quote(params[['limit']])
  service$operations[[1L]]$request$pagination$max_pages <- list(
    callback = 'cap'
  )
  run()
  env <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, env)
  }
  env$drop_null <- TRUE
  sent <- length(history())
  stopifnot(
    length(env$search(limit = 1, all_pages = TRUE)) == 1L,
    length(history()) == sent + 1L
  )
  validate <- getFromNamespace('validate_settings', 'specmill')
  for (bad in list(
    list(parameter = list(named = 'body', 'offset')),
    list(parameter = list('body', list('offset'))),
    list(max_pages = 0),
    list(max_pages = Inf),
    list(error_policy = c('stop', 'partial')),
    list(metadata = NA)
  )) {
    value <- settings
    value$request$pagination[names(bad)] <- bad
    stopifnot(inherits(
      tryCatch(validate(value, 'bad', callbacks), error = identity),
      'error'
    ))
  }
  cat(
    'Request pagination: unchanged formals, lazy skip, one hook cycle/full state, nested body offset/size, single envelope and combined records, partial HTTP recovery, hard errors, malformed metadata, dry run, excluded control updates, NULL result policy and dynamic page caps passed.\n'
  )
}
if (sys.nframe() == 0L) {
  request_pagination_acceptance()
}
