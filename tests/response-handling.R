response_handling_acceptance <- function() {
  port_file <- tempfile('response-port-')
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(request) {
          path <- request$PATH_INFO
          response <- function(body, type = 'application/json', status = 200L) {
            headers <- if (is.null(type)) list() else list('Content-Type' = type)
            list(status = status, headers = headers, body = body)
          }
          switch(
            path,
            '/object' = response('{"id":1}'),
            '/array' = response('[1,2]'),
            '/string' = response('"value"'),
            '/number' = response('1.5'),
            '/boolean' = response('true'),
            '/null' = response('null'),
            '/vendor' = response('{"id":2}', 'application/problem+json'),
            '/text' = response(as.raw(c(99, 97, 102, 233)), 'text/plain; charset=iso-8859-1'),
            '/json-as-text' = response('{"id":3}', 'text/plain'),
            '/binary' = response(as.raw(c(0, 255)), 'application/octet-stream'),
            '/empty' = response(raw(), 'application/json'),
            '/no-content' = response(NULL, status = 204L),
            '/missing-type' = response(charToRaw('plain'), NULL),
            '/unexpected-type' = response(charToRaw('<ok/>'), 'application/xml'),
            '/misleading-type' = response('not json'),
            '/bad-json' = response('{"secret":"response-secret"'),
            '/failure' = response('response-secret', 'text/plain', 503L),
            response('not found', 'text/plain', 404L)
          )
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat httpuv::service(100)
    },
    list(port_file = port_file),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  on.exit(unlink(port_file), add = TRUE)
  for (i in seq_len(200L)) {
    if (file.exists(port_file)) break
    if (!server$is_alive()) server$get_result()
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  template <- if (file.exists('inst/templates/request.R')) {
    'inst/templates/request.R'
  } else {
    system.file('templates/request.R', package = 'specmill', mustWork = TRUE)
  }
  code <- paste(readLines(template), collapse = '\n')
  code <- gsub(
    'BASE_URL',
    deparse(paste0('http://127.0.0.1:', readLines(port_file))),
    code,
    fixed = TRUE
  )
  code <- gsub('DRY_RUN_ENV', deparse('RESPONSE_TEST_DRY_RUN'), code, fixed = TRUE)
  runtime <- new.env(parent = baseenv())
  eval(parse(text = code), runtime)
  request <- function(path, query = list()) {
    runtime$api_request('GET', path, list(), query, NULL)
  }
  stopifnot(
    identical(request('/object'), list(id = 1L)),
    identical(request('/array'), list(1L, 2L)),
    identical(request('/string'), 'value'),
    identical(request('/number'), 1.5),
    identical(request('/boolean'), TRUE),
    is.null(request('/null')),
    identical(request('/vendor'), list(id = 2L)),
    identical(request('/text'), 'café'),
    identical(request('/json-as-text'), '{"id":3}'),
    identical(request('/binary'), as.raw(c(0, 255))),
    is.null(request('/empty')),
    is.null(request('/no-content')),
    identical(request('/missing-type'), charToRaw('plain')),
    identical(request('/unexpected-type'), charToRaw('<ok/>'))
  )
  decode_error <- tryCatch(request('/misleading-type'), error = identity)
  malformed_error <- tryCatch(request('/bad-json'), error = identity)
  http_error <- tryCatch(
    request('/failure', list(api_key = 'query-secret')),
    error = identity
  )
  stopifnot(
    grepl('HTTP 200 application/json', conditionMessage(decode_error), fixed = TRUE),
    grepl('HTTP 200 application/json', conditionMessage(malformed_error), fixed = TRUE),
    grepl('HTTP 503 text/plain', conditionMessage(http_error), fixed = TRUE),
    !grepl('response-secret', conditionMessage(malformed_error), fixed = TRUE),
    !grepl('query-secret|response-secret', conditionMessage(http_error))
  )
  cat('Response handling: typed success bodies, empty responses, safe HTTP errors, and safe decode errors passed.\n')
}

if (sys.nframe() == 0L) {
  response_handling_acceptance()
}
