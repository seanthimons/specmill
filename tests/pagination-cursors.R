pagination_cursors_acceptance <- function() {
  port_file <- tempfile('cursor-port-')
  on.exit(unlink(port_file), add = TRUE)
  process <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      other_port <- httpuv::randomPort()
      calls <- list()
      other_calls <- 0L
      other <- httpuv::startServer(
        '127.0.0.1',
        other_port,
        list(call = function(req) {
          other_calls <<- other_calls + 1L
          list(status = 200L, headers = list(), body = 'untrusted')
        })
      )
      on.exit(other$stop())
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          response <- function(x, headers = list()) {
            list(
              status = 200L,
              headers = c(list('Content-Type' = 'application/json'), headers),
              body = jsonlite::toJSON(x, auto_unbox = TRUE, null = 'null')
            )
          }
          if (req$PATH_INFO == '/calls') {
            return(response(list(calls = calls, other = other_calls)))
          }
          q <- httr2::url_query_parse(sub('^\\?', '', req$QUERY_STRING))
          calls[[length(calls) + 1L]] <<- list(
            path = req$PATH_INFO,
            query = q,
            auth = req$HTTP_AUTHORIZATION,
            key = req$HTTP_X_API_KEY
          )
          path <- req$PATH_INFO
          cursor <- q$cursor
          index <- if (is.null(cursor)) {
            1L
          } else if (cursor == 'opaque +/=') {
            2L
          } else {
            3L
          }
          token <- if (index == 1L) {
            'opaque +/='
          } else if (index == 2L) {
            'last'
          } else {
            NULL
          }
          data <- list(list(internal_id = paste0('GJ-', index)))
          if (path == '/empty') {
            data <- list()
          }
          if (path == '/repeat') {
            token <- 'opaque +/='
          }
          if (path == '/cycle') {
            token <- if (index == 2L) 'last' else 'opaque +/='
          }
          if (path == '/bad') {
            token <- 42L
          }
          if (path == '/failure' && index == 2L) {
            return(list(status = 503L, headers = list(), body = 'failed'))
          }
          if (path == '/redirect') {
            return(list(
              status = 302L,
              headers = list(
                Location = paste0('http://127.0.0.1:', other_port, '/stolen')
              ),
              body = ''
            ))
          }
          if (path == '/same-redirect') {
            return(list(
              status = 302L,
              headers = list(Location = '/stolen'),
              body = ''
            ))
          }
          page <- if (is.null(q$page)) 1L else as.integer(q$page)
          link <- if (page == 1L) '?page=2' else NULL
          if (path == '/cross') {
            link <- paste0('http://127.0.0.1:', other_port, '/stolen')
          }
          if (path == '/host') {
            link <- paste0('http://localhost:', port, '/stolen')
          }
          if (path == '/scheme') {
            link <- paste0('https://127.0.0.1:', port, '/stolen')
          }
          if (path == '/userinfo') {
            link <- paste0('http://user:pass@127.0.0.1:', port, '/stolen')
          }
          if (path == '/loop') {
            link <- '/loop'
          }
          if (path == '/linkcycle') {
            link <- if (page == 2L) '/linkcycle' else '?page=2'
          }
          if (path == '/to-redirect') {
            link <- '/redirect'
          }
          if (path == '/fragment') {
            link <- '#secret'
          }
          headers <- if (path == '/header' && page == 1L) {
            list(Link = '<?page=2>; rel="next"')
          } else {
            list()
          }
          response(
            list(
              results = data,
              pagination = list(hasNext = !is.null(token), nextCursor = token),
              nextLink = link
            ),
            headers
          )
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
  base <- paste0('http://127.0.0.1:', readLines(port_file))
  request <- function(path) {
    httr2::req_headers(
      httr2::request(paste0(base, path)),
      Authorization = 'Bearer local-test',
      `X-API-Key` = 'local-key'
    )
  }
  counts <- function() {
    httr2::resp_body_json(httr2::req_perform(request('/calls')))
  }
  body <- httr2::resp_body_json
  items <- function(response) body(response)$results
  next_link <- function(response) body(response)$nextLink
  error <- function(expr, pattern) {
    value <- tryCatch(force(expr), error = identity)
    stopifnot(inherits(value, 'error'), grepl(pattern, conditionMessage(value)))
  }
  cursor_call <- function(path, cursor, limit) {
    req <- httr2::req_url_query(request(path), cursor = cursor, limit = limit)
    body(httr2::req_perform(req))
  }
  retrieve <- function(path = '/cursor', ...) {
    specmill::paginated(
      cursor_call,
      path = path,
      mode = 'cursor',
      parameter = 'cursor',
      size_parameter = 'limit',
      page_size = 1,
      items = function(x) x$results,
      next_cursor = function(x) {
        if (isTRUE(x$pagination$hasNext)) x$pagination$nextCursor else NULL
      },
      ...
    )
  }
  result <- retrieve()
  sent <- counts()$calls
  stopifnot(
    result$requests == 3,
    result$item_count == 3,
    result$stop_reason == 'no_next_cursor',
    is.null(sent[[1]]$query$cursor),
    sent[[2]]$query$cursor == 'opaque +/=',
    sent[[3]]$query$cursor == 'last'
  )
  stopifnot(
    retrieve('/empty')$stop_reason == 'empty_page',
    retrieve(max_pages = 1)$stop_reason == 'max_pages',
    retrieve(max_items = 2)$item_count == 2
  )
  for (path in c('/repeat', '/cycle')) {
    before <- length(counts()$calls)
    error(retrieve(path), 'Repeated pagination')
    stopifnot(
      length(counts()$calls) == before + if (path == '/repeat') 2 else 3
    )
  }
  error(retrieve('/bad'), 'single non-missing string')
  error(retrieve('/failure'), '503')
  # A supplied initial cursor also participates in repeat detection.
  error(retrieve('/repeat', start = 'opaque +/='), 'Repeated pagination')
  for (bad in list(NA_character_, 2, c('a', 'b'))) {
    before <- length(counts()$calls)
    error(retrieve(start = bad), 'single non-missing string')
    stopifnot(length(counts()$calls) == before)
  }
  linked <- function(path, ...) {
    specmill::paginated_links(request(path), items, next_link, ...)
  }
  before <- length(counts()$calls)
  result <- linked('/body')
  stopifnot(
    result$requests == 2,
    result$item_count == 2,
    result$stop_reason == 'no_next_link',
    length(counts()$calls) == before + 2
  )
  stopifnot(
    specmill::paginated_links(request('/header'), items)$requests == 2,
    linked('/body', max_pages = 1)$stop_reason == 'max_pages',
    linked('/body', max_items = 1)$stop_reason == 'max_items'
  )
  for (path in c('/cross', '/host', '/scheme')) {
    error(linked(path), 'Cross-origin')
  }
  for (path in c('/userinfo', '/fragment')) {
    error(linked(path), 'userinfo or a fragment')
  }
  for (path in c('/loop', '/linkcycle')) {
    error(linked(path), 'Repeated pagination')
  }
  for (path in c('/redirect', '/to-redirect', '/same-redirect')) {
    error(linked(path), 'redirect refused')
  }
  permissive <- httr2::req_error(
    request('/redirect'),
    is_error = function(response) FALSE
  )
  permissive <- httr2::req_options(permissive, followlocation = TRUE)
  error(specmill::paginated_links(permissive, items), 'redirect refused')
  sent <- counts()
  stopifnot(
    sent$other == 0,
    all(vapply(
      sent$calls,
      function(x) {
        identical(x$auth, 'Bearer local-test') && identical(x$key, 'local-key')
      },
      logical(1)
    ))
  )
  before <- length(sent$calls)
  error(
    specmill::paginated_links(
      httr2::req_method(request('/body'), 'POST'),
      items
    ),
    'bodyless GET'
  )
  error(
    specmill::paginated_links(
      httr2::req_body_json(request('/body'), list(a = 1)),
      items
    ),
    'bodyless GET'
  )
  stopifnot(length(counts()$calls) == before)
  token <- paste(rep('x', 11000), collapse = '')
  error(
    specmill::paginated(
      function(cursor) list(1),
      mode = 'cursor',
      parameter = 'cursor',
      start = token,
      items = identity,
      next_cursor = function(x) token
    ),
    'Repeated pagination'
  )
  stopifnot(
    specmill::paginated(
      function(cursor) list(1),
      mode = 'cursor',
      parameter = 'cursor',
      items = identity,
      next_cursor = function(x) ''
    )$stop_reason ==
      'no_next_cursor'
  )
  cat(
    'Cursor/link pagination: AMOS-shaped responses, opaque tokens, cycles, limits, same-origin links and redirect credential isolation passed.\n'
  )
}
if (sys.nframe() == 0L) {
  pagination_cursors_acceptance()
}
