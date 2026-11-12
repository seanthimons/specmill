result_order_acceptance <- function() {
  for (package in c('httpuv', 'callr', 'withr', 'httr2')) {
    if (!requireNamespace(package, quietly = TRUE)) {
      message('Skipping result order: ', package, ' is not installed')
      return(invisible())
    }
  }
  internal <- function(name) utils::getFromNamespace(name, 'specmill')
  workspace <- tempfile('result-order-')
  dir.create(workspace)
  withr::defer(unlink(workspace, recursive = TRUE))
  port_file <- file.path(workspace, 'port')
  # The service returns the same records with fields and rows reversed for two
  # requests in every four to a path, so repeated calls see both orders.
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      counts <- list()
      bodies <- list()
      httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          json <- function(value, status = 200L) {
            list(
              status = status,
              headers = list('Content-Type' = 'application/json'),
              body = jsonlite::toJSON(value, auto_unbox = TRUE, na = 'null')
            )
          }
          path <- req$PATH_INFO
          if (path == '/bodies') {
            return(json(bodies))
          }
          counts[[path]] <<- (if (is.null(counts[[path]])) {
            0L
          } else {
            counts[[path]]
          }) +
            1L
          flip <- function(x) {
            if ((counts[[path]] %/% 2L) %% 2L == 1L) rev(x) else x
          }
          if (startsWith(path, '/chemical/')) {
            return(json(list(flip(list(
              dtxsid = sub('^/chemical/', '', path),
              inchikey = 'K',
              name = 'N',
              Zeta = 1L,
              alpha = 2L
            )))))
          }
          if (path == '/aed') {
            body <- rawToChar(req$rook.input$read())
            bodies[[length(bodies) + 1L]] <<- body
            ids <- unlist(jsonlite::fromJSON(body, simplifyVector = FALSE))
            if ('bad' %in% ids) {
              return(json(list(error = 'rejected'), 500L))
            }
            records <- unlist(
              lapply(ids, function(id) {
                list(
                  list(dtxsid = id, aeid = 2500L),
                  list(dtxsid = id, aeid = 1957L),
                  list(dtxsid = id, aeid = 1957L),
                  list(dtxsid = id, aeid = NA)
                )
              }),
              recursive = FALSE
            )
            return(json(flip(records)))
          }
          if (path == '/pages') {
            page <- sub('^.*page=([0-9]+).*$', '\\1', req$QUERY_STRING)
            return(json(switch(
              page,
              '1' = list(
                list(key = 'k', note = 'one'),
                list(key = 'a', note = 'one')
              ),
              '2' = list(
                list(key = 'm', note = 'two'),
                list(key = 'b', note = 'two')
              ),
              list()
            )))
          }
          json(list(
            list(key = 'k', note = 'first'),
            list(key = 'k', note = 'second'),
            list(key = 'a', note = 'third')
          ))
        })
      )
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    args = list(port_file = port_file),
    supervise = TRUE
  )
  withr::defer(server$kill())
  for (i in seq_len(200L)) {
    if (file.exists(port_file)) {
      break
    }
    if (!server$is_alive()) {
      stop(server$get_error())
    }
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  base <- paste0('http://127.0.0.1:', readLines(port_file))
  ok <- list('200' = list(description = 'OK'))
  read <- function(id, ...) {
    list(get = c(list(operationId = id, responses = ok), list(...)))
  }
  schema <- file.path(workspace, 'schema.json')
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Ordered', version = '1'),
      servers = list(list(url = base)),
      paths = list(
        '/chemical/{dtxsid}' = read(
          'chemical',
          parameters = list(list(
            name = 'dtxsid',
            `in` = 'path',
            required = TRUE,
            schema = list(type = 'string')
          ))
        ),
        '/aed' = list(
          post = list(
            operationId = 'aed',
            responses = ok,
            requestBody = list(
              required = TRUE,
              content = list(
                'application/json' = list(
                  schema = list(type = 'array', items = list(type = 'string'))
                )
              )
            )
          )
        ),
        '/ties' = read('ties'),
        '/records' = read('records'),
        '/absent' = read('absent'),
        '/nested' = read('nested'),
        '/twice' = read('twice'),
        '/keyed' = read('keyed'),
        '/tidy' = read('tidy'),
        '/pages' = read(
          'pages',
          parameters = list(list(
            name = 'page',
            `in` = 'query',
            schema = list(type = 'integer')
          ))
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  root <- file.path(workspace, 'client')
  invisible(specmill::initialize_client(
    root = root,
    schema = schema,
    package = 'orderclient',
    title = 'Ordered client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT',
    companions = 'pagination'
  ))
  writeLines(
    c(
      'as_frame <- function(data) {',
      '  rows <- lapply(data$result, function(record) {',
      '    as.data.frame(lapply(record, function(x) if (is.null(x)) NA else x), stringsAsFactors = FALSE)',
      '  })',
      '  frame <- if (length(rows)) do.call(rbind, rows) else data.frame()',
      '  attr(frame, "failed") <- attr(data$result, "failed")',
      '  frame',
      '}',
      'as_tagged <- function(data) {',
      '  frame <- as_frame(data)',
      '  attr(frame, "source") <- "ties"',
      '  class(frame) <- c("client_table", "data.frame")',
      '  frame',
      '}',
      'as_nested <- function(data) {',
      '  frame <- as_frame(data)',
      '  frame$key <- I(as.list(frame$key))',
      '  frame',
      '}',
      'as_twice <- function(data) {',
      '  frame <- as_frame(data)',
      '  names(frame) <- c("key", "key")',
      '  frame',
      '}',
      'as_keyed <- function(data) {',
      '  frame <- as_frame(data)',
      '  class(frame) <- c("data.table", "data.frame")',
      '  frame',
      '}',
      'as_tidy <- function(data) tibble::as_tibble(as_frame(data))',
      'page_table <- function(response, context, decode) as_frame(list(result = decode()))',
      'empty_table <- function() data.frame()',
      # A pre-request hook can skip the request and supply the result itself.
      'skip_hook <- function(state) state',
      'run_hook <- function(fn_name, hook_type, state) {',
      '  if (hook_type != "pre_request") return(state$result)',
      '  if (isTRUE(getOption("orderclient.skip"))) {',
      '    state$skip_request <- TRUE',
      '    state$result <- data.frame(key = c("z", "b"), note = c("hook", "hook"))',
      '  }',
      '  state',
      '}'
    ),
    file.path(root, 'R/hooks.R')
  )
  read_yaml <- function(path) {
    yaml::read_yaml(path, handlers = list(seq = function(x) x))
  }
  service_path <- list.files(file.path(root, 'apis'), full.names = TRUE)[[1L]]
  plain <- read_yaml(service_path)
  plain$operations[['GET /chemical/{dtxsid}']] <- list(
    result_formatter = 'as_frame'
  )
  plain$operations[['POST /aed']] <- list(
    batch = list(
      split = TRUE,
      max_items = 2L,
      on_error = 'drop',
      empty = 'empty_table'
    ),
    result_formatter = 'as_frame'
  )
  plain$operations[['GET /ties']] <- list(result_formatter = 'as_tagged')
  plain$operations[['GET /absent']] <- list(result_formatter = 'as_frame')
  plain$operations[['GET /nested']] <- list(result_formatter = 'as_nested')
  plain$operations[['GET /twice']] <- list(result_formatter = 'as_twice')
  plain$operations[['GET /keyed']] <- list(result_formatter = 'as_keyed')
  plain$operations[['GET /tidy']] <- list(result_formatter = 'as_tidy')
  plain$operations[['GET /pages']] <- list(
    response_policy = 'page_table',
    pagination = list(
      mode = 'page',
      parameter = 'page',
      start = 1L,
      max_pages = 5L
    )
  )
  plain$hooks <- list(ties = list(pre_request = list('skip_hook')))
  ordered <- plain
  set_order <- function(service, key, ...) {
    service$operations[[key]]$result_order <- list(...)
    service
  }
  ordered <- set_order(
    ordered,
    'GET /chemical/{dtxsid}',
    columns = list('dtxsid', 'name')
  )
  ordered <- set_order(
    ordered,
    'POST /aed',
    rows = list('dtxsid', 'aeid'),
    columns = list('dtxsid')
  )
  ordered <- set_order(ordered, 'GET /ties', rows = list('key'))
  ordered <- set_order(ordered, 'GET /records', rows = list('key'))
  ordered <- set_order(ordered, 'GET /absent', rows = list('key', 'gone'))
  ordered <- set_order(ordered, 'GET /nested', rows = list('key'))
  ordered <- set_order(ordered, 'GET /twice', columns = list('key'))
  ordered <- set_order(ordered, 'GET /keyed', rows = list('key'))
  ordered <- set_order(
    ordered,
    'GET /tidy',
    rows = list('key'),
    columns = list('note')
  )
  ordered <- set_order(ordered, 'GET /pages', rows = list('key'))
  generate <- function(service, mode = 'apply') {
    yaml::write_yaml(service, service_path)
    specmill::generate_client(root, config = 'specmill.yml', mode = mode)
  }
  client <- function(service) {
    generate(service)
    env <- new.env(parent = baseenv())
    for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
      sys.source(file, env)
    }
    env
  }
  failure <- function(expr) tryCatch(expr, error = identity)
  quietly <- function(expr) suppressWarnings(expr)
  before <- client(plain)
  # Without the policy the two answers differ, as the service sent them.
  stopifnot(
    !identical(names(before$chemical('X')), names(before$chemical('X'))),
    !identical(before$aed(c('B', 'A', 'C')), before$aed(c('B', 'A', 'C')))
  )
  kept <- list(
    empty = before$aed(character()),
    none = quietly(before$aed(c('bad', 'worse'))),
    records = before$records(),
    ties = before$ties()
  )
  before_pages <- before$pages()
  before_page <- before$pages(all_pages = FALSE)
  before_tidy <- before$tidy()
  after <- client(ordered)
  check <- generate(ordered, 'check')
  stopifnot(all(vapply(
    check$files,
    function(x) x$action == 'unchanged',
    logical(1)
  )))
  # Columns: the named ones first, the rest in name order (uppercase first).
  chemical <- after$chemical('X')
  stopifnot(
    identical(chemical, after$chemical('X')),
    identical(
      names(chemical),
      c('dtxsid', 'name', 'Zeta', 'alpha', 'inchikey')
    ),
    identical(chemical$dtxsid, 'X'),
    identical(chemical$Zeta, 1L)
  )
  # Rows: by the reviewed keys, missing values last, every duplicate kept.
  aed <- after$aed(c('B', 'A', 'C'))
  stopifnot(
    identical(aed, after$aed(c('B', 'A', 'C'))),
    identical(names(aed), c('dtxsid', 'aeid')),
    identical(aed$dtxsid, rep(c('A', 'B', 'C'), each = 4L)),
    identical(aed$aeid, rep(c(1957L, 1957L, 2500L, NA), 3L)),
    identical(attr(aed, 'row.names'), 1:12),
    .row_names_info(aed) < 0L
  )
  # Inputs are sent as given: ordering touches the result only.
  sent <- unlist(httr2::resp_body_json(
    httr2::req_perform(httr2::request(paste0(base, '/bodies')))
  ))
  stopifnot(identical(tail(sent, 2L), c('["B","A"]', '["C"]')))
  # A dropped request keeps its failure record on the ordered table, and
  # parallel requests give the same table as sequential ones.
  partial <- quietly(after$aed(c('C', 'bad', 'B', 'A')))
  together <- ordered
  together$operations[['POST /aed']]$batch$concurrency <- 2L
  together$operations[['POST /aed']]$request_controls <- list(
    throttle = list(capacity = 100L, fill_time_s = 1)
  )
  parallel <- client(together)
  stopifnot(
    identical(partial$dtxsid, rep(c('A', 'B'), each = 4L)),
    identical(names(attr(partial, 'failed')), 'C, bad'),
    identical(quietly(parallel$aed(c('C', 'bad', 'B', 'A'))), partial),
    identical(parallel$aed(c('B', 'A', 'C')), aed)
  )
  # Ties keep the order received; the class and other attributes survive.
  ties <- after$ties()
  stopifnot(
    identical(ties$key, c('a', 'k', 'k')),
    identical(ties$note, c('third', 'first', 'second')),
    identical(class(ties), c('client_table', 'data.frame')),
    identical(attr(ties, 'source'), 'ties'),
    identical(names(ties), names(kept$ties)),
    nrow(ties) == nrow(kept$ties)
  )
  # Results without records, results that are not tables and dry runs are
  # returned as they were. No row is invented.
  dry <- withr::with_options(
    list(orderclient.dry_run = TRUE),
    after$chemical('X')
  )
  stopifnot(
    identical(after$aed(character()), kept$empty),
    nrow(after$aed(character())) == 0L,
    identical(quietly(after$aed(c('bad', 'worse'))), kept$none),
    identical(after$records(), kept$records),
    is.list(after$records()),
    !is.data.frame(after$records()),
    inherits(dry, 'httr2_request')
  )
  # A table that cannot be ordered as reviewed is an error, never a guess.
  message_of <- function(expr) conditionMessage(failure(expr))
  stopifnot(
    identical(
      message_of(after$absent()),
      'result_order columns are missing from absent: gone'
    ),
    grepl('atomic columns: nested', message_of(after$nested()), fixed = TRUE),
    grepl(
      'unique column names: twice',
      message_of(after$twice()),
      fixed = TRUE
    ),
    grepl(
      'does not support data.table: keyed',
      message_of(after$keyed()),
      fixed = TRUE
    )
  )
  # Every page combined, a single page on request and a result that a
  # pre-request hook supplies instead of a request are all ordered.
  skipped <- withr::with_options(list(orderclient.skip = TRUE), after$ties())
  stopifnot(
    identical(after$pages()$key, c('a', 'b', 'k', 'm')),
    identical(after$pages(all_pages = FALSE)$key, c('a', 'k')),
    identical(before_pages$key, c('k', 'a', 'm', 'b')),
    identical(before_page$key, c('k', 'a')),
    identical(skipped$key, c('b', 'z')),
    identical(skipped$note, c('hook', 'hook'))
  )
  tidy <- after$tidy()
  stopifnot(
    inherits(tidy, 'tbl_df'),
    identical(class(tidy), class(before_tidy)),
    identical(names(tidy), c('note', 'key')),
    identical(tidy$key, c('a', 'k', 'k')),
    identical(tidy$note, c('third', 'first', 'second'))
  )
  # Every return of the wrapper itself is ordered, at any indentation; returns
  # of a nested function (one request, one page) are not.
  rewritten <- internal('order_wrapper_result')(
    paste(
      c(
        '# Generated with specmill; do not edit by hand.',
        'get_x <- function(id, all_pages = TRUE) {',
        '  if (!base::isTRUE(all_pages)) base::return(send(id))',
        '  send <- function(params) {',
        '    if (base::isTRUE(params$skip)) base::return(params$result)',
        '    params',
        '  }',
        '  if (base::is.null(id)) {',
        '    base::return(pick(id))',
        '  }',
        '  send(id)',
        '}'
      ),
      collapse = '\n'
    ),
    list(rows = list('key')),
    'get_x'
  )
  wrapped <- function(text) grepl(text, rewritten, fixed = TRUE)
  stopifnot(
    wrapped('base::return(.specmill_order(send(id)))'),
    wrapped('    base::return(.specmill_order(pick(id)))'),
    wrapped('base::return(params$result)'),
    wrapped('  result <- {\n'),
    wrapped('\n  .specmill_order(result)\n}'),
    is.expression(parse(text = rewritten))
  )
  invalid <- function(setting, pattern) {
    bad <- plain
    bad$operations[['GET /ties']]$result_order <- setting
    error <- failure(generate(bad, 'plan'))
    inherits(error, 'error') && grepl(pattern, conditionMessage(error))
  }
  sequence <- function(...) structure(list(...), class = 'specmill_sequence')
  defaulted <- plain
  defaulted$defaults$result_order <- list(rows = list('key'))
  invisible_result <- set_order(plain, 'GET /records', rows = list('key'))
  invisible_result$operations[['GET /records']]$preserve_visibility <- TRUE
  stopifnot(
    invalid(list(rows = 'key'), 'must be a sequence'),
    invalid(list(rows = list('key', 'key')), 'each column name once'),
    invalid(list(order = list('key')), 'unknown field'),
    invalid(list(rows = list(1L)), 'nonempty string'),
    grepl(
      'needs rows or columns',
      message_of(internal('validate_settings')(
        list(result_order = list()),
        'test'
      )),
      fixed = TRUE
    ),
    grepl(
      'each column name once',
      message_of(internal('validate_settings')(
        list(result_order = list(columns = sequence())),
        'test'
      )),
      fixed = TRUE
    ),
    grepl(
      'requires a generated implementation',
      message_of(internal('validate_settings')(
        list(
          result_order = list(rows = sequence('key')),
          implementation = 'existing'
        ),
        'test'
      )),
      fixed = TRUE
    ),
    grepl(
      'belongs under operations',
      message_of(generate(defaulted, 'plan')),
      fixed = TRUE
    ),
    grepl(
      'cannot be combined with preserve_visibility',
      message_of(generate(invisible_result, 'plan')),
      fixed = TRUE
    )
  )
  cat(
    'Result order: columns, rows, duplicates, missing values, ties, attributes, batches, parallel requests, pages, hook results, untouched results and policy errors passed.\n'
  )
}
if (sys.nframe() == 0L) {
  result_order_acceptance()
}
