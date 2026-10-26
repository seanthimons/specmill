path_parameters_correction_acceptance <- function() {
  workspace <- tempfile('reviewed-path-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  for (version in c('2.0', '3.0.3', '3.1.0')) {
    schema <- file.path(workspace, paste0(version, '.json'))
    parameter <- list(name = 'dtxsid', `in` = 'path', required = TRUE)
    query <- list(name = 'limit', `in` = 'query')
    if (version == '2.0') {
      parameter$type <- query$type <- 'string'
    } else {
      parameter$schema <- query$schema <- list(type = 'string')
    }
    operation <- list(
      operationId = 'similar',
      parameters = list(parameter, query),
      responses = list('200' = list(description = 'OK'))
    )
    paths <- list()
    key <- 'GET /similar/{identifier_type}/{identifier}'
    paths[['/similar/{identifier_type}/{identifier}']] <- list(get = operation)
    paths[['/sources/{record_type}']] <- list(
      get = list(operationId = 'sources', responses = operation$responses)
    )
    paths[['/public']] <- list(
      get = list(operationId = 'public', responses = operation$responses)
    )
    document <- list(
      info = list(title = 'Reviewed paths', version = '1'),
      paths = paths
    )
    document[[if (version == '2.0') 'swagger' else 'openapi']] <- version
    jsonlite::write_json(document, schema, auto_unbox = TRUE)
    uncorrected <- specmill::read_operations(schema)
    # Every contradiction is reported: three on the first route, one on the second.
    stopifnot(
      length(uncorrected$diagnostics) == 4L,
      length(unique(vapply(uncorrected$diagnostics, `[[`, '', 'key'))) == 2L
    )
    before <- tools::md5sum(schema)
    root <- file.path(workspace, version)
    specmill::initialize_client(
      root,
      schema,
      package = 'reviewedpaths',
      title = 'Reviewed paths',
      author = list(
        given = 'Test',
        family = 'Maintainer',
        email = 'test@example.org'
      ),
      license = 'MIT + file LICENSE',
      base_url = 'http://127.0.0.1:1'
    )
    config <- file.path(root, 'apis', 'default.yml')
    service <- yaml::read_yaml(config, handlers = list(seq = identity))
    service$operations[[key]] <- list(
      path_parameters_correction = list(
        parameters = list(
          identifier_type = list(type = 'string'),
          identifier = list(type = 'string')
        ),
        reason = 'Reviewed staging declarations and production read-only captures.'
      )
    )
    service$operations[['GET /sources/{record_type}']] <- list(
      path_parameters_correction = list(
        parameters = list(record_type = list(type = 'string')),
        reason = 'Reviewed required route segment; no vocabulary inferred.'
      )
    )
    yaml::write_yaml(service, config)
    plan <- specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'apply',
      validation = FALSE
    )
    stopifnot(
      !length(plan$diagnostics),
      identical(before, tools::md5sum(schema))
    )
    similar <- Filter(function(op) op$name == 'similar', plan$operations)[[1L]]
    stopifnot(
      identical(
        vapply(similar$parameters, `[[`, character(1), 'name'),
        c('limit', 'identifier_type', 'identifier')
      ),
      identical(similar$source_operation$parameters[[1L]]$name, 'dtxsid'),
      identical(
        similar$path_parameters_correction$reason,
        'Reviewed staging declarations and production read-only captures.'
      )
    )
    runtime <- new.env(parent = baseenv())
    for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
      sys.source(file, runtime)
    }
    # Capture the real generated wrapper's transport arguments without live services.
    runtime$api_request <- function(...) list(...)
    request <- runtime$similar(
      identifier_type = 'DTXSID',
      identifier = 'a / b',
      limit = '2'
    )
    stopifnot(
      identical(request$path, '/similar/{identifier_type}/{identifier}'),
      identical(
        request$path_params,
        list(identifier_type = 'DTXSID', identifier = 'a / b')
      ),
      identical(request$query, list(limit = '2')),
      inherits(try(runtime$sources(), silent = TRUE), 'try-error')
    )
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'check',
      validation = FALSE
    )
    invalid <- service
    invalid$defaults$path_parameters_correction <- service$operations[[
      key
    ]]$path_parameters_correction
    yaml::write_yaml(invalid, config)
    stopifnot(inherits(
      try(specmill::load_project(root), silent = TRUE),
      'try-error'
    ))
    invalid <- service
    invalid$operations[[
      key
    ]]$path_parameters_correction$parameters$identifier <- NULL
    yaml::write_yaml(invalid, config)
    missing <- specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'plan',
      validation = FALSE
    )
    stopifnot(any(vapply(
      missing$diagnostics,
      function(x) identical(x$code, 'missing_path_parameter'),
      logical(1)
    )))
    invalid <- service
    invalid$operations[[
      key
    ]]$path_parameters_correction$parameters$extra <- list(type = 'string')
    yaml::write_yaml(invalid, config)
    rejected <- specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'plan',
      validation = FALSE
    )
    stopifnot(any(vapply(
      rejected$diagnostics,
      function(x) identical(x$code, 'unmatched_path_parameter'),
      logical(1)
    )))
  }
  cat(
    'Reviewed path declarations: Swagger/OAS, provenance, required strings, query preservation, missing/extra rejection and freshness passed.\n'
  )
}
if (sys.nframe() == 0L) {
  path_parameters_correction_acceptance()
}
