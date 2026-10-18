input_preflight_acceptance <- function() {
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
      'clean_ids <- function(x) { x <- as.character(unlist(x)); unique(x[!is.na(x) & nzchar(x)]) }',
      'check_inputs <- function(params) { if (length(params$tail) && length(params$id) > 1L) cli::cli_abort("Only one input with a trailing value", class = "input_preflight_error"); invisible(NULL) }'
    ),
    file.path(root, 'R/input-policy.R')
  )
  service <- original
  service$operations[['GET /items/{id}']] <- list(
    inputs = list(
      id = list(type = 'any'),
      tail = list(type = 'any', required = FALSE, default = NULL)
    ),
    normalize_inputs = list(id = 'clean_ids'),
    validate_inputs = 'check_inputs',
    batch = list(
      fan_out = 'id',
      on_error = list(single = 'stop', multiple = 'drop'),
      warning = FALSE
    ),
    request = list(
      arguments = list(
        method = list(value = 'GET'),
        path = list(value = '/items'),
        path_params = list(
          object = list(id = list(from = list('params', 'id')))
        ),
        query = list(object = list(tail = list(from = list('params', 'tail')))),
        body = list(value = NULL)
      )
    )
  )
  write <- function() yaml::write_yaml(service, service_path)
  write()
  run()
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  sent <- list()
  runtime$api_request <- function(method, path, path_params, query, body) {
    id <- path_params$id
    tail <- query$tail
    sent[[length(sent) + 1L]] <<- list(id = id, tail = tail)
    data.frame(id = as.character(id))
  }
  value <- runtime$get_item(list(1, 2, 1, NA, ''))
  stopifnot(identical(value$id, c('1', '2')), length(sent) == 2L)
  stopifnot(identical(
    formals(runtime$get_item),
    formals(function(id, tail = NULL) NULL)
  ))
  before <- length(sent)
  error <- tryCatch(runtime$get_item(c('a', 'b'), 'suffix'), error = identity)
  stopifnot(inherits(error, 'input_preflight_error'), length(sent) == before)
  # Validation runs before the batch/drop boundary and propagates the original condition.
  condition <- errorCondition(
    'cross-input failed',
    class = 'client_input_error'
  )
  runtime$check_inputs <- function(params) stop(condition)
  error <- tryCatch(runtime$get_item(c('a', 'b')), error = identity)
  stopifnot(identical(error, condition), length(sent) == before)
  runtime$check_inputs <- function(params) invisible(NULL)
  response <- httr2::response(status_code = 500L, body = charToRaw('failed'))
  runtime$api_request <- function(method, path, path_params, query, body) {
    id <- path_params$id
    tail <- query$tail
    sent[[length(sent) + 1L]] <<- list(id = id, tail = tail)
    if (id == 'bad') {
      httr2::resp_check_status(response)
    }
    data.frame(id = as.character(id))
  }
  error <- tryCatch(runtime$get_item('bad'), error = identity)
  stopifnot(inherits(error, 'httr2_http_500'), identical(error$resp, response))
  value <- runtime$get_item(c('a', 'bad', 'b'))
  stopifnot(
    identical(value$id, c('a', 'b')),
    length(attr(value, 'failed')) == 1L
  )
  # No new hook stage or client executor is needed.
  runtime$api_request <- function(method, path, path_params, query, body) {
    id <- path_params$id
    tail <- query$tail
    stop(errorCondition('credential', class = 'specmill_call_error'))
  }
  error <- tryCatch(runtime$get_item(c('a', 'b')), error = identity)
  stopifnot(inherits(error, 'specmill_call_error'))
  service$operations[['GET /items/{id}']]$validate_inputs <- 'missing_validator'
  write()
  error <- tryCatch(run(), error = identity)
  stopifnot(grepl(
    'Missing client validate_inputs',
    conditionMessage(error),
    fixed = TRUE
  ))
  cat('Input preflight acceptance passed.\n')
}
if (sys.nframe() == 0L) {
  input_preflight_acceptance()
}
