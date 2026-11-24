# Evidence for runtime concurrency and promise return against a localhost
# service with injected latency. Sends nothing outside 127.0.0.1.
# source('dev/measure_concurrency.R'); measure_concurrency()
measure_concurrency <- function(
  output = 'dev/audits/issue-325-concurrency.md',
  items = 24L,
  latency = 0.2,
  levels = c(1L, 2L, 4L, 8L)
) {
  root <- tempfile('measure-client-')
  schema <- tempfile(fileext = '.json')
  ready <- tempfile()
  on.exit(unlink(c(root, schema, ready), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(ready, latency) {
      port <- httpuv::randomPort()
      httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          # Answer late without blocking, so overlapping requests overlap.
          promises::promise(function(resolve, reject) {
            later::later(
              function() {
                resolve(list(
                  status = 200L,
                  headers = list('Content-Type' = 'application/json'),
                  body = '[{"ok":true}]'
                ))
              },
              latency
            )
          })
        })
      )
      writeLines(as.character(port), ready)
      repeat {
        httpuv::service(10)
        later::run_now(0)
      }
    },
    list(ready, latency),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  while (!file.exists(ready)) {
    if (!server$is_alive()) {
      server$get_result()
    }
    Sys.sleep(0.025)
  }
  origin <- paste0('http://127.0.0.1:', readLines(ready))
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Measure', version = '1'),
      servers = list(list(url = origin)),
      paths = list(
        '/items/{id}' = list(
          get = list(
            operationId = 'item',
            parameters = list(list(
              name = 'id',
              `in` = 'path',
              required = TRUE,
              schema = list(type = 'string')
            )),
            responses = list('200' = list(description = 'OK'))
          )
        ),
        '/one/{id}' = list(
          get = list(
            operationId = 'one',
            parameters = list(list(
              name = 'id',
              `in` = 'path',
              required = TRUE,
              schema = list(type = 'string')
            )),
            responses = list('200' = list(description = 'OK'))
          )
        ),
        '/bulk' = list(
          post = list(
            operationId = 'bulk',
            requestBody = list(
              required = TRUE,
              content = list(
                'application/json' = list(
                  schema = list(type = 'array', items = list(type = 'string'))
                )
              )
            ),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'measureclient',
    title = 'Measure Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT'
  )
  path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(path, handlers = list(seq = function(x) x))
  # A throttle far above the measured rates, so latency is the only limit.
  service$defaults$request_controls$throttle <- list(
    capacity = 1000L,
    fill_time_s = 1L
  )
  service$defaults$batch <- list(concurrency = max(levels))
  service$operations[['GET /items/{id}']] <- list(batch = list(fan_out = 'id'))
  service$operations[['POST /bulk']] <- list(
    batch = list(split = TRUE, max_items = 1L)
  )
  service$operations[['GET /one/{id}']] <- list(async = TRUE)
  yaml::write_yaml(service, path)
  specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply',
    validation = FALSE
  )
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  ids <- as.character(seq_len(items))
  seconds <- function(expr) round(unname(system.time(expr)[['elapsed']]), 2)
  rows <- lapply(levels, function(level) {
    withr::local_options(
      measureclient.api_request.batching = list(concurrency = level)
    )
    data.frame(
      concurrency = level,
      fan_out_get_s = seconds(runtime$item(ids)),
      split_post_s = seconds(runtime$bulk(ids))
    )
  })
  timings <- do.call(rbind, rows)
  # Promise return: how long the call holds the session, and whether the event
  # loop keeps running while a Shiny ExtendedTask waits on it.
  withr::local_options(measureclient.request = list(async = TRUE))
  wait <- function(done) {
    while (!done()) {
      later::run_now(0.01)
    }
  }
  finished <- FALSE
  promises::then(runtime$one('warm'), function(value) finished <<- TRUE)
  wait(function() finished)
  held <- seconds(promise <- runtime$one('a'))
  finished <- FALSE
  promises::then(promise, function(value) finished <<- TRUE)
  wait(function() finished)
  ticks <- 0L
  tick <- function() {
    ticks <<- ticks + 1L
    later::later(tick, 0.02)
  }
  task <- shiny::ExtendedTask$new(function(id) runtime$one(id))
  blocked <- seconds(runtime$item('a'))
  task$invoke('b')
  tick()
  wait(function() shiny::isolate(task$status()) != 'running')
  status <- shiny::isolate(task$status())
  lines <- c(
    '# Issue 325: runtime concurrency and promise return',
    '',
    paste0(
      'Localhost service, ',
      latency,
      ' s injected latency per request, ',
      items,
      ' items, one request per item. Produced by ',
      '`dev/measure_concurrency.R` with httr2 ',
      as.character(utils::packageVersion('httr2')),
      '.'
    ),
    '',
    'The ceiling in YAML is the largest level; the session option lowers it.',
    'The fixture speaks HTTP/1.1, and curl waits on HTTP/2 negotiation before',
    'opening further connections (see tests/testthat/test-parallel-batches.R),',
    'so the low levels gain less here than the latency alone predicts.',
    '',
    '| concurrency | fan-out GET (s) | split POST (s) |',
    '|---|---|---|',
    sprintf(
      '| %d | %.2f | %.2f |',
      timings$concurrency,
      timings$fan_out_get_s,
      timings$split_post_s
    ),
    '',
    '## Promise return',
    '',
    paste0('- A plain call held the session for ', blocked, ' s.'),
    paste0(
      '- With the `async` request option on, the reviewed wrapper returned ',
      'its promise after ',
      held,
      ' s.'
    ),
    paste0(
      '- A `shiny::ExtendedTask` wrapping that wrapper finished with status `',
      status,
      '`; a 20 ms timer fired ',
      ticks,
      ' times while it ran.'
    )
  )
  writeLines(lines, output)
  stopifnot(identical(status, 'success'), ticks > 2L, held < latency)
  invisible(timings)
}
