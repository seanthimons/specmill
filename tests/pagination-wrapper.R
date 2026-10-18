pagination_wrapper_acceptance <- function() {
  workspace <- tempfile('pagination-wrapper-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  port_file <- file.path(workspace, 'port')
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      history <- list()
      json <- function(x, status = 200L) {
        list(
          status = status,
          headers = list('Content-Type' = 'application/json'),
          body = jsonlite::toJSON(x, auto_unbox = TRUE, null = 'null')
        )
      }
      record <- function(...) list(list(...))
      httpuv::startServer(
        '127.0.0.1',
        port,
        list(
          call = function(req) {
            if (req$PATH_INFO == '/history') {
              return(json(history))
            }
            if (req$PATH_INFO == '/plain') {
              return(json(record(id = 'p')))
            }
            hit <- regmatches(
              req$QUERY_STRING,
              regexpr('pageNumber=[0-9]+', req$QUERY_STRING)
            )
            page <- if (length(hit)) {
              as.integer(sub('pageNumber=', '', hit))
            } else {
              NA_integer_
            }
            kind <- sub('^/items/', '', req$PATH_INFO)
            history[[length(history) + 1L]] <<- list(kind = kind, page = page)
            switch(
              kind,
              a = json(switch(
                min(page, 3L),
                c(record(id = '1'), record(id = '2')),
                record(id = '3'),
                list()
              )),
              typed = json(switch(
                min(page, 3L),
                record(sex = 'F', id = '007'),
                record(sex = 'MF', id = '12'),
                list()
              )),
              word = json(if (page == 1L) record(id = 'x1') else list()),
              forever = json(record(id = as.character(page))),
              none = json(list()),
              nobody = if (page == 1L) {
                json(record(id = '1'))
              } else {
                # The legacy end of data: an empty body. (httpuv leaves the connection unusable after a 204.)
                list(
                  status = 200L,
                  headers = list('Content-Type' = 'application/json'),
                  body = ''
                )
              },
              flagged = json(
                record(id = as.character(page), last = page >= 2L)
              ),
              # A real API shape: every page, and the one past the end, is an envelope.
              envelope = {
                data <- switch(
                  min(page, 4L),
                  c(
                    record(sex = 'F', id = '007'),
                    record(sex = 'F', id = '008')
                  ),
                  record(sex = 'MF', id = '12'),
                  record(sex = 'M', id = '13'),
                  list()
                )
                json(list(
                  studyType = 'DNT',
                  totalRecords = 4L,
                  recordsOnPage = length(data),
                  pageNumber = page,
                  totalPages = 3L,
                  data = data
                ))
              },
              json(list(error = 'unknown kind'), 404L)
            )
          }
        )
      )
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
  origin <- paste0('http://127.0.0.1:', readLines(port_file))

  schema <- file.path(workspace, 'schema.json')
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Paged', version = '1'),
      servers = list(list(url = origin)),
      paths = list(
        '/items/{kind}' = list(
          get = list(
            operationId = 'get_items',
            parameters = list(
              list(
                name = 'kind',
                `in` = 'path',
                required = TRUE,
                schema = list(type = 'string')
              ),
              list(
                name = 'pageNumber',
                `in` = 'query',
                schema = list(type = 'integer')
              )
            ),
            responses = list('200' = list(description = 'OK'))
          )
        ),
        '/plain' = list(
          get = list(
            operationId = 'get_plain',
            responses = list('200' = list(description = 'OK'))
          )
        ),
        '/page/{n}' = list(
          get = list(
            operationId = 'get_page',
            parameters = list(list(
              name = 'n',
              `in` = 'path',
              required = TRUE,
              schema = list(type = 'integer')
            )),
            responses = list('200' = list(description = 'OK'))
          )
        ),
        '/numbered' = list(
          get = list(
            operationId = 'get_numbered',
            parameters = list(list(
              name = 'p',
              `in` = 'query',
              schema = list(type = 'number', default = 1)
            )),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  root <- file.path(workspace, 'client')
  initialize <- function(root, companions) {
    specmill::initialize_client(
      root,
      schema,
      package = 'pagewrap',
      title = 'Page Wrap',
      author = list(
        given = 'Test',
        family = 'Maintainer',
        email = 'test@example.org'
      ),
      license = 'MIT + file LICENSE',
      companions = companions
    )
  }
  initialize(root, c('batching', 'pagination'))
  service_path <- file.path(root, 'apis/default.yml')
  original <- yaml::read_yaml(
    service_path,
    handlers = list(seq = function(x) x)
  )
  writeLines(
    c(
      'table_policy <- function(response, context, decode) {',
      '  body <- decode()',
      '  envelope <- is.list(body) && "data" %in% names(body)',
      '  table <- api_request_table(api_request_records(if (envelope) body$data else body, query = context$query))',
      '  if (envelope) attr(table, "paging") <- body[c("pageNumber", "totalPages")]',
      '  table',
      '}',
      'stop_when_last <- function(response, state) {',
      '  paging <- attr(response, "paging")',
      '  any(response$last) || (!is.null(paging) && paging$pageNumber >= paging$totalPages)',
      '}'
    ),
    file.path(root, 'R/policy.R')
  )
  paged <- function(...) {
    service <- original
    service$defaults$response_policy <- 'table_policy'
    service$defaults$pagination <- list(
      mode = 'page',
      parameter = 'pageNumber',
      start = 1L,
      completed = 'stop_when_last',
      max_pages = 5L
    )
    modify <- list(...)
    for (name in names(modify)) {
      service[[name]] <- modify[[name]]
    }
    yaml::write_yaml(service, service_path)
    service
  }
  run <- function(mode = 'apply') {
    specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = mode
    )
  }
  fails <- function(pattern) {
    error <- tryCatch(run(), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }

  # --- Generation ----------------------------------------------------------------
  paged()
  run()
  before <- tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE))
  run()
  run('check')
  stopifnot(identical(
    before,
    tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE))
  ))
  code <- function(name) {
    paste(readLines(file.path(root, 'R', paste0(name, '.R'))), collapse = '\n')
  }
  stopifnot(
    grepl('api_request_pages(', code('get_items'), fixed = TRUE),
    grepl('@param all_pages', code('get_items'), fixed = TRUE),
    grepl('@param max_pages', code('get_items'), fixed = TRUE),
    # The service default only reaches operations that have the named parameter.
    !grepl('api_request_pages', code('get_plain'), fixed = TRUE),
    !grepl('all_pages', code('get_plain'), fixed = TRUE)
  )
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  stopifnot(
    identical(
      names(formals(runtime$get_items)),
      c('kind', 'pageNumber', 'all_pages', 'max_pages')
    ),
    identical(formals(runtime$get_items)$all_pages, TRUE),
    identical(formals(runtime$get_items)$max_pages, 5L),
    identical(formals(runtime$get_items)$pageNumber, 1L),
    !length(formals(runtime$get_plain))
  )
  history <- function() {
    got <- httr2::resp_body_json(
      httr2::req_perform(httr2::request(paste0(origin, '/history'))),
      simplifyVector = FALSE
    )
    list(
      kind = vapply(got, `[[`, character(1), 'kind'),
      page = vapply(got, function(x) x$page, integer(1))
    )
  }
  sent <- function() length(history()$kind)

  # --- Paging ----------------------------------------------------------------------
  seen <- sent()
  result <- runtime$get_items('a')
  now <- history()
  stopifnot(
    identical(result$id, 1:3),
    identical(result$query, rep('a', 3L)),
    identical(attr(result, 'pagination')$requests, 3L),
    identical(attr(result, 'pagination')$item_count, 3L),
    identical(attr(result, 'pagination')$stop_reason, 'empty_page'),
    identical(tail(now$page, 3L), 1:3),
    identical(tail(now$kind, 3L), rep('a', 3L)),
    is.null(attr(result, 'api_request_source'))
  )
  # Column types are recovered once over every page, not page by page (#100).
  typed <- runtime$get_items('typed')
  stopifnot(
    identical(typed$sex, c('F', 'MF')),
    identical(typed$id, c(7L, 12L))
  )
  # The caller's value starts the loop; all_pages = FALSE is the plain single request.
  seen <- sent()
  from_two <- runtime$get_items('a', pageNumber = 2L)
  stopifnot(
    identical(from_two$id, 3L),
    identical(attr(from_two, 'pagination')$requests, 2L),
    sent() - seen == 2L
  )
  seen <- sent()
  one <- runtime$get_items('a', pageNumber = 2L, all_pages = FALSE)
  stopifnot(
    sent() - seen == 1L,
    identical(one$id, 3L),
    is.null(attr(one, 'pagination')),
    inherits(one, 'data.frame')
  )
  # A page with no body at all ends the loop, as the legacy paging loop did.
  nobody <- runtime$get_items('nobody')
  stopifnot(
    identical(nobody$id, 1L),
    attr(nobody, 'pagination')$stop_reason == 'empty_page'
  )
  # An empty first page has the shape of a single empty page.
  none <- runtime$get_items('none')
  single_none <- runtime$get_items('none', all_pages = FALSE)
  stopifnot(
    nrow(none) == 0L,
    identical(attr(none, 'pagination')$requests, 1L),
    identical(unclass(none)[0L], unclass(single_none)[0L]),
    identical(class(none), class(single_none))
  )
  # A client function can end paging early; its response is the page's result.
  flagged <- runtime$get_items('flagged')
  stopifnot(
    identical(flagged$id, 1:2),
    attr(flagged, 'pagination')$stop_reason == 'completed',
    identical(attr(flagged, 'pagination')$requests, 2L)
  )
  # An envelope API: the policy unwraps data and tags the page with its paging fields, a
  # client function reads them, and paging stops on the last page without asking for another.
  seen <- sent()
  enveloped <- runtime$get_items('envelope')
  stopifnot(
    sent() - seen == 3L,
    identical(attr(enveloped, 'pagination')$requests, 3L),
    attr(enveloped, 'pagination')$stop_reason == 'completed',
    identical(enveloped$sex, c('F', 'F', 'MF', 'M')),
    identical(enveloped$id, c(7L, 8L, 12L, 13L)),
    is.null(attr(enveloped, 'paging'))
  )
  # Past the last page the API still answers with an envelope, whose data is empty.
  beyond <- runtime$get_items('envelope', pageNumber = 4L)
  stopifnot(
    nrow(beyond) == 0L,
    attr(beyond, 'pagination')$stop_reason == 'empty_page',
    identical(attr(beyond, 'pagination')$requests, 1L),
    # One page is combined like many: the policy's tag is not on the result.
    is.null(attr(beyond, 'paging'))
  )
  # max_pages bounds a runaway endpoint, with a warning, and records why paging stopped.
  warned <- character()
  seen <- sent()
  capped <- withCallingHandlers(
    runtime$get_items('forever', max_pages = 3L),
    warning = function(w) {
      warned <<- c(warned, conditionMessage(w))
      invokeRestart('muffleWarning')
    }
  )
  stopifnot(
    sent() - seen == 3L,
    nrow(capped) == 3L,
    attr(capped, 'pagination')$stop_reason == 'max_pages',
    length(warned) == 1L,
    grepl('max_pages', warned)
  )
  # Bad controls are rejected before any request.
  seen <- sent()
  for (call in list(
    quote(runtime$get_items('a', all_pages = NA)),
    quote(runtime$get_items('a', all_pages = 'yes')),
    quote(runtime$get_items('a', max_pages = 0L)),
    quote(runtime$get_items('a', pageNumber = NULL))
  )) {
    error <- tryCatch(eval(call), error = identity)
    stopifnot(inherits(error, 'error'))
  }
  stopifnot(
    grepl(
      'Supply pageNumber',
      conditionMessage(tryCatch(
        runtime$get_items('a', pageNumber = NULL),
        error = identity
      ))
    ),
    sent() == seen
  )
  # A dry run prepares the first page only.
  withr::local_envvar(c(PAGEWRAP_DRY_RUN = 'true'))
  prepared <- runtime$get_items('a')
  stopifnot(inherits(prepared, 'httr2_request'), sent() == seen)
  withr::local_envvar(c(PAGEWRAP_DRY_RUN = 'false'))
  # The page sequence a contract mock sees: one helper call per page, each with its page number.
  calls <- list()
  real <- runtime$api_request
  responses <- list(
    list(list(id = '1')),
    list(list(id = '2')),
    list()
  )
  runtime$api_request <- function(...) {
    calls[[length(calls) + 1L]] <<- list(...)
    responses[[length(calls)]]
  }
  mocked <- runtime$get_items('a')
  runtime$api_request <- real
  stopifnot(
    identical(vapply(calls, function(x) x$query$pageNumber, integer(1)), 1:3),
    attr(mocked, 'pagination')$requests == 3L,
    attr(mocked, 'pagination')$stop_reason == 'empty_page'
  )

  # --- Hooks -------------------------------------------------------------------------
  write_executor <- function() {
    writeLines(
      c(
        'log_hook <- function(state) state',
        'log_to <- function(entry) options(pagewrap.log = c(getOption("pagewrap.log"), entry))',
        'run_hook <- function(fn_name, hook_type, state) {',
        '  if (hook_type == "pre_request") {',
        '    log_to(paste("pre", state$params$pageNumber))',
        '    if (isTRUE(getOption("pagewrap.rewrite"))) state$params$pageNumber <- 99L',
        '    return(state)',
        '  }',
        '  if (hook_type == "post_response") {',
        '    log_to(paste("post", state$params$pageNumber))',
        '    return(state$result)',
        '  }',
        '  if (hook_type == "post_combine") {',
        '    log_to("combine")',
        '    options(pagewrap.combined = list(params = state$params, rows = nrow(state$result)))',
        '    out <- state$result',
        '    attr(out, "pagination") <- NULL',
        '    attr(out, "failed") <- NULL',
        '    return(out)',
        '  }',
        '  stop("Unsupported hook stage")',
        '}'
      ),
      file.path(root, 'R/hooks.R')
    )
  }
  write_executor()
  paged(
    hooks = list(
      get_items = list(
        pre_request = list('log_hook'),
        post_response = list('log_hook'),
        post_combine = list('log_hook')
      )
    )
  )
  run()
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  withr::local_options(
    pagewrap.log = NULL,
    pagewrap.combined = NULL,
    pagewrap.rewrite = NULL
  )
  hooked <- runtime$get_items('a')
  stopifnot(
    identical(
      getOption('pagewrap.log'),
      c('pre 1', 'post 1', 'pre 2', 'post 2', 'pre 3', 'post 3', 'combine')
    ),
    # post_combine sees the caller's params, not the last page's, and the finished table.
    identical(getOption('pagewrap.combined')$params$pageNumber, 1L),
    identical(getOption('pagewrap.combined')$rows, 3L),
    # The pagination record is restored when a post_combine hook drops it.
    identical(attr(hooked, 'pagination')$requests, 3L)
  )
  # A hook that changes the page argument would fight the loop: stop with a clear error.
  options(pagewrap.rewrite = TRUE, pagewrap.log = NULL)
  seen <- sent()
  error <- tryCatch(runtime$get_items('a'), error = identity)
  stopifnot(
    inherits(error, 'error'),
    grepl(
      'must not change the pagination argument pageNumber',
      conditionMessage(error)
    ),
    sent() == seen
  )
  options(pagewrap.rewrite = NULL)

  # A reviewed operation can return plain legacy attributes while retaining paging.
  service <- yaml::read_yaml(service_path, handlers = list(seq = identity))
  service$operations[['GET /items/{kind}']] <- list(
    pagination = list(metadata = FALSE)
  )
  yaml::write_yaml(service, service_path)
  metadata_plan <- run()
  plain <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, plain)
  }
  expected <- hooked
  attr(expected, 'pagination') <- NULL
  seen <- sent()
  stopifnot(
    identical(plain$get_items('a'), expected),
    identical(tail(history()$page, -seen), 1:3),
    identical(
      plain$get_items('a', all_pages = FALSE),
      runtime$get_items('a', all_pages = FALSE)
    )
  )
  empty <- runtime$get_items('none')
  attr(empty, 'pagination') <- NULL
  stopifnot(
    identical(plain$get_items('none'), empty),
    inherits(try(plain$get_items('missing'), silent = TRUE), 'try-error')
  )
  warned <- character()
  limited <- withCallingHandlers(
    plain$get_items('forever', max_pages = 2L),
    warning = function(w) {
      warned <<- c(warned, conditionMessage(w))
      invokeRestart('muffleWarning')
    }
  )
  stopifnot(
    nrow(limited) == 2L,
    is.null(attr(limited, 'pagination')),
    length(warned) == 1L,
    grepl('max_pages', warned)
  )
  dry <- withr::with_envvar(c(PAGEWRAP_DRY_RUN = 'true'), plain$get_items('a'))
  stopifnot(
    inherits(dry, 'httr2_request'),
    !grepl("attr(result, 'pagination')", code('get_items'), fixed = TRUE)
  )
  # Raw list results also retain exact classes and attributes after omission.
  raw_operation <- Filter(
    function(op) op$name == 'get_items',
    metadata_plan$operations
  )[[1L]]
  raw_operation$name <- 'get_records'
  raw_operation$response_policy <- NULL
  raw_operation$paginate$completed <- 'empty'
  eval(
    parse(
      text = specmill::render_operation(
        raw_operation,
        list(helper = 'api_request')
      )
    ),
    plain
  )
  stopifnot(
    identical(
      plain$get_records('a'),
      list(list(id = '1'), list(id = '2'), list(id = '3'))
    ),
    identical(plain$get_records('none'), list())
  )
  run('check')

  # An operation opts out of inherited paging with null.
  service <- paged()
  service$operations[['GET /items/{kind}']] <- list(pagination = NULL)
  yaml::write_yaml(service, service_path)
  run()
  stopifnot(
    !grepl('api_request_pages', code('get_items'), fixed = TRUE),
    !grepl('all_pages', code('get_items'), fixed = TRUE)
  )

  # --- Pagination inside fan-out (#111) ----------------------------------------------
  service <- paged()
  service$operations[['GET /items/{kind}']] <- list(
    batch = list(fan_out = 'kind', on_error = 'drop'),
    pagination = list(metadata = FALSE)
  )
  yaml::write_yaml(service, service_path)
  run()
  fan <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, fan)
  }
  seen <- sent()
  result <- fan$get_items(c('a', 'typed'))
  now <- history()
  stopifnot(
    # Each element pages to completion: a has 3 pages (the last empty), typed has 3.
    identical(result$query, c('a', 'a', 'a', 'typed', 'typed')),
    identical(result$id, c(1L, 2L, 3L, 7L, 12L)),
    identical(tail(now$kind, -seen), c(rep('a', 3L), rep('typed', 3L))),
    identical(tail(now$page, -seen), c(1:3, 1:3))
  )
  # Types are guessed once over every element's records.
  stopifnot(
    identical(result$sex, c(NA, NA, NA, 'F', 'MF')),
    is.null(attr(result, 'api_request_source'))
  )
  # One typing pass over every element: a non-numeric id keeps the whole column text.
  mixed <- fan$get_items(c('a', 'word'))
  stopifnot(identical(mixed$id, c('1', '2', '3', 'x1')))
  # all_pages = FALSE: one request per element.
  seen <- sent()
  one <- fan$get_items(c('a', 'typed'), all_pages = FALSE)
  stopifnot(
    identical(tail(history()$page, -seen), c(1L, 1L)),
    nrow(one) == 3L
  )
  # An element that fails drops, with its earlier pages; the rest are kept.
  both <- fan$get_items(c('a', 'missing'))
  stopifnot(
    identical(unique(both$query), 'a'),
    identical(names(attr(both, 'failed')), 'missing')
  )
  # Dry runs return one request per element and are not combined into a table.
  dry <- withr::with_envvar(
    c(PAGEWRAP_DRY_RUN = 'true'),
    fan$get_items(c('a', 'typed'))
  )
  stopifnot(
    is.list(dry),
    length(dry) == 2L,
    all(vapply(dry, inherits, logical(1), 'httr2_request'))
  )

  # post_combine runs once on the combined result of a paged fan-out, and the
  # failed record survives a hook that drops attributes.
  service <- paged(
    hooks = list(get_items = list(post_combine = list('log_hook')))
  )
  service$operations[['GET /items/{kind}']] <- list(
    batch = list(fan_out = 'kind', on_error = 'drop')
  )
  yaml::write_yaml(service, service_path)
  run()
  hooked_fan <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, hooked_fan)
  }
  options(pagewrap.log = NULL, pagewrap.combined = NULL)
  combined <- hooked_fan$get_items(c('a', 'missing'))
  stopifnot(
    identical(getOption('pagewrap.log'), 'combine'),
    identical(getOption('pagewrap.combined')$rows, 3L),
    identical(names(attr(combined, 'failed')), 'missing')
  )
  options(pagewrap.log = NULL, pagewrap.combined = NULL)

  # --- Configuration errors --------------------------------------------------------------
  service <- paged()
  service$defaults$pagination$metadata <- FALSE
  yaml::write_yaml(service, service_path)
  fails('pagination.metadata belongs under operations')
  service <- paged()
  service$operations[['GET /items/{kind}']] <- list(
    pagination = list(metadata = 'no')
  )
  yaml::write_yaml(service, service_path)
  fails('pagination.metadata must be true or false')
  paged()
  write_executor()
  # An operation-level setting must fit; the same setting inherited from defaults need not.
  service <- paged()
  service$operations[['GET /plain']] <- list(
    pagination = list(mode = 'page', parameter = 'pageNumber', start = 1L)
  )
  yaml::write_yaml(service, service_path)
  fails(
    'pagination.parameter must name an integer or number path or query parameter'
  )
  service <- paged()
  service$defaults$pagination$mode <- 'offset'
  yaml::write_yaml(service, service_path)
  fails('pagination.mode must be page')
  service <- paged()
  service$defaults$pagination$start <- NULL
  yaml::write_yaml(service, service_path)
  fails('pagination.start is required because pageNumber has no default')
  service <- paged()
  service$defaults$pagination$completed <- 'no_such_function'
  yaml::write_yaml(service, service_path)
  fails('Missing client pagination callback')
  service <- paged()
  service$defaults$pagination$max_pages <- 0L
  yaml::write_yaml(service, service_path)
  fails('pagination.max_pages must be a positive integer')
  service <- paged()
  service$operations[['GET /items/{kind}']] <- list(
    parameters = list('query pageNumber' = list(name = 'max_pages'))
  )
  yaml::write_yaml(service, service_path)
  fails('collide with an argument')
  # Missing or null settings are named; a start cannot be set on a required parameter.
  service <- paged()
  service$defaults$pagination$mode <- NULL
  yaml::write_yaml(service, service_path)
  fails('pagination requires mode')
  service <- paged()
  service$defaults$pagination['parameter'] <- list(NULL)
  yaml::write_yaml(service, service_path)
  fails('pagination requires parameter')
  service <- paged()
  service$defaults$pagination$max_pages <- 3000000000
  yaml::write_yaml(service, service_path)
  fails('pagination.max_pages must be a positive integer')
  service <- paged()
  service$operations[['GET /page/{n}']] <- list(
    pagination = list(mode = 'page', parameter = 'n', start = 1L)
  )
  yaml::write_yaml(service, service_path)
  fails(
    'pagination.start sets the default of an optional parameter, but n is required'
  )
  # A number-typed query parameter with a schema default pages without a start.
  service <- paged()
  service$operations[['GET /numbered']] <- list(
    pagination = list(mode = 'page', parameter = 'p', start = NULL)
  )
  yaml::write_yaml(service, service_path)
  run()
  stopifnot(
    grepl('api_request_pages(', code('get_numbered'), fixed = TRUE),
    grepl('all_pages = TRUE', code('get_numbered'), fixed = TRUE),
    # The schema default drives the wrapper when no start is configured.
    grepl(
      'get_numbered <- function(p = 1, all_pages',
      code('get_numbered'),
      fixed = TRUE
    )
  )
  # A start value cannot also be a configured default.
  service <- paged()
  service$operations[['GET /items/{kind}']] <- list(
    parameters = list('query pageNumber' = list(default = 2L))
  )
  yaml::write_yaml(service, service_path)
  fails('pagination.start conflicts with the default configured')
  # An outdated pagination engine in the client helper is named, not run.
  paged()
  run()
  helper_path <- file.path(root, 'R/api_request.R')
  helper <- readLines(helper_path)
  stopifnot(any(grepl(
    'offset mode requires size_parameter',
    helper,
    fixed = TRUE
  )))
  writeLines(
    sub(
      'offset mode requires size_parameter',
      'size is required',
      helper,
      fixed = TRUE
    ),
    helper_path
  )
  fails('pagination needs api_request_paginated\\(\\)')
  writeLines(helper, helper_path)
  run('check')

  # A client without the pagination companion says what is missing.
  bare <- file.path(workspace, 'bare')
  initialize(bare, character())
  bare_service <- file.path(bare, 'apis/default.yml')
  service <- yaml::read_yaml(bare_service, handlers = list(seq = function(x) x))
  service$defaults$pagination <- list(
    mode = 'page',
    parameter = 'pageNumber',
    start = 1L
  )
  yaml::write_yaml(service, bare_service)
  error <- tryCatch(
    specmill::generate_client(
      validation = FALSE,
      bare,
      config = 'specmill.yml',
      mode = 'apply'
    ),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('pagination needs', conditionMessage(error))
  )

  # Single-call contracts cannot describe a paginated operation; call sequences can.
  operation <- list(
    name = 'get_items',
    paginate = list(parameter = 'pageNumber')
  )
  spec <- list(
    package = 'pagewrap',
    helper = 'api_request',
    response_fixture = list()
  )
  contract <- list(inputs = list(kind = 'a'), request = list(), result = list())
  error <- tryCatch(
    specmill:::render_contract(operation, spec, contract),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('must set all_pages to false', conditionMessage(error))
  )
  contract$inputs$all_pages <- FALSE
  stopifnot(is.character(specmill:::render_contract(operation, spec, contract)))
  cat(
    'Pagination wrapper: pages, typing, controls, stop reasons, hooks, contracts and configuration errors passed.\n'
  )
}

if (sys.nframe() == 0L) {
  pagination_wrapper_acceptance()
}
