# Regression for issue 258: a generated cassette scenario records a reviewed
# localhost response once, then replays it offline through the real wrapper
# and request helper of an installed client.

scenario_replay_acceptance <- function() {
  for (package in c('vcr', 'withr', 'testthat', 'httpuv', 'callr')) {
    if (!requireNamespace(package, quietly = TRUE)) {
      message('Skipping cassette scenario test: ', package, ' is not installed')
      return(invisible())
    }
  }
  secret <- 'S3cr+t/Key=1 x'
  header_secret <- 'H3ader/Key+=2'
  # An ordinary argument bound to an environment variable, echoed back by the
  # API like AQS does, must stay out of recordings too.
  email_secret <- 'reviewer.person+aqs@example.org'
  port_file <- tempfile('http-port-')
  count_file <- tempfile('http-count-')
  server <- callr::r_bg(
    function(port_file, count_file, secret, header_secret, email_secret) {
      decode <- function(x) utils::URLdecode(gsub('+', ' ', x, fixed = TRUE))
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(request) {
          cat('.', file = count_file, append = TRUE)
          json <- function(x) {
            list(
              status = 200L,
              headers = list('Content-Type' = 'application/json'),
              body = jsonlite::toJSON(x, auto_unbox = TRUE)
            )
          }
          denied <- list(
            status = 401L,
            headers = list('Content-Type' = 'application/json'),
            body = '{}'
          )
          if (request$REQUEST_METHOD == 'POST') {
            return(list(
              status = 201L,
              headers = list('Content-Type' = 'application/json'),
              body = '{"id":"new-1","owner":"bob@corp.example"}'
            ))
          }
          if (startsWith(request$PATH_INFO, '/header-items/')) {
            if (!identical(request$HTTP_X_API_KEY, header_secret)) {
              return(denied)
            }
            return(json(list(
              id = sub('^/header-items/', '', request$PATH_INFO)
            )))
          }
          pairs <- strsplit(
            strsplit(sub('^\\?', '', request$QUERY_STRING), '&')[[1L]],
            '='
          )
          query <- stats::setNames(
            lapply(pairs, function(x) decode(paste(x[-1L], collapse = '='))),
            vapply(pairs, `[[`, character(1), 1L)
          )
          if (
            !identical(query$access_key, secret) ||
              (startsWith(request$PATH_INFO, '/items/') &&
                !identical(query$email, email_secret))
          ) {
            return(list(
              status = 401L,
              headers = list('Content-Type' = 'application/json'),
              body = '{}'
            ))
          }
          # Synthetic markers that recording filters must keep out of fixtures.
          list(
            status = 200L,
            headers = list(
              'Content-Type' = 'application/json',
              'Set-Cookie' = 'session=COOKIE-MARKER-9; Path=/',
              'X-Internal-Host' = 'db.internal.corp'
            ),
            body = jsonlite::toJSON(
              list(
                id = sub('^/items/', '', request$PATH_INFO),
                title = paste('Item in', query$language),
                tags = list('a', 'b'),
                owner = 'alice@corp.example',
                echo = paste0('/items?email=', query$email),
                link = 'https://intranet.corp.example/items/1'
              ),
              auto_unbox = TRUE
            )
          )
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(
      port_file = port_file,
      count_file = count_file,
      secret = secret,
      header_secret = header_secret,
      email_secret = email_secret
    ),
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
  requests <- function() {
    if (file.exists(count_file)) {
      nchar(readLines(count_file, warn = FALSE))
    } else {
      0L
    }
  }

  workspace <- tempfile('scenario-replay-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  schema <- file.path(workspace, 'schema.json')
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Replay', version = '1'),
      security = list(list(key = list())),
      components = list(
        securitySchemes = list(
          key = list(type = 'apiKey', name = 'access_key', 'in' = 'query'),
          hkey = list(type = 'apiKey', name = 'x-api-key', 'in' = 'header')
        )
      ),
      paths = list(
        '/header-items/{item_id}' = list(
          get = list(
            operationId = 'get_header_item',
            security = list(list(hkey = list())),
            parameters = list(list(
              name = 'item_id',
              'in' = 'path',
              required = TRUE,
              schema = list(type = 'string')
            )),
            responses = list('200' = list(description = 'Item'))
          )
        ),
        '/items' = list(
          post = list(
            operationId = 'create_item',
            requestBody = list(
              required = TRUE,
              content = list(
                'application/json' = list(
                  schema = list(
                    type = 'object',
                    properties = list(title = list(type = 'string'))
                  )
                )
              )
            ),
            responses = list('201' = list(description = 'Created'))
          )
        ),
        '/items/{item_id}' = list(
          get = list(
            operationId = 'get_item',
            parameters = list(
              list(
                name = 'item_id',
                'in' = 'path',
                required = TRUE,
                schema = list(type = 'string')
              ),
              list(
                name = 'language',
                'in' = 'query',
                schema = list(type = 'string', enum = list('en', 'fr'))
              ),
              list(
                name = 'email',
                'in' = 'query',
                required = TRUE,
                schema = list(type = 'string')
              )
            ),
            responses = list('200' = list(description = 'Item'))
          )
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  root <- file.path(workspace, 'client')
  specmill::initialize_client(
    root,
    schema,
    package = 'replayclient',
    title = 'Replay Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = paste0('http://127.0.0.1:', readLines(port_file))
  )
  credentials <- specmill::load_project(root)$authentication
  stopifnot(
    identical(credentials[['key']], 'REPLAYCLIENT_KEY'),
    identical(credentials[['hkey']], 'REPLAYCLIENT_HKEY')
  )
  fixtures <- file.path(root, 'tests/testthat/fixtures')
  dir.create(fixtures, recursive = TRUE)
  scenarios <- function(language = 'en') {
    writeLines(
      c(
        'scenarios:',
        '  get_item_basic:',
        "    operation: GET /items/{item_id}",
        paste0('    inputs: {item_id: item-1, language: ', language, '}'),
        '    checks:',
        '      class: list',
        '      values: [{path: [id], equals: item-1}, {path: [tags, 2], equals: b}]',
        '  header_item_basic:',
        "    operation: GET /header-items/{item_id}",
        '    inputs: {item_id: h-1}',
        '    checks: {values: [{path: [id], equals: h-1}]}'
      ),
      file.path(fixtures, 'testing.yml')
    )
  }
  scenarios()
  # The email comes from REPLAYCLIENT_EMAIL; no scenario or example names it.
  policy_lines <- readLines(file.path(root, 'apis/default.yml'))
  writeLines(
    sub(
      '^operations: \\{\\}$',
      "operations:\n  'GET /items/{item_id}':\n    parameters: {query email: {env: REPLAYCLIENT_EMAIL}}",
      policy_lines
    ),
    file.path(root, 'apis/default.yml')
  )
  cat(
    paste0(
      "testing:\n",
      "  file: tests/testthat/fixtures/testing.yml\n",
      "  filter:\n",
      "    response_headers: [X-Internal-Host]\n",
      "    patterns:\n",
      "      '<<EMAIL>>': '[a-z]+@corp\\.example'\n",
      "      '<<PRIVATE_URL>>': 'https://intranet\\.corp\\.example[^\"]*'\n"
    ),
    file = file.path(root, 'apis/default.yml'),
    append = TRUE
  )
  generate <- function(mode = 'apply') {
    specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = mode
    )
  }

  # Test dependencies are reported, never added to the client DESCRIPTION.
  stopifnot(identical(
    unname(read.dcf(file.path(root, 'DESCRIPTION'))[1L, 'Suggests']),
    'testthat, vcr (>= 2.0.0), withr, yaml'
  ))
  description <- read.dcf(file.path(root, 'DESCRIPTION'))
  description[1L, 'Suggests'] <- 'testthat'
  write.dcf(description, file.path(root, 'DESCRIPTION'))
  missing <- tryCatch(generate(), error = conditionMessage)
  stopifnot(
    grepl('Declared tests need these packages', missing, fixed = TRUE),
    endsWith(missing, ': vcr, withr, yaml')
  )
  description <- read.dcf(file.path(root, 'DESCRIPTION'))
  description[1L, 'Suggests'] <- paste(
    description[1L, 'Suggests'],
    'vcr, withr, yaml',
    sep = ', '
  )
  write.dcf(description, file.path(root, 'DESCRIPTION'))
  generate()
  test_file <- file.path(
    root,
    'tests/testthat/test-scenario-replayclient-get_item_basic.R'
  )
  helper_file <- file.path(root, 'tests/testthat/helper-scenario-replay.R')
  runner_file <- file.path(root, 'tests/testthat.R')
  stopifnot(
    file.exists(test_file),
    file.exists(helper_file),
    file.exists(runner_file)
  )
  generated <- paste(readLines(test_file), collapse = '\n')
  # Bound the way client tooling binds it, outside the specmill namespace.
  context <- new.env(parent = globalenv())
  specmill::bind_tools('test_validation', context)
  specmill::bind_tools('test_helpers', context)
  context$tg_config <- list(
    generated_header = '# Generated with specmill; do not edit by hand.',
    legacy_metadata_header = '# legacy generated'
  )
  stopifnot(
    context$tg_validate_generated_text(generated)$valid,
    !context$tg_validate_generated_text(sub(
      'replay_cassette(',
      'testthat::local_mocked_bindings(replayclient_request = identity); replay_cassette(',
      generated,
      fixed = TRUE
    ))$valid,
    !grepl('specmill::', generated, fixed = TRUE),
    !grepl(
      'specmill::',
      paste(readLines(helper_file), collapse = '\n'),
      fixed = TRUE
    ),
    !grepl(
      'specmill',
      read.dcf(file.path(root, 'DESCRIPTION'))[1L, 'Suggests'],
      fixed = TRUE
    )
  )

  library <- tempfile('replay-library-')
  dir.create(library)
  install_log <- tempfile('replay-install-')
  status <- system2(
    file.path(R.home('bin'), 'R'),
    c('CMD', 'INSTALL', paste0('--library=', shQuote(library)), shQuote(root)),
    stdout = install_log,
    stderr = install_log
  )
  if (status != 0L) {
    stop(paste(readLines(install_log), collapse = '\n'))
  }
  run_tests <- function(env) {
    callr::r(
      function(root) {
        result <- tryCatch(
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
        list(
          result = result,
          specmill_loaded = 'specmill' %in% loadedNamespaces()
        )
      },
      list(root = root),
      libpath = c(library, .libPaths()),
      # CI is cleared unless a case sets it, so recording works under CI.
      env = c(
        callr::rcmd_safe_env(),
        local({
          vars <- c(CI = 'false')
          vars[names(env)] <- env
          vars
        })
      )
    )
  }
  cassette <- file.path(
    root,
    'tests/testthat/_vcr/replayclient/get_item_basic.yml'
  )
  signature <- file.path(
    root,
    'tests/testthat/_signatures/replayclient/get_item_basic.yml'
  )

  # Routine runs never record: without a cassette the test fails offline.
  before <- requests()
  routine <- run_tests(c(
    REPLAYCLIENT_KEY = secret,
    REPLAYCLIENT_HKEY = header_secret
  ))
  stopifnot(
    startsWith(routine$result, 'failed'),
    requests() == before,
    !file.exists(cassette)
  )

  # CI never records, even when a scenario is listed.
  ci <- run_tests(c(
    CI = 'true',
    REPLAYCLIENT_KEY = secret,
    REPLAYCLIENT_RECORD = 'replayclient/get_item_basic'
  ))
  stopifnot(
    startsWith(ci$result, 'failed'),
    requests() == before,
    !file.exists(cassette)
  )

  # Explicit recording writes the cassette and signature without the secret.
  recorded <- run_tests(c(
    REPLAYCLIENT_KEY = secret,
    REPLAYCLIENT_HKEY = header_secret,
    REPLAYCLIENT_EMAIL = email_secret,
    REPLAYCLIENT_RECORD = 'replayclient/get_item_basic, replayclient/header_item_basic'
  ))
  stopifnot(identical(recorded$result, 'passed'), requests() == before + 2L)
  stopifnot(file.exists(cassette), file.exists(signature))
  recordings <- file.path(root, 'tests/testthat/_vcr/replayclient')
  text <- paste(
    unlist(lapply(list.files(recordings, full.names = TRUE), readLines)),
    collapse = '\n'
  )
  for (form in c(
    secret,
    'S3cr',
    'Key%3D1',
    'Key=1',
    '%2FKey',
    header_secret,
    'H3ader',
    'COOKIE-MARKER',
    email_secret,
    'reviewer.person',
    'Set-Cookie',
    'db.internal.corp',
    'alice@corp.example',
    'intranet.corp.example'
  )) {
    if (grepl(form, text, fixed = TRUE)) {
      stop('Secret reached a recording: ', form)
    }
  }
  stopifnot(
    grepl('<<EMAIL>>', text, fixed = TRUE),
    grepl('<<PRIVATE_URL>>', text, fixed = TRUE)
  )
  # A clean recording keeps digests of what it depends on, never values.
  provenance <- readLines(file.path(recordings, 'get_item_basic.provenance'))
  stopifnot(
    identical(
      sub(':.*', '', provenance),
      c('schema', 'policy', 'helper', 'hooks', 'expectation')
    ),
    all(grepl('^[a-z]+: [0-9a-f]{16}$', provenance))
  )
  # Only credential names are kept, so header credentials can be replayed.
  stopifnot(identical(
    readLines(file.path(recordings, 'header_item_basic.credentials')),
    c('REPLAYCLIENT_EMAIL', 'REPLAYCLIENT_HKEY', 'REPLAYCLIENT_KEY')
  ))
  # Query filtering writes the placeholder URL-encoded.
  stopifnot(grepl('%3C%3CREPLAYCLIENT_KEY%3E%3E', text, fixed = TRUE))
  saved <- yaml::read_yaml(signature)
  stopifnot(
    identical(saved$class, 'list'),
    identical(saved$elements$tags$item$class, 'character')
  )

  # Replay passes offline with no credential, no recording, and no specmill.
  before <- requests()
  replayed <- run_tests(c(
    REPLAYCLIENT_KEY = '',
    REPLAYCLIENT_HKEY = '',
    REPLAYCLIENT_RECORD = ''
  ))
  stopifnot(
    identical(replayed$result, 'passed'),
    !replayed$specmill_loaded,
    requests() == before
  )

  # Listing an already recorded scenario replays it and keeps its signature.
  signature_hash <- tools::md5sum(signature)
  relisted <- run_tests(c(
    REPLAYCLIENT_KEY = secret,
    REPLAYCLIENT_EMAIL = email_secret,
    REPLAYCLIENT_RECORD = 'replayclient/get_item_basic'
  ))
  stopifnot(
    identical(relisted$result, 'passed'),
    identical(signature_hash, tools::md5sum(signature)),
    requests() == before
  )

  # A different request does not match the recording and contacts nothing.
  scenarios('fr')
  generate()
  changed <- run_tests(c(REPLAYCLIENT_KEY = ''))
  stopifnot(startsWith(changed$result, 'failed'), requests() == before)
  scenarios()
  generate()

  # A changed or missing signature fails replay.
  writeLines(
    sub('class: list', 'class: data.frame', readLines(signature)),
    signature
  )
  stopifnot(startsWith(run_tests(c(REPLAYCLIENT_KEY = ''))$result, 'failed'))
  file.remove(signature)
  stopifnot(startsWith(run_tests(c(REPLAYCLIENT_KEY = ''))$result, 'failed'))
  writeLines(c('# restored', yaml::as.yaml(saved)), signature)
  stopifnot(identical(run_tests(c(REPLAYCLIENT_KEY = ''))$result, 'passed'))

  # A second generation changes nothing.
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  generate('check')
  current <- hashes()
  generate()
  stopifnot(identical(current, hashes()))

  # Removing the declaration removes the owned scenario test and helper; the
  # runner and the reviewed recording stay.
  writeLines('scenarios: {}', file.path(fixtures, 'testing.yml'))
  generate()
  stopifnot(
    !file.exists(test_file),
    !file.exists(helper_file),
    file.exists(runner_file),
    file.exists(cassette)
  )

  # Recording a state-changing scenario is refused until approval exists.
  writeLines(
    c(
      'scenarios:',
      '  create_basic:',
      '    operation: POST /items',
      '    inputs: {body: {title: x}}',
      '    match: [method, uri, body_json]'
    ),
    file.path(fixtures, 'testing.yml')
  )
  generate()
  before <- requests()
  refused <- run_tests(c(
    REPLAYCLIENT_KEY = secret,
    REPLAYCLIENT_RECORD = 'replayclient/create_basic'
  ))
  stopifnot(
    startsWith(refused$result, 'failed'),
    requests() == before,
    !file.exists(file.path(
      root,
      'tests/testthat/_vcr/replayclient/create_basic.yml'
    ))
  )

  # An approved write records once, keeps filtered values out, and replays.
  writeLines(
    c(
      'scenarios:',
      '  create_basic:',
      '    operation: POST /items',
      '    inputs: {body: {title: x}}',
      '    match: [method, uri, body_json]',
      '    record_write: {reason: Localhost fixture accepts writes}'
    ),
    file.path(fixtures, 'testing.yml')
  )
  generate()
  approved <- run_tests(c(
    REPLAYCLIENT_KEY = secret,
    REPLAYCLIENT_RECORD = 'replayclient/create_basic'
  ))
  write_cassette <- file.path(
    root,
    'tests/testthat/_vcr/replayclient/create_basic.yml'
  )
  stopifnot(
    identical(approved$result, 'passed'),
    requests() == before + 1L,
    file.exists(write_cassette)
  )
  written <- paste(readLines(write_cassette), collapse = '\n')
  stopifnot(
    grepl('{"title":"x"}', written, fixed = TRUE),
    !grepl('bob@corp.example', written, fixed = TRUE)
  )
  before <- requests()
  stopifnot(
    identical(run_tests(c(REPLAYCLIENT_KEY = ''))$result, 'passed'),
    requests() == before
  )

  # A recording the scan rejects is deleted with its credential list and
  # signature, and the run fails: this pattern rewrites the request URI.
  policy_file <- file.path(root, 'apis/default.yml')
  policy <- readLines(policy_file)
  writeLines(c(policy, "      '<<ITEM9>>': 'item-9'"), policy_file)
  writeLines(
    c(
      'scenarios:',
      '  scan_basic:',
      "    operation: GET /items/{item_id}",
      '    inputs: {item_id: item-9, language: en}'
    ),
    file.path(fixtures, 'testing.yml')
  )
  generate()
  before <- requests()
  scanned <- run_tests(c(
    REPLAYCLIENT_KEY = secret,
    REPLAYCLIENT_EMAIL = email_secret,
    REPLAYCLIENT_RECORD = 'replayclient/scan_basic'
  ))
  stopifnot(
    startsWith(scanned$result, 'failed'),
    requests() == before + 1L,
    !file.exists(file.path(recordings, 'scan_basic.yml')),
    !file.exists(file.path(recordings, 'scan_basic.credentials')),
    !file.exists(file.path(
      root,
      'tests/testthat/_signatures/replayclient/scan_basic.yml'
    ))
  )
  # Filter placeholders cannot reuse a credential placeholder.
  writeLines(c(policy, "      '<<REPLAYCLIENT_KEY>>': 'zzz'"), policy_file)
  stopifnot(grepl(
    'testing filter placeholders must differ from credential names',
    tryCatch(generate(), error = conditionMessage),
    fixed = TRUE
  ))
  writeLines(policy, policy_file)

  # A recording whose test fails (here on a 401) keeps nothing.
  writeLines(
    c(
      'scenarios:',
      '  denied:',
      "    operation: GET /items/{item_id}",
      '    inputs: {item_id: item-7, language: en}'
    ),
    file.path(fixtures, 'testing.yml')
  )
  generate()
  before <- requests()
  denied <- run_tests(c(
    REPLAYCLIENT_KEY = 'wrong-key',
    REPLAYCLIENT_EMAIL = email_secret,
    REPLAYCLIENT_RECORD = 'replayclient/denied'
  ))
  stopifnot(
    startsWith(denied$result, 'failed'),
    requests() == before + 1L,
    !any(file.exists(file.path(
      recordings,
      c('denied.yml', 'denied.credentials', 'denied.provenance')
    )))
  )

  # The record variable and credentials cannot be set through environment.
  writeLines(
    c(
      'scenarios:',
      '  get_item_basic:',
      "    operation: GET /items/{item_id}",
      '    inputs: {item_id: item-1}',
      '    environment: {REPLAYCLIENT_RECORD: replayclient/get_item_basic}'
    ),
    file.path(fixtures, 'testing.yml')
  )
  stopifnot(grepl(
    'environment must not set credential or record variables',
    tryCatch(generate(), error = conditionMessage),
    fixed = TRUE
  ))

  # A scenario whose operation is deferred keeps its existing test, whether
  # it names the wrapper or the route.
  held <- file.path(workspace, 'held')
  dir.create(file.path(held, 'tests/testthat'), recursive = TRUE)
  writeLines(
    c(
      'Package: heldclient',
      'Imports: httr2, jsonlite',
      'Suggests: testthat, vcr, withr, yaml'
    ),
    file.path(held, 'DESCRIPTION')
  )
  old <- c('by_name', 'by_route')
  for (id in old) {
    writeLines(
      paste('# existing', id),
      file.path(held, 'tests/testthat', paste0('test-scenario-svc-', id, '.R'))
    )
  }
  writeLines(
    '# existing chain',
    file.path(held, 'tests/testthat/test-hook-case-svc-chain.R')
  )
  writeLines(
    '# existing wiring',
    file.path(held, 'tests/testthat/test-hook-integration-svc-wiring.R')
  )
  service <- list(
    id = 'svc',
    package = 'heldclient',
    testing = list(
      file = 'tests/testthat/fixtures/testing.yml',
      match = c('method', 'uri'),
      gaps = list(),
      unrecorded = list(),
      scenarios = list(
        by_name = list(operation = 'get_x', inputs = list()),
        by_route = list(operation = 'GET /x', inputs = list())
      ),
      hook_cases = list(
        chain = list(
          chain = 'get_x',
          stage = 'pre_request',
          state = list(),
          expect = list(state = list())
        )
      ),
      hook_integrations = list(
        wiring = list(
          operation = 'GET /x',
          inputs = list(),
          calls = list(),
          result = 1L
        )
      )
    )
  )
  outputs <- specmill:::replay_outputs(
    held,
    list(service),
    list(list(
      inventory = list(list(
        id = 'svc GET /x',
        key = 'GET /x',
        status = 'selected'
      ))
    )),
    list(),
    list(),
    NULL,
    'get_x',
    'svc GET /x',
    list()
  )
  stopifnot(
    identical(
      unname(unlist(outputs$files[paste0(
        'tests/testthat/test-scenario-svc-',
        old,
        '.R'
      )])),
      paste('# existing', old)
    ),
    'tests/testthat/helper-scenario-replay.R' %in% names(outputs$files),
    # Held hook declarations keep their tests too.
    identical(
      outputs$files[['tests/testthat/test-hook-case-svc-chain.R']],
      '# existing chain'
    ),
    identical(
      outputs$files[['tests/testthat/test-hook-integration-svc-wiring.R']],
      '# existing wiring'
    ),
    identical(
      outputs$owners[['tests/testthat/test-hook-case-svc-chain.R']],
      'specmill hook case svc/chain'
    )
  )
  # A client without credentials gets empty credential lists and can replay.
  helper <- outputs$files[['tests/testthat/helper-scenario-replay.R']]
  stopifnot(
    grepl('replay_credentials <- character()\n', helper, fixed = TRUE),
    grepl('replay_query_credentials <- character()\n', helper, fixed = TRUE)
  )
  helpers <- new.env()
  eval(parse(text = helper), helpers)
  dir.create(file.path(held, 'tests/testthat/_vcr/svc'), recursive = TRUE)
  writeLines(
    c('http_interactions: []', 'recorded_with: VCR-vcr/2.1.0'),
    file.path(held, 'tests/testthat/_vcr/svc/by_name.yml')
  )
  withr::with_dir(held, {
    local({
      helpers$replay_cassette('svc', 'by_name', c('method', 'uri'))
      invisible()
    })
    # Replay without a recording names the record variable.
    missing <- tryCatch(
      local(helpers$replay_cassette('svc', 'by_route', c('method', 'uri'))),
      error = conditionMessage
    )
    stopifnot(identical(
      missing,
      'No recording for svc/by_route; list it in HELDCLIENT_RECORD to record it on purpose'
    ))
  })

  # The post-recording scan deletes a recording that redaction missed.
  scan <- function(uri, body, header = 'Content-Type: text/plain') {
    files <- file.path(workspace, c('scan.yml', 'scan.credentials'))
    writeLines(
      c(
        'http_interactions:',
        '- request:',
        '    method: GET',
        paste0('    uri: ', uri),
        '  response:',
        '    status: 200',
        '    headers:',
        paste0('      ', header),
        '    body:',
        paste0("      string: '", body, "'")
      ),
      files[[1L]]
    )
    writeLines('HELD_KEY', files[[2L]])
    message <- tryCatch(
      {
        helpers$replay_scan(
          'svc',
          'scan',
          files,
          'LEAK-123',
          c('<<EMAIL>>' = '[a-z]+@corp[.]example'),
          'Set-Cookie'
        )
        'clean'
      },
      error = conditionMessage
    )
    list(message = message, kept = file.exists(files))
  }
  # A recording counts only once its signature was written.
  unsigned <- scan('http://127.0.0.1/x', 'owner <<EMAIL>>')
  stopifnot(
    grepl('did not complete and was deleted', unsigned$message, fixed = TRUE),
    !any(unsigned$kept)
  )
  helpers$replay_signed[['svc/scan']] <- TRUE
  raw_scan <- function(body) {
    writeLines(
      c(
        'http_interactions:',
        '- request:',
        '    method: POST',
        '    uri: http://127.0.0.1/x',
        '    body:',
        paste0(
          '      base64_string: ',
          jsonlite::base64_enc(as.raw(c(0xff, 0xfe)))
        ),
        '  response:',
        '    status: 200',
        '    body:',
        paste0('      ', body)
      ),
      raw_files[[1L]]
    )
    writeLines('HELD_KEY', raw_files[[2L]])
    message <- tryCatch(
      {
        helpers$replay_scan(
          'svc',
          'scan',
          raw_files,
          'LEAK-123',
          character(),
          'Set-Cookie'
        )
        'clean'
      },
      error = conditionMessage
    )
    list(message = message, kept = file.exists(raw_files))
  }
  raw_files <- file.path(workspace, c('scan.yml', 'scan.credentials'))
  # Both sides are decoded; a non-UTF-8 body cannot hide a credential.
  latin1 <- raw_scan(paste0(
    'base64_string: ',
    jsonlite::base64_enc(c(as.raw(c(0xe9, 0x00)), charToRaw(' key=LEAK-123')))
  ))
  stopifnot(
    grepl('a credential value', latin1$message, fixed = TRUE),
    !any(latin1$kept)
  )
  garbled <- raw_scan('raw_gzip: bm90IGd6aXA=')
  stopifnot(
    grepl('a body that could not be decoded', garbled$message, fixed = TRUE),
    !any(garbled$kept)
  )
  # A body vcr kept as base64 (no content type, binary or gzip) is not filtered
  # by vcr, so the scan decodes it.
  raw_files <- file.path(workspace, c('scan.yml', 'scan.credentials'))
  gz <- jsonlite::base64_enc(memCompress(
    charToRaw('echo key=LEAK-123'),
    type = 'gzip'
  ))
  writeLines(
    c(
      'http_interactions:',
      '- request:',
      '    method: GET',
      '    uri: http://127.0.0.1/x',
      '  response:',
      '    status: 200',
      '    body:',
      paste0('      raw_gzip: ', gz)
    ),
    raw_files[[1L]]
  )
  writeLines('HELD_KEY', raw_files[[2L]])
  raw_hit <- tryCatch(
    {
      helpers$replay_scan(
        'svc',
        'scan',
        raw_files,
        'LEAK-123',
        character(),
        'Set-Cookie'
      )
      'clean'
    },
    error = conditionMessage
  )
  stopifnot(
    grepl('a credential value', raw_hit, fixed = TRUE),
    !any(file.exists(raw_files))
  )
  clean <- scan('http://127.0.0.1/x', 'owner <<EMAIL>>')
  stopifnot(identical(clean$message, 'clean'), all(clean$kept))
  # A recording that never wrote a cassette leaves no credential list behind.
  leftover <- file.path(workspace, c('none.yml', 'none.credentials'))
  writeLines('HELD_KEY', leftover[[2L]])
  helpers$replay_scan(
    'svc',
    'none',
    leftover,
    character(),
    character(),
    'Set-Cookie'
  )
  stopifnot(!any(file.exists(leftover)))
  for (case in list(
    list('http://127.0.0.1/x?k=LEAK-123', 'ok', 'a credential value'),
    list(
      'http://127.0.0.1/x',
      'owner a@corp.example',
      'a value matching a filter pattern'
    ),
    list(
      'http://127.0.0.1/x?o=<<EMAIL>>',
      'ok',
      'a filter placeholder in its request'
    ),
    list(
      'http://127.0.0.1/x',
      'ok',
      'a response header that should have been dropped',
      'set-cookie: s=1'
    )
  )) {
    hit <- scan(
      case[[1L]],
      case[[2L]],
      if (length(case) > 3L) case[[4L]] else 'Content-Type: text/plain'
    )
    stopifnot(grepl(case[[3L]], hit$message, fixed = TRUE), !any(hit$kept))
  }
}

if (sys.nframe() == 0L) {
  scenario_replay_acceptance()
}
