pagination_companion_acceptance <- function() {
  port_file <- tempfile('pagination-policy-port-')
  on.exit(unlink(port_file), add = TRUE)
  process <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      calls <- list()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          response <- function(x, status = 200L) {
            list(
              status = status,
              headers = list('Content-Type' = 'application/json'),
              body = jsonlite::toJSON(x, auto_unbox = TRUE, null = 'null')
            )
          }
          if (req$PATH_INFO == '/calls') {
            return(response(calls))
          }
          bytes <- rawToChar(req$rook.input$read())
          query <- httr2::url_query_parse(req$QUERY_STRING)
          payload <- if (nzchar(bytes)) {
            jsonlite::fromJSON(bytes, simplifyVector = FALSE)
          } else {
            NULL
          }
          scenario <- query$scenario
          position <- if (!is.null(payload)) {
            payload$pagination$position
          } else {
            query$position
          }
          if (is.null(position)) {
            position <- '0'
          }
          index <- if (scenario == 'cursor') {
            if (position == '0') {
              0
            } else if (position == 'token one') {
              1
            } else {
              2
            }
          } else {
            as.numeric(position)
          }
          calls[[length(calls) + 1L]] <<- list(
            bytes = bytes,
            auth = req$HTTP_AUTHORIZATION,
            position = position,
            scenario = scenario
          )
          if (scenario == 'failure' && index == 1) {
            return(response('failed', 503L))
          }
          if (scenario == 'empty') {
            return(response(list(data = list())))
          }
          values <- if (index >= 3) {
            list()
          } else if (scenario == 'large') {
            as.list(seq_len(12000))
          } else {
            list(index)
          }
          response(list(
            data = values,
            length = length(values),
            total = 3,
            last = index >= 2,
            pagination = list(
              hasNext = index < 2,
              nextCursor = if (index < 2) {
                c('token one', 'token two')[[index + 1L]]
              } else {
                NULL
              }
            )
          ))
        })
      )
      on.exit(server$stop())
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file),
    supervise = TRUE
  )
  on.exit(process$kill(), add = TRUE)
  for (i in seq_len(200L)) {
    if (file.exists(port_file)) {
      break
    }
    if (!process$is_alive()) {
      process$get_result()
    }
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  origin <- paste0('http://127.0.0.1:', readLines(port_file))
  request <- function(path = '/items') {
    httr2::req_headers(
      httr2::request(paste0(origin, path)),
      Authorization = 'Bearer local-policy'
    )
  }
  fetch <- function(body = NULL, position = NULL, size = NULL, scenario) {
    req <- httr2::req_url_query(
      request(),
      position = position,
      size = size,
      scenario = scenario
    )
    if (!is.null(body)) {
      req <- httr2::req_body_json(req, body)
    }
    httr2::resp_body_json(httr2::req_perform(req))
  }
  calls <- function() {
    httr2::resp_body_json(httr2::req_perform(request('/calls')))
  }
  policy <- list(
    mode = 'offset',
    parameter = c('body', 'pagination', 'position'),
    size_parameter = c('body', 'pagination', 'size'),
    page_size = 2,
    start = 0,
    items = function(x) x$data,
    max_items = NULL,
    advance = function(x, position, page_size) position + x$length,
    completed = function(x, state) state$item_count >= x$total,
    format = function(x) unlist(x$pages)
  )
  payload <- list(
    filters = list(active = TRUE),
    options = list(flag = 'keep'),
    sort = list('name'),
    pagination = list(unrelated = 'preserved')
  )
  result <- specmill::paginated(
    fetch,
    body = payload,
    scenario = 'offset',
    policy = policy
  )
  sent <- calls()
  stopifnot(
    identical(result, 0:2),
    length(sent) == 3,
    identical(payload$pagination, list(unrelated = 'preserved')),
    identical(vapply(sent, function(x) x$position, 0), c(0, 1, 2))
  )
  for (i in seq_along(sent)) {
    expected <- payload
    expected$pagination$position <- i - 1L
    expected$pagination$size <- 2
    stopifnot(
      sent[[i]]$bytes ==
        as.character(jsonlite::toJSON(expected, auto_unbox = TRUE)),
      sent[[i]]$auth == 'Bearer local-policy'
    )
  }
  cursor <- policy
  cursor$mode <- 'cursor'
  cursor$start <- '0'
  cursor$advance <- NULL
  cursor$completed <- function(x, state) !x$pagination$hasNext
  cursor$next_cursor <- function(x) x$pagination$nextCursor
  result <- specmill::paginated(
    fetch,
    body = payload,
    scenario = 'cursor',
    policy = cursor
  )
  stopifnot(
    identical(result, 0:2),
    identical(
      vapply(tail(calls(), 3), function(x) x$position, ''),
      c('0', 'token one', 'token two')
    )
  )
  plain <- list(
    mode = 'page',
    parameter = 'position',
    size_parameter = 'size',
    page_size = 2,
    start = 0,
    items = function(x) x$data,
    max_items = NULL
  )
  spring <- specmill::paginated(
    fetch,
    scenario = 'spring',
    policy = plain,
    completed = function(x, state) x$last
  )
  short <- specmill::paginated(
    fetch,
    scenario = 'short',
    policy = plain,
    stop_on_short = TRUE
  )
  stopifnot(
    spring$requests == 3,
    spring$stop_reason == 'completed',
    short$requests == 1,
    short$stop_reason == 'short_page',
    specmill::paginated(fetch, scenario = 'empty', policy = plain)$requests == 1
  )
  warning_result <- function(expr) {
    warnings <- character()
    value <- withCallingHandlers(expr, warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart('muffleWarning')
    })
    stopifnot(length(warnings) == 1L)
    value
  }
  capped <- warning_result(specmill::paginated(
    fetch,
    scenario = 'page',
    policy = plain,
    max_pages = 2,
    warn_limits = TRUE
  ))
  stopifnot(capped$stop_reason == 'max_pages', capped$requests == 2)
  for (recovery in c('partial', 'empty')) {
    recovered <- warning_result(specmill::paginated(
      fetch,
      scenario = 'failure',
      policy = plain,
      error_policy = recovery
    ))
    stopifnot(
      recovered$stop_reason == 'request_error',
      recovered$requests == 2,
      recovered$item_count == if (recovery == 'partial') 1 else 0
    )
  }
  failed <- tryCatch(
    specmill::paginated(fetch, scenario = 'failure', policy = plain),
    error = identity
  )
  stopifnot(inherits(failed, 'error'), grepl('503', conditionMessage(failed)))
  large <- specmill::paginated(
    fetch,
    scenario = 'large',
    policy = plain,
    max_pages = 1
  )
  stopifnot(large$item_count == 12000)
  before <- length(calls())
  for (bad in list(
    list(unknown = TRUE),
    list(stop_on_short = NA),
    list(max_items = Inf)
  )) {
    failed <- tryCatch(
      specmill::paginated(fetch, scenario = 'page', policy = c(plain, bad)),
      error = identity
    )
    stopifnot(inherits(failed, 'error'))
  }
  stopifnot(length(calls()) == before)
  cat(
    'Pagination policies: localhost nested state, exact bytes, metadata, cursors, limits, formatting and recovery passed.\n'
  )
}
if (sys.nframe() == 0L) {
  pagination_companion_acceptance()
}
