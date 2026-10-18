private_hook_state_acceptance <- function() {
  source <- tempfile(fileext = '.R')
  writeLines(
    c(
      'base::identity(NULL)',
      '(function() stop("must not run"))()',
      'mapped <- function(x) x'
    ),
    source
  )
  definitions <- getFromNamespace('tg_find_function_defs_in_file', 'specmill')
  stopifnot(identical(names(definitions(source)), 'mapped'))
  writeLines('broken <- function(', source)
  stopifnot(inherits(tryCatch(definitions(source), error = identity), 'error'))
  root <- tempfile('mapped-client-')
  dir.create(root)
  fixture <- system.file('catalogue', package = 'specmill', mustWork = TRUE)
  stopifnot(all(file.copy(
    list.files(fixture, full.names = TRUE),
    root,
    recursive = TRUE
  )))
  writeLines(
    c('config_version: 1', 'validation: false', 'services: [service.yml]'),
    file.path(root, 'specmill.yml')
  )
  service <- c(
    'id: mapped',
    'schemas: {files: [schema.json]}',
    'helper: catalogue_request',
    'selection: {methods: [GET], exclude: ["^/items$"]}',
    'hooks:',
    '  get_item: {pre_request: [normalize_input], post_response: [extract_output]}',
    'operations:',
    '  GET /items/{item_id}:',
    '    parameters:',
    '      path item_id: {name: identifier}',
    '      query language: {default: fr}',
    '    private_params: {chemicals: null}',
    '    post_params: [identifier, mode, language, enabled]',
    '    extra_parameters:',
    '      enabled: {type: logical, default: false}',
    '      mode: {type: character, default: [wide, raw]}',
    '    parameter_order: [identifier, mode, language, enabled]',
    '    request:',
    '      arguments:',
    '        route: {value: items}',
    '        id: {from: [params, identifier]}',
    '        language: {from: [params, language]}',
    '        enabled: {from: [params, enabled]}',
    '        amount: {value: 0.0}',
    '        payload: {from: [params, chemicals]}',
    '    docs:',
    '      title: Mapped item',
    '      lifecycle: stable',
    '      examples: [{identifier: sample}]'
  )
  put <- function(lines) writeLines(lines, file.path(root, 'service.yml'))
  put(service)
  project <- specmill::load_project(root)
  selected <- project$services$mapped
  operation <- specmill::read_operations(
    selected$files,
    selected$policy
  )$operations[[1L]]
  configured <- getFromNamespace('configure_operation', 'specmill')(
    operation,
    selected
  )
  env <- new.env(parent = baseenv())
  eval(
    parse(text = getFromNamespace('validation_runtime', 'specmill')()),
    env
  )
  calls <- list()
  order <- character()
  skip <- FALSE
  initial <- NULL
  post <- NULL
  env$run_hook <- function(name, stage, data) {
    order <<- c(order, stage)
    if (stage == 'pre_request') {
      initial <<- data
      stopifnot(
        'chemicals' %in% names(data$params),
        is.null(data$params$chemicals)
      )
      data$params <- list(chemicals = c('A', 'B'), language = NULL)
      data$skip_request <- skip
      data$result <- 'skipped'
      return(data)
    }
    post <<- data
    stopifnot(
      identical(
        names(data$params),
        c('identifier', 'mode', 'language', 'enabled')
      ),
      !'chemicals' %in% names(data$params),
      is.null(data$params$language)
    )
    data$result
  }
  env$catalogue_request <- function(...) {
    calls[[length(calls) + 1L]] <<- list(...)
    order <<- c(order, 'request')
    'complete'
  }
  render <- function(spec = configured$spec) {
    eval(
      parse(text = specmill::render_operation(configured$operation, spec)),
      env
    )
    env$get_item
  }
  fn <- render()
  stopifnot(!'chemicals' %in% names(formals(fn)))
  skip <- TRUE
  stopifnot(
    identical(fn('x'), 'skipped'),
    identical(order, 'pre_request'),
    !length(calls)
  )
  skip <- FALSE
  order <- character()
  stopifnot(
    identical(fn('x'), 'complete'),
    identical(order, c('pre_request', 'request', 'post_response')),
    identical(calls[[1L]]$payload, c('A', 'B')),
    is.null(calls[[1L]]$language),
    identical(post$params$identifier, 'x'),
    identical(post$params$enabled, FALSE)
  )
  # Partial updates preserve omitted values, including the initial private NULL.
  env$run_hook <- function(name, stage, data) {
    if (stage == 'pre_request') {
      data$params <- list(language = 'de')
      return(data)
    }
    stopifnot(
      !'chemicals' %in% names(data$params),
      identical(data$params$language, 'de')
    )
    data$result
  }
  fn('x')
  stopifnot('payload' %in% names(calls[[2L]]), is.null(calls[[2L]]$payload))
  invalid <- configured$spec
  invalid$private_params <- list(identifier = NULL)
  error <- tryCatch(render(invalid), error = identity)
  stopifnot(inherits(error, 'error'), grepl('collide', conditionMessage(error)))
  invalid <- configured$spec
  invalid$post_params <- list('unknown')
  error <- tryCatch(render(invalid), error = identity)
  stopifnot(
    inherits(error, 'error'),
    grepl('Unknown post_params', conditionMessage(error))
  )
  invalid <- configured$spec
  invalid$post_state <- 'hook_state'
  error <- tryCatch(render(invalid), error = identity)
  stopifnot(
    inherits(error, 'error'),
    grepl('post_state', conditionMessage(error))
  )
  cat(
    'Private hook state: initial NULL, partial updates, flat transport, selected post params and unchanged formals passed.\n'
  )
}

if (sys.nframe() == 0L) {
  private_hook_state_acceptance()
}
