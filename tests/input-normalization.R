input_normalization_acceptance <- function() {
  root <- tempfile('input-normalization-client-')
  schema <- tempfile(fileext = '.json')
  port_file <- tempfile('input-normalization-port-')
  count_file <- tempfile('input-normalization-count-')
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
                path = req$PATH_INFO,
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
  op <- function(
    id,
    parameters = list(),
    body = NULL,
    media = 'application/json'
  ) {
    value <- list(
      operationId = id,
      parameters = parameters,
      responses = list('200' = list(description = 'OK'))
    )
    if (!is.null(body)) {
      value$requestBody <- list(
        required = TRUE,
        content = setNames(list(list(schema = body)), media)
      )
    }
    value
  }
  string <- list(type = 'string')
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Normalize', version = '1'),
      paths = list(
        '/items/{id}' = list(
          get = op(
            'items',
            list(list(
              name = 'id',
              `in` = 'path',
              required = TRUE,
              schema = string
            ))
          )
        ),
        '/array' = list(
          post = op('array', body = list(type = 'array', items = string))
        ),
        '/lines' = list(post = op('lines', body = string, media = 'text/plain'))
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'normalizeclient',
    title = 'Normalize',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = paste0('http://127.0.0.1:', readLines(port_file))
  )
  writeLines(
    c(
      'normalizations <- 0L',
      'clean_ids <- function(x) {',
      '  normalizations <<- normalizations + 1L',
      '  x <- unique(as.vector(x))',
      '  x <- x[!is.na(x) & nzchar(x)]',
      '  if (!length(x)) stop("Empty identifiers", call. = FALSE)',
      '  x',
      '}',
      'bad_ids <- function(x) 1L'
    ),
    file.path(root, 'R', 'normalize.R')
  )
  path <- file.path(root, 'apis', 'default.yml')
  service <- yaml::read_yaml(path, handlers = list(seq = identity))
  service$operations[['GET /items/{id}']] <- list(
    parameters = list('path id' = list(name = 'query')),
    extra_parameters = list(option = list(default = NULL)),
    normalize_inputs = list(query = 'clean_ids'),
    batch = list(fan_out = 'id')
  )
  service$operations[['POST /array']] <- list(
    body = list(name = 'query'),
    normalize_inputs = list(query = 'clean_ids'),
    batch = list(split = TRUE, max_items = 2L)
  )
  service$operations[['POST /lines']] <- list(
    body = list(name = 'query'),
    text_encoding = 'lines',
    batch = list(split = TRUE, max_items = 2L)
  )
  run <- function(mode = 'apply') {
    yaml::write_yaml(service, path)
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      validation = FALSE,
      mode = mode
    )
  }
  fails <- function(fn, pattern) {
    before <- if (file.exists(count_file)) readLines(count_file) else '0'
    error <- tryCatch(fn(), error = identity)
    stopifnot(
      inherits(error, 'error'),
      grepl(pattern, conditionMessage(error)),
      identical(
        before,
        if (file.exists(count_file)) readLines(count_file) else '0'
      )
    )
  }
  run()
  load <- function() {
    env <- new.env(parent = baseenv())
    for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
      sys.source(file, env)
    }
    env
  }
  env <- load()
  values <- c('one', 'one', '', NA_character_)
  result <- env$items(values)
  stopifnot(
    length(result) == 1L,
    identical(result[[1L]]$path, '/items/one'),
    env$normalizations == 1L,
    identical(result, env$items(query = values)),
    env$normalizations == 2L
  )
  # The selected input is normalized before unrelated option promises are forced.
  fails(
    function() env$items(NULL, option = stop('option evaluated')),
    'Empty identifiers'
  )
  fails(function() env$items(c('', NA_character_)), 'Empty identifiers')
  before_normalization <- env$normalizations
  normalized <- env$array(c('\u00e9', '\u00e9', '', NA_character_, 'b', 'c'))
  stopifnot(
    env$normalizations == before_normalization + 1L,
    length(normalized) == 2L,
    identical(
      vapply(normalized, `[[`, character(1), 'body'),
      c('["\u00e9","b"]', '["c"]')
    )
  )
  # No implicit normalization for text: duplicate entries and LF boundaries remain.
  text <- env$lines(c('a', 'a', 'b'))
  stopifnot(identical(vapply(text, `[[`, character(1), 'body'), c('a\na', 'b')))
  # A normalizer's output still passes native type validation before HTTP.
  service$operations[['GET /items/{id}']]$normalize_inputs$query <- 'bad_ids'
  run()
  invalid <- load()
  fails(function() invalid$items('one'), 'Invalid')
  # Defaults retain duplicates and reject missing values unless explicitly configured.
  service$operations[['GET /items/{id}']]$normalize_inputs <- NULL
  run()
  plain <- load()
  stopifnot(length(plain$items(c('one', 'one'))) == 2L)
  fails(function() plain$items(values), 'Invalid')
  service$operations[['GET /items/{id}']]$normalize_inputs <- list(
    unknown = 'clean_ids'
  )
  error <- tryCatch(run(), error = identity)
  stopifnot(
    inherits(error, 'error'),
    grepl('Unknown public input', conditionMessage(error))
  )
  validate <- getFromNamespace('validate_settings', 'specmill')
  for (setting in list(
    list(normalize_inputs = 'clean_ids'),
    list(normalize_inputs = list('clean_ids')),
    list(normalize_inputs = list(query = 1L)),
    list(normalize_inputs = list(query = 'not a function')),
    list(
      normalize_inputs = list(query = 'clean_ids'),
      implementation = 'existing'
    )
  )) {
    error <- tryCatch(validate(setting, 'test'), error = identity)
    stopifnot(inherits(error, 'error'))
  }
  service$operations[['GET /items/{id}']]$normalize_inputs <- list(
    query = 'clean_ids'
  )
  service$defaults$normalize_inputs <- list(query = 'clean_ids')
  error <- tryCatch(run(), error = identity)
  stopifnot(
    inherits(error, 'error'),
    grepl('belongs under operations', conditionMessage(error))
  )
  service$defaults$normalize_inputs <- NULL
  run()
  check <- run('check')
  stopifnot(
    !length(check$diagnostics),
    !length(check$mapping_diagnostics),
    !length(check$drift)
  )
  cat(
    'Input normalization: once before validation/fan-out/array splitting, client errors, renamed inputs, unchanged defaults/line bytes and freshness passed.\n'
  )
}

if (sys.nframe() == 0L) {
  input_normalization_acceptance()
}
