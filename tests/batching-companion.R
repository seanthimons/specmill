batching_companion_acceptance <- function() {
  root <- tempfile('batching-client-')
  port_file <- tempfile('batching-port-')
  on.exit(unlink(c(root, port_file), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      history <- list()
      retried <- FALSE
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          if (req$PATH_INFO == '/history') {
            return(list(
              status = 200L,
              headers = list('Content-Type' = 'application/json'),
              body = jsonlite::toJSON(history, auto_unbox = TRUE)
            ))
          }
          bytes <- req$rook.input$read()
          history[[length(history) + 1L]] <<- list(
            path = req$PATH_INFO,
            query = req$QUERY_STRING,
            authorization = req$HTTP_AUTHORIZATION,
            type = req$CONTENT_TYPE,
            body = rawToChar(bytes)
          )
          fail <- req$PATH_INFO == '/fail' && rawToChar(bytes) == '["c","d"]'
          retry <- req$PATH_INFO == '/retry' && !retried
          if (retry) {
            retried <<- TRUE
          }
          list(
            status = if (fail || retry) 503L else 200L,
            headers = list(
              'Content-Type' = 'application/json',
              'Retry-After' = '0'
            ),
            body = jsonlite::toJSON(
              list(body = rawToChar(bytes)),
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
    list(port_file = port_file),
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
  base_url <- paste0('http://127.0.0.1:', readLines(port_file))
  schema <- tempfile('batching-schema-', fileext = '.json')
  on.exit(unlink(schema), add = TRUE)
  document <- jsonlite::read_json(system.file(
    'configuration/petstore.json',
    package = 'specmill'
  ))
  document$components$securitySchemes$bearer <- list(
    type = 'http',
    scheme = 'bearer'
  )
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  withr::local_envvar(c(BATCHINGCLIENT_BEARER = 'fixture-only'))
  specmill::initialize_client(
    root,
    schema,
    package = 'batchingclient',
    title = 'Batching Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = base_url,
    companions = 'batching'
  )
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  stopifnot(is.function(runtime$api_request_batched))
  history <- function() {
    httr2::resp_body_json(
      httr2::req_perform(httr2::request(paste0(base_url, '/history'))),
      simplifyVector = FALSE
    )
  }
  request <- function(
    body,
    path = '/echo',
    body_media = 'application/json',
    request_controls = list()
  ) {
    runtime$api_request(
      'POST',
      path,
      path_params = list(),
      query = list(filter = 'fixed'),
      body = body,
      auth = list(list(list(
        scheme = 'bearer',
        type = 'bearer',
        envvar = 'BATCHINGCLIENT_BEARER'
      ))),
      body_media = body_media,
      batch = if (body_media == 'application/json') {
        list(max_items = 2)
      } else {
        list()
      },
      request_controls = request_controls
    )
  }
  for (n in c(0L, 1L, 2L, 3L, 5L)) {
    before <- length(history())
    values <- letters[seq_len(n)]
    result <- runtime$api_request_batched(
      request,
      values,
      2,
      policy = list(build = function(chunk, index) as.list(chunk))
    )
    wire <- history()
    after <- length(wire)
    stopifnot(
      after - before == ceiling(n / 2),
      length(result) == ceiling(n / 2)
    )
    if (n) {
      calls <- wire[seq.int(before + 1L, after)]
      expected <- switch(
        as.character(n),
        '1' = '["a"]',
        '2' = '["a","b"]',
        '3' = c('["a","b"]', '["c"]'),
        '5' = c('["a","b"]', '["c","d"]', '["e"]')
      )
      stopifnot(
        identical(vapply(calls, `[[`, character(1), 'body'), expected),
        all(
          vapply(calls, `[[`, character(1), 'authorization') ==
            'Bearer fixture-only'
        ),
        all(vapply(calls, `[[`, character(1), 'query') == '?filter=fixed')
      )
    }
  }
  before <- length(history())
  for (limit in list(0, -1, 1.1, NA_real_, Inf, '2')) {
    stopifnot(inherits(
      try(
        runtime$api_request_batched(request, letters[1:3], limit),
        silent = TRUE
      ),
      'try-error'
    ))
  }
  stopifnot(length(history()) == before)
  text <- runtime$api_request_batched(
    request,
    c('b', 'a', 'b', NA, '', 'c'),
    2,
    body_media = 'text/plain',
    policy = list(
      normalize = function(x) unique(x[!is.na(x) & nzchar(x)]),
      build = function(chunk, index) paste(chunk, collapse = '\n')
    )
  )
  stopifnot(identical(
    lapply(text, `[[`, 'body'),
    list('1' = 'b\na', '2' = 'c')
  ))
  before <- length(history())
  result <- runtime$api_request_batched(
    request,
    c('a', 'b', 'c'),
    2,
    path = '/retry',
    request_controls = list(max_retries = 1, retry_writes = TRUE),
    policy = list(build = function(chunk, index) as.list(chunk))
  )
  wire <- history()[seq.int(before + 1L, length(history()))]
  stopifnot(
    length(result) == 2L,
    length(wire) == 3L,
    identical(
      vapply(wire, `[[`, character(1), 'body'),
      c('["a","b"]', '["a","b"]', '["c"]')
    ),
    all(vapply(wire, `[[`, character(1), 'query') == '?filter=fixed'),
    all(
      vapply(wire, `[[`, character(1), 'authorization') == 'Bearer fixture-only'
    )
  )
  before <- length(history())
  error <- try(
    runtime$api_request_batched(
      request,
      letters[1:5],
      2,
      path = '/fail',
      policy = list(build = function(chunk, index) as.list(chunk))
    ),
    silent = TRUE
  )
  stopifnot(inherits(error, 'try-error'), length(history()) - before == 2L)
  for (mode in c('drop', 'keep')) {
    before <- length(history())
    warnings <- character()
    result <- withCallingHandlers(
      runtime$api_request_batched(
        request,
        letters[1:5],
        2,
        path = '/fail',
        policy = list(
          build = function(chunk, index) as.list(chunk),
          on_error = mode
        )
      ),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart('muffleWarning')
      }
    )
    wire <- history()[seq.int(before + 1L, length(history()))]
    stopifnot(
      length(wire) == 3L,
      length(warnings) == 1L,
      grepl('Batch 2 failed', warnings, fixed = TRUE),
      identical(
        vapply(wire, `[[`, character(1), 'body'),
        c('["a","b"]', '["c","d"]', '["e"]')
      ),
      identical(
        names(result),
        if (mode == 'keep') c('1', '2', '3') else c('1', '3')
      )
    )
    if (mode == 'keep') stopifnot(is.null(result[[2L]]))
  }
  stopifnot(inherits(
    try(request(as.list(letters[1:3])), silent = TRUE),
    'try-error'
  ))
  cat(
    'Batching companion: localhost bytes, bounds, transport and partial failures passed.\n'
  )
}
if (sys.nframe() == 0L) {
  batching_companion_acceptance()
}
