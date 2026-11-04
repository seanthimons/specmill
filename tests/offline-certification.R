# Certification for issue 262: a client generated from a Swagger 2 YAML schema
# records encoded, authenticated, JSON, form, binary, empty, paged and batched
# calls once against localhost, and refuses multipart. With the server stopped
# and no credentials, R CMD check then replays them through its real hooks and
# request helper, without specmill, and a second generation changes nothing.

offline_certification <- function() {
  for (package in c(
    'vcr',
    'withr',
    'testthat',
    'httpuv',
    'callr',
    'yaml',
    'jsonlite'
  )) {
    if (!requireNamespace(package, quietly = TRUE)) {
      message('Skipping offline certification: ', package, ' is not installed')
      return(invisible())
    }
  }
  step <- function(x) message('offline certification: ', x)
  secret <- 'C3rt/Key+=1 x'
  port_file <- tempfile('http-port-')
  on.exit(unlink(port_file), add = TRUE)
  server <- callr::r_bg(
    function(port_file, secret) {
      decode <- function(x) utils::URLdecode(gsub('+', ' ', x, fixed = TRUE))
      json <- function(x, status = 200L) {
        list(
          status = status,
          headers = list('Content-Type' = 'application/json'),
          body = jsonlite::toJSON(x, auto_unbox = TRUE)
        )
      }
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(request) {
          pairs <- strsplit(
            strsplit(sub('^\\?', '', request$QUERY_STRING), '&')[[1L]],
            '='
          )
          pairs <- pairs[lengths(pairs) > 0L]
          query <- stats::setNames(
            lapply(pairs, function(x) decode(paste(x[-1L], collapse = '='))),
            vapply(pairs, `[[`, character(1), 1L)
          )
          if (!identical(query$api_key, secret)) {
            return(json(list(), 401L))
          }
          path <- request$PATH_INFO
          method <- request$REQUEST_METHOD
          body <- if (method == 'POST') {
            rawToChar(request$rook.input$read())
          } else {
            ''
          }
          if (method == 'DELETE') {
            # httpuv ends an empty 204 with a chunk terminator that curl never
            # reads, which breaks the next response on a reused connection.
            return(list(
              status = 204L,
              headers = list(Connection = 'close'),
              body = ''
            ))
          }
          if (startsWith(path, '/records/')) {
            return(json(list(
              id = decode(sub('^/records/', '', path)),
              tags = strsplit(query$tags, ',', fixed = TRUE)[[1L]],
              trace = request$HTTP_X_TRACE
            )))
          }
          if (path == '/records') {
            return(json(
              list(id = 'r-new', title = jsonlite::fromJSON(body)$title),
              201L
            ))
          }
          if (path == '/forms') {
            return(json(list(
              form = startsWith(request$CONTENT_TYPE, 'application/x-www-form'),
              title = grepl('title=Hi', body, fixed = TRUE)
            )))
          }
          if (startsWith(path, '/exports/')) {
            return(list(
              status = 200L,
              headers = list('Content-Type' = 'application/octet-stream'),
              body = as.raw(c(0:5, 255L))
            ))
          }
          if (path == '/pages') {
            page <- if (is.null(query$page)) 1L else as.integer(query$page)
            return(json(
              if (page <= 2L) list(list(id = paste0('p', page))) else list()
            ))
          }
          if (startsWith(path, '/stations/')) {
            return(json(list(id = sub('^/stations/', '', path))))
          }
          json(list(), 404L)
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file = port_file, secret = secret),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  for (i in seq_len(200L)) {
    if (file.exists(port_file)) {
      break
    }
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))

  step('generate from a Swagger 2 YAML schema')
  workspace <- tempfile('offline-certification-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  schema <- file.path(workspace, 'schema.yaml')
  writeLines(
    c(
      "swagger: '2.0'",
      "info: {title: Certification, version: '1'}",
      'securityDefinitions:',
      '  key: {type: apiKey, name: api_key, in: query}',
      'security: [{key: []}]',
      'paths:',
      '  /records/{record_id}:',
      '    get:',
      '      operationId: get_record',
      '      produces: [application/json]',
      '      parameters:',
      '        - {name: record_id, in: path, required: true, type: string}',
      '        - {name: tags, in: query, type: array, items: {type: string}, collectionFormat: csv}',
      '        - {name: X-Trace, in: header, type: string}',
      "      responses: {'200': {description: Record}}",
      '    delete:',
      '      operationId: delete_record',
      '      parameters:',
      '        - {name: record_id, in: path, required: true, type: string}',
      "      responses: {'204': {description: Deleted}}",
      '  /records:',
      '    post:',
      '      operationId: create_record',
      '      consumes: [application/json]',
      '      produces: [application/json]',
      '      parameters:',
      '        - name: record',
      '          in: body',
      '          required: true',
      '          schema: {type: object, properties: {title: {type: string}}}',
      "      responses: {'201': {description: Created}}",
      '  /forms:',
      '    post:',
      '      operationId: submit_form',
      '      consumes: [application/x-www-form-urlencoded]',
      '      produces: [application/json]',
      '      parameters:',
      '        - {name: title, in: formData, required: true, type: string}',
      '        - {name: count, in: formData, type: integer}',
      "      responses: {'200': {description: Received}}",
      '  /uploads:',
      '    post:',
      '      operationId: upload_note',
      '      consumes: [multipart/form-data]',
      '      produces: [application/json]',
      '      parameters:',
      '        - {name: note, in: formData, required: true, type: string}',
      "      responses: {'200': {description: Received}}",
      '  /exports/{name}:',
      '    get:',
      '      operationId: get_export',
      '      produces: [application/octet-stream]',
      '      parameters:',
      '        - {name: name, in: path, required: true, type: string}',
      '      responses:',
      "        '200': {description: Bytes, schema: {type: string, format: binary}}",
      '  /pages:',
      '    get:',
      '      operationId: list_pages',
      '      produces: [application/json]',
      '      parameters:',
      '        - {name: page, in: query, type: integer}',
      "      responses: {'200': {description: Page}}",
      '  /stations/{station_id}:',
      '    get:',
      '      operationId: get_station',
      '      produces: [application/json]',
      '      parameters:',
      '        - {name: station_id, in: path, required: true, type: string}',
      "      responses: {'200': {description: Station}}"
    ),
    schema
  )
  root <- file.path(workspace, 'certclient')
  specmill::initialize_client(
    root,
    schema,
    package = 'certclient',
    title = 'Certification Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = paste0('http://127.0.0.1:', readLines(port_file)),
    companions = 'pagination'
  )
  # Hooks read their registry with yaml at runtime, so it moves to Imports.
  description <- read.dcf(file.path(root, 'DESCRIPTION'))
  description[1L, 'Imports'] <- paste(
    description[1L, 'Imports'],
    'yaml',
    sep = ', '
  )
  suggests <- trimws(strsplit(description[1L, 'Suggests'], ',')[[1L]])
  description[1L, 'Suggests'] <- paste(
    setdiff(suggests, 'yaml'),
    collapse = ', '
  )
  write.dcf(description, file.path(root, 'DESCRIPTION'))
  specmill::configure_hooks(root, mode = 'apply')
  writeLines(
    c(
      'trim_record_id <- function(state) {',
      '  state$params$record_id <- trimws(state$params$record_id)',
      '  state',
      '}'
    ),
    file.path(root, 'R/hooks_certification.R')
  )
  writeLines(
    c('get_record:', '  pre_request: [trim_record_id]'),
    file.path(root, 'inst/hooks.yml')
  )
  service_path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
  service$hook_callback <- 'run_hook'
  service$hook_config <- 'inst/hooks.yml'
  service$operations <- list(
    'GET /pages' = list(
      pagination = list(mode = 'page', parameter = 'page', start = 1L)
    ),
    'GET /stations/{station_id}' = list(batch = list(fan_out = 'station_id'))
  )
  service$testing <- list(
    file = 'tests/testthat/fixtures/testing.yml',
    match = c('method', 'uri', 'body')
  )
  yaml::write_yaml(service, service_path)
  # vcr cannot store multipart parts, so the route is declared unrecorded.
  service$testing$unrecorded <- list(
    'POST /uploads' = list(reason = 'Multipart bodies cannot be recorded')
  )
  fixtures <- file.path(root, 'tests/testthat/fixtures')
  dir.create(fixtures, recursive = TRUE)
  write_approved <- '    record_write: {reason: Local certification server}'
  declarations <- c(
    'scenarios:',
    '  record_encoded:',
    '    operation: GET /records/{record_id}',
    "    inputs: {record_id: ' a b/c ', tags: [a, b], X.Trace: trace-1}",
    '    checks:',
    '      values:',
    "        - {path: [id], equals: 'a b/c'}",
    '        - {path: [tags, 2], equals: b}',
    '        - {path: [trace], equals: trace-1}',
    '  record_create:',
    '    operation: POST /records',
    '    inputs: {body: {title: Hello}}',
    write_approved,
    '    checks: {values: [{path: [title], equals: Hello}]}',
    '  form_submit:',
    '    operation: POST /forms',
    "    inputs: {body: {title: 'Hi there', count: 2}}",
    write_approved,
    '    checks: {values: [{path: [form], equals: true}, {path: [title], equals: true}]}',
    '  export_bytes:',
    '    operation: GET /exports/{name}',
    '    inputs: {name: data.bin}',
    '    checks: {class: raw}',
    '  record_delete:',
    '    operation: DELETE /records/{record_id}',
    '    inputs: {record_id: r-1}',
    write_approved,
    '  pages_all:',
    '    operation: GET /pages',
    '    inputs: {all_pages: true}',
    '  stations_batch:',
    '    operation: GET /stations/{station_id}',
    '    inputs: {station_id: [s1, s2]}',
    'hook_cases:',
    '  trims_record_id:',
    '    hook: trim_record_id',
    '    stage: pre_request',
    "    state: {params: {record_id: ' r '}}",
    '    expect: {state: {params: {record_id: r}}}'
  )
  generate <- function() {
    specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = 'apply'
    )
  }
  writeLines(
    c(
      declarations[1L],
      '  note_upload:',
      '    operation: POST /uploads',
      '    inputs: {body: {note: hello}}',
      write_approved,
      declarations[-1L]
    ),
    file.path(fixtures, 'testing.yml')
  )
  rejected <- tryCatch(generate(), error = conditionMessage)
  stopifnot(
    is.character(rejected),
    grepl('multipart request bodies cannot be recorded', rejected, fixed = TRUE)
  )
  yaml::write_yaml(service, service_path)
  writeLines(declarations, file.path(fixtures, 'testing.yml'))
  generate()
  scenarios <- c(
    'record_encoded',
    'record_create',
    'form_submit',
    'export_bytes',
    'record_delete',
    'pages_all',
    'stations_batch'
  )

  step('record every scenario once against localhost')
  library <- tempfile('certification-library-')
  dir.create(library)
  on.exit(unlink(library, recursive = TRUE), add = TRUE)
  installed <- callr::rcmd(
    'INSTALL',
    c(paste0('--library=', library), root),
    wd = workspace,
    env = callr::rcmd_safe_env()
  )
  if (installed$status != 0L) {
    stop(installed$stdout, installed$stderr)
  }
  recorded <- callr::r(
    function(root) {
      tryCatch(
        {
          testthat::test_local(
            root,
            filter = 'scenario',
            load_package = 'installed',
            reporter = 'silent',
            stop_on_failure = TRUE
          )
          'passed'
        },
        error = function(e) paste('failed:', conditionMessage(e))
      )
    },
    list(root = root),
    libpath = c(library, .libPaths()),
    env = c(
      callr::rcmd_safe_env(),
      CI = 'false',
      CERTCLIENT_KEY = secret,
      CERTCLIENT_RECORD = paste0('certclient/', scenarios, collapse = ',')
    )
  )
  if (!identical(recorded, 'passed')) {
    stop('Recording failed: ', recorded)
  }
  recordings <- file.path(root, 'tests/testthat/_vcr/certclient')
  stopifnot(
    file.exists(file.path(recordings, paste0(scenarios, '.yml'))),
    file.exists(file.path(
      root,
      'tests/testthat/_signatures/certclient',
      paste0(scenarios, '.yml')
    ))
  )
  interactions <- function(scenario) {
    length(
      yaml::read_yaml(file.path(
        recordings,
        paste0(scenario, '.yml')
      ))$http_interactions
    )
  }
  # Paging stops on the empty third page; the batch fans out one call per ID.
  stopifnot(
    interactions('pages_all') == 3L,
    interactions('stations_batch') == 2L
  )
  files <- list.files(
    root,
    recursive = TRUE,
    all.files = TRUE,
    full.names = TRUE
  )
  text <- paste(unlist(lapply(files, readLines, warn = FALSE)), collapse = '\n')
  for (form in c(secret, 'C3rt', 'Key%2B', 'Key+=1', '%2FKey')) {
    if (grepl(form, text, fixed = TRUE)) {
      stop('The credential reached a client file: ', form)
    }
  }

  step('stop the server, then build and check the client offline')
  server$kill()
  stopifnot(!server$is_alive())
  check_env <- c(
    callr::rcmd_safe_env(),
    CI = 'true',
    CERTCLIENT_KEY = '',
    CERTCLIENT_RECORD = '',
    NOT_CRAN = 'true',
    `_R_CHECK_FUTURE_FILE_TIMESTAMPS_` = 'false',
    `_R_CHECK_SYSTEM_CLOCK_` = 'false',
    `_R_CHECK_CRAN_INCOMING_` = 'false',
    `_R_CHECK_CRAN_INCOMING_REMOTE_` = 'false'
  )
  built <- callr::rcmd(
    'build',
    c('--no-build-vignettes', '--no-manual', root),
    wd = workspace,
    env = check_env
  )
  if (built$status != 0L) {
    stop(built$stdout, built$stderr)
  }
  tarball <- list.files(
    workspace,
    '^certclient_.*\\.tar\\.gz$',
    full.names = TRUE
  )
  checked <- callr::rcmd(
    'check',
    c('--no-manual', paste0('--output=', workspace), tarball),
    wd = workspace,
    env = check_env
  )
  log_path <- file.path(workspace, 'certclient.Rcheck/00check.log')
  if (!file.exists(log_path)) {
    stop('R CMD check wrote no log:\n', checked$stdout, checked$stderr)
  }
  check_log <- readLines(log_path)
  problems <- grep('\\.\\.\\. (ERROR|WARNING)', check_log, value = TRUE)
  if (checked$status != 0L || length(problems)) {
    stop(
      'R CMD check of the generated client failed:\n',
      paste(check_log, collapse = '\n')
    )
  }
  test_log <- readLines(
    file.path(workspace, 'certclient.Rcheck/tests/testthat.Rout')
  )
  stopifnot(
    any(grepl('* checking tests ... OK', check_log, fixed = TRUE)),
    !any(grepl('listed in more than one of', check_log, fixed = TRUE)),
    any(grepl('[ FAIL 0 | ', test_log, fixed = TRUE)),
    any(grepl('PASS [1-9][0-9]* \\]', test_log)),
    !any(grepl('SKIP [1-9]', test_log))
  )

  step('confirm no specmill dependency and an unchanged second generation')
  metadata <- read.dcf(file.path(root, 'DESCRIPTION'))[1L, ]
  fields <- intersect(
    c('Depends', 'Imports', 'Suggests', 'LinkingTo'),
    names(metadata)
  )
  sources <- list.files(
    file.path(root, c('R', 'tests')),
    '\\.R$',
    recursive = TRUE,
    full.names = TRUE
  )
  code <- paste(unlist(lapply(sources, readLines)), collapse = '\n')
  stopifnot(
    !any(grepl('specmill', metadata[fields], fixed = TRUE)),
    !grepl(
      "specmill::|library\\(specmill\\)|requireNamespace\\(['\"]specmill",
      code
    )
  )
  before <- tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE))
  generate()
  after <- tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE))
  if (!identical(before, after)) {
    stop(
      'A second generation changed: ',
      paste(
        union(
          setdiff(names(after), names(before)),
          names(before)[
            before != after[names(before)] | is.na(after[names(before)])
          ]
        ),
        collapse = ', '
      )
    )
  }
  step('passed')
}

if (sys.nframe() == 0L) {
  offline_certification()
}
