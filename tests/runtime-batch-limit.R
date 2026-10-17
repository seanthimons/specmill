runtime_batch_limit_acceptance <- function() {
  root <- tempfile('runtime-batch-client-')
  schema <- tempfile(fileext = '.json')
  port_file <- tempfile('runtime-batch-port-')
  count_file <- tempfile('runtime-batch-count-')
  on.exit(
    unlink(c(root, schema, port_file, count_file), recursive = TRUE),
    add = TRUE
  )
  server <- callr::r_bg(
    function(port_file, count_file) {
      port <- httpuv::randomPort()
      count <- 0L
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          count <<- count + 1L
          writeLines(as.character(count), count_file)
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(
              list(
                body = rawToChar(req$rook.input$read()),
                query = req$QUERY_STRING,
                type = req$CONTENT_TYPE
              ),
              auto_unbox = TRUE
            )
          )
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file, count_file),
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
  op <- function(id, media, shape, parameters = list()) {
    list(
      operationId = id,
      parameters = parameters,
      requestBody = list(
        required = TRUE,
        content = setNames(list(list(schema = shape)), media)
      ),
      responses = list('200' = list(description = 'OK'))
    )
  }
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Runtime batch', version = '1'),
      paths = list(
        '/array' = list(
          post = op(
            'array',
            'application/json',
            list(type = 'array', items = list(type = 'string')),
            list(
              list(
                name = 'projection',
                `in` = 'query',
                schema = list(type = 'string', default = 'all')
              ),
              list(
                name = '.batch_limit',
                `in` = 'query',
                schema = list(type = 'string')
              )
            )
          )
        ),
        '/lines' = list(post = op('lines', 'text/plain', list(type = 'string')))
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'batchlimitclient',
    title = 'Runtime batch',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = paste0('http://127.0.0.1:', readLines(port_file))
  )
  writeLines(
    '.batch_limit <- function(response, context, decode) decode()',
    file.path(root, 'R', 'policy.R')
  )
  path <- file.path(root, 'apis', 'default.yml')
  service <- yaml::read_yaml(path, handlers = list(seq = identity))
  service$operations[['POST /array']] <- list(
    body = list(name = 'query'),
    parameter_order = list('query', 'projection'),
    batch = list(
      max_items = list(env = 'batch_limit', default = 100L),
      split = TRUE
    )
  )
  service$operations[['POST /lines']] <- list(
    body = list(name = 'query'),
    response_policy = '.batch_limit',
    text_encoding = 'lines',
    batch = list(
      max_items = list(env = 'batch_limit', default = 1000L, cap = 200L),
      split = TRUE
    )
  )
  yaml::write_yaml(service, path)
  withr::local_envvar(c(batch_limit = NA_character_))
  plan <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    validation = FALSE,
    mode = 'apply'
  )
  before <- tools::md5sum(list.files(file.path(root, 'R'), full.names = TRUE))
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  ids <- c('a', 'b', 'c')
  stopifnot(
    identical(names(formals(runtime$array))[1:2], c('query', 'projection')),
    length(runtime$array(ids)) == 1L
  )
  Sys.setenv(batch_limit = '2')
  positional <- runtime$array(ids)
  named <- runtime$array(query = ids, projection = 'all')
  stopifnot(
    identical(positional, named),
    length(named) == 2L,
    identical(
      vapply(named, `[[`, character(1), 'body'),
      c('["a","b"]', '["c"]')
    ),
    all(vapply(named, `[[`, character(1), 'type') == 'application/json')
  )
  # The generated local must not shadow a public input or the response policy.
  collision <- runtime$array(ids, .batch_limit = 'keep')
  stopifnot(grepl('.batch_limit=keep', collision[[1L]]$query, fixed = TRUE))
  line_result <- runtime$lines(ids)
  stopifnot(
    identical(vapply(line_result, `[[`, character(1), 'body'), c('a\nb', 'c')),
    all(vapply(line_result, `[[`, character(1), 'type') == 'text/plain')
  )
  Sys.setenv(batch_limit = '1')
  stopifnot(length(runtime$array(ids)) == 3L, length(runtime$lines(ids)) == 3L)
  Sys.setenv(batch_limit = '1000')
  stopifnot(length(runtime$array(rep('a', 201L))) == 1L)
  capped <- runtime$lines(rep('a', 201L))
  stopifnot(
    length(capped) == 2L,
    identical(capped[[1L]]$body, paste(rep('a', 200L), collapse = '\n')),
    identical(capped[[2L]]$body, 'a')
  )
  Sys.unsetenv('batch_limit')
  stopifnot(
    length(runtime$array(rep('a', 101L))) == 2L,
    length(runtime$lines(rep('a', 201L))) == 2L
  )
  Sys.setenv(batch_limit = '')
  if (is.na(Sys.getenv('batch_limit', unset = NA_character_))) {
    # Windows unsets the variable when given an empty value, so defaults apply.
    stopifnot(
      length(runtime$array(rep('a', 101L))) == 2L,
      length(runtime$lines(rep('a', 201L))) == 2L
    )
  } else {
    count <- readLines(count_file)
    for (fn in list(runtime$array, runtime$lines)) {
      stopifnot(
        inherits(try(fn(ids), silent = TRUE), 'try-error'),
        identical(readLines(count_file), count)
      )
    }
  }
  count <- readLines(count_file)
  for (value in c(' ', '0', '-1', '1.5', 'NaN', 'Inf', 'bad', '2147483648')) {
    Sys.setenv(batch_limit = value)
    for (fn in list(runtime$array, runtime$lines)) {
      stopifnot(
        inherits(try(fn(ids), silent = TRUE), 'try-error'),
        identical(readLines(count_file), count)
      )
    }
  }
  Sys.setenv(batch_limit = '2')
  stopifnot(identical(
    before,
    tools::md5sum(list.files(file.path(root, 'R'), full.names = TRUE))
  ))
  specmill::generate_client(
    root,
    config = 'specmill.yml',
    validation = FALSE,
    mode = 'check'
  )
  stopifnot(callr::r(
    function(root) {
      stopifnot(!isNamespaceLoaded('specmill'))
      Sys.setenv(batch_limit = '2')
      runtime <- new.env(parent = baseenv())
      for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
        sys.source(file, runtime)
      }
      stopifnot(length(runtime$array(c('a', 'b', 'c'))) == 2L)
      !isNamespaceLoaded('specmill')
    },
    list(root)
  ))
  guarded <- Filter(function(op) op$name == 'array', plan$operations)[[1L]]
  guarded$name <- 'guarded_array'
  guarded$guard_literals <- TRUE
  eval(
    parse(
      text = specmill::render_operation(guarded, list(helper = 'api_request'))
    ),
    runtime
  )
  runtime$list <- function(...) {
    stop('Client list() must not construct request data')
  }
  stopifnot(length(runtime$guarded_array(query = ids)) == 2L)
  rm('list', envir = runtime)
  for (binding in list(
    list(env = 'batch_limit'),
    list(env = 'bad name', default = 100L),
    list(env = 'batch_limit', default = 0L),
    list(env = 'batch_limit', default = 100L, cap = 0L)
  )) {
    invalid <- service
    invalid$operations[['POST /array']]$batch$max_items <- binding
    yaml::write_yaml(invalid, path)
    stopifnot(inherits(
      try(specmill::load_project(root), silent = TRUE),
      'try-error'
    ))
  }
  cat(
    'Runtime batch limit: per-call environment, defaults, caps, array/line bytes, public names, no regeneration/runtime dependency and invalid-value preflight passed.\n'
  )
}
if (sys.nframe() == 0L) {
  runtime_batch_limit_acceptance()
}
