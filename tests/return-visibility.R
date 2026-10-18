return_visibility_acceptance <- function() {
  configure <- getFromNamespace('configure_operation', 'specmill')
  validation_runtime <- getFromNamespace('validation_runtime', 'specmill')
  validate <- getFromNamespace('validate_settings', 'specmill')
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(schema), add = TRUE)
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Visibility', version = '1'),
      paths = list(
        '/calculate' = list(
          post = list(
            operationId = 'calculate',
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
  op$name <- 'calculate'
  seq_value <- function(...) structure(list(...), class = 'specmill_sequence')
  ref <- function(name) list(from = seq_value('params', name))
  callbacks <- new.env(parent = baseenv())
  callbacks$chemicals <- function(operation) {
    quote(lapply(params$query, function(id) list(sid = id)))
  }
  settings <- list(
    preserve_visibility = TRUE,
    inputs = list(
      query = list(type = 'character', required = TRUE),
      odds_ratio = list(type = 'integer', default = 3L),
      p_val = list(type = 'numeric', default = 0.05),
      true_pos = list(type = 'numeric', default = 3)
    ),
    request = list(
      arguments = list(
        method = list(value = 'POST'),
        path = list(value = '/calculate'),
        body = list(
          object = list(
            chemicals = list(callback = 'chemicals'),
            options = list(
              object = list(
                OR = ref('odds_ratio'),
                PV1 = ref('p_val'),
                TP = ref('true_pos')
              )
            )
          )
        )
      )
    )
  )
  render <- function(settings, extra = list(), operation = op) {
    service <- c(
      list(
        helper = 'api_request',
        callbacks = callbacks,
        operations = setNames(list(settings), op$key)
      ),
      extra
    )
    configured <- configure(operation, service)
    specmill::render_operation(configured$operation, configured$spec)
  }
  env <- new.env(parent = baseenv())
  eval(parse(text = validation_runtime()), env)
  captured <- NULL
  visible <- FALSE
  response <- structure(
    list(score = 0, flag = FALSE),
    class = 'visibility_probe'
  )
  env$api_request <- function(method, path, body, ...) {
    captured <<- body
    if (visible) response else invisible(response)
  }
  eval(parse(text = render(settings)), env)
  for (value in list(
    response,
    NULL,
    FALSE,
    0,
    list(nested = list(flag = FALSE, absent = NULL))
  )) {
    response <- value
    for (flag in c(FALSE, TRUE)) {
      visible <- flag
      result <- withVisible(env$calculate('one'))
      stopifnot(
        identical(result$value, response),
        identical(result$visible, flag)
      )
    }
  }
  for (options in list(
    list(),
    list(odds_ratio = NULL, p_val = NULL, true_pos = NULL),
    list(odds_ratio = FALSE, p_val = 0, true_pos = 0),
    list(odds_ratio = list(absent = NULL, flag = FALSE, count = 0))
  )) {
    do.call(env$calculate, c(list(query = c('one', 'two')), options))
    expected <- modifyList(
      list(odds_ratio = 3L, p_val = 0.05, true_pos = 3),
      options,
      keep.null = TRUE
    )
    stopifnot(identical(
      captured,
      list(
        chemicals = list(list(sid = 'one'), list(sid = 'two')),
        options = setNames(expected, c('OR', 'PV1', 'TP'))
      )
    ))
  }
  # Guarded helper dispatch via do.call forwards the same visibility.
  guarded <- op
  guarded$routes <- list(list(key = 'POST /calculate'))
  guarded_settings <- settings
  guarded_settings$route_guard <- TRUE
  visible <- FALSE
  eval(parse(text = render(guarded_settings, operation = guarded)), env)
  stopifnot(!withVisible(env$calculate('one'))$visible)
  # Unconfigured clients retain the existing visible result behavior.
  settings$preserve_visibility <- FALSE
  visible <- FALSE
  eval(parse(text = render(settings)), env)
  stopifnot(withVisible(env$calculate('one'))$visible)
  # The default native helper call also forwards visibility with no request mapping.
  settings <- list(preserve_visibility = TRUE)
  eval(parse(text = render(settings)), env)
  stopifnot(!withVisible(env$calculate(list()))$visible)
  fails <- function(fn, pattern) {
    error <- tryCatch(fn(), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  for (value in list(NULL, 'yes', 1, NA, c(TRUE, FALSE))) {
    fails(
      function() {
        validate(list(preserve_visibility = value), 'test')
      },
      'preserve_visibility'
    )
  }
  fails(
    function() {
      validate(
        list(preserve_visibility = TRUE, implementation = 'existing'),
        'test'
      )
    },
    'generated implementation'
  )
  for (kind in c('pre_request', 'post_response', 'post_combine')) {
    fails(
      function() {
        render(
          settings,
          list(hooks = list(calculate = setNames(list('hook'), kind)))
        )
      },
      'without hooks'
    )
  }
  iterated <- op
  iterated$iterate <- list(split = TRUE)
  fails(function() render(settings, operation = iterated), 'unbatched')
  cat(
    'Return visibility: native/mapped helper values and visibility, NULL/FALSE/zero/nested option bindings, unchanged default and unsupported pipeline rejection passed.\n'
  )
}

if (sys.nframe() == 0L) {
  return_visibility_acceptance()
}
