pagination_acceptance <- function() {
  port_file <- tempfile('pagination-port-')
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(c(port_file, schema)), add = TRUE)
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
              body = jsonlite::toJSON(x, auto_unbox = TRUE)
            )
          }
          if (req$PATH_INFO == '/calls') {
            return(response(calls))
          }
          query <- strsplit(
            sub('^\\?', '', req$QUERY_STRING),
            '&',
            fixed = TRUE
          )[[1L]]
          query <- strsplit(query, '=', fixed = TRUE)
          query <- setNames(lapply(query, `[`, 2L), vapply(query, `[`, '', 1L))
          calls[[length(calls) + 1L]] <<- query
          position <- as.numeric(query$position)
          size <- as.numeric(query$size)
          scenario <- query$scenario
          offset <- if (scenario == 'offset') {
            position
          } else {
            (position - 1) * size
          }
          if (scenario == 'error' && position == 2) {
            return(response('failed', 503L))
          }
          if (scenario == 'decode' && position == 2) {
            return(list(
              status = 200L,
              headers = list('Content-Type' = 'application/json'),
              body = '{'
            ))
          }
          total <- if (scenario == 'full') 4 else 5
          values <- if (scenario == 'repeat') {
            list(1L, 2L)
          } else if (scenario == 'empty' || offset >= total) {
            list()
          } else {
            as.list(seq.int(offset + 1, min(offset + size, total)))
          }
          response(list(
            data = values,
            nextLink = 'https://untrusted.invalid/next'
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
  document <- jsonlite::read_json(system.file(
    'catalogue/schema.json',
    package = 'specmill'
  ))
  operation <- document$paths[['/items']]$get
  operation$parameters <- lapply(
    c('position', 'size', 'scenario'),
    function(name) {
      list(
        name = name,
        'in' = 'query',
        schema = list(type = if (name == 'scenario') 'string' else 'integer')
      )
    }
  )
  document$paths <- list('/items' = list(get = operation))
  document$servers <- list(list(url = origin))
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  parsed <- specmill::read_operations(schema)
  runtime <- new.env(parent = baseenv())
  code <- paste(
    readLines(system.file('templates/request.R', package = 'specmill')),
    collapse = '\n'
  )
  code <- gsub('BASE_URL', deparse(origin), code, fixed = TRUE)
  code <- gsub(
    'DRY_RUN_ENV',
    deparse('PAGINATION_TEST_DRY_RUN'),
    code,
    fixed = TRUE
  )
  eval(parse(text = code), runtime)
  wrapper <- specmill::render_operation(
    parsed$operations$list_items,
    list(helper = 'api_request')
  )
  eval(parse(text = wrapper), runtime)
  single <- runtime$list_items
  calls <- function() {
    httr2::resp_body_json(httr2::req_perform(httr2::request(paste0(
      origin,
      '/calls'
    ))))
  }
  retrieve <- function(scenario = 'page', ...) {
    specmill::paginated(
      single,
      scenario = scenario,
      mode = if (scenario == 'offset') 'offset' else 'page',
      parameter = 'position',
      size_parameter = 'size',
      page_size = 2,
      start = if (scenario == 'offset') 0 else 1,
      items = function(x) x$data,
      ...
    )
  }
  for (scenario in c('page', 'offset')) {
    before <- length(calls())
    result <- retrieve(scenario)
    sent <- tail(calls(), result$requests)
    stopifnot(
      identical(unlist(result$pages), 1:5),
      result$requests == 4,
      result$item_count == 5,
      result$stop_reason == 'empty_page',
      length(calls()) == before + 4,
      identical(
        vapply(sent, function(x) x$position, ''),
        if (scenario == 'page') c('1', '2', '3', '4') else c('0', '2', '4', '6')
      ),
      all(vapply(
        sent,
        function(x) x$size == '2' && x$scenario == scenario,
        logical(1)
      ))
    )
  }
  full <- retrieve('full')
  stopifnot(
    full$requests == 3,
    full$item_count == 4,
    full$stop_reason == 'empty_page'
  )
  both <- retrieve(max_pages = 1, max_items = 2)
  stopifnot(both$requests == 1, both$stop_reason == 'max_items')
  before <- length(calls())
  empty <- retrieve('empty')
  limited <- retrieve(max_items = 3)
  capped <- retrieve('repeat', max_pages = 3)
  stopifnot(
    empty$requests == 1,
    !length(empty$pages),
    empty$stop_reason == 'empty_page',
    identical(unlist(limited$pages), 1:3),
    limited$requests == 2,
    limited$stop_reason == 'max_items',
    capped$requests == 3,
    capped$item_count == 6,
    capped$stop_reason == 'max_pages',
    length(calls()) == before + 6
  )
  error <- function(expr, pattern) {
    value <- tryCatch(force(expr), error = identity)
    stopifnot(inherits(value, 'error'), grepl(pattern, conditionMessage(value)))
  }
  for (scenario in c('error', 'decode')) {
    before <- length(calls())
    error(retrieve(scenario), if (scenario == 'error') 'HTTP 503' else 'decode')
    stopifnot(length(calls()) == before + 2)
  }
  before <- length(calls())
  original <- single(position = 1, size = 2, scenario = 'page')
  stopifnot(
    length(calls()) == before + 1,
    identical(original$data, list(1L, 2L)),
    identical(single, runtime$list_items),
    identical(
      wrapper,
      specmill::render_operation(
        parsed$operations$list_items,
        list(helper = 'api_request')
      )
    )
  )
  settings <- list(
    fn = single,
    scenario = 'page',
    mode = 'page',
    parameter = 'position',
    size_parameter = 'size',
    page_size = 2,
    start = 1,
    items = function(x) x$data
  )
  before <- length(calls())
  for (field in c('page_size', 'max_pages', 'max_items', 'start')) {
    for (bad in list(NA_real_, Inf, -1, 1.5, '2', numeric(), c(1, 2), 2^53)) {
      invalid <- settings
      invalid[field] <- list(bad)
      error(do.call(specmill::paginated, invalid), field)
    }
  }
  for (field in c('page_size', 'max_pages', 'max_items')) {
    invalid <- settings
    invalid[[field]] <- 0
    error(do.call(specmill::paginated, invalid), field)
  }
  invalid <- settings
  invalid$mode <- 'unsupported'
  error(do.call(specmill::paginated, invalid), 'mode')
  invalid <- settings
  invalid$parameter <- 'missing'
  error(do.call(specmill::paginated, invalid), 'Unknown pagination')
  invalid <- settings
  invalid$size_parameter <- 'position'
  error(do.call(specmill::paginated, invalid), 'distinct')
  error(retrieve(position = 1), 'Fixed arguments')
  error(do.call(specmill::paginated, c(settings, list(1))), 'Fixed arguments')
  invalid <- settings
  invalid$start <- 2^53 - 1
  error(do.call(specmill::paginated, invalid), 'exact integer range')
  invalid <- settings
  invalid$mode <- 'next_link'
  error(do.call(specmill::paginated, invalid), 'mode')
  stopifnot(length(calls()) == before)
  # Extraction errors stop immediately; rows, not columns, count as items.
  settings$items <- function(x) stop('extract failed')
  error(do.call(specmill::paginated, settings), 'extract failed')
  stopifnot(length(calls()) == before + 1)
  settings$items <- function(x) NULL
  error(do.call(specmill::paginated, settings), 'items must return')
  settings$items <- function(x) data.frame(id = unlist(x$data))
  settings$max_items <- 3
  result <- do.call(specmill::paginated, settings)
  stopifnot(
    result$item_count == 3,
    nrow(result$pages[[2]]) == 1,
    result$pages[[2]]$id == 3
  )
  cat(
    'Pagination: generated single requests, page/offset retrieval, limits, termination, errors and validation passed.\n'
  )
}
if (sys.nframe() == 0L) {
  pagination_acceptance()
}
