schema_endpoint_changes_acceptance <- function() {
  fixtures <- if (dir.exists('tests/fixtures/amos-transition')) {
    'tests/fixtures/amos-transition'
  } else {
    'fixtures/amos-transition'
  }
  root <- tempfile('endpoint-changes-')
  dir.create(root)
  dir.create(file.path(root, 'R'))
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines(
    'request_helper <- function(...) list(...)',
    file.path(root, 'R/helper.R')
  )
  # The frozen production Swagger document has known validation defects.
  writeLines(
    c('config_version: 1', 'validation: false', 'services: [service.yml]'),
    file.path(root, 'specmill.yml')
  )
  writeLines(
    c(
      'id: amos',
      'schemas: {files: [amos.json]}',
      'helper: request_helper',
      'selection:',
      '  include:',
      '  - GET /api/amos/database_summary/',
      '  - GET /api/amos/get_fact_sheet_editor_info/{internal_id}',
      'names:',
      '  GET /api/amos/database_summary/: amos_summary',
      '  GET /api/amos/get_fact_sheet_editor_info/{internal_id}: amos_editor'
    ),
    file.path(root, 'service.yml')
  )
  active <- file.path(root, 'amos.json')
  file.copy(file.path(fixtures, 'production.json'), active)
  run <- function(mode) {
    specmill::generate_client(root, config = 'specmill.yml', mode = mode)
  }
  run('apply')
  manifest <- file.path(root, '.specmill/manifest.json')
  before <- readLines(manifest)
  source <- readLines(file.path(root, 'R/amos_editor.R'))
  file.copy(file.path(fixtures, 'development.json'), active, overwrite = TRUE)
  warnings <- character()
  checked <- withCallingHandlers(
    tryCatch(run('check'), error = identity),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart('muffleWarning')
    }
  )
  stopifnot(
    length(warnings) == 1L,
    grepl('Added endpoints (8; 8 not selected)', warnings, fixed = TRUE),
    grepl('GET /api/amos/version', warnings, fixed = TRUE),
    grepl('Removed endpoints (16)', warnings, fixed = TRUE),
    grepl(
      'GET /api/amos/get_fact_sheet_editor_info/{internal_id} -> amos_editor',
      warnings,
      fixed = TRUE
    ),
    grepl('Configured functions affected (1)', warnings, fixed = TRUE),
    inherits(checked, 'error'),
    identical(before, readLines(manifest)),
    identical(source, readLines(file.path(root, 'R/amos_editor.R')))
  )
  # Removing the obsolete mapping is a reviewed policy change, not deletion of client code.
  policy <- file.path(root, 'service.yml')
  lines <- readLines(policy)
  writeLines(
    lines[!grepl('get_fact_sheet_editor_info', lines, fixed = TRUE)],
    policy
  )
  plan <- run('plan')
  change <- plan$schema_changes[['amos.json']]
  stopifnot(
    length(change$added) == 8L,
    length(change$removed) == 16L,
    identical(change$affected_functions, 'amos_editor'),
    grepl(
      'Removed endpoints (16)',
      paste(capture.output(print(plan)), collapse = '\n'),
      fixed = TRUE
    )
  )
  run('apply')
  checked <- withCallingHandlers(run('check'), warning = function(w) {
    stop(conditionMessage(w))
  })
  stopifnot(
    length(checked$schema_changes) == 0L,
    all(vapply(checked$files, function(x) x$action == 'unchanged', logical(1))),
    identical(source, readLines(file.path(root, 'R/amos_editor.R')))
  )
  # An older manifest cannot establish an endpoint diff from its hash alone.
  legacy <- jsonlite::read_json(manifest)
  legacy$schema_inventory <- NULL
  jsonlite::write_json(legacy, manifest, auto_unbox = TRUE, pretty = TRUE)
  file.copy(file.path(fixtures, 'production.json'), active, overwrite = TRUE)
  warnings <- character()
  withCallingHandlers(
    tryCatch(run('check'), error = function(e) NULL),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart('muffleWarning')
    }
  )
  stopifnot(
    length(warnings) == 1L,
    grepl('Endpoint comparison unavailable', warnings, fixed = TRUE),
    !grepl('Added endpoints', warnings, fixed = TRUE)
  )
  cat(
    'AMOS endpoint changes: eight additions, sixteen removals, affected function names and read-only failure passed.\n'
  )
}
schema_endpoint_selection_acceptance <- function() {
  root <- tempfile('endpoint-selection-')
  dir.create(root)
  dir.create(file.path(root, 'R'))
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines(
    'request_helper <- function(...) list(...)',
    file.path(root, 'R/helper.R')
  )
  schema <- file.path(root, 'schema.yml')
  operation <- function(name) {
    list(operationId = name, responses = list('200' = list(description = 'OK')))
  }
  document <- list(
    swagger = '2.0',
    info = list(title = 'Selection', version = '1'),
    paths = list(
      '/items' = list(get = operation('items')),
      '/gone' = list(get = operation('gone'))
    )
  )
  yaml::write_yaml(document, schema)
  spec <- list(files = schema, helper = 'request_helper')
  run <- function(mode) {
    specmill::generate_client(root, spec, mode = mode, validation = FALSE)
  }
  run('apply')
  document$paths[['/gone']] <- NULL
  document$paths[['/items']]$post <- operation('create_items')
  yaml::write_yaml(document, schema)
  plan <- run('plan')
  change <- plan$schema_changes[['schema.yml']]
  stopifnot(
    identical(change$added, 'POST /items'),
    length(change$unselected) == 0L,
    identical(names(change$removed), 'GET /gone'),
    identical(change$affected_functions, 'gone')
  )
  warnings <- character()
  withCallingHandlers(
    tryCatch(run('check'), error = function(e) NULL),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart('muffleWarning')
    }
  )
  stopifnot(
    length(warnings) == 1L,
    grepl('Added endpoints (1; 0 not selected)', warnings, fixed = TRUE)
  )
  run('apply')
  withCallingHandlers(run('check'), warning = function(w) {
    stop(conditionMessage(w))
  })
  cat(
    'Endpoint selection: YAML, method identity, selected additions and default function names passed.\n'
  )
}
if (sys.nframe() == 0L) {
  schema_endpoint_changes_acceptance()
  schema_endpoint_selection_acceptance()
}
