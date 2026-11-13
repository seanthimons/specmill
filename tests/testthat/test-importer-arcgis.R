arcgis_importer_acceptance <- function() {
  internal <- function(name) utils::getFromNamespace(name, 'specmill')
  fixtures <- test_path('fixtures', 'arcgis')
  files <- list.files(
    fixtures,
    pattern = '\\.json$',
    recursive = TRUE,
    full.names = TRUE
  )
  services <- files[basename(files) != 'epa-directory.json']
  operations <- list()
  for (file in services) {
    imported <- internal('import_description')(file)
    stopifnot(
      !length(internal('validate_ir')(imported$ir)),
      imported$ir$sources[[1L]]$format == 'arcgis-rest'
    )
    operations[[file]] <- imported$ir$operations
    parsed <- specmill::read_operations(file)
    stopifnot(
      length(parsed$operations) == length(imported$ir$operations),
      !length(parsed$diagnostics)
    )
  }
  catalogue <- suppressWarnings(specmill::configure_apis(
    fixtures,
    review = FALSE
  ))
  stopifnot(
    nrow(catalogue) == 7L,
    all(catalogue$source_format == 'arcgis-rest'),
    length(attr(catalogue, 'source_diagnostics')) == 4L,
    any(grepl(
      'ECHOGov',
      vapply(attr(catalogue, 'source_diagnostics'), `[[`, character(1), 'url')
    ))
  )
  all_ops <- unlist(operations, recursive = FALSE)
  stopifnot(
    any(vapply(all_ops, function(op) op$native_name == 'identify', logical(1))),
    any(vapply(
      all_ops,
      function(op) op$native_name == 'queryRelatedRecords',
      logical(1)
    )),
    !any(vapply(
      all_ops,
      function(op) op$native_name == 'applyEdits',
      logical(1)
    ))
  )
  workspace <- tempfile('arcgis-acceptance-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  empty_path <- file.path(workspace, 'empty-directory.json')
  jsonlite::write_json(
    list(arcgis_capture_version = '1', kind = 'directory', services = list()),
    empty_path,
    auto_unbox = TRUE
  )
  empty_error <- tryCatch(
    specmill::configure_apis(workspace, schemas = empty_path, review = FALSE),
    error = identity
  )
  stopifnot(
    inherits(empty_error, 'error'),
    grepl('No supported service captures', conditionMessage(empty_error))
  )
  jsonlite::write_json(
    list(arcgis_capture_version = '2', kind = 'directory', services = list()),
    empty_path,
    auto_unbox = TRUE
  )
  version_error <- tryCatch(
    specmill::configure_apis(workspace, schemas = empty_path, review = FALSE),
    error = identity
  )
  stopifnot(
    inherits(version_error, 'error'),
    grepl('capture version', conditionMessage(version_error))
  )
  port_file <- file.path(workspace, 'port')
  server <- callr::r_bg(
    function(port_file) {
      `%or_test%` <- function(x, y) if (is.null(x)) y else x
      port <- httpuv::randomPort()
      history <- list()
      json <- function(value) {
        list(
          status = 200L,
          headers = list('Content-Type' = 'application/json'),
          body = jsonlite::toJSON(value, auto_unbox = TRUE, null = 'null')
        )
      }
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
          if (req$REQUEST_METHOD == 'POST') {
            query <- utils::modifyList(
              query,
              httr2::url_parse(paste0(
                'http://localhost/?',
                rawToChar(req$rook.input$read())
              ))$query
            )
          }
          history[[length(history) + 1L]] <<- list(
            method = req$REQUEST_METHOD,
            path = req$PATH_INFO,
            query = query
          )
          if (isTRUE(query$where == 'error')) {
            return(json(list(
              error = list(code = 400L, message = 'sensitive response detail')
            )))
          }
          if (endsWith(req$PATH_INFO, '/queryRelatedRecords')) {
            offset <- as.integer(query$resultOffset %or_test% '0')
            groups <- if (offset == 0L) {
              list(
                list(
                  objectId = 1L,
                  relatedRecords = list(list(attributes = list(OBJECTID = 1L)))
                ),
                list(
                  objectId = 2L,
                  relatedRecords = list(list(attributes = list(OBJECTID = 2L)))
                )
              )
            } else {
              list(
                list(
                  objectId = 1L,
                  relatedRecords = list(list(attributes = list(OBJECTID = 3L)))
                )
              )
            }
            return(json(list(relatedRecordGroups = groups)))
          }
          if (endsWith(req$PATH_INFO, '/applyEdits')) {
            if (
              !identical(query$token, 'fixture-token') ||
                !identical(query$f, 'json')
            ) {
              return(json(list(error = list(code = 498L))))
            }
            return(json(list(
              addResults = list(list(success = TRUE, objectId = 9L))
            )))
          }
          offset <- as.integer(query$resultOffset %or_test% '0')
          if (offset == 0L) {
            return(json(list(
              features = list(
                list(attributes = list(OBJECTID = 1L)),
                list(attributes = list(OBJECTID = 2L))
              ),
              exceededTransferLimit = TRUE
            )))
          }
          if (offset == 2L) {
            return(json(list(features = list(), exceededTransferLimit = TRUE)))
          }
          json(list(
            features = list(list(attributes = list(OBJECTID = 5L))),
            exceededTransferLimit = FALSE
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
  base <- paste0('http://127.0.0.1:', readLines(port_file), '/FeatureServer')
  capture <- jsonlite::read_json(file.path(fixtures, 'conductivity.json'))
  capture$url <- base
  capture$document$layers <- capture$document$layers[1L]
  capture$layers <- capture$layers[1L]
  capture$layers[[1L]]$url <- paste0(base, '/1')
  path <- file.path(workspace, 'service.json')
  save <- function() {
    jsonlite::write_json(
      capture,
      path,
      auto_unbox = TRUE,
      pretty = TRUE,
      null = 'null'
    )
  }
  save()
  root <- file.path(workspace, 'client')
  invisible(specmill::initialize_client(
    root,
    path,
    package = 'arcgistest',
    title = 'ArcGIS client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT'
  ))
  # The client-owned init script recreates the scaffold from the retained capture.
  clone <- file.path(workspace, 'clone')
  init <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/init.R'), init)
  init$init_main(clone)
  stopifnot(
    file.exists(file.path(clone, 'schema/arcgis.json')),
    identical(
      readLines(file.path(root, 'specmill.yml')),
      readLines(file.path(clone, 'specmill.yml'))
    )
  )
  generated <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  stopifnot(
    length(generated$operations) == 1L,
    all(vapply(
      generated$validation,
      function(x) x$status == 'valid',
      logical(1)
    ))
  )
  env <- new.env(parent = baseenv())
  for (file in list.files(
    file.path(root, 'R'),
    pattern = '\\.R$',
    full.names = TRUE
  )) {
    sys.source(file, env)
  }
  result <- env$query_layer_1(resultRecordCount = 2L)
  stopifnot(identical(
    vapply(result, function(x) x$attributes$OBJECTID, integer(1)),
    c(1L, 2L, 5L)
  ))
  history <- httr2::resp_body_json(
    httr2::req_perform(httr2::request(sub(
      '/FeatureServer$',
      '/history',
      base
    ))),
    simplifyVector = FALSE
  )
  stopifnot(
    identical(
      vapply(history, function(x) x$query$resultOffset, character(1)),
      c('0', '2', '4')
    ),
    all(vapply(
      history,
      function(x) {
        identical(x$query$resultRecordCount, '2') &&
          identical(x$query$f, 'json')
      },
      logical(1)
    ))
  )
  error <- tryCatch(env$query_layer_1(where = 'error'), error = identity)
  stopifnot(
    inherits(error, 'specmill_call_error'),
    error$code == 400L,
    !grepl('sensitive response detail', conditionMessage(error), fixed = TRUE)
  )
  single <- env$query_layer_1(resultRecordCount = 2L, all_pages = FALSE)
  stopifnot(length(single) == 2L)
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
  service_path <- file.path(root, 'apis/layer_1.yml')
  service <- yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
  service$operations[['GET /1/query']]$parameters <- list(
    'query resultRecordCount' = list(name = 'limit')
  )
  yaml::write_yaml(service, service_path)
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  renamed <- new.env(parent = baseenv())
  for (file in list.files(
    file.path(root, 'R'),
    pattern = '\\.R$',
    full.names = TRUE
  )) {
    sys.source(file, renamed)
  }
  stopifnot(length(renamed$query_layer_1(limit = 2L)) == 3L)
  # Reviews that patch an OpenAPI document cannot apply to imported requests.
  reviewed <- service
  reviewed$operations[['GET /1/query']]$opaque_body <- list(
    reference = 'https://example.org/schemas/body.json',
    reason = 'Reviewed recursive body.'
  )
  yaml::write_yaml(reviewed, service_path)
  rejected <- tryCatch(
    specmill::generate_client(root, config = 'specmill.yml', mode = 'plan'),
    error = identity
  )
  stopifnot(
    inherits(rejected, 'error'),
    grepl('OpenAPI-specific corrections', conditionMessage(rejected))
  )
  yaml::write_yaml(service, service_path)
  # Editing and protected-service metadata are synthetic; all requests stay on
  # localhost. Public acceptance sources above remain read-only captures.
  capture$layers[[1L]]$document$relationships <- list(list(
    id = 0L,
    name = 'Related',
    relatedTableId = 1L
  ))
  capture$requires_token <- TRUE
  capture$document$authInfo <- list(
    isTokenBasedSecurity = TRUE,
    tokenServicesUrl = paste0(
      sub('/FeatureServer$', '', base),
      '/generateToken'
    )
  )
  capture$layers[[1L]]$document$capabilities <- 'Query,Create,Update,Delete'
  save()
  ir <- internal('import_description')(path)$ir
  stopifnot(
    any(vapply(
      ir$operations,
      function(x) x$native_name == 'applyEdits',
      logical(1)
    )),
    ir$sources[[1L]]$auth_schemes$arcgis_token$kind == 'session_token',
    ir$sources[[1L]]$auth_schemes$arcgis_token$token_url ==
      capture$document$authInfo$tokenServicesUrl,
    identical(
      ir$sources[[
        1L
      ]]$auth_schemes$arcgis_token$native$auth_info$tokenServicesUrl,
      capture$document$authInfo$tokenServicesUrl
    )
  )
  protected_root <- file.path(workspace, 'protected')
  invisible(specmill::initialize_client(
    protected_root,
    path,
    package = 'arcgistest',
    title = 'Protected ArcGIS client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT'
  ))
  specmill::generate_client(
    protected_root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  protected <- new.env(parent = baseenv())
  for (file in list.files(
    file.path(protected_root, 'R'),
    pattern = '\\.R$',
    full.names = TRUE
  )) {
    sys.source(file, protected)
  }
  withr::with_envvar(c(ARCGISTEST_ARCGIS_TOKEN = 'fixture-token'), {
    edited <- protected$apply_edits_layer_1(
      body = list(adds = '[{"attributes":{"OBJECTID":9}}]')
    )
    stopifnot(edited$addResults[[1L]]$success)
    related <- protected$query_related_records_layer_1(
      objectIds = '1,2',
      relationshipId = 0L,
      resultRecordCount = 2L
    )
    stopifnot(
      identical(
        vapply(
          related,
          function(group) length(group$relatedRecords),
          integer(1)
        ),
        c(1L, 1L, 1L)
      ),
      attr(related, 'pagination')$requests == 2L
    )
  })
  history <- httr2::resp_body_json(
    httr2::req_perform(httr2::request(sub(
      '/FeatureServer$',
      '/history',
      base
    ))),
    simplifyVector = FALSE
  )
  edit <- Filter(function(x) endsWith(x$path, '/applyEdits'), history)[[1L]]
  stopifnot(
    edit$method == 'POST',
    edit$path == '/FeatureServer/1/applyEdits',
    edit$query$adds == '[{"attributes":{"OBJECTID":9}}]'
  )
  # Directory captures also initialize one helper per API with renamed protocol
  # callbacks. Generation here remains offline despite the recorded public URLs.
  multi <- file.path(workspace, 'multi')
  dir.create(multi)
  local_fixtures <- file.path(multi, 'captures')
  dir.create(local_fixtures)
  stopifnot(all(file.copy(
    list.files(fixtures, full.names = TRUE),
    local_fixtures,
    recursive = TRUE
  )))
  catalog <- suppressWarnings(specmill::configure_apis(
    multi,
    schemas = file.path(local_fixtures, 'epa-directory.json'),
    review = FALSE
  ))
  invisible(specmill::initialize_client(
    multi,
    catalog,
    package = 'arcgismulti',
    title = 'ArcGIS directory client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT'
  ))
  planned <- specmill::generate_client(
    multi,
    config = 'specmill.yml',
    mode = 'apply'
  )
  stopifnot(length(planned$operations) > 20L)
  limited <- capture
  limited$url <- sub('/FeatureServer$', '/MapServer', base)
  limited$layers[[1L]]$url <- paste0(limited$url, '/1')
  limited$document$capabilities <- 'Map,Query'
  limited$layers[[1L]]$document$capabilities <- 'Map,Query'
  limited$document$supportedOperations <- list('query')
  limited_path <- file.path(workspace, 'limited.json')
  jsonlite::write_json(limited, limited_path, auto_unbox = TRUE)
  limited_ir <- internal('import_description')(limited_path)$ir
  stopifnot(
    length(limited_ir$operations) == 1L,
    limited_ir$operations[[1L]]$native_name == 'query'
  )
  limited$document$supportedOperations <- NULL
  limited$document$capabilities <- 'Map,Data'
  limited$layers[[1L]]$document$capabilities <- 'Map,Data'
  jsonlite::write_json(limited, limited_path, auto_unbox = TRUE)
  data_ir <- internal('import_description')(limited_path)$ir
  stopifnot(setequal(
    vapply(data_ir$operations, `[[`, character(1), 'native_name'),
    c('queryRelatedRecords', 'identify')
  ))
  bad <- capture
  bad$layers[[1L]]$document$id <- 2L
  jsonlite::write_json(bad, path, auto_unbox = TRUE)
  stopifnot(inherits(
    tryCatch(internal('import_description')(path), error = identity),
    'error'
  ))
  cat(
    'ArcGIS: seven captured services, directory diagnostics, fields, related records, identify, localhost offset paging through an empty page, HTTP-200 errors, form edits and token metadata passed.\n'
  )
}
test_that('ArcGIS importer imports fixtures, generates clients and preserves edits', {
  arcgis_importer_acceptance()
  succeed()
})
