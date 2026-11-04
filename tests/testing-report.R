# Regression for issue 261: testing_report() keeps verification layers apart,
# explains routes without recordings, maps supplied test results, and names
# the components that changed since a scenario was recorded.

testing_report_acceptance <- function() {
  workspace <- tempfile('testing-report-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  string <- list(type = 'string')
  item <- list(`$ref` = '#/components/schemas/Item')
  ok <- function(schema = item) {
    list(
      '200' = list(
        description = 'OK',
        content = list('application/json' = list(schema = schema))
      )
    )
  }
  path_id <- function(name = 'id', ...) {
    c(
      list(name = name, `in` = 'path', required = TRUE, schema = string),
      list(...)
    )
  }
  get <- function(id, parameters = list(), responses = ok()) {
    list(
      get = list(
        operationId = id,
        parameters = parameters,
        responses = responses
      )
    )
  }
  schema <- file.path(workspace, 'schema.json')
  full <- list(
    openapi = '3.0.3',
    info = list(title = 'Report', version = '1'),
    paths = list(
      '/items/{id}' = get('get_item', list(path_id(example = 'i-1'))),
      '/things/{id}' = get('get_thing', list(path_id())),
      '/notes' = get(
        'get_notes',
        responses = ok(list(type = 'array', items = string))
      ),
      '/codes/{code}' = get(
        'get_code',
        list(list(
          name = 'code',
          `in` = 'path',
          required = TRUE,
          schema = list(type = 'string', maxLength = 2L)
        )),
        ok(list(type = 'object'))
      ),
      '/contracted' = get(
        'get_contracted',
        responses = ok(list(type = 'object'))
      ),
      '/hidden' = get('get_hidden'),
      '/odd' = list(
        post = list(
          operationId = 'odd',
          requestBody = list(
            required = TRUE,
            content = list(
              'application/json' = list(
                schema = list(
                  oneOf = list(list(
                    type = 'string',
                    not = list(enum = list('blocked'))
                  ))
                )
              )
            )
          ),
          responses = ok()
        )
      ),
      '/items' = list(
        post = list(
          operationId = 'create_item',
          requestBody = list(
            required = TRUE,
            content = list('application/json' = list(schema = item))
          ),
          responses = ok()
        )
      )
    ),
    components = list(
      schemas = list(
        Item = list(type = 'object', properties = list(id = string)),
        Unrelated = list(type = 'object')
      )
    )
  )
  # Generation refuses selected operations it cannot support, so the
  # unsupported route joins the schema only after generating.
  generated <- full
  generated$paths[['/odd']] <- NULL
  jsonlite::write_json(generated, schema, auto_unbox = TRUE)
  root <- file.path(workspace, 'client')
  specmill::initialize_client(
    root,
    schema,
    package = 'reportclient',
    title = 'Report Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'http://127.0.0.1:1'
  )
  description <- read.dcf(file.path(root, 'DESCRIPTION'))
  description[1L, 'Imports'] <- paste(
    description[1L, 'Imports'],
    'yaml',
    sep = ', '
  )
  stopifnot(identical(
    unname(description[1L, 'Suggests']),
    'testthat, vcr (>= 2.0.0), withr, yaml'
  ))
  write.dcf(description, file.path(root, 'DESCRIPTION'))
  specmill::configure_hooks(root, mode = 'apply')
  hook_file <- file.path(root, 'R/hooks_report.R')
  writeLines('keep_item <- function(state) state$result', hook_file)
  writeLines(
    'get_item:\n  post_response: [keep_item]',
    file.path(root, 'inst/hooks.yml')
  )
  # A second API selects the same route under its own service identity.
  mirror_schema <- file.path(root, 'schema/mirror.json')
  file.copy(schema, mirror_schema)
  writeLines(
    c(
      'id: mirror',
      'schemas: {files: [schema/mirror.json]}',
      'helper: api_request',
      "selection: {include: ['GET /items/{id}']}",
      "names: {'GET /items/{id}': mirror_item}"
    ),
    file.path(root, 'apis/mirror.yml')
  )
  project_path <- file.path(root, 'specmill.yml')
  project <- yaml::read_yaml(project_path, handlers = list(seq = function(x) x))
  project$services <- c(as.list(project$services), list('apis/mirror.yml'))
  yaml::write_yaml(project, project_path)
  service_path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
  service$selection <- list(exclude = list('^/hidden$'))
  service$hook_callback <- 'run_hook'
  service$hook_config <- 'inst/hooks.yml'
  service$contracts <- list(
    get_contracted = list(
      inputs = list(),
      request = list(method = 'GET'),
      result = list()
    )
  )
  service$response_fixture <- list()
  service$testing <- list(
    file = 'tests/testthat/fixtures/testing.yml',
    gaps = list('POST /items' = list(reason = 'Write expectations pending')),
    unrecorded = list('GET /notes' = list(reason = 'Changes every minute'))
  )
  write_service <- function(x) yaml::write_yaml(x, service_path)
  write_service(service)
  dir.create(file.path(root, 'tests/testthat/fixtures'), recursive = TRUE)
  testing <- file.path(root, 'tests/testthat/fixtures/testing.yml')
  declarations <- function(checks = 'class: list') {
    c(
      'scenarios:',
      '  get_item:',
      "    operation: 'GET /items/{id}'",
      "    represents: ['GET /items/{id}', 'GET /things/{id}']",
      paste0('    checks: {', checks, '}'),
      "  get_code: {operation: 'GET /codes/{code}'}"
    )
  }
  writeLines(declarations(), testing)
  generate <- function() {
    specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = 'apply'
    )
  }
  suppressMessages(generate())
  client_schema <- file.path(root, 'schema/openapi.json')
  write_document <- function(x) {
    jsonlite::write_json(x, client_schema, auto_unbox = TRUE)
  }
  write_document(full)
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  report <- function(...) specmill::testing_report(root, ...)$services

  # Before recording: declarations and tests exist, nothing is recorded or run.
  before <- hashes()
  first <- report()
  stopifnot(identical(before, hashes()))
  stopifnot(identical(names(first), c('reportclient', 'mirror')))
  routes <- first$reportclient$routes
  row <- function(key) routes[routes$route == key, ]
  stopifnot(
    identical(row('GET /hidden')$selection, 'excluded'),
    identical(row('POST /odd')$support, 'unsupported'),
    identical(row('POST /odd')$no_cassette, 'no scenario'),
    identical(row('POST /items')$gap, 'Write expectations pending'),
    identical(row('GET /contracted')$contract, 'declared'),
    identical(row('GET /contracted')$contract_test, 'present'),
    identical(row('GET /things/{id}')$no_cassette, 'represented by get_item'),
    identical(
      row('GET /notes')$no_cassette,
      'unrecorded: Changes every minute'
    ),
    identical(row('GET /items/{id}')$no_cassette, 'not recorded yet'),
    startsWith(
      row('GET /codes/{code}')$no_cassette,
      'blocked: missing example for code'
    ),
    identical(first$reportclient$scenarios$get_item$review, 'record'),
    identical(first$reportclient$scenarios$get_code$review, 'resolve inputs'),
    isTRUE(first$reportclient$scenarios$get_item$test_current),
    identical(first$reportclient$scenarios$get_item$execution, 'not run'),
    first$reportclient$summary$schema_operations == 8L,
    first$reportclient$summary$selected == 7L,
    first$reportclient$summary$selected_unsupported == 1L,
    first$reportclient$summary$routes_replayed == 0L,
    first$reportclient$summary$tests_passed == 0L,
    # Overlapping routes stay with their own service.
    identical(
      first$mirror$routes$route[first$mirror$routes$selection == 'selected'],
      'GET /items/{id}'
    ),
    all(is.na(first$mirror$routes$replay))
  )

  # Simulate a recording: the cassette plus the digests the test embeds.
  test_file <- file.path(
    root,
    'tests/testthat/test-scenario-reportclient-get_item.R'
  )
  embedded <- specmill:::provenance_embedded(test_file)
  stopifnot(identical(
    names(embedded),
    c('schema', 'policy', 'helper', 'hooks', 'expectation')
  ))
  recordings <- file.path(root, 'tests/testthat/_vcr/reportclient')
  dir.create(recordings, recursive = TRUE)
  writeLines('http_interactions: []', file.path(recordings, 'get_item.yml'))
  provenance <- file.path(recordings, 'get_item.provenance')
  writeLines(paste0(names(embedded), ': ', embedded), provenance)
  results <- data.frame(
    file = c('test-scenario-reportclient-get_item.R', 'test-get_contracted.R'),
    failed = c(0L, 1L),
    error = c(FALSE, FALSE),
    skipped = c(FALSE, FALSE)
  )
  recorded <- report(results = results)$reportclient
  stopifnot(
    identical(recorded$scenarios$get_item$provenance, 'current'),
    identical(recorded$scenarios$get_item$review, 'none'),
    identical(recorded$scenarios$get_item$execution, 'passed'),
    identical(recorded$contracts[['GET /contracted']]$execution, 'failed'),
    is.na(recorded$routes$no_cassette[
      recorded$routes$route == 'GET /items/{id}'
    ]),
    recorded$summary$routes_recorded == 1L,
    recorded$summary$routes_replayed == 1L,
    recorded$summary$tests_failed == 1L
  )

  changed <- function() report()$reportclient$scenarios$get_item
  # An unrelated component does not affect the scenario.
  document <- full
  document$components$schemas$Unrelated$properties <- list(x = string)
  write_document(document)
  stopifnot(identical(changed()$provenance, 'current'))
  # A referenced component does.
  document$components$schemas$Item$properties$name <- string
  write_document(document)
  stopifnot(
    identical(changed()$changed, 'schema'),
    identical(changed()$review, 'review changes')
  )
  write_document(full)
  # A hook function edit, before regeneration, marks the test stale too.
  writeLines('keep_item <- function(state) { state$result }', hook_file)
  after <- changed()
  stopifnot(
    identical(after$changed, 'hooks'),
    identical(after$test_current, FALSE)
  )
  writeLines('keep_item <- function(state) state$result', hook_file)
  # Policy and expectation changes.
  policy <- service
  policy$operations <- list(
    'GET /items/{id}' = list(request_controls = list(timeout = 5L))
  )
  write_service(policy)
  stopifnot(identical(changed()$changed, 'policy'))
  write_service(service)
  writeLines(declarations('class: list, rows: 1'), testing)
  stopifnot(identical(changed()$changed, 'expectation'))
  writeLines(declarations(), testing)
  stopifnot(identical(changed()$provenance, 'current'))
  # A recording without provenance is flagged for review, not trusted.
  file.remove(provenance)
  stopifnot(
    identical(changed()$provenance, 'unknown'),
    identical(changed()$review, 'review changes')
  )
}

if (sys.nframe() == 0L) {
  testing_report_acceptance()
}
