deferred_inputs_acceptance <- function() {
  configure <- getFromNamespace('configure_operation', 'specmill')
  validate <- getFromNamespace('validate_settings', 'specmill')
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(schema), add = TRUE)
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Deferred', version = '1'),
      paths = list(
        '/lookup' = list(
          post = list(
            operationId = 'lookup',
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
  op <- specmill::read_operations(schema)$operations[[1L]]
  op$name <- 'lookup'
  callbacks <- new.env(parent = baseenv())
  callbacks$body <- function(operation) {
    quote(list(ids = params$ids, option = params$option))
  }
  callbacks$response <- function(operation) {
    quote(function(response, context, decode) {
      list(body = decode(), tidy = params$tidy(), again = params$tidy())
    })
  }
  settings <- list(
    inputs = list(
      ids = list(type = 'character', required = TRUE),
      option = list(type = 'character', default = 'AnyId'),
      tidy = list(type = 'logical', default = TRUE)
    ),
    normalize_inputs = list(ids = 'initial_ids'),
    defer_inputs = list('tidy'),
    request = list(
      arguments = list(
        method = list(value = 'POST'),
        path = list(value = '/lookup'),
        body = list(callback = 'body'),
        response_policy = list(callback = 'response')
      )
    )
  )
  render <- function(value = settings) {
    service <- list(
      helper = 'api_request',
      callbacks = callbacks,
      hooks = list(lookup = list(pre_request = list('cleanup'))),
      operations = setNames(list(value), op$key)
    )
    configured <- configure(op, service)
    specmill::render_operation(configured$operation, configured$spec)
  }
  env <- new.env(parent = baseenv())
  env$initial_ids <- function(x) {
    if (is.null(x) || !length(x)) {
      stop('initial ids guard')
    }
    as.character(x)
  }
  env$run_hook <- function(fn_name, hook_type, state) {
    ids <- unique(state$params$ids)
    ids <- ids[!is.na(ids) & nzchar(ids)]
    if (!length(ids)) {
      stop('empty query')
    }
    state$params$ids <- ids
    state
  }
  calls <- 0L
  transport_error <- FALSE
  env$api_request <- function(method, path, body, response_policy) {
    calls <<- calls + 1L
    if (transport_error) {
      stop('transport sentinel')
    }
    response_policy(NULL, list(), function() body)
  }
  eval(parse(text = render()), env)
  message_of <- function(expr) {
    conditionMessage(tryCatch(force(expr), error = identity))
  }
  stopifnot(
    identical(
      message_of(env$lookup(
        NULL,
        option = stop('option evaluated'),
        tidy = stop('tidy evaluated')
      )),
      'initial ids guard'
    ),
    identical(
      message_of(env$lookup(
        c('', NA),
        option = stop('option evaluated'),
        tidy = stop('tidy evaluated')
      )),
      'option evaluated'
    ),
    identical(
      message_of(env$lookup(c('', NA), tidy = stop('tidy evaluated'))),
      'empty query'
    ),
    calls == 0L
  )
  evaluated <- 0L
  result <- env$lookup(c('one', 'one', '', NA), tidy = {
    evaluated <- evaluated + 1L
    FALSE
  })
  stopifnot(
    identical(
      result,
      list(
        body = list(ids = 'one', option = 'AnyId'),
        tidy = FALSE,
        again = FALSE
      )
    ),
    evaluated == 1L,
    calls == 1L
  )
  transport_error <- TRUE
  stopifnot(identical(
    message_of(env$lookup('one', tidy = stop('tidy evaluated'))),
    'transport sentinel'
  ))
  transport_error <- FALSE
  for (value in list(NULL, FALSE, 0, list(flag = FALSE))) {
    stopifnot(identical(
      env$lookup('one', option = NULL, tidy = value),
      list(body = list(ids = 'one', option = NULL), tidy = value, again = value)
    ))
  }
  # Omission leaves the existing eager capture contract intact.
  eager <- settings
  eager$defer_inputs <- NULL
  eval(parse(text = render(eager)), env)
  stopifnot(identical(
    message_of(env$lookup(c('', NA), tidy = stop('tidy evaluated'))),
    'tidy evaluated'
  ))
  fails <- function(fn, pattern) {
    error <- tryCatch(fn(), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  for (value in list(
    TRUE,
    list(NA_character_),
    list('tidy', 'tidy'),
    list('not a name')
  )) {
    fails(
      function() validate(list(defer_inputs = value), 'test'),
      'defer_inputs'
    )
  }
  bad <- settings
  bad$defer_inputs <- list('missing')
  fails(function() render(bad), 'client inputs')
  fails(function() render(list(defer_inputs = list('body'))), 'client inputs')
  bad <- settings
  bad$defer_inputs <- list('ids')
  fails(function() render(bad), 'normalize_inputs')
  fails(
    function() {
      validate(
        list(defer_inputs = list('tidy'), implementation = 'existing'),
        'test'
      )
    },
    'generated implementation'
  )
  # The complete client generation path retains policy and stable ownership.
  root <- tempfile('deferred-client-')
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    root,
    schema,
    package = 'deferredclient',
    title = 'Deferred Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  policy_file <- file.path(root, 'R/input-policy.R')
  writeLines(
    c(
      'initial_ids <- function(x) { if (is.null(x) || !length(x)) stop("initial ids guard"); as.character(x) }',
      'cleanup <- function(state) {',
      '  ids <- unique(state$params$ids); ids <- ids[!is.na(ids) & nzchar(ids)]',
      '  if (!length(ids)) stop("empty query")',
      '  state$params$ids <- ids; state',
      '}',
      'run_hook <- function(fn_name, hook_type, state) { if (hook_type == "pre_request") cleanup(state) else state$result }'
    ),
    policy_file
  )
  service_file <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_file, handlers = list(seq = function(x) x))
  settings$request$arguments$path_params <- list(value = list())
  settings$request$arguments$query <- list(value = list())
  service$operations <- setNames(list(settings), op$key)
  service$hooks <- list(lookup = list(pre_request = list('cleanup')))
  yaml::write_yaml(service, service_file)
  applied <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    callbacks = callbacks,
    validation = FALSE,
    mode = 'apply'
  )
  checked <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    callbacks = callbacks,
    validation = FALSE,
    mode = 'check'
  )
  stopifnot(nrow(applied$diagnostics) == 0L, nrow(checked$diagnostics) == 0L)
  generated <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, generated)
  }
  generated$api_request <- function(method, path, body, response_policy, ...) {
    response_policy(NULL, list(), function() body)
  }
  stopifnot(identical(
    message_of(generated$lookup(c('', NA), tidy = stop('tidy evaluated'))),
    'empty query'
  ))
  defaults <- service
  defaults$defaults$defer_inputs <- list('tidy')
  yaml::write_yaml(defaults, service_file)
  fails(
    function() {
      specmill::generate_client(
        root,
        config = 'specmill.yml',
        callbacks = callbacks,
        validation = FALSE,
        mode = 'plan'
      )
    },
    'belongs under operations'
  )
  cat(
    'Deferred inputs: guard/body-option/format order, memoized evaluation, transport precedence, NULL values, unchanged eager capture and invalid policy passed.\n'
  )
}
if (sys.nframe() == 0L) {
  deferred_inputs_acceptance()
}
