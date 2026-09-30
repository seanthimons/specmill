schema_validation_options <- function(legacy = FALSE) {
  list(
    jsonSchemaValidation = TRUE,
    legacyJsonSchemaValidation = legacy,
    resolve = FALSE,
    resolveFully = FALSE,
    validateInternalRefs = TRUE,
    validateExternalRefs = FALSE,
    resolveRequestBody = FALSE,
    resolveCombinators = FALSE,
    allowEmptyStrings = FALSE,
    legacyYamlDeserialization = FALSE,
    inferSchemaType = FALSE
  )
}

schema_validation_operations <- function(document) {
  operations <- list()
  methods <- c(
    'get',
    'post',
    'put',
    'patch',
    'delete',
    'head',
    'options',
    'trace'
  )
  for (path in names(document$paths)) {
    for (method in intersect(names(document$paths[[path]]), methods)) {
      operations[[length(operations) + 1L]] <- list(
        key = paste(toupper(method), path),
        method = toupper(method),
        path = path,
        source_location = schema_location(
          schema_location('#/paths', path),
          method
        )
      )
    }
  }
  operations
}

schema_validation_findings <- function(raw, operations, version) {
  sequence <- function(x) is.list(x) && is.null(names(x))
  if (
    !is.list(raw) ||
      is.null(names(raw)) ||
      anyDuplicated(names(raw)) ||
      (!length(raw) && !startsWith(version, '3.1.')) ||
      (length(raw) &&
        !any(c('messages', 'schemaValidationMessages') %in% names(raw)))
  ) {
    stop('Unrecognized validator report')
  }
  findings <- list()
  add <- function(message, level, pointer = NULL) {
    keys <- character()
    if (!is.null(pointer)) {
      if (!is.character(pointer) || length(pointer) != 1L || is.na(pointer)) {
        stop('Invalid instance pointer')
      }
      if (nzchar(pointer) && !startsWith(pointer, '/')) {
        stop('Invalid instance pointer')
      }
      if (grepl('~([^01]|$)', pointer)) {
        stop('Invalid instance pointer escape')
      }
      parts <- strsplit(sub('^/', '', pointer), '/', fixed = TRUE)[[1L]]
      parts <- gsub(
        '~0',
        '~',
        gsub('~1', '/', parts, fixed = TRUE),
        fixed = TRUE
      )
      if (length(parts) >= 2L && identical(parts[[1L]], 'paths')) {
        matched <- Filter(
          function(op) identical(op$path, parts[[2L]]),
          operations
        )
        if (
          length(parts) >= 3L &&
            parts[[3L]] %in%
              c(
                'get',
                'post',
                'put',
                'patch',
                'delete',
                'head',
                'options',
                'trace'
              )
        ) {
          matched <- Filter(
            function(op) identical(tolower(op$method), parts[[3L]]),
            matched
          )
        }
        keys <- vapply(matched, `[[`, character(1), 'key')
      }
    }
    # ponytail: shared or unlocated errors block the document; reverse-reference
    # attribution can narrow shared-component errors when needed.
    findings[[length(findings) + 1L]] <<- list(
      level = level,
      message = message,
      source_location = paste0('#', pointer %or% ''),
      scope = if (length(keys)) 'operation' else 'document',
      keys = as.list(keys)
    )
  }
  if ('messages' %in% names(raw)) {
    if (!sequence(raw$messages)) {
      stop('Validator messages must be an array')
    }
    for (message in raw$messages) {
      add(config_string(message, 'validator message'), 'error')
    }
  }
  if ('schemaValidationMessages' %in% names(raw)) {
    if (!sequence(raw$schemaValidationMessages)) {
      stop('Validator schema messages must be an array')
    }
    for (error in raw$schemaValidationMessages) {
      if (
        !is.list(error) ||
          is.null(names(error)) ||
          !is.character(error$level) ||
          length(error$level) != 1L ||
          is.na(error$level) ||
          !error$level %in% c('error', 'warning', 'info')
      ) {
        stop('Unknown validator error level')
      }
      pointer <- if ('instance' %in% names(error)) {
        if (!is.list(error$instance) || !'pointer' %in% names(error$instance)) {
          stop('Invalid validator instance')
        }
        error$instance$pointer
      } else {
        NULL
      }
      add(
        config_string(error$message, 'validator error message'),
        error$level,
        pointer
      )
    }
  }
  findings
}

