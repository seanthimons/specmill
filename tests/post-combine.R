post_combine_acceptance <- function() {
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
  write_service <- function(hooks) {
    service <- original
    service$operations[['GET /items/{id}']] <- list(
      batch = list(fan_out = 'id', on_error = 'drop')
    )
    service$operations[['POST /bulk']] <- list(
      batch = list(max_items = 2L, split = TRUE)
    )
    service$hooks <- hooks
    yaml::write_yaml(service, service_path)
  }
  # The executor mentions post_combine, as a client updated for the stage would.
  write_executor <- function(stage_name = "'post_combine'") {
    writeLines(
      c(
        'log_hook <- function(state) state',
        'build_table <- function(state) {',
        '  options(combineclient.log = c(getOption("combineclient.log"), paste("post_response", paste(state$params$id, collapse = ","))))',
        '  api_request_table(api_request_records(state$result, query = state$params$id))',
        '}',
        'combine_hook <- function(state) {',
        '  options(combineclient.combined = list(class = class(state$result), params = state$params))',
        '  out <- state$result',
        '  if (is.data.frame(out)) {',
        '    out$combined <- TRUE',
        '    attr(out, "failed") <- NULL',
        '  }',
        '  out',
        '}',
        'run_hook <- function(fn_name, hook_type, state) {',
        '  if (hook_type == "pre_request") {',
        '    options(combineclient.log = c(getOption("combineclient.log"), paste("pre_request", paste(state$params$id, collapse = ","))))',
        '    return(state)',
        '  }',
        paste0(
          '  if (hook_type == "post_response") return(build_table(state))'
        ),
        paste0('  if (hook_type == ', stage_name, ') {'),
        '    options(combineclient.log = c(getOption("combineclient.log"), "combine ran"))',
        '    return(combine_hook(state))',
        '  }',
        '  stop("Unsupported hook stage")',
        '}'
      ),
      file.path(root, 'R/hooks.R')
    )
  }
  fails <- function(pattern) {
    error <- tryCatch(run(), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }

  # post_combine only makes sense where results are combined.
  write_executor()
  write_service(list(plain = list(post_combine = list('combine_hook'))))
  fails('post_combine requires batch.fan_out or batch.split')
  # A configured stage the client's executor cannot run stops generation, naming the fix.
  write_executor(stage_name = "'post_response_again'")
  write_service(list(
    get_item = list(
      post_response = list('build_table'),
      post_combine = list('combine_hook')
    )
  ))
  fails('does not accept that stage')
  # Unsupported stage names are still rejected.
  write_executor()
  write_service(list(get_item = list(post_batch = list('combine_hook'))))
  fails('unknown field post_batch')

  # The supported shape: per-request pre/post hooks, then one post_combine.
  write_executor()
  write_service(list(
    get_item = list(
      pre_request = list('log_hook'),
      post_response = list('build_table'),
      post_combine = list('combine_hook')
    ),
    bulk = list(post_combine = list('combine_hook'))
  ))
  run()
  before <- tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE))
  run()
  run('check')
  stopifnot(identical(
    before,
    tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE))
  ))
  code <- function(name) {
    paste(readLines(file.path(root, 'R', paste0(name, '.R'))), collapse = '\n')
  }
  stopifnot(
    grepl('"post_combine"', code('get_item'), fixed = TRUE),
    grepl('"post_combine"', code('bulk'), fixed = TRUE),
    !grepl('post_combine', code('plain'), fixed = TRUE)
  )
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  requests <- character()
  runtime$api_request <- function(method, path, path_params, query, body, ...) {
    requests <<- c(
      requests,
      if (length(path_params)) {
        path_params$id
      } else {
        paste(unlist(body), collapse = ',')
      }
    )
    id <- if (length(path_params)) path_params$id else unlist(body)[[1L]]
    if (identical(id, 'bad')) {
      stop('HTTP 404 response')
    }
    lapply(id, function(one) {
      list(sex = if (one %in% c('a', 'c', 'e')) 'F' else 'MF')
    })
  }
  withr::local_options(combineclient.log = NULL, combineclient.combined = NULL)

  # Types are recovered once over all requests, then post_combine sees the finished table.
  result <- runtime$get_item(c('a', 'b'))
  combined <- getOption('combineclient.combined')
  stopifnot(
    identical(requests, c('a', 'b')),
    identical(result$sex, c('F', 'MF')),
    identical(result$combined, c(TRUE, TRUE)),
    identical(combined$class, 'data.frame'),
    identical(combined$params$id, c('a', 'b')),
    identical(
      getOption('combineclient.log'),
      c(
        'pre_request a',
        'post_response a',
        'pre_request b',
        'post_response b',
        'combine ran'
      )
    )
  )
  # One input runs the same stages; the hook still runs once.
  options(combineclient.log = NULL)
  one <- runtime$get_item('a')
  stopifnot(
    identical(
      getOption('combineclient.log'),
      c('pre_request a', 'post_response a', 'combine ran')
    ),
    identical(one$sex, FALSE),
    identical(one$combined, TRUE)
  )
  # Dropped requests are still recorded after a post_combine hook that returns a new object.
  options(combineclient.log = NULL)
  dropped <- suppressWarnings(runtime$get_item(c('a', 'bad', 'c')))
  stopifnot(
    identical(attr(dropped, 'failed'), c(bad = 'HTTP 404 response')),
    identical(dropped$query, c('a', 'c')),
    sum(getOption('combineclient.log') == 'combine ran') == 1L
  )
  # Split wrappers run it once with the caller's whole array, not a chunk.
  options(combineclient.log = NULL, combineclient.combined = NULL)
  requests <- character()
  bulk <- runtime$bulk(c('a', 'b', 'c', 'd', 'e'))
  stopifnot(
    length(requests) == 3L,
    identical(
      unlist(getOption('combineclient.combined')$params$body),
      c('a', 'b', 'c', 'd', 'e')
    ),
    identical(sum(getOption('combineclient.log') == 'combine ran'), 1L)
  )
  # The scaffold executor accepts the stage and returns the result when no chain is set.
  executor <- new.env(parent = baseenv())
  template <- if (file.exists('inst/templates/hooks.R')) {
    'inst/templates/hooks.R'
  } else {
    system.file('templates/hooks.R', package = 'specmill', mustWork = TRUE)
  }
  sys.source(template, executor)
  executor$shout <- function(data) toupper(data$result)
  executor$read_hook_config <- function() {
    list(
      chained = list(post_combine = list('shout')),
      empty = list(pre_request = list('shout'))
    )
  }
  stopifnot(
    identical(
      executor$run_hook(
        'chained',
        'post_combine',
        list(result = 'x', params = list())
      ),
      'X'
    ),
    identical(
      executor$run_hook(
        'empty',
        'post_combine',
        list(result = 'y', params = list())
      ),
      'y'
    ),
    identical(
      executor$run_hook(
        'unlisted',
        'post_combine',
        list(result = 'z', params = list())
      ),
      'z'
    )
  )
  error <- tryCatch(
    executor$run_hook('chained', 'post_batch', list()),
    error = identity
  )
  stopifnot(inherits(error, 'error'))
  cat(
    'Post combine: one run on the combined result, batched-only, executor guard and failure records passed.\n'
  )
}

if (sys.nframe() == 0L) {
  post_combine_acceptance()
}
