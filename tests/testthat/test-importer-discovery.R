discovery_importer_acceptance <- function() {
  internal <- function(name) utils::getFromNamespace(name, 'specmill')
  fixture <- test_path('fixtures', 'discovery', 'monitoring.json')
  imported <- internal('import_description')(fixture)
  ir <- imported$ir
  source <- ir$sources[[1L]]
  operations <- stats::setNames(
    ir$operations,
    vapply(ir$operations, `[[`, character(1), 'key')
  )
  stopifnot(
    !length(internal('validate_ir')(ir)),
    internal('resolve_importer')(fixture)$format == 'google-discovery',
    source$format == 'google-discovery',
    source$servers[[1L]]$url == 'https://monitoring.example.test',
    setequal(
      names(operations),
      c(
        'GET /v1/readings:list',
        'POST /v1/readings:lookup',
        'POST /v1/history:lookup',
        'GET /v1/stations/{stationId}',
        'POST /v1/stations/{stationId}/attachments'
      )
    ),
    # Reserved expansion without an equivalent flatPath is reported, not guessed.
    setequal(
      vapply(ir$diagnostics, `[[`, character(1), 'code'),
      c('reserved_expansion', 'media_upload_unsupported', 'body_page_token')
    ),
    'GET /v1/{+name}' %in% vapply(ir$diagnostics, `[[`, character(1), 'key'),
    source$auth_schemes$api_key$kind == 'api_key',
    source$auth_schemes$api_key$name == 'key',
    source$auth_schemes$oauth2$kind == 'oauth2',
    identical(
      names(operations[['GET /v1/readings:list']]$security[[1L]]),
      'api_key'
    ),
    # System parameters stay on the source and are not operation arguments.
    'fields' %in% names(source$native$parameters),
    !any(vapply(
      ir$operations,
      function(op) {
        any(
          vapply(op$parameters, `[[`, character(1), 'name') %in%
            c('key', 'alt', 'fields', 'prettyPrint')
        )
      },
      logical(1)
    ))
  )
  listing <- operations[['GET /v1/readings:list']]
  parameters <- stats::setNames(
    listing$parameters,
    vapply(listing$parameters, `[[`, character(1), 'name')
  )
  reading <- stats::setNames(
    source$types$Reading$fields,
    vapply(source$types$Reading$fields, `[[`, character(1), 'name')
  )
  stopifnot(
    identical(listing$name, 'readings_list'),
    identical(listing$native_name, 'monitoring.readings.list'),
    identical(listing$pagination$strategy, 'cursor'),
    identical(listing$pagination$cursor_parameter, 'pageToken'),
    identical(listing$pagination$limit_parameter, 'pageSize'),
    is.null(operations[['POST /v1/history:lookup']]$pagination),
    # Defaults and bounds are spelled as strings in the document.
    identical(parameters$pageSize$type$default, 2),
    identical(parameters$pageSize$type$minimum, 1),
    identical(parameters$validatedOnly$type$default, FALSE),
    parameters$since$type$name == 'datetime',
    parameters$quality$type$kind == 'list',
    # A repeated parameter's description documents the argument.
    identical(
      parameters$quality$type$description,
      'Quality levels to include.'
    ),
    is.null(parameters$quality$type$items$description),
    parameters$quality$type$items$kind == 'enum',
    isTRUE(parameters$quality$explode),
    reading$takenAt$type$name == 'datetime',
    reading$takenAt$type$native_format == 'google-datetime',
    # 64-bit integers and durations travel as strings.
    reading$sampleCount$type$name == 'string',
    reading$sampleCount$type$native_format == 'int64',
    reading$averagingPeriod$type$name == 'string',
    reading$rawSignal$type$name == 'bytes',
    reading$rawSignal$type$encoding == 'base64',
    reading$labels$type$kind == 'map',
    reading$quality$type$kind == 'enum',
    isTRUE(reading$revision$type$read_only),
    source$types$Station$fields[[3L]]$type$name == 'Station',
    operations[['POST /v1/readings:lookup']]$body$type$name ==
      'LookupReadingsRequest'
  )
  parsed <- specmill::read_operations(fixture)
  records <- stats::setNames(
    parsed$operations,
    vapply(parsed$operations, `[[`, character(1), 'key')
  )
  body <- records[['POST /v1/readings:lookup']]$body
  listed <- stats::setNames(
    records[['GET /v1/readings:list']]$parameters,
    vapply(
      records[['GET /v1/readings:list']]$parameters,
      `[[`,
      character(1),
      'name'
    )
  )
  stopifnot(
    length(parsed$operations) == 5L,
    # Named types are expanded; a type that refers to itself stays open.
    identical(body$properties$location$properties$latitude$type, 'number'),
    identical(body$required, list('location')),
    identical(
      body$properties$station$properties$parent,
      list(
        type = 'object',
        description = 'The station this one reports to.'
      )
    ),
    identical(listed$quality$schema$description, 'Quality levels to include.'),
    identical(listed$since$schema$type, 'string'),
    identical(listed$since$schema$format, 'date-time'),
    identical(listed$pageSize$schema$type, 'integer'),
    identical(listed$pageSize$schema$maximum, 100)
  )
  workspace <- tempfile('discovery-acceptance-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  document <- jsonlite::read_json(fixture)
  write_document <- function(document, path) {
    jsonlite::write_json(
      document,
      path,
      auto_unbox = TRUE,
      pretty = TRUE,
      null = 'null'
    )
  }
  # A document that is not a Discovery description is not claimed by the importer.
  plain <- document
  plain$kind <- NULL
  plain_path <- file.path(workspace, 'plain.json')
  write_document(plain, plain_path)
  unknown <- tryCatch(
    internal('resolve_importer')(plain_path),
    error = identity
  )
  mismatch <- document
  mismatch$resources$stations$methods$get$path <- 'v1/stations/{other}'
  mismatch_path <- file.path(workspace, 'mismatch.json')
  write_document(mismatch, mismatch_path)
  stopifnot(
    inherits(unknown, 'error'),
    grepl('Unknown schema format', conditionMessage(unknown)),
    inherits(
      tryCatch(
        internal('import_description')(mismatch_path),
        error = identity
      ),
      'error'
    ),
    internal('discovery_validation_report')(mismatch_path)$status == 'invalid',
    internal('discovery_validation_report')(fixture)$status == 'valid'
  )
  port_file <- file.path(workspace, 'port')
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      history <- list()
      json <- function(value, status = 200L) {
        list(
          status = status,
          headers = list('Content-Type' = 'application/json'),
          body = jsonlite::toJSON(value, auto_unbox = TRUE, null = 'null')
        )
      }
      reading <- function(i) list(station = paste0('s', i), value = i)
      httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          if (req$PATH_INFO == '/history') {
            return(json(history))
          }
          query <- httr2::url_parse(paste0(
            'http://localhost/?',
            sub('^\\?', '', req$QUERY_STRING)
          ))$query
          body <- rawToChar(req$rook.input$read())
          history[[length(history) + 1L]] <<- list(
            method = req$REQUEST_METHOD,
            path = req$PATH_INFO,
            query = query,
            body = body
          )
          if (!identical(query$key, 'fixture-key')) {
            return(json(
              list(error = list(code = 403L, message = 'API key not valid.')),
              403L
            ))
          }
          if (req$PATH_INFO == '/v1/readings:list') {
            token <- query$pageToken
            page <- if (is.null(token)) {
              list(
                readings = list(reading(1L), reading(2L)),
                nextPageToken = 'p2'
              )
            } else if (token == 'p2') {
              list(
                readings = list(reading(3L), reading(4L)),
                nextPageToken = 'p3'
              )
            } else {
              list(readings = list(reading(5L)))
            }
            return(json(page))
          }
          if (req$PATH_INFO == '/v1/readings:lookup') {
            return(json(list(
              readings = list(reading(9L)),
              received = jsonlite::fromJSON(body, simplifyVector = FALSE)
            )))
          }
          json(list(name = sub('^/v1/stations/', '', req$PATH_INFO)))
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
  on.exit(server$kill(), add = TRUE)
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
  document$rootUrl <- paste0(base, '/')
  path <- file.path(workspace, 'monitoring.json')
  write_document(document, path)
  metadata <- list(
    package = 'monitorclient',
    title = 'Monitoring client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT'
  )
  root <- file.path(workspace, 'client')
  invisible(do.call(
    specmill::initialize_client,
    c(list(root = root, schema = path), metadata)
  ))
  project <- yaml::read_yaml(file.path(root, 'specmill.yml'))
  readings <- yaml::read_yaml(file.path(root, 'apis/readings.yml'))
  stopifnot(
    file.exists(file.path(root, 'schema/discovery.json')),
    identical(project$authentication, list(api_key = 'MONITORCLIENT_API_KEY')),
    identical(readings$format, 'google-discovery'),
    identical(
      readings$operations[['GET /v1/readings:list']]$pagination,
      list(
        mode = 'cursor',
        parameter = 'pageToken',
        next_cursor = 'api_request_discovery_next_page_token'
      )
    ),
    any(grepl(
      'api_request_discovery_next_page_token <- function',
      readLines(file.path(root, 'R/api_request.R')),
      fixed = TRUE
    ))
  )
  # The client-owned init script recreates the scaffold from the retained document.
  clone <- file.path(workspace, 'clone')
  init <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/init.R'), init)
  init$init_main(clone)
  stopifnot(
    file.exists(file.path(clone, 'schema/discovery.json')),
    identical(
      readLines(file.path(root, 'specmill.yml')),
      readLines(file.path(clone, 'specmill.yml'))
    ),
    identical(
      readLines(file.path(root, 'apis/readings.yml')),
      readLines(file.path(clone, 'apis/readings.yml'))
    )
  )
  generated <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  stopifnot(
    length(generated$operations) == 5L,
    all(vapply(
      generated$validation,
      function(x) x$status == 'valid',
      logical(1)
    ))
  )
  load_client <- function(root) {
    env <- new.env(parent = baseenv())
    for (file in list.files(
      file.path(root, 'R'),
      pattern = '\\.R$',
      full.names = TRUE
    )) {
      sys.source(file, env)
    }
    env
  }
  history <- function() {
    httr2::resp_body_json(
      httr2::req_perform(httr2::request(paste0(base, '/history'))),
      simplifyVector = FALSE
    )
  }
  env <- load_client(root)
  withr::with_envvar(c(MONITORCLIENT_API_KEY = NA), {
    missing_key <- tryCatch(env$readings_list(), error = identity)
  })
  stopifnot(
    inherits(missing_key, 'error'),
    grepl('MONITORCLIENT_API_KEY', conditionMessage(missing_key), fixed = TRUE),
    !length(history())
  )
  withr::with_envvar(c(MONITORCLIENT_API_KEY = 'fixture-key'), {
    pages <- env$readings_list(location.latitude = 39.1, pageSize = 2L)
    first <- env$readings_list(pageSize = 2L, all_pages = FALSE)
    looked <- env$readings_lookup(
      body = list(
        location = list(latitude = 39.1, longitude = -84.5),
        pollutants = list('pm25')
      )
    )
    station <- env$stations_get(stationId = 'a b')
    invalid <- tryCatch(env$readings_lookup(body = list()), error = identity)
  })
  stations <- function(page) {
    vapply(page$readings, `[[`, character(1), 'station')
  }
  calls <- history()
  listed <- Filter(function(x) x$path == '/v1/readings:list', calls)
  stopifnot(
    # Three requests follow nextPageToken until it is absent.
    identical(
      unlist(lapply(pages, stations), use.names = FALSE),
      paste0('s', 1:5)
    ),
    identical(
      lapply(listed[1:3], function(x) x$query$pageToken),
      list(NULL, 'p2', 'p3')
    ),
    all(vapply(
      listed[1:3],
      function(x) {
        identical(x$query$key, 'fixture-key') &&
          identical(x$query[['location.latitude']], '39.1') &&
          identical(x$query$pageSize, '2')
      },
      logical(1)
    )),
    length(listed) == 4L,
    identical(stations(first), c('s1', 's2')),
    identical(first$nextPageToken, 'p2'),
    identical(looked$received$location$latitude, 39.1),
    identical(looked$received$pollutants, list('pm25')),
    identical(station$name, 'a%20b'),
    # The required body member comes from the named request type.
    inherits(invalid, 'error')
  )
  checked <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'check'
  )
  stopifnot(all(vapply(
    checked$files,
    function(x) x$action == 'unchanged',
    logical(1)
  )))
  # Multi-API setup finds the retained document and renames its callbacks.
  multi <- file.path(workspace, 'multi')
  inputs <- file.path(multi, 'input')
  dir.create(inputs, recursive = TRUE)
  stopifnot(
    file.copy(path, file.path(inputs, 'monitoring.json')),
    file.copy(
      system.file(
        'catalogue/schema.json',
        package = 'specmill',
        mustWork = TRUE
      ),
      file.path(inputs, 'catalogue.json')
    )
  )
  catalog <- specmill::configure_apis(
    multi,
    schemas = list.files(inputs, full.names = TRUE),
    review = FALSE
  )
  monitoring <- catalog$api[catalog$source_format == 'google-discovery']
  catalog$base_url[catalog$source_format == 'openapi'] <-
    'https://catalogue.example.test'
  metadata$package <- 'monitormulti'
  invisible(do.call(
    specmill::initialize_client,
    c(list(root = multi, schema = catalog), metadata)
  ))
  helper <- paste0(monitoring, '_request')
  group <- yaml::read_yaml(file.path(
    multi,
    'apis',
    paste0(monitoring, '.yml')
  ))
  callbacks <- unlist(group, use.names = FALSE)
  stopifnot(
    length(monitoring) == 1L,
    setequal(catalog$source_format, c('google-discovery', 'openapi')),
    file.exists(file.path(multi, 'schema', paste0(monitoring, '.json'))),
    paste0(helper, '_discovery_next_page_token') %in% callbacks,
    !'api_request_discovery_next_page_token' %in% callbacks,
    file.exists(file.path(multi, 'dev/init.R'))
  )
  # The multi-API init script also finds each retained source.
  multi_clone <- file.path(workspace, 'multi-clone')
  multi_init <- new.env(parent = baseenv())
  sys.source(file.path(multi, 'dev/init.R'), multi_init)
  multi_init$init_main(multi_clone)
  api_file <- file.path('apis', paste0(monitoring, '.yml'))
  stopifnot(
    file.exists(file.path(multi_clone, 'schema', paste0(monitoring, '.json'))),
    identical(
      readLines(file.path(multi, 'specmill.yml')),
      readLines(file.path(multi_clone, 'specmill.yml'))
    ),
    identical(
      readLines(file.path(multi, api_file)),
      readLines(file.path(multi_clone, api_file))
    )
  )
  multi_generated <- specmill::generate_client(
    multi,
    config = 'specmill.yml',
    mode = 'apply'
  )
  multi_env <- load_client(multi)
  paged <- names(multi_generated$operations)[grepl(
    'readings_list',
    names(multi_generated$operations)
  )]
  stopifnot(length(paged) == 1L)
  withr::with_envvar(
    stats::setNames(
      'fixture-key',
      yaml::read_yaml(file.path(multi, 'specmill.yml'))$authentication[[1L]]
    ),
    {
      multi_pages <- multi_env[[paged]](pageSize = 2L)
    }
  )
  stopifnot(identical(
    unlist(lapply(multi_pages, stations), use.names = FALSE),
    paste0('s', 1:5)
  ))
  cat(
    'Discovery: type and parameter mapping, system parameters, diagnostics, localhost token paging, JSON bodies from named types, API key authentication, setup-script round trip and multi-API setup passed.\n'
  )
}
test_that('discovery importer maps types, paging, auth and multi-API setup', {
  skip_if_not_installed('callr')
  skip_if_not_installed('httpuv')
  skip_if_not_installed('httr2')
  discovery_importer_acceptance()
  succeed()
})
