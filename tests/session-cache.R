session_cache_acceptance <- function() {
  root <- tempfile('session-cache-')
  port_file <- tempfile('session-cache-port-')
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
          text <- rawToChar(req$rook.input$read())
          body <- if (nzchar(text)) {
            jsonlite::fromJSON(text, simplifyVector = FALSE)
          } else {
            NULL
          }
          history[[length(history) + 1L]] <<- list(
            method = req$REQUEST_METHOD,
            path = req$PATH_INFO,
            body = text
          )
          if (startsWith(req$PATH_INFO, '/search/')) {
            return(json(list(
              ids = if (grepl('/empty$', req$PATH_INFO)) {
                list()
              } else {
                list(1L, 2L)
              }
            )))
          }
          ids <- if (req$REQUEST_METHOD == 'POST') {
            unlist(body$ids)
          } else {
            as.integer(sub('^.*/', '', req$PATH_INFO))
          }
          if (any(ids == 401L)) {
            return(json(list(error = 'credential'), 401L))
          }
          if (any(ids == 500L)) {
            return(json(list(error = 'failed'), 500L))
          }
          json(list(
            records = lapply(ids, function(id) {
              list(CID = id, value = paste0('value-', id))
            })
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
  for (i in seq_len(400L)) {
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
  response <- list('200' = list(description = 'OK'))
  parameter <- function(name) {
    list(
      name = name,
      `in` = 'path',
      required = TRUE,
      schema = list(type = 'string')
    )
  }
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Cache', version = '1'),
      servers = list(list(url = origin)),
      paths = list(
        '/search/{query}' = list(
          get = list(
            operationId = 'search',
            parameters = list(parameter('query')),
            responses = response
          )
        ),
        '/rows' = list(post = list(operationId = 'rows', responses = response)),
        '/rows/{cid}' = list(
          get = list(
            operationId = 'get_rows',
            parameters = list(parameter('cid')),
            responses = response
          )
        ),
        '/synonyms' = list(
          post = list(operationId = 'synonyms', responses = response)
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'cachewrap',
    title = 'Cache Wrap',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  description <- read.dcf(file.path(root, 'DESCRIPTION'))
  description[1L, 'Imports'] <- paste(
    description[1L, 'Imports'],
    'purrr',
    sep = ', '
  )
  write.dcf(description, file.path(root, 'DESCRIPTION'))
  writeLines(
    c(
      'owner <- new.env(parent = emptyenv())',
      'normalize_query <- function(query) { if (!is.character(query) || length(query) != 1L || is.na(query) || !nzchar(query)) stop("invalid query"); query }',
      'normalize_properties <- function(properties) if (is.null(properties)) c("A", "B") else properties',
      'normalize_ids <- function(cid) { cid <- as.integer(cid); cid <- cid[!is.na(cid)]; if (!length(cid)) stop("invalid ids"); cid }',
      'search_key <- function(data) paste0("search:", data$params$query)',
      'row_key <- function(data) paste0(data$input, "|", paste(sort(data$params$properties), collapse = ","))',
      'synonym_key <- function(data) as.character(data$input)',
      'search_result <- function(data) { if (data$params$query == "null") return(NULL); ids <- as.integer(unlist(data$result$ids)); if (!length(ids)) warning("empty search", call. = FALSE); data.frame(cid = ids) }',
      'rows_response <- function(response, context, decode) { x <- decode(); data.frame(CID = vapply(x$records, function(x) as.integer(x$CID), integer(1)), value = vapply(x$records, `[[`, character(1), "value")) }',
      'rows_result <- function(data) if (length(data$pending) > 1L) do.call(rbind, data$result) else data$result',
      'row_entries <- function(data) { out <- lapply(seq_len(nrow(data$result)), function(i) data$result[i, , drop = FALSE]); names(out) <- paste0(data$result$CID, "|", paste(sort(data$params$properties), collapse = ",")); out }',
      'combine_rows <- function(data) do.call(rbind, c(data$cached, list(data$result)))',
      'raw_response <- function(response, context, decode) decode()$records',
      'raw_result <- function(data) if (length(data$pending) > 1L) unlist(data$result, recursive = FALSE) else data$result',
      'raw_entries <- function(data) { out <- data$result; names(out) <- vapply(out, function(x) as.character(x$CID), character(1)); out }',
      'combine_raw <- function(data) c(data$cached, data$result)',
      'project_raw <- function(data) { if (!data$params$tidy()) return(data$result); data.frame(cid = vapply(data$result, function(x) as.integer(x$CID), integer(1))) }'
    ),
    file.path(root, 'R/policy.R')
  )
  callbacks <- new.env(parent = baseenv())
  callbacks$owner <- function(operation) quote(owner)
  callbacks$method <- function(operation) {
    quote(if (length(cache_state$pending) > 1L) 'POST' else 'GET')
  }
  callbacks$path <- function(operation) {
    quote(if (length(cache_state$pending) > 1L) '/rows' else '/rows/{cid}')
  }
  callbacks$path_params <- function(operation) {
    quote(
      if (length(cache_state$pending) > 1L) {
        list()
      } else {
        list(cid = params[['cid']])
      }
    )
  }
  callbacks$body <- function(operation) {
    quote(
      if (length(cache_state$pending) > 1L) {
        list(ids = as.list(params[['cid']]))
      } else {
        NULL
      }
    )
  }
  ref <- function(...) list(from = list(...))
  val <- function(x) list(value = x)
  call_cache <- list(
    mode = 'call',
    enabled = ref('params', 'cache'),
    environment = list(callback = 'owner'),
    name = 'search_cache',
    key = 'search_key'
  )
  item_cache <- list(
    mode = 'items',
    enabled = ref('params', 'cache'),
    environment = list(callback = 'owner'),
    name = 'row_cache',
    key = 'row_key',
    input = 'cid',
    max_items = 100,
    entries = 'row_entries',
    combine = 'combine_rows'
  )
  search <- list(
    inputs = list(
      query = list(type = 'any'),
      cache = list(type = 'any', default = TRUE)
    ),
    normalize_inputs = list(query = 'normalize_query'),
    cache = call_cache,
    result_formatter = 'search_result',
    request = list(
      arguments = list(
        method = val('GET'),
        path = val('/search/{query}'),
        path_params = list(object = list(query = ref('params', 'query'))),
        query = val(list()),
        body = val(NULL)
      )
    )
  )
  rows <- list(
    inputs = list(
      cid = list(type = 'any'),
      properties = list(type = 'any', default = NULL),
      cache = list(type = 'any', default = TRUE)
    ),
    normalize_inputs = list(
      properties = 'normalize_properties',
      cid = 'normalize_ids'
    ),
    cache = item_cache,
    result_formatter = 'rows_result',
    request = list(
      arguments = list(
        method = list(callback = 'method'),
        path = list(callback = 'path'),
        path_params = list(callback = 'path_params'),
        query = val(list()),
        body = list(callback = 'body'),
        response_policy = val('rows_response'),
        request_controls = val(list(preserve_errors = TRUE))
      )
    )
  )
  synonyms <- rows
  synonyms$inputs$properties <- NULL
  synonyms$normalize_inputs$properties <- NULL
  synonyms$inputs <- c(
    synonyms$inputs[1L],
    list(tidy = list(type = 'any', default = TRUE)),
    synonyms$inputs[2L]
  )
  synonyms$defer_inputs <- list('tidy')
  synonyms$result_formatter <- 'raw_result'
  synonyms$request$arguments$response_policy <- val('raw_response')
  synonyms$cache[c('name', 'key', 'entries', 'combine', 'project')] <- list(
    'syn_cache',
    'synonym_key',
    'raw_entries',
    'combine_raw',
    'project_raw'
  )
  service_file <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_file, handlers = list(seq = function(x) x))
  service$selection <- list(
    include = list('GET /search/{query}', 'POST /rows', 'POST /synonyms')
  )
  service$operations <- setNames(
    list(search, rows, synonyms),
    c('GET /search/{query}', 'POST /rows', 'POST /synonyms')
  )
  run <- function(mode = 'apply') {
    yaml::write_yaml(service, service_file)
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      callbacks = callbacks,
      mode = mode,
      artifacts = 'wrappers',
      validation = TRUE
    )
  }
  run()
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
  one <- env$search('one')
  stopifnot(
    identical(env$search('one'), one),
    length(history()) == 1L,
    identical(names(formals(env$search)), c('query', 'cache'))
  )
  options(cachewrap.request = list(base_url = ''))
  on.exit(options(cachewrap.request = NULL), add = TRUE)
  stopifnot(
    identical(env$search('one'), one),
    length(history()) == 1L,
    inherits(tryCatch(env$search(''), error = identity), 'error')
  )
  options(cachewrap.request = NULL)
  warnings <- character()
  empty <- withCallingHandlers(env$search('empty'), warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart('muffleWarning')
  })
  sent <- length(history())
  stopifnot(
    identical(env$search('empty'), empty),
    identical(warnings, 'empty search'),
    length(history()) == sent
  )
  env$rows(1L)
  mixed <- env$rows(c(2L, 1L))
  stopifnot(
    identical(mixed$CID, 1:2),
    identical(tail(history(), 1L)[[1L]]$method, 'GET'),
    identical(tail(history(), 1L)[[1L]]$path, '/rows/2')
  )
  sent <- length(history())
  stopifnot(
    identical(env$rows(c(2L, 1L, 2L))$CID, c(2L, 1L, 2L)),
    length(history()) == sent,
    identical(env$rows(c(1L, 2L), properties = c('B', 'A'))$CID, 1:2),
    length(history()) == sent
  )
  env$rows(1L, properties = 'C')
  stopifnot(length(history()) == sent + 1L)
  sent <- length(history())
  many <- env$rows(1:201, cache = FALSE)
  wires <- tail(history(), 3L)
  stopifnot(
    identical(many$CID, 1:201),
    length(history()) == sent + 3L,
    all(vapply(wires, function(x) identical(x$method, 'POST'), logical(1))),
    identical(
      vapply(
        wires,
        function(x) length(jsonlite::fromJSON(x$body)$ids),
        integer(1)
      ),
      c(100L, 100L, 1L)
    )
  )
  raw <- env$synonyms(1L, tidy = FALSE)
  stopifnot(
    length(raw) == 1L,
    identical(env$synonyms(c(2L, 1L), tidy = FALSE)[[1L]], raw[[1L]]),
    identical(env$synonyms(c(2L, 1L, 2L))$cid, c(2L, 1L, 2L))
  )
  sent <- length(history())
  stopifnot(
    inherits(
      tryCatch(env$synonyms(3L, tidy = stop('late tidy')), error = identity),
      'error'
    ),
    exists('3', envir = env$owner$syn_cache, inherits = FALSE),
    length(history()) == sent + 1L
  )
  denied <- tryCatch(env$rows(c(4L, 401L), cache = FALSE), error = identity)
  failed <- tryCatch(env$rows(c(4L, 500L), cache = FALSE), error = identity)
  single <- tryCatch(env$rows(500L, cache = FALSE), error = identity)
  stopifnot(
    inherits(denied, 'specmill_call_error'),
    inherits(failed, 'purrr_error_indexed'),
    inherits(failed$parent, 'httr2_http_500'),
    inherits(single, 'httr2_http_500')
  )
  sent <- length(history())
  stopifnot(
    is.null(env$search('null')),
    is.null(env$search('null')),
    length(history()) == sent + 1L,
    exists('search:null', envir = env$owner$search_cache, inherits = FALSE)
  )
  options(cachewrap.dry_run = TRUE)
  on.exit(options(cachewrap.dry_run = NULL), add = TRUE)
  sent <- length(history())
  stopifnot(
    inherits(env$search('dry'), 'httr2_request'),
    !exists('search:dry', envir = env$owner$search_cache, inherits = FALSE)
  )
  prepared <- env$rows(c(31L, 32L))
  stopifnot(
    length(prepared) == 1L,
    inherits(prepared[[1L]], 'httr2_request'),
    !exists('31|A,B', envir = env$owner$row_cache, inherits = FALSE),
    length(history()) == sent
  )
  options(cachewrap.dry_run = FALSE)
  validate <- getFromNamespace('validate_settings', 'specmill')
  for (bad in list(
    list(mode = 'unknown'),
    list(max_items = 0),
    list(max_items = Inf),
    list(key = 'not::a_function'),
    list(enabled = list(value = TRUE, from = list('params', 'cache')))
  )) {
    value <- rows
    value$cache[names(bad)] <- bad
    stopifnot(inherits(
      tryCatch(validate(value, 'bad', callbacks), error = identity),
      'error'
    ))
  }
  service$operations[['POST /rows']]$cache$key <- 'absent_callback'
  stopifnot(inherits(tryCatch(run('plan'), error = identity), 'error'))
  service$operations[['POST /rows']] <- rows
  before <- read.dcf(file.path(root, 'DESCRIPTION'))
  without <- before
  without[1L, 'Imports'] <- sub(
    ', purrr',
    '',
    without[1L, 'Imports'],
    fixed = TRUE
  )
  write.dcf(without, file.path(root, 'DESCRIPTION'))
  missing_import <- tryCatch(run('plan'), error = identity)
  stopifnot(
    inherits(missing_import, 'error'),
    grepl('requires purrr', conditionMessage(missing_import), fixed = TRUE)
  )
  write.dcf(before, file.path(root, 'DESCRIPTION'))
  stopifnot(nrow(run('check')$diagnostics) == 0L)
  cat(
    'Session cache: whole hits/empty results, validation-before-lookup, pending routing/chunks, duplicate ordering, property-set keys, raw/final projection, store timing and native/indexed error boundaries passed.\n'
  )
}
if (sys.nframe() == 0L) {
  session_cache_acceptance()
}
