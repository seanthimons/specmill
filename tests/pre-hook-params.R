pre_hook_params_acceptance <- function() {
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(schema), add = TRUE)
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Facade params', version = '1'),
      paths = list(
        '/search' = list(
          post = list(
            operationId = 'facade',
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  op <- specmill::read_operations(schema)$operations[[1L]]
  callbacks <- new.env(parent = baseenv())
  callbacks$paging <- function(operation) quote(params[['all_pages']]())
  settings <- list(
    inputs = list(
      query = list(type = 'any', default = NULL),
      limit = list(type = 'numeric', default = 50),
      all_pages = list(type = 'logical', default = FALSE)
    ),
    defer_inputs = list('all_pages'),
    pre_params = list('query', 'limit'),
    post_on_skip = TRUE,
    post_state = 'hook_state',
    request = list(
      arguments = list(
        body = list(
          from = structure(
            list('hook_state', 'request', 'body'),
            class = 'specmill_sequence'
          )
        ),
        paginate = list(callback = 'paging')
      )
    )
  )
  validate <- getFromNamespace('validate_settings', 'specmill')
  validate(settings, 'facade', callbacks)
  configure <- getFromNamespace('configure_operation', 'specmill')
  service <- list(
    helper = 'request',
    callbacks = callbacks,
    hooks = list(
      facade = list(
        pre_request = list('prepare'),
        post_response = list('format')
      )
    ),
    operations = setNames(list(settings), op$key)
  )
  configured <- configure(op, service)
  env <- new.env(parent = baseenv())
  eval(parse(text = getFromNamespace('validation_runtime', 'specmill')()), env)
  skip <- TRUE
  traces <- character()
  returned <- NULL
  env$run_hook <- function(name, stage, state) {
    traces <<- c(traces, stage)
    if (stage == 'pre_request') {
      stopifnot(
        identical(names(state$params), c('query', 'limit')),
        is.null(state$params$query),
        identical(state$params$limit, 50)
      )
      returned <<- list(
        params = list(query = 'changed', unknown = 'keep'),
        skip_request = skip,
        result = 'skipped',
        marker = 'preserve',
        request = list(body = list(query = 'changed'))
      )
      return(returned)
    }
    expected <- returned
    expected['result'] <- state['result']
    stopifnot(identical(state, expected))
    state$result
  }
  calls <- 0L
  env$request <- function(body, paginate) {
    traces <<- c(traces, 'request')
    calls <<- calls + 1L
    list(body = body, paginate = paginate)
  }
  render <- function(spec = configured$spec) {
    eval(
      parse(text = specmill::render_operation(configured$operation, spec)),
      env
    )
  }
  render()
  stopifnot(
    identical(names(formals(env$facade)), c('query', 'limit', 'all_pages')),
    identical(
      env$facade(all_pages = stop('must remain lazy on skip')),
      'skipped'
    ),
    calls == 0L,
    identical(traces, c('pre_request', 'post_response'))
  )
  skip <- FALSE
  traces <- character()
  forced <- 0L
  result <- env$facade(all_pages = {
    forced <- forced + 1L
    TRUE
  })
  stopifnot(
    identical(result, list(body = list(query = 'changed'), paginate = TRUE)),
    forced == 1L,
    calls == 1L,
    identical(traces, c('pre_request', 'request', 'post_response'))
  )
  for (value in list(
    list('missing'),
    list('query', 'query'),
    list(named = 'query')
  )) {
    bad <- configured$spec
    bad$pre_params <- value
    error <- tryCatch(
      {
        bad_settings <- settings
        bad_settings$pre_params <- value
        validate(bad_settings, 'bad', callbacks)
        render(bad)
      },
      error = identity
    )
    stopifnot(inherits(error, 'error'))
  }
  bad <- configured$spec
  bad$hooks <- list()
  stopifnot(inherits(tryCatch(render(bad), error = identity), 'error'))
  cat(
    'Initial hook params: selected state excludes deferred transport control, skip stays lazy, partial and extra return state survives post, and public formals remain unchanged.\n'
  )
}
if (sys.nframe() == 0L) {
  pre_hook_params_acceptance()
}
