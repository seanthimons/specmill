schema_change_warning_acceptance <- function() {
  root <- tempfile('schema-change-warning-')
  dir.create(root)
  dir.create(file.path(root, 'R'))
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  schema <- file.path(root, 'schema.json')
  file.copy(system.file('catalogue/schema.json', package = 'specmill'), schema)
  writeLines(
    'request_helper <- function(...) list(...)',
    file.path(root, 'R/helper.R')
  )
  writeLines(
    c('config_version: 1', 'validation: false', 'services: [service.yml]'),
    file.path(root, 'specmill.yml')
  )
  writeLines(
    c(
      'id: catalogue',
      'schemas: {files: [schema.json]}',
      'helper: request_helper',
      'defaults: {file: R/generated.R}'
    ),
    file.path(root, 'service.yml')
  )
  run <- function(mode) {
    specmill::generate_client(root, config = 'specmill.yml', mode = mode)
  }
  observe <- function() {
    warnings <- character()
    result <- withCallingHandlers(
      tryCatch(run('check'), error = identity),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart('muffleWarning')
      }
    )
    list(result = result, warnings = warnings)
  }
  run('apply')
  stopifnot(length(observe()$warnings) == 0L)
  manifest <- file.path(root, '.specmill/manifest.json')
  before <- readLines(manifest)
  source_before <- readLines(file.path(root, 'R/generated.R'))
  document <- jsonlite::read_json(schema)
  document$paths[['/items']]$get$parameters[[1L]]$schema$default <- 2L
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  checked <- observe()
  stopifnot(
    length(checked$warnings) == 1L,
    grepl(
      'Schema changed since last apply: schema.json',
      checked$warnings,
      fixed = TRUE
    ),
    grepl('Previous SHA-256:', checked$warnings, fixed = TRUE),
    grepl('Current SHA-256:', checked$warnings, fixed = TRUE),
    inherits(checked$result, 'error'),
    grepl('R/generated.R', conditionMessage(checked$result), fixed = TRUE),
    identical(before, readLines(manifest)),
    identical(source_before, readLines(file.path(root, 'R/generated.R')))
  )
  run('apply')
  checked <- observe()
  stopifnot(!inherits(checked$result, 'error'), length(checked$warnings) == 0L)
  # Metadata can change without changing generated functions.
  source_before <- readLines(file.path(root, 'R/generated.R'))
  document$info$version <- '2'
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  checked <- observe()
  stopifnot(
    length(checked$warnings) == 1L,
    inherits(checked$result, 'error'),
    !grepl('R/generated.R', conditionMessage(checked$result), fixed = TRUE),
    identical(source_before, readLines(file.path(root, 'R/generated.R')))
  )
  run('apply')
  stopifnot(length(observe()$warnings) == 0L)
  # A changed schema is reported even when an operation cannot be translated.
  document$paths[['/items']]$get$parameters[[1L]]$schema$type <- 'unknown'
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  checked <- observe()
  stopifnot(
    length(checked$warnings) == 1L,
    grepl(
      'Schema changed since last apply: schema.json',
      checked$warnings,
      fixed = TRUE
    ),
    inherits(checked$result, 'error')
  )
  cat(
    'Schema change warning: check reports changed input before stale output; apply establishes the new baseline.\n'
  )
}
if (sys.nframe() == 0L) {
  schema_change_warning_acceptance()
}
