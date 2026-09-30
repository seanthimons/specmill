response_handling_acceptance <- function() {
  port_file <- tempfile('response-port-')
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      retry_count <- 0L
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(request) {
          path <- request$PATH_INFO
          response <- function(body, type = 'application/json', status = 200L) {
            headers <- if (is.null(type)) {
              list()
            } else {
              list('Content-Type' = type)
            }
            list(status = status, headers = headers, body = body)
          }
          if (path == '/retry') {
            retry_count <<- retry_count + 1L
            return(response(
              paste0('{"attempt":', retry_count, '}'),
              status = if (retry_count < 3L) 503L else 200L
            ))
          }
          switch(
            path,
            '/csv' = response(
              'id,label name,active\n001,"a,b",TRUE\n002,"#hash",FALSE\n',
              'Text/CSV; charset=utf-8'
            ),
            '/tsv' = response(
              'id\tlabel name\n1\t"a,b"\n',
              'text/tab-separated-values'
            ),
            '/csv-empty' = response('', 'text/csv'),
            '/csv-header' = response('id,label name\n', 'text/csv'),
            '/csv-bad' = response('a,b\n1,2\n3\n', 'text/csv'),
            '/csv-extra' = response('a,b\n1,2,3\n', 'text/csv'),
            '/csv-quote' = response('a,b\n1,"unclosed\n', 'text/csv'),
            '/csv-multiline' = response('a,b\n1,"two\nlines"\n', 'text/csv'),
            '/envelope' = response(
              '{"records":[{"id":"001","x":null,"nested":[1,2]},{"id":2,"other":true,"nested":"one"}],"total":9}'
            ),
            '/empty-array' = response('[]'),
            '/empty-object' = response('{}'),
            '/failure-json' = response(
              '{"error":"missing"}',
              'application/json',
              404L
            ),
            '/object' = response('{"id":1}'),
            '/array' = response('[1,2]'),
            '/string' = response('"value"'),
            '/number' = response('1.5'),
            '/boolean' = response('true'),
            '/null' = response('null'),
            '/vendor' = response('{"id":2}', 'application/problem+json'),
            '/text' = response(
              as.raw(c(99, 97, 102, 233)),
              'text/plain; charset=iso-8859-1'
            ),
            '/json-as-text' = response('{"id":3}', 'text/plain'),
            '/binary' = response(as.raw(c(0, 255)), 'application/octet-stream'),
            '/empty' = response(raw(), 'application/json'),
            '/no-content' = response(NULL, status = 204L),
            '/missing-type' = response(charToRaw('plain'), NULL),
            '/unexpected-type' = response(
              charToRaw('<ok/>'),
              'application/xml'
            ),
            '/misleading-type' = response('not json'),
            '/bad-json' = response('{"secret":"response-secret"'),
            '/failure' = response('response-secret', 'text/plain', 503L),
            response('not found', 'text/plain', 404L)
          )
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file = port_file),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  on.exit(unlink(port_file), add = TRUE)
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
  code <- gsub(
    'DRY_RUN_ENV',
    deparse('RESPONSE_TEST_DRY_RUN'),
    code,
    fixed = TRUE
  )
  runtime <- new.env(parent = baseenv())
  eval(parse(text = code), runtime)
  request <- function(path, query = list(), ...) {
    runtime$api_request('GET', path, list(), query, NULL, ...)
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
    grepl(
      'HTTP 200 application/json',
      conditionMessage(decode_error),
      fixed = TRUE
    ),
    grepl(
      'HTTP 200 application/json',
      conditionMessage(malformed_error),
      fixed = TRUE
    ),
    grepl('HTTP 503 text/plain', conditionMessage(http_error), fixed = TRUE),
    !grepl('response-secret', conditionMessage(malformed_error), fixed = TRUE),
    !grepl('query-secret|response-secret', conditionMessage(http_error))
  )
  fails <- function(expr, pattern) {
    error <- tryCatch(force(expr), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  observed <- list()
  observer <- function(response, context, decode) {
    observed[[length(observed) + 1L]] <<- list(
      response = response,
      context = context
    )
    decode()
  }
  stopifnot(identical(
    request('/object', response_policy = observer),
    list(id = 1L)
  ))
  fails(
    request('/failure', list(api_key = 'secret'), response_policy = observer),
    'HTTP 503'
  )
  fails(request('/bad-json', response_policy = observer), 'Cannot decode')
  stopifnot(
    length(observed) == 3L,
    inherits(observed[[1L]]$response, 'httr2_response'),
    identical(
      observed[[2L]]$context,
      list(method = 'GET', status = 503L, media = 'text/plain')
    ),
    !grepl(
      'secret',
      paste(capture.output(str(observed[[2L]]$context)), collapse = '')
    )
  )
  retried <- request(
    '/retry',
    request_controls = list(max_retries = 2L),
    response_policy = observer
  )
  stopifnot(
    identical(retried$attempt, 3L),
    length(observed) == 4L,
    observed[[4L]]$context$status == 200L
  )
  replacement <- function(response, context, decode) NULL
  stopifnot(
    is.null(request('/failure', response_policy = replacement)),
    is.null(request('/bad-json', response_policy = replacement))
  )
  warning <- NULL
  recovered <- withCallingHandlers(
    request('/failure', response_policy = function(response, context, decode) {
      warning('selected warning')
      list()
    }),
    warning = function(w) {
      warning <<- w
      invokeRestart('muffleWarning')
    }
  )
  stopifnot(
    identical(recovered, list()),
    identical(conditionMessage(warning), 'selected warning')
  )
  fails(
    request('/object', response_policy = function(response, context, decode) {
      stop('selected abort')
    }),
    'selected abort'
  )
  stopifnot(identical(
    request(
      '/failure-json',
      response_policy = function(response, context, decode) {
        decode(check_status = FALSE)
      }
    ),
    list(error = 'missing')
  ))
  preserved <- request(
    '/envelope',
    response_policy = function(response, context, decode) {
      list(response = response, result = decode())
    }
  )
  stopifnot(
    preserved$result$total == 9L,
    httr2::resp_status(preserved$response) == 200L
  )
  delimited <- runtime$api_request_delimited
  csv <- request('/csv', response_policy = delimited)
  tsv <- request('/tsv', response_policy = delimited)
  stopifnot(
    is.character(request('/csv')),
    identical(names(csv), c('id', 'label name', 'active')),
    identical(csv$id, 1:2),
    identical(csv[['label name']], c('a,b', '#hash')),
    identical(csv$active, c(TRUE, FALSE)),
    identical(names(tsv), c('id', 'label name')),
    identical(tsv$id, 1L),
    identical(request('/csv-empty', response_policy = delimited), data.frame()),
    identical(
      names(request('/csv-header', response_policy = delimited)),
      c('id', 'label name')
    ),
    nrow(request('/csv-header', response_policy = delimited)) == 0L,
    identical(
      request('/csv-multiline', response_policy = delimited)$b,
      'two\nlines'
    ),
    identical(
      request('/json-as-text', response_policy = delimited),
      '{"id":3}'
    ),
    identical(
      request('/binary', response_policy = delimited),
      as.raw(c(0, 255))
    ),
    is.null(request('/empty', response_policy = delimited))
  )
  typed <- request(
    '/csv',
    response_policy = function(response, context, decode) {
      decode('delimited', col_classes = c(id = 'character'))
    }
  )
  stopifnot(identical(typed$id, c('001', '002')))
  fails(request('/csv-bad', response_policy = delimited), 'field counts')
  fails(request('/csv-extra', response_policy = delimited), 'field counts')
  # read.table reports unterminated quotes as a warning; malformed input must fail.
  quote_error <- tryCatch(
    request('/csv-quote', response_policy = delimited),
    error = identity
  )
  stopifnot(inherits(quote_error, 'error'))
  runtime$common_policy <- observer
  stopifnot(identical(
    request('/object', response_policy = 'common_policy'),
    list(id = 1L)
  ))
  options(response_test.response_policy = observer)
  on.exit(options(response_test.response_policy = NULL), add = TRUE)
  stopifnot(identical(request('/object'), list(id = 1L)))
  stopifnot(identical(
    request('/object', response_policy = NULL),
    list(id = 1L)
  ))
  options(response_test.response_policy = NULL)
  fails(
    request('/object', response_policy = 'absent'),
    'Missing client response policy'
  )
  fails(request('/object', response_policy = list()), 'response_policy must')
  fails(
    request('/object', response_policy = c('a', 'b')),
    'response_policy must'
  )
  records <- runtime$api_request_records
  table <- runtime$api_request_table
  native <- request('/envelope')
  stopifnot(is.null(native$records[[1L]]$x), native$total == 9L)
  selected <- records(
    native,
    collection = 'records',
    query = 'Q',
    null_to_na = TRUE
  )
  stopifnot(
    is.na(selected[[1L]]$x),
    identical(attr(selected[[2L]], 'query'), 'Q'),
    is.null(native$records[[1L]]$x)
  )
  tidy <- table(selected, as_table = tibble::as_tibble)
  stopifnot(
    inherits(tidy, 'tbl_df'),
    identical(tidy$id, 1:2),
    identical(tidy$nested, c('1; 2', 'one')),
    identical(tidy$query, c('Q', 'Q')),
    identical(tidy$other, c(NA, TRUE)),
    all(is.na(tidy$x)),
    identical(table(selected, type_convert = FALSE)$id, c('001', '2')),
    identical(records(NULL), list()),
    identical(records(request('/empty-object')), list()),
    identical(records(request('/empty-array')), list()),
    identical(table(list()), data.frame()),
    inherits(table(list(), as_table = tibble::as_tibble), 'tbl_df'),
    identical(records(request('/object')), list(list(id = 1L))),
    identical(records(request('/array')), list(1L, 2L)),
    identical(table(records(request('/string')))$value, 'value'),
    identical(table(records(request('/boolean')))$value, TRUE),
    identical(table(records(request('/number')))$value, 1.5),
    identical(
      table(list(list(x = 1), list(x = list(a = 2, b = 3))))$x,
      c('1', '2; 3')
    )
  )
  keyed <- records(list(A = list(id = 1), B = list(id = 2)), keyed = TRUE)
  stopifnot(identical(
    table(keyed, names_to = 'query_id')$query_id,
    c('A', 'B')
  ))
  fails(records(native, 'absent'), 'Missing collection')
  fails(records(native, 'records', query = 1:3), 'query must')
  fails(
    table(records(list(query = 'existing'), query = 'new')),
    'replace a record field'
  )
  cat(
    'Response handling: native defaults, final-response policy, delimited decoding and selected record/table formatting passed.\n'
  )
}

if (sys.nframe() == 0L) {
  response_handling_acceptance()
}
