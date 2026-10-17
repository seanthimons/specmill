response_correction_acceptance <- function() {
  workspace <- tempfile('response-review-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  for (version in c('2.0', '3.0.3', '3.1.0')) {
    schema <- file.path(workspace, paste0(version, '.json'))
    empty <- structure(list(), names = character())
    document <- list(
      info = list(title = 'Reviewed response', version = '1'),
      paths = list(
        '/lookup' = list(get = list(operationId = 'lookup', responses = empty)),
        '/unreviewed' = list(
          get = list(operationId = 'unreviewed', responses = empty)
        )
      )
    )
    document[[if (version == '2.0') 'swagger' else 'openapi']] <- version
    jsonlite::write_json(document, schema, auto_unbox = TRUE)
    before <- tools::md5sum(schema)
    stopifnot(identical(specmill::validate_schema(schema)$status, 'invalid'))
    root <- file.path(workspace, version)
    specmill::initialize_client(
      root,
      schema,
      package = 'responseview',
      title = 'Reviewed response',
      author = list(
        given = 'Test',
        family = 'Maintainer',
        email = 'test@example.org'
      ),
      license = 'MIT + file LICENSE',
      base_url = 'https://example.invalid'
    )
    path <- file.path(root, 'apis', 'default.yml')
    service <- yaml::read_yaml(path, handlers = list(seq = identity))
    service$selection$include <- list('GET /lookup')
    correction <- list(
      status = '200',
      media_type = 'application/json',
      description = 'Reviewed JSON lookup result.',
      reason = 'Staging declaration and captured production 200 JSON.'
    )
    service$operations[['GET /lookup']] <- list(
      response_correction = correction
    )
    yaml::write_yaml(service, path)
    plan <- specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'apply'
    )
    stopifnot(
      !length(plan$diagnostics),
      !length(plan$mapping_diagnostics),
      identical(before, tools::md5sum(schema)),
      length(plan$operations) == 1L
    )
    op <- plan$operations[[1L]]
    stopifnot(
      identical(op$response_correction, correction),
      !length(op$source_operation$responses),
      identical(op$response[['200']]$description, correction$description)
    )
    raw <- plan$validation[[1L]]
    reviewed <- raw$reviewed[[1L]]
    # The source remains invalid: its findings and hash are not relabelled as passed.
    stopifnot(
      identical(raw$status, 'invalid'),
      length(raw$findings) > 0L,
      identical(
        raw$source_sha256,
        digest::digest(file = op$source, algo = 'sha256')
      ),
      identical(reviewed$status, 'invalid'),
      !is.null(reviewed$reviewed_document_sha256),
      all(vapply(
        reviewed$findings,
        function(f) !'GET /lookup' %in% f$keys,
        logical(1)
      ))
    )
    specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
    # Selecting the uncorrected sibling must still block generation.
    service$selection$include <- list('GET /lookup', 'GET /unreviewed')
    yaml::write_yaml(service, path)
    blocked <- specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'plan'
    )
    stopifnot(any(vapply(
      blocked$diagnostics,
      function(d) {
        identical(d$key, 'GET /unreviewed') &&
          identical(d$code, 'schema_validation_invalid')
      },
      logical(1)
    )))
    # Correcting every empty response yields a passed reviewed view, while raw stays invalid.
    service$operations[['GET /unreviewed']] <- list(
      response_correction = correction
    )
    yaml::write_yaml(service, path)
    all <- specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'plan'
    )
    stopifnot(
      !length(all$diagnostics),
      identical(all$validation[[1L]]$status, 'invalid'),
      identical(all$validation[[1L]]$reviewed[[1L]]$status, 'passed')
    )
    # Operation review must not bypass document-level defects.
    client_schema <- all$operations[[1L]]$source
    original_bytes <- readBin(
      client_schema,
      'raw',
      n = file.info(client_schema)$size
    )
    invalid_document <- document
    invalid_document$info <- NULL
    jsonlite::write_json(invalid_document, client_schema, auto_unbox = TRUE)
    invalid_plan <- specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'plan'
    )
    stopifnot(
      length(invalid_plan$diagnostics) > 0L,
      !length(invalid_plan$operations)
    )
    writeBin(original_bytes, client_schema)
    if (version == '2.0') {
      conflict <- document
      conflict$produces <- list('text/plain')
      jsonlite::write_json(conflict, schema, auto_unbox = TRUE)
      rejected <- specmill::read_operations(
        schema,
        list(
          include = 'GET /lookup',
          response_corrections = list('GET /lookup' = correction)
        )
      )
      stopifnot(any(vapply(
        rejected$diagnostics,
        function(d) identical(d$code, 'response_correction'),
        logical(1)
      )))
    }
    # A correction must not overwrite existing response declarations.
    document$paths[['/lookup']]$get$responses <- list(
      '200' = list(description = 'Existing')
    )
    jsonlite::write_json(document, schema, auto_unbox = TRUE)
    bad <- specmill::read_operations(
      schema,
      list(
        include = 'GET /lookup',
        response_corrections = list('GET /lookup' = correction)
      )
    )
    stopifnot(any(vapply(
      bad$diagnostics,
      function(d) identical(d$code, 'response_correction'),
      logical(1)
    )))
    service$defaults$response_correction <- correction
    yaml::write_yaml(service, path)
    stopifnot(inherits(
      try(specmill::load_project(root), silent = TRUE),
      'try-error'
    ))
  }
  cat(
    'Reviewed responses: validation-on generation, raw/corrected reports, unchanged sources, siblings, conflict rejection and freshness passed.\n'
  )
}
if (sys.nframe() == 0L) {
  response_correction_acceptance()
}
