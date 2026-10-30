# Regression for issue 266: opt-in skipping of overrides for absent operations.

absent_overrides_acceptance <- function() {
  root <- tempfile('absent-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  fixture <- system.file('catalogue', package = 'specmill', mustWork = TRUE)
  stopifnot(all(file.copy(
    list.files(fixture, full.names = TRUE),
    root,
    recursive = TRUE
  )))
  writeLines(
    c('config_version: 1', 'services: [service.yml]'),
    file.path(root, 'specmill.yml')
  )
  writeLines(
    c(
      'id: mapped',
      'schemas: {files: [schema.json]}',
      'helper: catalogue_request',
      'selection: {include: ["GET /items/{item_id}", "GET /gone"]}',
      'names:',
      '  GET /items/{item_id}: fetch_item',
      '  DELETE /gone/{id}: remove_gone',
      'operations:',
      '  GET /gone:',
      '    docs: {title: Gone}',
      '  GET /gone/{id}:',
      '    duplicate_response: {source: a.json, reason: Old revision.}'
    ),
    file.path(root, 'service.yml')
  )
  plan <- function(...) {
    specmill::generate_client(root, config = 'specmill.yml', mode = 'plan', ...)
  }

  # Strict by default: the first check that meets an absent key stops the run.
  failed <- tryCatch(plan(), error = conditionMessage)
  stopifnot(
    is.character(failed),
    startsWith(
      failed,
      'duplicate_response requires a loaded duplicate operation: GET /gone/{id}'
    )
  )

  # Opt-in: warn, name every absent key, and generate the rest.
  warnings <- character()
  result <- withCallingHandlers(
    plan(absent_overrides = 'warn'),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart('muffleWarning')
    }
  )
  skipped <- grep('Skipping overrides', warnings, value = TRUE, fixed = TRUE)
  stopifnot(
    length(skipped) >= 1L,
    all(grepl('GET /gone', skipped, fixed = TRUE)),
    all(grepl('DELETE /gone/{id}', skipped, fixed = TRUE)),
    identical(
      unname(vapply(result$operations, `[[`, character(1), 'name')),
      'fetch_item'
    )
  )

  # Legacy specification mode takes the same argument.
  spec <- list(
    files = file.path(root, 'schema.json'),
    helper = 'h',
    policy = list(names = list('GET /gone' = 'gone'))
  )
  failed <- tryCatch(
    specmill::generate_client(root, spec, 'plan'),
    error = conditionMessage
  )
  stopifnot(identical(failed, 'Unknown operation override: GET /gone'))
  legacy <- suppressWarnings(
    specmill::generate_client(root, spec, 'plan', absent_overrides = 'warn')
  )
  stopifnot(length(legacy$operations) > 0L)

  failed <- tryCatch(plan(absent_overrides = 'skip'), error = conditionMessage)
  stopifnot(grepl("'arg' should be one of", failed, fixed = TRUE))
}

if (sys.nframe() == 0L) {
  absent_overrides_acceptance()
}
