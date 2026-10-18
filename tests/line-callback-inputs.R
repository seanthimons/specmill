line_callback_inputs_acceptance <- function() {
  root <- tempfile('line-inputs-client-')
  schema <- tempfile(fileext = '.json')
  port_file <- tempfile('line-inputs-port-')
  count_file <- tempfile('line-inputs-count-')
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
  operation <- function(id) {
    list(
      operationId = id,
      requestBody = list(
        required = TRUE,
        content = list(
          'text/plain' = list(schema = list(type = 'string', minLength = 1L))
        )
      ),
      responses = list('200' = list(description = 'OK'))
    )
  }
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Lines', version = '1'),
      paths = list(
        '/chunked' = list(post = operation('chunked')),
        '/whole' = list(post = operation('whole'))
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'lineinputsclient',
    title = 'Lines',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = paste0('http://127.0.0.1:', readLines(port_file))
  )
  callbacks <- new.env(parent = baseenv())
  callbacks$keep_entries <- function(operation) {
    quote(function(response, context, decode) {
      value <- decode()
      value['inputs'] <- list(params[['query']])
      value$collision <- params[['.text_body']]
      value
    })
  }
  seq_value <- function(...) structure(list(...), class = 'specmill_sequence')
  path <- file.path(root, 'apis', 'default.yml')
  service <- yaml::read_yaml(path, handlers = list(seq = identity))
  settings <- function(route) {
    list(
      body = list(name = 'query'),
      parameter_order = seq_value('query', '.text_body'),
      text_encoding = 'lines',
      extra_parameters = list(
        '.text_body' = list(default = 'keep', type = 'character')
      ),
      request = list(
        arguments = list(
          method = list(value = 'POST'),
          path = list(value = route),
          path_params = list(value = list()),
          query = list(value = list()),
          body = list(from = seq_value('params', 'query')),
          body_media = list(value = 'text/plain'),
          response_policy = list(callback = 'keep_entries')
        )
      )
    )
  }
  service$operations[['POST /chunked']] <- settings('/chunked')
  service$operations[['POST /chunked']]$batch <- list(
    split = TRUE,
    max_items = list(env = 'batch_limit', default = 2L, cap = 2L)
  )
  service$operations[['POST /whole']] <- settings('/whole')
  yaml::write_yaml(service, path)
  run <- function(mode = 'apply') {
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      callbacks = callbacks,
      validation = FALSE,
      mode = mode
    )
  }
  run()
  env <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, env)
  }
  withr::local_envvar(c(batch_limit = '2'))
  multiple <- env$chunked(c('one', 'two'))
  embedded <- env$chunked('one\ntwo')
  stopifnot(
    identical(multiple[[1L]]$body, embedded[[1L]]$body),
    identical(multiple[[1L]]$inputs, c('one', 'two')),
    identical(embedded[[1L]]$inputs, 'one\ntwo'),
    identical(multiple[[1L]]$collision, 'keep')
  )
  entries <- c(
    '\u00e9',
    '',
    'same',
    'same',
    'embedded\nLF',
    'trailing\n',
    'last'
  )
  chunks <- list(entries[1:2], entries[3:4], entries[5:6], entries[7])
  result <- env$chunked(entries)
  stopifnot(
    identical(lapply(result, `[[`, 'inputs'), chunks),
    identical(
      vapply(result, `[[`, character(1), 'body'),
      vapply(chunks, paste, character(1), collapse = '\n')
    ),
    identical(result, env$chunked(query = entries))
  )
  whole <- env$whole(entries)
  stopifnot(
    identical(whole$inputs, entries),
    identical(whole$body, paste(entries, collapse = '\n'))
  )
  # A pre-request hook changes logical entries before wire encoding.
  operation <- Filter(
    function(op) op$key == 'POST /whole',
    specmill::read_operations(schema)$operations
  )[[1L]]
  operation$name <- 'hooked'
  operation$text_encoding <- 'lines'
  configured <- getFromNamespace('configure_operation', 'specmill')(
    operation,
    list(
      helper = 'api_request',
      callbacks = callbacks,
      hook_callback = 'test_hook',
      hooks = list(hooked = list(pre_request = list('suffix'))),
      operations = setNames(list(settings('/whole')), operation$key)
    )
  )
  env$test_hook <- function(name, stage, state) {
    state$params$query <- paste0(state$params$query, '!')
    state
  }
  eval(
    parse(
      text = specmill::render_operation(configured$operation, configured$spec)
    ),
    env
  )
  hooked <- env$hooked(c('one', 'two'))
  stopifnot(
    identical(hooked$body, 'one!\ntwo!'),
    identical(hooked$inputs, c('one!', 'two!'))
  )
  Sys.setenv(batch_limit = '1')
  single <- env$chunked(entries[-2])
  stopifnot(identical(lapply(single, `[[`, 'inputs'), as.list(entries[-2])))
  # Validation still happens before HTTP and counts entries, not newline characters.
  before <- readLines(count_file)
  error <- tryCatch(env$chunked(c('valid', NA_character_)), error = identity)
  stopifnot(inherits(error, 'error'), identical(before, readLines(count_file)))
  check <- run('check')
  stopifnot(
    !length(check$diagnostics),
    !length(check$mapping_diagnostics),
    !length(check$drift)
  )
  cat(
    'Line callbacks retain per-chunk inputs while exact LF wire bytes, limits, invalid preflight and freshness pass.\n'
  )
}

if (sys.nframe() == 0L) {
  line_callback_inputs_acceptance()
}
