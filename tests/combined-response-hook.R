combined_response_hook_acceptance <- function() {
  root <- tempfile('post-combine-client-')
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(c(root, schema), recursive = TRUE), add = TRUE)
  string <- list(type = 'string')
  operation <- function(name, parameters = list(), body = NULL) {
    x <- list(
      operationId = name,
      parameters = parameters,
      responses = list('200' = list(description = 'OK'))
    )
    if (!is.null(body)) {
      x$requestBody <- list(
        required = TRUE,
        content = list('application/json' = list(schema = body))
      )
    }
    x
  }
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Post combine', version = '1'),
      servers = list(list(url = 'http://127.0.0.1:1')),
      paths = list(
        '/items/{id}' = list(
          get = operation(
            'get_item',
            list(list(
              name = 'id',
              `in` = 'path',
              required = TRUE,
              schema = string
            ))
          )
        ),
        '/bulk' = list(
          post = operation(
            'bulk',
            body = list(type = 'array', items = string, maxItems = 2L)
          )
        ),
        '/plain' = list(get = operation('plain'))
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'combineclient',
    title = 'Combine Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  service_path <- file.path(root, 'apis/default.yml')
  original <- yaml::read_yaml(
    service_path,
    handlers = list(seq = function(x) x)
  )
  run <- function(mode = 'apply') {
    specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = mode
    )
  }
  writeLines(
    c(
      'normalize_id <- function(x) unique(trimws(x[!is.na(x) & nzchar(trimws(x))]))',
      'format_rows <- function(data) { options(combineclient.events = c(getOption("combineclient.events"), "format")); dplyr::bind_rows(data$result) }',
      'extract_ids <- function(data) { options(combineclient.events = c(getOption("combineclient.events"), "post_response"), combineclient.post = data$params); unique(data$result) }'
    ),
    file.path(root, 'R/formatters.R')
  )
  service <- original
  service$operations[['GET /items/{id}']] <- list(
    batch = list(fan_out = 'id', on_error = 'drop', metadata = FALSE),
    normalize_inputs = list(id = 'normalize_id'),
    extra_parameters = list(
      original_params = list(type = 'character', default = 'raw')
    ),
    post_response_scope = 'combined',
    post_params_source = 'original',
    result_formatter = 'format_rows'
  )
  service$hooks <- list(get_item = list(post_response = list('extract_ids')))
  write <- function() yaml::write_yaml(service, service_path)
  write()
  run()
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  sys.source(
    system.file('templates/hooks.R', package = 'specmill', mustWork = TRUE),
    runtime
  )
  runtime$read_hook_config <- function() {
    list(get_item = list(post_response = list('extract_ids')))
  }
  requests <- character()
  runtime$api_request <- function(method, path, path_params, ...) {
    requests <<- c(requests, path_params$id)
    options(
      combineclient.events = c(getOption('combineclient.events'), 'request')
    )
    list(data.frame(dtxsid = 'SAME'))
  }
  options(combineclient.events = character())
  raw <- c(' A ', 'B', ' A ', '', NA_character_)
  value <- runtime$get_item(raw)
  stopifnot(nrow(value) == 1L)
  stopifnot(
    identical(requests, c('A', 'B')),
    identical(
      getOption('combineclient.events'),
      c('request', 'request', 'format', 'post_response')
    ),
    identical(getOption('combineclient.post')$id, raw),
    identical(getOption('combineclient.post')$original_params, 'raw')
  )
  # The unchanged client executor retains post_response stage and error wrapping.
  parent <- errorCondition('extract failed', class = 'extract_error')
  runtime$extract_ids <- function(data) stop(parent)
  error <- tryCatch(runtime$get_item(c('A', 'B')), error = identity)
  stopifnot(
    inherits(error, 'client_hook_error'),
    identical(error$stage, 'post_response'),
    identical(error$parent, parent)
  )
  runtime$format_rows <- function(data) stop(parent)
  error <- tryCatch(runtime$get_item(c('A', 'B')), error = identity)
  stopifnot(identical(error, parent))
  runtime$api_request <- function(...) {
    stop(structure(
      list(message = 'denied', call = NULL),
      class = c('specmill_call_error', 'error', 'condition')
    ))
  }
  stopifnot(inherits(
    tryCatch(runtime$get_item(c('A', 'B')), error = identity),
    'specmill_call_error'
  ))
  fails <- function(pattern) {
    write()
    error <- tryCatch(run(), error = identity)
    stopifnot(
      inherits(error, 'error'),
      grepl(pattern, conditionMessage(error), fixed = TRUE)
    )
  }
  saved <- service
  service$operations[['GET /items/{id}']]$post_response_scope <- 'invalid'
  fails('post_response_scope must be request or combined')
  service <- saved
  service$operations[['GET /items/{id}']]$post_params_source <- 'invalid'
  fails('post_params_source must be current or original')
  service <- saved
  service$operations[['GET /items/{id}']]$post_state <- 'hook_state'
  fails('require a post-response hook with post_state parameters')
  service <- saved
  service$defaults <- list(post_response_scope = 'combined')
  fails('belongs under operations')
  service <- saved
  service$operations[['GET /items/{id}']]$batch <- NULL
  service$operations[['GET /items/{id}']]$result_formatter <- NULL
  fails(
    'post_response_scope combined requires batch.fan_out or batch.split'
  )
  cat(
    'Combined response hook: single final projection and original params passed.\n'
  )
}
if (sys.nframe() == 0L) {
  combined_response_hook_acceptance()
}
