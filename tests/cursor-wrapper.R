cursor_wrapper_acceptance <- function() {
  root <- tempfile('cursor-wrapper-')
  port_file <- tempfile('cursor-port-')
  on.exit(unlink(c(root, port_file), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      history <- list()
      json <- function(value, status = 200L) {
        list(
          status = status,
          headers = list('Content-Type' = 'application/json'),
          body = jsonlite::toJSON(value, auto_unbox = TRUE, null = 'null')
        )
      }
      httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          if (req$PATH_INFO == '/history') {
            return(json(history))
          }
          text <- rawToChar(req$rook.input$read())
          value <- if (req$REQUEST_METHOD == 'POST') {
            jsonlite::fromJSON(text, simplifyVector = FALSE)
          } else {
            httr2::url_parse(paste0(
              'http://x/?',
              sub('^[?]', '', req$QUERY_STRING)
            ))$query
          }
          history[[length(history) + 1L]] <<- list(
            path = req$PATH_INFO,
            query = req$QUERY_STRING,
            body = text
          )
          kind <- sub('^/(get|post)/', '', req$PATH_INFO)
          cursor <- value$cursor
          first <- is.null(cursor) || identical(cursor, '')
          if (kind == 'error' && !first) {
            return(json(list(error = 'failed'), 500L))
          }
          if (kind == 'denied') {
            return(json(list(error = 'credential'), 401L))
          }
          token <- if (kind == 'repeat') {
            'loop'
          } else if (kind == 'missing') {
            NULL
          } else {
            'two+/='
          }
          rows <- if (kind == 'empty' || (kind == 'skip' && first)) {
            list()
          } else {
            list(list(
              id = if (first) '001' else '2',
              sex = if (first) 'F' else 'MF'
            ))
          }
          json(list(
            results = rows,
            pagination = list(
              hasNext = kind %in%
                c('repeat', 'missing') ||
                (first && kind != 'terminal'),
              nextCursor = token
            )
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
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(schema), add = TRUE)
  path_parameter <- list(
    name = 'kind',
    `in` = 'path',
    required = TRUE,
    schema = list(type = 'string')
  )
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Cursor', version = '1'),
      servers = list(list(url = origin)),
      paths = list(
        '/get/{kind}' = list(
          get = list(
            operationId = 'get_cursor',
            parameters = list(
              path_parameter,
              list(
                name = 'cursor',
                `in` = 'query',
                schema = list(type = 'string')
              ),
              list(
                name = 'filter',
                `in` = 'query',
                schema = list(type = 'string', default = 'keep')
              )
            ),
            responses = list('200' = list(description = 'OK'))
          )
        ),
        '/post/{kind}' = list(
          post = list(
            operationId = 'post_cursor',
            parameters = list(path_parameter),
            requestBody = list(
              required = TRUE,
              content = list(
                'application/json' = list(schema = list(type = 'object'))
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
    package = 'cursorwrap',
    title = 'Cursor Wrap',
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
      'cursor_items <- function(page) api_request_table(page$results)',
      'cursor_next <- function(page) page$pagination$nextCursor',
      'cursor_done <- function(page, state) identical(page$pagination$hasNext, FALSE)',
      'cursor_limit <- function(result, limit) warning(paste("legacy limit", limit), call. = FALSE)',
      'run_hook <- function(fn_name, hook_type, state) { if (hook_type == "post_combine") { stopifnot(is.null(attr(state$result, "pagination"))); return(state$result) }; state }',
      'require_plain <- function(state) state$result'
    ),
    file.path(root, 'R/policy.R')
  )
  service_file <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_file, handlers = list(seq = function(x) x))
  pg <- list(
    mode = 'cursor',
    parameter = 'cursor',
    next_cursor = 'cursor_next',
    items = 'cursor_items',
    completed = 'cursor_done',
    metadata = FALSE,
    error_policy = 'partial',
    warn_errors = FALSE,
    on_limit = 'cursor_limit'
  )
  ref <- function(name) list(from = list('params', name))
  service$operations <- list()
  service$operations[['GET /get/{kind}']] <- list(pagination = pg)
  service$operations[['POST /post/{kind}']] <- list(
    pagination = pg,
    inputs = list(
      kind = list(type = 'character', required = TRUE),
      cursor = list(type = 'character', default = ''),
      filter = list(type = 'character', default = 'keep')
    ),
    request = list(
      arguments = list(
        method = list(value = 'POST'),
        path = list(value = '/post/{kind}'),
        path_params = list(object = list(kind = ref('kind'))),
        query = list(value = list()),
        body = list(
          object = list(
            cursor = ref('cursor'),
            filters = list(object = list(value = ref('filter'))),
            sort = list(value = list('x', 'y')),
            flag = list(value = FALSE)
          )
        )
      )
    )
  )
  service$hooks <- list(
    get_cursor = list(post_combine = list('require_plain')),
    post_cursor = list(post_combine = list('require_plain'))
  )
  run <- function(mode = 'apply') {
    yaml::write_yaml(service, service_file)
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      validation = FALSE,
      mode = mode
    )
  }
  run()
  check <- run('check')
  stopifnot(nrow(check$diagnostics) == 0L)
  env <- new.env(parent = baseenv())
  load <- function() {
    for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
      sys.source(file, env)
    }
  }
  load()
  history <- function() {
    httr2::resp_body_json(
      httr2::req_perform(httr2::request(paste0(origin, '/history'))),
      simplifyVector = FALSE
    )
  }
  warnings <- function(expr) {
    out <- character()
    value <- withCallingHandlers(force(expr), warning = function(w) {
      out <<- c(out, conditionMessage(w))
      invokeRestart('muffleWarning')
    })
    list(value = value, warnings = out)
  }
  for (name in c('get_cursor', 'post_cursor')) {
    fn <- env[[name]]

    manual <- fn('normal', all_pages = FALSE)
    stopifnot(
      is.data.frame(manual),
      nrow(manual) == 1L,
      is.null(attr(manual, 'pagination'))
    )
    result <- fn('normal')
    stopifnot(
      identical(result$sex, c('F', 'MF')),
      is.null(attr(result, 'pagination')),
      is.null(attr(result, 'api_request_source'))
    )
    stopifnot(
      nrow(fn('missing')) == 1L,
      nrow(fn('terminal')) == 1L,
      nrow(fn('empty')) == 0L,
      nrow(fn('skip')) == 0L
    )
    error <- tryCatch(fn('repeat'), error = identity)
    stopifnot(
      inherits(error, 'error'),
      grepl('Repeated pagination cursor', conditionMessage(error))
    )
    limited <- warnings(fn('normal', max_pages = 2L))
    stopifnot(
      identical(limited$warnings, 'legacy limit 2'),
      nrow(limited$value) == 2L
    )
    partial <- warnings(fn('error'))
    stopifnot(nrow(partial$value) == 1L, !length(partial$warnings))
    error <- tryCatch(fn('denied'), error = identity)
    stopifnot(inherits(error, 'specmill_call_error'))
    for (invalid in list(NA_character_, 1, c('a', 'b'))) {
      sent <- length(history())
      error <- tryCatch(fn('normal', cursor = invalid), error = identity)
      stopifnot(inherits(error, 'error'), length(history()) == sent)
    }
  }
  h <- history()
  posts <- Filter(function(x) startsWith(x$path, '/post/normal'), h)
  for (entry in posts) {
    body <- jsonlite::fromJSON(entry$body, simplifyVector = FALSE)
    stopifnot(
      identical(body$filters, list(value = 'keep')),
      identical(body$sort, list('x', 'y')),
      identical(body$flag, FALSE)
    )
  }
  stopifnot(any(grepl(
    'cursor=two%2B%2F%3D',
    vapply(h, `[[`, character(1), 'query'),
    fixed = TRUE
  )))
  dry <- withr::with_options(
    list(cursorwrap.dry_run = TRUE),
    env$get_cursor('normal')
  )
  stopifnot(inherits(dry, 'httr2_request'))
  # Client callbacks can share names with generated transport and paging locals.
  saved_service <- service
  policy_file <- file.path(root, 'R/policy.R')
  saved_policy <- readLines(policy_file)
  for (field in c('items', 'next_cursor', 'on_limit')) {
    definition <- switch(
      field,
      items = 'send <- function(page) cursor_items(page)',
      next_cursor = 'send <- function(page) cursor_next(page)',
      on_limit = 'send <- function(result, limit) cursor_limit(result, limit)'
    )
    writeLines(c(saved_policy, definition), policy_file)
    service <- saved_service
    for (key in names(service$operations)) {
      service$operations[[key]]$pagination[[field]] <- 'send'
    }
    # Fan-out puts the paging callback in a nested generated closure.
    service$operations[['GET /get/{kind}']]$batch <- list(fan_out = 'kind')
    run()
    run('check')
    load()
    for (name in c('get_cursor', 'post_cursor')) {
      fn <- env[[name]]
      manual <- fn('normal', all_pages = FALSE)
      limited <- warnings(fn('normal', max_pages = 2L))
      stopifnot(
        nrow(manual) == 1L,
        nrow(limited$value) == 2L,
        identical(limited$value$sex, c('F', 'MF')),
        identical(limited$warnings, 'legacy limit 2')
      )
    }
  }
  service <- saved_service
  writeLines(saved_policy, policy_file)
  run()
  load()
  # A reviewed envelope may advertise a next cursor on an empty collection.
  for (key in names(service$operations)) {
    service$operations[[key]]$pagination$stop_on_empty <- FALSE
  }
  run()
  load()
  for (name in c('get_cursor', 'post_cursor')) {
    fn <- env[[name]]
    continued <- warnings(fn('skip'))
    stopifnot(
      nrow(continued$value) == 1L,
      identical(as.character(continued$value$id), '2')
    )
    error <- tryCatch(fn('repeat'), error = identity)
    stopifnot(inherits(error, 'error'))
  }
  # Explicit metadata and default engine warning remain available.
  service$hooks <- NULL
  for (key in names(service$operations)) {
    service$operations[[key]]$pagination$metadata <- TRUE
    service$operations[[key]]$pagination$on_limit <- NULL
    service$operations[[key]]$pagination$warn_errors <- TRUE
  }
  run()
  load()
  limited <- warnings(env$get_cursor('normal', max_pages = 1L))
  stopifnot(
    identical(limited$warnings, 'Pagination truncated at max_pages'),
    identical(attr(limited$value, 'pagination')$stop_reason, 'max_pages')
  )
  service$operations[['GET /get/{kind}']]$pagination$error_policy <- 'empty'
  run()
  load()
  discarded <- warnings(env$get_cursor('error'))
  stopifnot(
    length(discarded$value) == 0L,
    identical(attr(discarded$value, 'pagination')$stop_reason, 'request_error'),
    identical(
      discarded$warnings,
      'Pagination request failed; returning empty results'
    )
  )
  # Item formatting is a policy failure, not a recoverable request failure.
  env$cursor_items <- function(page) stop('format sentinel')
  error <- tryCatch(env$get_cursor('normal'), error = identity)
  stopifnot(
    inherits(error, 'error'),
    identical(conditionMessage(error), 'format sentinel')
  )
  validate <- getFromNamespace('validate_settings', 'specmill')
  fails <- function(fn, pattern) {
    error <- tryCatch(fn(), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  validate(list(pagination = list(start = 'opaque')), 'inherited cursor start')
  for (bad in list(
    list(mode = 'cursor', start = 1),
    list(mode = 'cursor', start = NA_character_),
    list(mode = 'cursor', warn_errors = NA),
    list(mode = 'cursor', error_policy = 'drop')
  )) {
    fails(
      function() validate(list(pagination = bad), 'cursor-test'),
      'pagination'
    )
  }
  service$operations[['GET /get/{kind}']]$pagination$next_cursor <- NULL
  fails(function() run('plan'), 'requires next_cursor')
  cat(
    'Cursor wrappers: GET/POST, manual/automatic, filters, opaque cursors, termination, partial errors, hard credentials, typing, limits and freshness passed.\n'
  )
}
if (sys.nframe() == 0L) {
  cursor_wrapper_acceptance()
}