validate_schema <- function(
  file,
  validator_url = 'https://validator.swagger.io/validator',
  cache_dir = tools::R_user_dir('specmill', 'cache'),
  timeout = 30,
  refresh = FALSE
) {
  config_string(file, 'schema file')
  file <- normalizePath(file, winslash = '/', mustWork = TRUE)
  if (!valid_server_url(validator_url)) {
    stop(
      'validator_url must be an absolute HTTP(S) URL without credentials, query or fragment'
    )
  }
  validator_url <- sub('/+$', '', validator_url)
  if (
    !is.numeric(timeout) ||
      length(timeout) != 1L ||
      is.na(timeout) ||
      !is.finite(timeout) ||
      timeout <= 0
  ) {
    stop('validation timeout must be finite and positive')
  }
  if (!is.logical(refresh) || length(refresh) != 1L || is.na(refresh)) {
    stop('refresh must be true or false')
  }
  if (!is.null(cache_dir)) {
    config_string(cache_dir, 'validation cache directory')
  }
  bytes <- readBin(file, 'raw', n = file.info(file)$size)
  source_hash <- digest::digest(bytes, algo = 'sha256', serialize = FALSE)
  version <- ''
  operations <- list()
  report <- list(
    report_version = 1L,
    source = file,
    source_sha256 = source_hash,
    validator_url = validator_url,
    validator_version = NULL,
    schema_version = version,
    checked_at = format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC'),
    status = 'unverified',
    coverage = 'incomplete',
    reason = '',
    operations = operations,
    findings = list(),
    responses = list(),
    cached = FALSE
  )
  fail <- function(status, reason) {
    report$status <- status
    report$reason <- reason
    report
  }
  document <- tryCatch(
    read_schema_document(file, resolve_references = FALSE),
    error = identity
  )
  if (inherits(document, 'error')) {
    return(fail('invalid', 'Cannot parse the local schema document.'))
  }
  if (!is.list(document) || is.null(names(document))) {
    return(fail('invalid', 'Schema root must be an object.'))
  }
  operations <- schema_validation_operations(document)
  duplicate_keys <- function(node) {
    is.list(node) &&
      (anyDuplicated(names(node)) > 0L ||
        any(vapply(node, duplicate_keys, logical(1))))
  }
  if (duplicate_keys(document)) {
    return(fail('invalid', 'Duplicate schema object keys are ambiguous.'))
  }
  report$operations <- operations
  version <- document$openapi %or% document$swagger %or% ''
  if (
    !is.character(version) ||
      length(version) != 1L ||
      is.na(version) ||
      !grepl('^(2[.]0$|3[.][01][.])', version)
  ) {
    return(fail(
      'unsupported',
      'Validator coverage is not established for this schema version.'
    ))
  }
  report$schema_version <- version
  external_refs <- function(node) {
    if (!is.list(node)) {
      return(FALSE)
    }
    ref <- node[['$ref']]
    if (
      is.character(ref) &&
        length(ref) == 1L &&
        !is.na(ref) &&
        !startsWith(ref, '#')
    ) {
      return(TRUE)
    }
    # ponytail: every external $ref is conservative, including example data;
    # a context-aware reference walker can relax literal examples if needed.
    any(vapply(node, external_refs, logical(1)))
  }
  if (external_refs(document)) {
    return(fail(
      'unsupported',
      'Validation requires a self-contained schema; bundle external references before generation.'
    ))
  }
  engines <- if (startsWith(version, '3.0.')) {
    c('legacy', 'modern')
  } else {
    'modern'
  }
  options <- stats::setNames(
    lapply(engines, function(engine) {
      schema_validation_options(engine == 'legacy')
    }),
    engines
  )
  report$options <- options
  identity <- digest::digest(
    list(
      report_version = report$report_version,
      source_hash = source_hash,
      type = tolower(tools::file_ext(file)),
      validator_url = validator_url,
      options = options
    ),
    algo = 'sha256'
  )
  report$identity <- identity
  cache_file <- if (!is.null(cache_dir)) {
    file.path(cache_dir, paste0(identity, '.json'))
  } else {
    NULL
  }
  finish <- function(result) {
    result$findings <- unlist(
      lapply(
        result$responses,
        schema_validation_findings,
        operations = operations,
        version = version
      ),
      recursive = FALSE
    )
    result$coverage <- if (startsWith(version, '3.1.')) {
      'incomplete'
    } else {
      'structural'
    }
    errors <- Filter(function(x) x$level == 'error', result$findings)
    result$status <- if (length(errors)) {
      'invalid'
    } else if (result$coverage == 'incomplete') {
      'unsupported'
    } else {
      'passed'
    }
    result$reason <- switch(
      result$status,
      invalid = 'The validator reported schema errors.',
      unsupported = 'Swagger Validator does not provide OAS 3.1 structural coverage.',
      'No errors reported within the supported structural coverage.'
    )
    result$operations <- operations
    result$source <- file
    result
  }
  if (!refresh && !is.null(cache_file) && file.exists(cache_file)) {
    cached <- tryCatch(jsonlite::read_json(cache_file), error = function(e) {
      NULL
    })
    if (
      is.list(cached) &&
        identical(cached$report_version, report$report_version) &&
        identical(cached$identity, identity) &&
        identical(cached$source_sha256, source_hash) &&
        identical(cached$options, options) &&
        identical(cached$validator_url, validator_url) &&
        identical(cached$schema_version, version) &&
        identical(names(cached$responses), engines) &&
        is.character(cached$validator_version) &&
        length(cached$validator_version) == 1L &&
        !is.na(cached$validator_version) &&
        nzchar(cached$validator_version)
    ) {
      cached <- tryCatch(finish(cached), error = function(e) NULL)
      if (!is.null(cached)) {
        if (
          !identical(digest::digest(file = file, algo = 'sha256'), source_hash)
        ) {
          return(fail(
            'unverified',
            'The schema changed during validation; retry with the current source.'
          ))
        }
        cached$cached <- TRUE
        return(cached)
      }
    }
  }
  if (!requireNamespace('httr2', quietly = TRUE)) {
    return(fail('unverified', 'Install httr2 to contact the schema validator.'))
  }
  request <- function(url) {
    httr2::request(url) %>%
      httr2::req_timeout(timeout) %>%
      httr2::req_error(is_error = function(response) FALSE) %>%
      httr2::req_options(followlocation = FALSE) %>%
      httr2::req_headers(Accept = 'application/json')
  }
  result <- tryCatch(
    {
      metadata_response <- httr2::req_perform(request(paste0(
        validator_url,
        '/openapi.json'
      )))
      report$http_status <- httr2::resp_status(metadata_response)
      if (httr2::resp_status(metadata_response) != 200L) {
        stop('Unexpected validator metadata status')
      }
      metadata <- httr2::resp_body_json(
        metadata_response,
        simplifyVector = FALSE
      )
      report$validator_version <- config_string(
        metadata$info$version,
        'validator version'
      )
      for (engine in engines) {
        report$http_status <- NULL
        call <- request(paste0(validator_url, '/debug'))
        call <- do.call(
          httr2::req_url_query,
          c(
            list(call),
            lapply(options[[engine]], function(x) if (x) 'true' else 'false')
          )
        )
        response <- call %>%
          httr2::req_body_raw(
            bytes,
            type = if (tolower(tools::file_ext(file)) %in% c('yaml', 'yml')) {
              'application/yaml'
            } else {
              'application/json'
            }
          ) %>%
          httr2::req_perform()
        report$http_status <- httr2::resp_status(response)
        if (httr2::resp_status(response) != 200L) {
          stop('Unexpected validator status')
        }
        report$responses[[engine]] <- httr2::resp_body_json(
          response,
          simplifyVector = FALSE
        )
      }
      finish(report)
    },
    error = function(e) {
      fail(
        'unverified',
        if (!is.null(report$http_status) && report$http_status != 200L) {
          paste0(
            'Validator returned HTTP ',
            report$http_status,
            '; the schema remains unverified.'
          )
        } else {
          'Validator request failed or returned an unrecognized report; the schema remains unverified.'
        }
      )
    }
  )
  if (!identical(digest::digest(file = file, algo = 'sha256'), source_hash)) {
    return(fail(
      'unverified',
      'The schema changed during validation; retry with the current source.'
    ))
  }
  if (result$status != 'unverified' && !is.null(cache_file)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE, mode = '0700')
    temporary <- tempfile('validation-', tmpdir = cache_dir)
    on.exit(unlink(temporary), add = TRUE)
    jsonlite::write_json(
      result,
      temporary,
      pretty = TRUE,
      auto_unbox = TRUE,
      null = 'null'
    )
    Sys.chmod(temporary, '0600')
    if (!file.rename(temporary, cache_file)) {
      stop('Cannot save schema validation report')
    }
  }
  result
}

