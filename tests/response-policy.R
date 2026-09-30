response_policy_acceptance <- function() {
  root <- tempfile('response-client-')
  library <- tempfile('response-library-')
  port_file <- tempfile('response-port-')
  dir.create(library)
  on.exit(unlink(c(root, library, port_file), recursive = TRUE), add = TRUE)
  process <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          body <- switch(
            req$PATH_INFO,
            '/csv' = 'id,label name\n1,hello\n',
            '/envelope' = '{"records":[{"id":"001","empty":null},{"id":2,"extra":true}],"total":10}',
            '{"id":1}'
          )
          list(
            status = 200L,
            headers = list(
              'Content-Type' = if (req$PATH_INFO == '/csv') {
                'text/csv'
              } else {
                'application/json'
              }
            ),
            body = body
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
  origin <- paste0('http://127.0.0.1:', readLines(port_file))
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(schema), add = TRUE)
  operation <- function(name) {
    list(operationId = name, responses = list('200' = list(description = 'OK')))
  }
  envelope <- operation('envelope')
  envelope$parameters <- list(list(
    name = 'q',
    `in` = 'query',
    schema = list(type = 'string')
  ))
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Responses', version = '1'),
      servers = list(list(url = origin)),
      paths = list(
        '/object' = list(get = operation('object')),
        '/csv' = list(get = operation('csv')),
        '/envelope' = list(get = envelope)
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'responseclient',
    title = 'Response Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  service_path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
  service$defaults$response_policy <- 'common_response'
  service$operations <- list('GET /object' = list(response_policy = NULL))
  service$hooks <- list(
    envelope = list(post_response = list('format_response'))
  )
  yaml::write_yaml(service, service_path)
  metadata <- read.dcf(file.path(root, 'DESCRIPTION'))
  metadata[1, 'Imports'] <- paste(metadata[1, 'Imports'], 'tibble', sep = ', ')
  write.dcf(metadata, file.path(root, 'DESCRIPTION'))
  writeLines(
    c(
      'common_response <- function(response, context, decode) {',
      '  options(responseclient.observed = context)',
      '  decode(format = "delimited")',
      '}',
      'format_response <- function(state) {',
      '  api_request_table(api_request_records(state$result, collection = "records",',
      '    query = state$params$q, null_to_na = TRUE), as_table = tibble::as_tibble)',
      '}',
      'run_hook <- function(fn_name, hook_type, state) format_response(state)'
    ),
    file.path(root, 'R/response_policy.R')
  )
  run <- function(mode) {
    specmill::generate_client(validation = FALSE, root, config = 'specmill.yml', mode = mode)
  }
  run('apply')
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  before <- hashes()
  run('apply')
  run('check')
  stopifnot(identical(before, hashes()))
  object_code <- paste(
    readLines(file.path(root, 'R/object.R')),
    collapse = '\n'
  )
  csv_code <- paste(readLines(file.path(root, 'R/csv.R')), collapse = '\n')
  stopifnot(
    !grepl('response_policy =', object_code, fixed = TRUE),
    grepl('response_policy = "common_response"', csv_code, fixed = TRUE)
  )
  # Policy selection is declarative and must resolve to retained client code.
  fails <- function(expr, pattern) {
    error <- tryCatch(force(expr), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  bad <- service
  bad$defaults$response_policy <- 'function(x) x'
  yaml::write_yaml(bad, service_path)
  fails(run('plan'), 'client function name')
  bad$defaults$response_policy <- 'missing_policy'
  yaml::write_yaml(bad, service_path)
  fails(run('apply'), 'Missing client response policy')
  stopifnot(identical(
    before[names(before) != service_path],
    hashes()[names(before) != service_path]
  ))
  yaml::write_yaml(service, service_path)
  # Companion names are helper-scoped, including in multi-service scaffolds.
  renamed <- getFromNamespace('request_helper_scaffold', 'specmill')(
    'other_request',
    origin,
    NULL,
    'RESPONSECLIENT_DRY_RUN'
  )
  other <- new.env(parent = baseenv())
  eval(parse(text = renamed$code), other)
  stopifnot(
    all(
      c(
        'other_request',
        'other_request_delimited',
        'other_request_records',
        'other_request_table'
      ) %in%
        ls(other)
    ),
    !'api_request_records' %in% ls(other)
  )
  # Existing edited helpers and their ownership baseline survive ordinary generation.
  helper_path <- file.path(root, 'R/api_request.R')
  write('# retained client customization', helper_path, append = TRUE)
  baseline_path <- file.path(root, '.specmill/helpers/api_request.json')
  retained <- tools::md5sum(c(helper_path, baseline_path))
  run('apply')
  run('check')
  stopifnot(
    identical(retained, tools::md5sum(c(helper_path, baseline_path))),
    specmill::inspect_client(root)$helpers$api_request$customized
  )
  installed <- system2(
    file.path(R.home('bin'), 'R'),
    c('CMD', 'INSTALL', '-l', shQuote(library), shQuote(root)),
    stdout = TRUE,
    stderr = TRUE
  )
  if (!is.null(attr(installed, 'status'))) {
    stop(paste(installed, collapse = '\n'))
  }
  callr::r(
    function(library) {
      .libPaths(c(library, .libPaths()))
      ns <- loadNamespace('responseclient')
      stopifnot(!'specmill' %in% loadedNamespaces())
      object <- get('object', ns)()
      stopifnot(
        identical(object, list(id = 1L)),
        is.null(getOption('responseclient.observed'))
      )
      csv <- get('csv', ns)()
      stopifnot(
        identical(names(csv), c('id', 'label name')),
        identical(csv$id, 1L),
        getOption('responseclient.observed')$media == 'text/csv'
      )
      result <- get('envelope', ns)('Q')
      stopifnot(
        inherits(result, 'tbl_df'),
        identical(result$id, 1:2),
        identical(result$query, c('Q', 'Q')),
        all(is.na(result$empty))
      )
      request <- get('api_request', ns)
      preserved <- request(
        'GET',
        '/envelope',
        list(),
        list(),
        NULL,
        response_policy = function(response, context, decode) {
          list(response = response, result = decode())
        }
      )
      stopifnot(
        preserved$result$total == 10L,
        inherits(preserved$response, 'httr2_response'),
        !'specmill' %in% loadedNamespaces()
      )
    },
    args = list(library = library)
  )
  cat(
    'Response policy: shared service selection, hooks, deterministic generation, helper ownership and independent installed runtime passed.\n'
  )
}
if (sys.nframe() == 0L) {
  response_policy_acceptance()
}
