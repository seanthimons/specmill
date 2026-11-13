graphql_importer_acceptance <- function() {
  internal <- function(name) utils::getFromNamespace(name, 'specmill')
  fixture <- test_path('fixtures', 'graphql', 'monitoring.json')
  ir <- internal('import_description')(fixture)$ir
  source <- ir$sources[[1L]]
  operations <- stats::setNames(
    ir$operations,
    vapply(ir$operations, `[[`, character(1), 'key')
  )
  station <- operations[['query station']]
  listing <- stats::setNames(
    operations[['query stations']]$parameters,
    vapply(
      operations[['query stations']]$parameters,
      `[[`,
      character(1),
      'name'
    )
  )
  filter <- stats::setNames(
    source$types$ReadingFilter$fields,
    vapply(source$types$ReadingFilter$fields, `[[`, character(1), 'name')
  )
  stopifnot(
    !length(internal('validate_ir')(ir)),
    internal('resolve_importer')(fixture)$format == 'graphql',
    ir$paradigm == 'graphql',
    source$format == 'graphql',
    !length(source$servers),
    identical(
      names(operations),
      c(
        'query version',
        'query station',
        'query stations',
        'query search',
        'query latest',
        'query network',
        'query oldStations',
        'mutation tagStation',
        'mutation station'
      )
    ),
    # A mutation that shares a query's field name gets its own wrapper name.
    operations[['mutation station']]$name == 'mutate_station',
    isTRUE(operations[['query oldStations']]$deprecated),
    identical(
      vapply(ir$diagnostics, `[[`, character(1), 'code'),
      'subscriptions_unsupported'
    ),
    identical(
      station$binding,
      list(
        operation_type = 'query',
        field = 'station',
        method = 'POST',
        path = '/graphql'
      )
    ),
    station$parameters[[1L]]$location == 'argument',
    isTRUE(station$parameters[[1L]]$required),
    station$parameters[[1L]]$type$native_type == 'ID!',
    # An argument with a default value is optional; its text is kept.
    !listing$limit$required,
    !listing$offset$required,
    listing$offset$type$native_type == 'Int!',
    listing$limit$type$native$default_value == '10',
    listing$kinds$type$native_type == '[StationKind!]',
    listing$kinds$type$kind == 'list',
    identical(source$types$Station$implements, list('Node')),
    isTRUE(source$types$Node$abstract),
    source$types$SearchResult$kind == 'union',
    source$types$SearchResult$discriminator$property == '__typename',
    length(source$types$SearchResult$variants) == 2L,
    isTRUE(source$types$StationKind$values[[3L]]$deprecated),
    # A custom scalar's wire form is not known from the schema.
    source$types$Long$kind == 'any',
    identical(source$types$Long$lossy, list('custom_scalar')),
    isTRUE(filter$stationIds$required),
    !filter$kind$required,
    !any(startsWith(names(source$types), '__'))
  )
  read <- function(policy = list()) {
    parsed <- suppressMessages(specmill::read_operations(fixture, policy))
    list(
      documents = vapply(
        parsed$operations,
        function(op) op$graphql$document,
        character(1)
      ),
      codes = stats::setNames(
        vapply(parsed$diagnostics, `[[`, character(1), 'code'),
        vapply(parsed$diagnostics, `[[`, character(1), 'key')
      )
    )
  }
  default <- read()
  stopifnot(
    # One level of scalar and enum fields: no objects, no deprecated fields, no
    # fields that take required arguments.
    identical(
      default$documents[['station']],
      'query station($id: ID!) { station(id: $id) { id name elevation active kind sampleCount tags } }'
    ),
    identical(default$documents[['version']], 'query version { version }'),
    identical(
      default$documents[['search']],
      'query search($filter: ReadingFilter!, $page: PageInput = {index: 0, size: 25}) { search(filter: $filter, page: $page) { total } }'
    ),
    startsWith(
      default$documents[['tagStation']],
      'mutation tagStation($id: ID!'
    ),
    # A non-null argument with a default stays optional in the declaration.
    startsWith(
      default$documents[['stations']],
      'query stations($region: String, $limit: Int = 10, $offset: Int! = 0, $kinds: [StationKind!], $sort: String = "name") { stations(region: $region, limit: $limit, offset: $offset, kinds: $kinds, sort: $sort)'
    ),
    # A return type without scalar fields needs a reviewed selection.
    identical(
      default$codes,
      c(
        'query latest' = 'selection_required',
        'query network' = 'selection_required'
      )
    )
  )
  selection <- function(key, fields) {
    read(list(graphql_fields = stats::setNames(list(fields), key)))
  }
  nested <- selection(
    'query station',
    list('id', list(location = list('latitude', list(region = list('code')))))
  )
  typename <- selection('query latest', list('__typename'))
  reviewed <- read(list(
    graphql_documents = list(
      'query latest' = 'query latest { latest { __typename ... on Station { id } } }'
    )
  ))
  rejected <- function(fields, code = 'graphql_selection') {
    identical(selection('query station', fields)$codes[['query station']], code)
  }
  stopifnot(
    identical(
      nested$documents[['station']],
      'query station($id: ID!) { station(id: $id) { id location { latitude region { code } } } }'
    ),
    identical(
      typename$documents[['latest']],
      'query latest { latest { __typename } }'
    ),
    # A reviewed document replaces rendering.
    identical(
      reviewed$documents[['latest']],
      'query latest { latest { __typename ... on Station { id } } }'
    ),
    rejected(list('nope')),
    rejected(list('location')),
    rejected(list(list(name = list('first')))),
    rejected(list(list(readings = list('value')))),
    rejected(list('id', 'id')),
    rejected(list(), 'selection_required'),
    identical(
      selection('query version', list('major'))$codes[['query version']],
      'graphql_selection'
    )
  )
  workspace <- tempfile('graphql-acceptance-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
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
      httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          if (req$PATH_INFO == '/history') {
            return(json(history))
          }
          raw <- rawToChar(req$rook.input$read())
          request <- jsonlite::fromJSON(raw, simplifyVector = FALSE)
          history[[length(history) + 1L]] <<- list(
            method = req$REQUEST_METHOD,
            path = req$PATH_INFO,
            raw = raw,
            query = request$query,
            variables = request$variables
          )
          name <- sub('^(query|mutation) ([A-Za-z]+).*$', '\\2', request$query)
          id <- request$variables$id
          one <- function(id) list(id = id, name = paste('Station', id))
          if (name == 'version') {
            return(json(list(data = list(version = '1.2.3'))))
          }
          if (name == 'station' && identical(id, 'missing')) {
            return(json(list(data = list(station = NULL))))
          }
          if (name == 'station' && identical(id, 'partial')) {
            return(json(list(
              errors = list(list(message = 'secret detail for partial')),
              data = list(station = one(id))
            )))
          }
          if (name == 'station' && identical(id, 'denied')) {
            return(json(
              list(errors = list(list(message = 'not allowed'))),
              400L
            ))
          }
          if (name == 'station' && identical(id, 'down')) {
            return(json(list(status = 'unavailable'), 503L))
          }
          if (name == 'station' && id %in% c('garbled', 'truncated')) {
            return(list(
              status = if (id == 'garbled') 502L else 200L,
              headers = list('Content-Type' = 'application/json'),
              body = '{'
            ))
          }
          if (name == 'stations') {
            return(json(list(data = list(stations = list(one('a'), one('b'))))))
          }
          if (name == 'latest') {
            return(json(list(
              data = list(latest = list(`__typename` = 'Station', id = 'z'))
            )))
          }
          if (name == 'search') {
            return(json(list(data = list(search = list(total = 2L)))))
          }
          json(list(data = stats::setNames(list(one(id)), name)))
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
  origin <- paste0('http://127.0.0.1:', readLines(port_file))
  # The endpoint is <base_url>/graphql; introspection names no server.
  base <- paste0(origin, '/api')
  metadata <- list(
    package = 'graphclient',
    title = 'GraphQL client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT'
  )
  unnamed <- tryCatch(
    do.call(
      specmill::initialize_client,
      c(
        list(root = file.path(workspace, 'unnamed'), schema = fixture),
        metadata
      )
    ),
    error = identity
  )
  stopifnot(
    inherits(unnamed, 'error'),
    grepl('supply base_url', conditionMessage(unnamed), fixed = TRUE)
  )
  root <- file.path(workspace, 'client')
  invisible(do.call(
    specmill::initialize_client,
    c(list(root = root, schema = fixture, base_url = base), metadata)
  ))
  query_path <- file.path(root, 'apis/query.yml')
  read_service <- function(path) {
    yaml::read_yaml(path, handlers = list(seq = function(x) x))
  }
  service <- read_service(query_path)
  stopifnot(
    file.exists(file.path(root, 'schema/graphql.json')),
    file.exists(file.path(root, 'apis/mutation.yml')),
    identical(service$format, 'graphql'),
    identical(service$defaults$response_policy, 'api_request_graphql_response'),
    identical(service$defaults$graphql_path, '/graphql'),
    # The default selection is written as reviewable policy.
    identical(
      service$operations[['query station']]$fields,
      list('id', 'name', 'elevation', 'active', 'kind', 'sampleCount', 'tags')
    ),
    identical(service$operations[['query network']]$fields, list()),
    any(grepl(
      'api_request_graphql_response <- function',
      readLines(file.path(root, 'R/api_request.R')),
      fixed = TRUE
    ))
  )
  # The client-owned init script recreates the scaffold from the retained file.
  clone <- file.path(workspace, 'clone')
  init <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/init.R'), init)
  init$init_main(clone)
  stopifnot(
    file.exists(file.path(clone, 'schema/graphql.json')),
    identical(
      readLines(file.path(root, 'specmill.yml')),
      readLines(file.path(clone, 'specmill.yml'))
    ),
    identical(
      readLines(query_path),
      readLines(file.path(clone, 'apis/query.yml'))
    )
  )
  # Two operations have no default selection, so generation waits for review.
  blocked <- tryCatch(
    specmill::generate_client(root, config = 'specmill.yml', mode = 'apply'),
    error = identity
  )
  service$operations[['query station']]$fields <- list(
    'id',
    'name',
    list(location = list('latitude', list(region = list('code'))))
  )
  service$operations[['query network']]$fields <- list(
    list(owner = list('code'))
  )
  service$operations[['query latest']]$fields <- NULL
  service$operations[['query latest']]$query_document <-
    'query latest { latest { __typename ... on Station { id } } }'
  yaml::write_yaml(service, query_path)
  generated <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  stopifnot(
    inherits(blocked, 'error'),
    grepl('Unsupported selected operations', conditionMessage(blocked)),
    length(generated$operations) == 9L,
    !length(generated$diagnostics),
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
      httr2::req_perform(httr2::request(paste0(origin, '/history'))),
      simplifyVector = FALSE
    )
  }
  failure <- function(expr) tryCatch(expr, error = identity)
  env <- load_client(root)
  version <- env$version()
  found <- env$station(id = 's1')
  everything <- env$stations()
  filtered <- env$stations(region = 'east', kinds = list('AIR', 'WATER'))
  searched <- env$search(filter = list(stationIds = list('s1'), minValue = 2))
  absent <- env$station(id = 'missing')
  latest <- env$latest()
  tagged <- env$tagStation(id = 's1', tag = 'coastal')
  replaced <- env$mutate_station(id = 's2')
  partial <- failure(env$station(id = 'partial'))
  denied <- failure(env$station(id = 'denied'))
  down <- failure(env$station(id = 'down'))
  garbled <- failure(env$station(id = 'garbled'))
  truncated <- failure(env$station(id = 'truncated'))
  calls <- history()
  stopifnot(
    identical(version, '1.2.3'),
    identical(found$id, 's1'),
    length(everything) == 2L,
    identical(searched$total, 2L),
    # A null root field is a valid answer, not an error.
    is.null(absent),
    identical(latest$`__typename`, 'Station'),
    identical(tagged$id, 's1'),
    identical(replaced$id, 's2'),
    all(vapply(calls, function(x) x$method == 'POST', logical(1))),
    all(vapply(calls, function(x) x$path == '/api/graphql', logical(1))),
    # No arguments: no variables member. Arguments travel as variables only.
    !grepl('variables', calls[[1L]]$raw, fixed = TRUE),
    identical(
      calls[[2L]]$query,
      'query station($id: ID!) { station(id: $id) { id name location { latitude region { code } } } }'
    ),
    identical(calls[[2L]]$variables, list(id = 's1')),
    !grepl('s1', calls[[2L]]$query, fixed = TRUE),
    # Omitted optional arguments are not sent, and none is still an object.
    grepl('"variables":{}', calls[[3L]]$raw, fixed = TRUE),
    identical(
      calls[[4L]]$variables,
      list(region = 'east', kinds = list('AIR', 'WATER'))
    ),
    identical(
      calls[[5L]]$variables$filter,
      list(stationIds = list('s1'), minValue = 2L)
    ),
    startsWith(calls[[8L]]$query, 'mutation tagStation('),
    identical(calls[[8L]]$variables, list(id = 's1', tag = 'coastal')),
    # Errors always raise, also beside partial data and with HTTP 200; the
    # server's text stays out of the message and on the condition.
    inherits(partial, 'specmill_call_error'),
    !grepl('secret detail', conditionMessage(partial), fixed = TRUE),
    identical(partial$errors[[1L]]$message, 'secret detail for partial'),
    inherits(denied, 'specmill_call_error'),
    identical(denied$errors[[1L]]$message, 'not allowed'),
    # Without a GraphQL errors body the ordinary status and decoding errors
    # apply, also when an error status carries an undecodable body.
    is.null(down$errors),
    grepl('HTTP 503', conditionMessage(down), fixed = TRUE),
    grepl('HTTP 502', conditionMessage(garbled), fixed = TRUE),
    !grepl('Cannot decode', conditionMessage(garbled), fixed = TRUE),
    grepl('Cannot decode', conditionMessage(truncated), fixed = TRUE)
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
  # Settings for GraphQL operations are refused elsewhere.
  catalogue <- file.path(workspace, 'catalogue')
  invisible(do.call(
    specmill::initialize_client,
    c(
      list(
        root = catalogue,
        schema = system.file(
          'catalogue/schema.json',
          package = 'specmill',
          mustWork = TRUE
        ),
        base_url = 'https://catalogue.example.test'
      ),
      metadata
    )
  ))
  rest_path <- list.files(file.path(catalogue, 'apis'), full.names = TRUE)[[1L]]
  rest <- read_service(rest_path)
  rest$operations[[rest$selection$include[[1L]]]]$fields <- list('id')
  yaml::write_yaml(rest, rest_path)
  refused <- failure(specmill::generate_client(
    catalogue,
    config = 'specmill.yml',
    mode = 'plan'
  ))
  stopifnot(
    inherits(refused, 'error'),
    grepl('GraphQL operations only', conditionMessage(refused), fixed = TRUE)
  )
  # Multi-API setup finds the retained file and renames the callback.
  multi <- file.path(workspace, 'multi')
  inputs <- file.path(multi, 'input')
  dir.create(inputs, recursive = TRUE)
  stopifnot(
    file.copy(fixture, file.path(inputs, 'monitoring.json')),
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
  graph <- catalog$api[catalog$source_format == 'graphql']
  catalog$base_url[catalog$source_format == 'graphql'] <- base
  catalog$base_url[catalog$source_format == 'openapi'] <-
    'https://catalogue.example.test'
  metadata$package <- 'graphmulti'
  invisible(do.call(
    specmill::initialize_client,
    c(list(root = multi, schema = catalog), metadata)
  ))
  api_file <- file.path('apis', paste0(graph, '.yml'))
  callbacks <- unlist(
    read_service(file.path(multi, api_file)),
    use.names = FALSE
  )
  multi_clone <- file.path(workspace, 'multi-clone')
  multi_init <- new.env(parent = baseenv())
  sys.source(file.path(multi, 'dev/init.R'), multi_init)
  multi_init$init_main(multi_clone)
  written <- read_service(file.path(multi, api_file))$groups
  station_fields <- Filter(
    Negate(is.null),
    lapply(written, function(group) {
      group$operations[['query station']]$fields
    })
  )
  stopifnot(
    length(graph) == 1L,
    # The default selections reach the multi-API group files.
    identical(
      unname(station_fields),
      list(list(
        'id',
        'name',
        'elevation',
        'active',
        'kind',
        'sampleCount',
        'tags'
      ))
    ),
    file.exists(file.path(multi, 'schema', paste0(graph, '.json'))),
    paste0(graph, '_request_graphql_response') %in% callbacks,
    !'api_request_graphql_response' %in% callbacks,
    identical(
      readLines(file.path(multi, api_file)),
      readLines(file.path(multi_clone, api_file))
    )
  )
  group <- read_service(file.path(multi, api_file))
  for (id in names(group$groups)) {
    for (key in c('query latest', 'query network')) {
      if (!is.null(group$groups[[id]]$operations[[key]])) {
        group$groups[[id]]$operations[[key]]$fields <- list('__typename')
      }
    }
    if (!is.null(group$groups[[id]]$operations[['query network']])) {
      group$groups[[id]]$operations[['query network']]$fields <- list(
        list(owner = list('code'))
      )
    }
  }
  yaml::write_yaml(group, file.path(multi, api_file))
  multi_generated <- specmill::generate_client(
    multi,
    config = 'specmill.yml',
    mode = 'apply'
  )
  multi_env <- load_client(multi)
  versions <- grep('version$', names(multi_generated$operations), value = TRUE)
  stopifnot(
    length(versions) == 1L,
    identical(multi_env[[versions]](), '1.2.3')
  )
  cat(
    'GraphQL: introspection types, default and reviewed selections, reviewed documents, variables, null results, errors beside partial data, setup-script round trip and multi-API setup passed.\n'
  )
}
test_that('GraphQL importer maps schema, selections, variables and errors end to end', {
  graphql_importer_acceptance()
  succeed()
})