schema_validation_policy <- function(policy, root) {
  if (is.logical(policy) && length(policy) == 1L && !is.na(policy)) {
    return(if (policy) list() else FALSE)
  }
  config_fields(
    policy,
    c('validator_url', 'cache_dir', 'timeout'),
    'validation'
  )
  if (
    !is.null(policy$cache_dir) && !grepl('^(/|[A-Za-z]:)', policy$cache_dir)
  ) {
    policy$cache_dir <- project_path(
      root,
      config_string(policy$cache_dir, 'validation cache_dir')
    )
  }
  policy
}

validated_service_operations <- function(service, reports) {
  service$files <- normalizePath(service$files, winslash = '/', mustWork = TRUE)
  source_reports <- reports[normalizePath(
    service$files,
    winslash = '/',
    mustWork = TRUE
  )]
  blocked <- Filter(
    function(report) {
      report$status %in% c('invalid', 'unverified', 'unsupported')
    },
    source_reports
  )
  document_blocked <- Filter(
    function(report) {
      report$status != 'invalid' ||
        !length(report$findings) ||
        any(vapply(
          report$findings,
          function(x) x$level == 'error' && x$scope == 'document',
          logical(1)
        ))
    },
    blocked
  )
  excluded_files <- vapply(document_blocked, `[[`, character(1), 'source')
  excluded_keys <- unlist(
    lapply(document_blocked, function(x) {
      vapply(x$operations, `[[`, character(1), 'key')
    }),
    use.names = FALSE
  )
  readable <- service
  readable$files <- setdiff(service$files, excluded_files)
  for (field in union(
    'names',
    grep('_overrides$', names(service$policy), value = TRUE)
  )) {
    readable$policy[[field]] <- service$policy[[field]][
      !names(service$policy[[field]]) %in% excluded_keys
    ]
  }
  readable$policy$override_keys <- setdiff(
    service$policy$override_keys,
    excluded_keys
  )
  readable$policy$validation_blocked_keys <- unique(unlist(
    lapply(blocked, function(report) {
      unlist(
        lapply(
          Filter(
            function(x) x$level == 'error' && x$scope == 'operation',
            report$findings
          ),
          `[[`,
          'keys'
        ),
        use.names = FALSE
      )
    }),
    use.names = FALSE
  ))
  blocked_routes <- names(Filter(
    function(routes) {
      any(vapply(
        routes,
        function(route) {
          any(vapply(
            blocked,
            function(report) {
              same_source <- identical(route$source, report$source) ||
                endsWith(report$source, paste0('/', route$source))
              keys <- if (report$source %in% excluded_files) {
                vapply(report$operations, `[[`, character(1), 'key')
              } else {
                unlist(
                  lapply(
                    Filter(function(x) x$level == 'error', report$findings),
                    `[[`,
                    'keys'
                  ),
                  use.names = FALSE
                )
              }
              same_source && route$key %in% keys
            },
            logical(1)
          ))
        },
        logical(1)
      ))
    },
    service$policy[['routes_overrides']] %or% list()
  ))
  readable$policy$validation_blocked_keys <- union(
    readable$policy$validation_blocked_keys,
    blocked_routes
  )
  if (!is.null(service$policy$include)) {
    readable$policy$include <- setdiff(service$policy$include, excluded_keys)
  }
  parsed <- if (length(readable$files)) {
    read_service_operations(readable)
  } else {
    list(
      operations = list(),
      diagnostics = list(),
      inventory = list(),
      mapping_diagnostics = list(),
      retained_diagnostics = list(),
      server_diagnostics = list()
    )
  }
  for (i in seq_along(parsed$inventory)) {
    operation <- parsed$inventory[[i]]
    if (!operation$key %in% blocked_routes) {
      next
    }
    selection <- operation_selection_reason(
      operation$key,
      operation$path,
      operation$method,
      service$policy
    )
    if (length(selection)) {
      operation$reason <- paste(selection, collapse = '; ')
    } else {
      operation$status <- 'unsupported'
      operation$reason <- 'A declared hook route is blocked by schema validation.'
      operation$classification <- 'schema_defect'
      operation$code <- 'schema_validation_route_blocked'
      operation$guidance <- 'Correct every declared route before generating this wrapper.'
      parsed$diagnostics[[length(parsed$diagnostics) + 1L]] <- operation
    }
    parsed$inventory[[i]] <- operation
  }
  for (report in blocked) {
    full <- report$source %in% excluded_files
    errors <- Filter(function(x) x$level == 'error', report$findings)
    keys <- if (full) {
      vapply(report$operations, `[[`, character(1), 'key')
    } else {
      unique(unlist(lapply(errors, `[[`, 'keys'), use.names = FALSE))
    }
    id <- service$policy$service %or% service$id %or% 'default'
    fields <- list(
      status = 'unsupported',
      reason = report$reason,
      classification = if (report$status == 'invalid') {
        'schema_defect'
      } else {
        'review_required'
      },
      code = paste0('schema_validation_', report$status),
      source_location = if (length(errors)) {
        errors[[1L]]$source_location
      } else {
        '#'
      },
      guidance = 'Correct the source or restore validator coverage before generation; request mappings cannot bypass schema validation.'
    )
    for (operation in report$operations) {
      if (!operation$key %in% keys) {
        next
      }
      operation$id <- paste(id, operation$key)
      operation$service <- id
      operation$source <- report$source
      operation$source_hash <- unname(tools::md5sum(report$source))
      operation <- utils::modifyList(operation, fields)
      if (!full) {
        matching <- Filter(
          function(x) operation$key %in% unlist(x$keys, use.names = FALSE),
          errors
        )
        operation$source_location <- matching[[1L]]$source_location
        operation$reason <- paste(
          unique(vapply(matching, `[[`, character(1), 'message')),
          collapse = '; '
        )
      }
      selected <- operation_selection_reason(
        operation$key,
        operation$path,
        operation$method,
        service$policy %or% list()
      )
      if (length(selected)) {
        operation$status <- 'excluded'
        operation$reason <- paste(selected, collapse = '; ')
        operation$classification <- 'policy_exclusion'
      } else if (!full) {
        parsed$diagnostics <- c(
          list(operation),
          Filter(function(x) x$id != operation$id, parsed$diagnostics)
        )
      }
      parsed$inventory <- c(
        Filter(function(x) x$id != operation$id, parsed$inventory),
        list(operation)
      )
    }
    if (full) {
      # A document blocker still applies when every operation was policy-excluded.
      fields$reason <- paste(
        unique(c(report$reason, if (length(errors)) errors[[1L]]$message)),
        collapse = '; '
      )
      parsed$diagnostics[[length(parsed$diagnostics) + 1L]] <- c(
        list(
          id = paste(id, 'SCHEMA', report$source),
          service = id,
          key = paste('SCHEMA', basename(report$source)),
          source = report$source
        ),
        fields
      )
    }
    remove <- function(x) {
      identical(
        normalizePath(x$source, winslash = '/', mustWork = FALSE),
        report$source
      ) &&
        x$key %in% keys
    }
    parsed$operations <- Filter(function(x) !remove(x), parsed$operations)
    parsed$mapping_diagnostics <- Filter(
      function(x) !remove(x),
      parsed$mapping_diagnostics
    )
    parsed$retained_diagnostics <- Filter(
      function(x) !remove(x),
      parsed$retained_diagnostics
    )
    parsed$server_diagnostics <- Filter(
      function(x) !remove(x),
      parsed$server_diagnostics
    )
  }
  parsed
}
