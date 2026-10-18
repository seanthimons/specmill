request_throttle_acceptance <- function() {
  validate <- getFromNamespace('validate_settings', 'specmill')
  throttle <- list(capacity = 4L, fill_time_s = 1)
  validate(list(request_controls = list(throttle = throttle)), 'throttled')
  scaffold <- getFromNamespace('request_helper_scaffold', 'specmill')
  helper <- scaffold(
    'api_request',
    'https://example.invalid',
    NULL,
    'THROTTLE_DRY_RUN',
    companions = 'batching'
  )
  runtime <- new.env(parent = baseenv())
  eval(parse(text = helper$code), runtime)
  request <- function(
    controls = list(),
    path = '/one',
    method = 'GET',
    body = NULL
  ) {
    runtime$api_request(
      method,
      path,
      list(),
      list(),
      body,
      request_controls = controls
    )
  }
  withr::local_options(list(throttle.dry_run = TRUE))
  baseline <- request()
  stopifnot(is.null(baseline$policies$throttle_realm))
  native <- request(list(throttle = throttle, max_retries = 2L))
  expected <- httr2::req_throttle(
    httr2::request('https://example.invalid'),
    capacity = 4L,
    fill_time_s = 1
  )
  stopifnot(identical(
    native$policies$throttle_realm,
    expected$policies$throttle_realm
  ))
  stopifnot(
    identical(
      request(list(throttle = throttle), '/two')$policies$throttle_realm,
      native$policies$throttle_realm
    ),
    !is.null(native$policies$retry_max_tries)
  )
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(schema), add = TRUE)
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Throttle', version = '1'),
      servers = list(list(url = 'https://example.invalid')),
      paths = list(
        '/one' = list(
          get = list(
            operationId = 'one',
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  operation <- specmill::read_operations(schema)$operations[[1L]]
  configured <- getFromNamespace('configure_operation', 'specmill')(
    operation,
    list(
      helper = 'api_request',
      defaults = list(request_controls = list(throttle = throttle))
    )
  )
  eval(
    parse(
      text = specmill::render_operation(configured$operation, configured$spec)
    ),
    runtime
  )
  stopifnot(
    runtime$one()$policies$throttle_realm == expected$policies$throttle_realm
  )
  custom <- throttle
  custom$realm <- 'specmill-reviewed-throttle'
  stopifnot(
    request(
      list(throttle = custom),
      method = 'POST',
      body = list()
    )$policies$throttle_realm ==
      custom$realm
  )
  withr::with_options(list(throttle.request = list(throttle = custom)), {
    stopifnot(
      request(list(throttle = throttle))$policies$throttle_realm == custom$realm
    )
  })
  invalid <- list(
    list(),
    list(capacity = 0, fill_time_s = 1),
    list(capacity = 1.5, fill_time_s = 1),
    list(capacity = 4, fill_time_s = 0),
    list(capacity = Inf, fill_time_s = 1),
    list(capacity = 4, fill_time_s = NA_real_),
    list(capacity = c(1, 2), fill_time_s = 1),
    list(capacity = 4, fill_time_s = 1, realm = ''),
    list(capacity = 4, fill_time_s = 1, unknown = TRUE)
  )
  for (value in invalid) {
    stopifnot(inherits(
      try(
        validate(list(request_controls = list(throttle = value)), 'bad'),
        silent = TRUE
      ),
      'try-error'
    ))
    error <- tryCatch(
      runtime$api_request_each(
        function(x) request(list(throttle = value)),
        'one',
        1L,
        on_error = 'drop'
      ),
      error = identity
    )
    stopifnot(inherits(error, 'error'), inherits(error, 'specmill_call_error'))
  }
  # Real execution consumes the shared httr2 bucket across GET, POST and fan-out.
  port_file <- tempfile('throttle-port-')
  on.exit(unlink(port_file), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = '{"ok":true}'
          )
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
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
    if (!server$is_alive()) {
      server$get_result()
    }
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  live <- list(
    capacity = 100L,
    fill_time_s = 3600,
    realm = basename(tempfile('throttle-test-'))
  )
  withr::with_options(
    list(
      throttle.dry_run = FALSE,
      throttle.request = list(
        base_url = paste0('http://127.0.0.1:', readLines(port_file))
      )
    ),
    {
      stopifnot(isTRUE(request(list(throttle = live))$ok))
      stopifnot(isTRUE(
        request(list(throttle = live), method = 'POST', body = list())$ok
      ))
      result <- runtime$api_request_each(
        function(x) request(list(throttle = live), paste0('/', x)),
        c('one', 'two'),
        1L
      )
      stopifnot(length(result) == 2L)
      status <- httr2::throttle_status()
      bucket <- status[status$realm == live$realm, ]
      stopifnot(
        nrow(bucket) == 1L,
        bucket$capacity == 100L,
        bucket$tokens <= 96L
      )
    }
  )
  cat(
    'Request throttling: default unchanged, declarative/runtime policy, shared real GET/POST/fan-out bucket and hard configuration errors passed.\n'
  )
}
if (sys.nframe() == 0L) {
  request_throttle_acceptance()
}
