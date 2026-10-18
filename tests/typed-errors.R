typed_errors_acceptance <- function() {
  # Exercise the client-owned template, with real httr2 HTTP error construction.
  template <- system.file(
    'templates/request.R',
    package = 'specmill',
    mustWork = TRUE
  )
  code <- paste(readLines(template), collapse = '\n')
  code <- gsub('BASE_URL', '"http://127.0.0.1:1"', code, fixed = TRUE)
  code <- gsub('DRY_RUN_ENV', '"TYPEDCLIENT_DRY_RUN"', code, fixed = TRUE)
  runtime <- new.env(parent = baseenv())
  eval(parse(text = code), runtime)
  request <- function(...) {
    runtime$api_request('GET', '/items', list(), list(), NULL, ...)
  }
  capture <- function(expr) tryCatch(force(expr), error = identity)
  local({
    sentinel <- structure(
      list(
        message = 'transport sentinel',
        call = NULL,
        resp = NULL,
        parent = structure(
          list(message = 'timeout'),
          class = 'curl_error_operation_timedout'
        )
      ),
      class = c('httr2_error', 'rlang_error', 'error', 'condition')
    )
    testthat::local_mocked_bindings(
      req_perform = function(...) stop(sentinel),
      .package = 'httr2'
    )
    stopifnot(inherits(capture(request()), 'simpleError'))
    preserved <- capture(request(
      request_controls = list(preserve_errors = TRUE)
    ))
    stopifnot(identical(preserved, sentinel))
    # Single versus multiple count policy remains outside the transport boundary.
    send <- function(items) {
      request(request_controls = list(preserve_errors = TRUE))
    }
    single <- capture(runtime$api_request_each(
      send,
      'one',
      1L,
      on_error = list(single = 'stop', multiple = 'drop')
    ))
    stopifnot(identical(single, sentinel))
    many <- suppressWarnings(runtime$api_request_each(
      send,
      c('one', 'two'),
      1L,
      on_error = list(single = 'stop', multiple = 'drop')
    ))
    stopifnot(identical(
      attr(many, 'failed'),
      c(one = 'transport sentinel', two = 'transport sentinel')
    ))
  })
  # The scaffold's standalone decoder has no transport-scope closure variables.
  decoder <- runtime$api_request_decode
  response <- httr2::response(
    200L,
    headers = list('content-type' = 'application/json'),
    body = charToRaw('{"ok":true}')
  )
  stopifnot(identical(decoder(response), list(ok = TRUE)))
  policy <- function(response, context, decode) decode()
  stopifnot(identical(
    decoder(response, response_policy = policy),
    list(ok = TRUE)
  ))
  # Real received HTTP responses, not req_perform mocks that bypass httr2 handling.
  port_file <- tempfile()
  on.exit(unlink(port_file), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          list(
            status = as.integer(sub('^/', '', req$PATH_INFO)),
            headers = list('Content-Type' = 'application/json'),
            body = '{"error":"missing"}'
          )
        })
      )
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(50)
      }
    },
    list(port_file),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  for (i in seq_len(200L)) {
    if (file.exists(port_file)) {
      break
    }
    stopifnot(server$is_alive())
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  origin <- paste0('http://127.0.0.1:', readLines(port_file))
  for (status in c(404L, 500L)) {
    path <- paste0('/', status)
    legacy <- capture(httr2::req_perform(httr2::request(paste0(origin, path))))
    native <- capture(runtime$api_request(
      'GET',
      path,
      list(),
      list(),
      NULL,
      server = list(url = origin),
      request_controls = list(preserve_errors = TRUE)
    ))
    default <- capture(runtime$api_request(
      'GET',
      path,
      list(),
      list(),
      NULL,
      server = list(url = origin)
    ))
    stopifnot(
      identical(class(legacy), class(native)),
      identical(native$status, status),
      inherits(native$resp, 'httr2_response'),
      identical(
        httr2::resp_body_raw(native$resp),
        httr2::resp_body_raw(legacy$resp)
      ),
      inherits(default, 'simpleError'),
      !inherits(default, 'httr2_http')
    )
  }
  denied <- function(items) {
    runtime$api_request(
      'GET',
      '/401',
      list(),
      list(),
      NULL,
      server = list(url = origin),
      request_controls = list(preserve_errors = TRUE)
    )
  }
  error <- capture(runtime$api_request_each(
    denied,
    c('a', 'b'),
    1L,
    on_error = 'drop'
  ))
  stopifnot(inherits(error, 'specmill_call_error'))
  for (invalid in list(NA, 'yes', 1, c(TRUE, FALSE))) {
    error <- capture(request(
      request_controls = list(preserve_errors = invalid)
    ))
    stopifnot(
      inherits(error, 'specmill_call_error'),
      grepl('preserve_errors', conditionMessage(error))
    )
  }
  local({
    withr::local_options(typedclient.request = list(preserve_errors = 'yes'))
    stopifnot(inherits(capture(request()), 'specmill_call_error'))
  })
  # Response policy can still deliberately handle a received status.
  handled <- runtime$api_request(
    'GET',
    '/404',
    list(),
    list(),
    NULL,
    server = list(url = origin),
    request_controls = list(preserve_errors = TRUE),
    response_policy = function(response, context, decode) {
      decode(check_status = FALSE)
    }
  )
  stopifnot(identical(handled, list(error = 'missing')))
  cat(
    'Typed errors: exact transport condition, real HTTP metadata, unchanged defaults and hard calls passed.\n'
  )
}
if (sys.nframe() == 0L) {
  typed_errors_acceptance()
}
