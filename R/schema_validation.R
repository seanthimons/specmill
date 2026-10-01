schema_validation_state <- new.env(parent = emptyenv())

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

schema_validation_findings <- function(errors, operations) {
  findings <- list()
  for (error in errors) {
    pointer <- error$pointer
    parts <- strsplit(sub('^/', '', pointer), '/', fixed = TRUE)[[1L]]
    parts <- gsub(
      '~0',
      '~',
      gsub('~1', '/', parts, fixed = TRUE),
      fixed = TRUE
    )
    keys <- character()
    if (length(parts) >= 2L && identical(parts[[1L]], 'paths')) {
      matched <- Filter(
        function(op) identical(op$path, parts[[2L]]),
        operations
      )
      if (length(parts) >= 3L) {
        by_method <- Filter(
          function(op) identical(tolower(op$method), parts[[3L]]),
          matched
        )
        if (length(by_method)) matched <- by_method
      }
      keys <- vapply(matched, `[[`, character(1), 'key')
    }
    # ponytail: shared or unlocated errors block the document; reverse-reference
    # attribution can narrow shared-component errors when needed.
    findings[[length(findings) + 1L]] <- list(
      level = 'error',
      message = paste0('#', pointer, ' ', error$message),
      source_location = paste0('#', pointer),
      scope = if (length(keys)) 'operation' else 'document',
      keys = as.list(keys)
    )
  }
  findings
}

schema_validator <- function() {
  if (!is.null(schema_validation_state$v8)) {
    return(schema_validation_state$v8)
  }
  read <- function(name) {
    paste(
      readLines(
        system.file('validation', name, package = 'specmill', mustWork = TRUE),
        encoding = 'UTF-8',
        warn = FALSE
      ),
      collapse = '\n'
    )
  }
  # The bundled ajv mis-resolves OAS 3.1's dynamic dialect binding and rejects
  # valid Schema Objects, so bind the default dialect statically.
  oas31 <- gsub(
    '"$dynamicRef": "#meta"',
    '"$ref": "https://spec.openapis.org/oas/3.1/dialect/base"',
    read('openapi-3.1.json'),
    fixed = TRUE
  )
  v8 <- V8::v8()
  # ponytail: reuses the ajv build shipped with jsonvalidate; vendor ajv if
  # jsonvalidate stops shipping AjvSchema2020/AjvSchema4/addFormats.
  v8$source(system.file('bundle.js', package = 'jsonvalidate', mustWork = TRUE))
  v8$eval(sprintf(
    paste(
      'var options = {allErrors: true, strict: false, logger: false};',
      'var ajv04 = new AjvSchema4(options); addFormats(ajv04);',
      'var ajv2020 = new AjvSchema2020(options); addFormats(ajv2020);',
      'ajv2020.addFormat("media-range", true);',
      'ajv2020.addSchema(%s); ajv2020.addSchema(%s);',
      'var validators = {"2.0": ajv04.compile(%s), "3.0": ajv04.compile(%s),',
      '  "3.1": ajv2020.compile(%s)};',
      # Swagger 2.0 parameters are a oneOf over locations, so a bad parameter
      # reports every location's errors. Recheck it against the location named
      # by its own `in` instead.
      'var swagger = "http://swagger.io/v2/schema.json#/definitions/";',
      'var locations = {body: {$ref: swagger + "bodyParameter"}};',
      '["header", "formData", "query", "path"].forEach(function (name) {',
      '  locations[name] = {type: "object", required: ["name", "in", "type"],',
      '    allOf: [{$ref: swagger + name + "ParameterSubSchema"}]}; });',
      'Object.keys(locations).forEach(function (name) {',
      '  locations[name] = ajv04.compile(locations[name]); });',
      'function resolve(document, pointer) {',
      '  return pointer.split("/").slice(1).reduce(function (node, part) {',
      '    return node == null ? node :',
      '      node[part.replace(/~1/g, "/").replace(/~0/g, "~")]; }, document); }',
      'function parameter_errors(errors, document) {',
      '  var parameters = {};',
      '  errors.forEach(function (a) {',
      '    if (a.keyword === "enum" && /\\/in$/.test(a.instancePath))',
      '      parameters[a.instancePath.slice(0, -3)] = true; });',
      '  Object.keys(parameters).forEach(function (pointer) {',
      '    var parameter = resolve(document, pointer);',
      '    var check = locations[parameter && parameter["in"]];',
      '    var replacement = [{instancePath: pointer + "/in", keyword: "enum",',
      '      message: "must be equal to one of the allowed values",',
      '      params: {allowedValues: Object.keys(locations)}}];',
      '    if (check) replacement = check(parameter) ? [] :',
      '      check.errors.map(function (a) { return Object.assign({}, a,',
      '        {instancePath: pointer + a.instancePath}); });',
      '    errors = errors.filter(function (a) {',
      '      return a.instancePath !== pointer &&',
      '        a.instancePath.indexOf(pointer + "/") !== 0;',
      '    }).concat(replacement);',
      '  });',
      '  return errors;',
      '}',
      'function validate_document(version, document) {',
      '  var validate = validators[version];',
      '  if (validate(document)) return [];',
      '  var combinators = ["oneOf", "anyOf", "if", "not", "$ref"];',
      '  var errors = validate.errors;',
      '  if (version === "2.0") errors = parameter_errors(errors, document);',
      '  errors = errors.filter(function (a) {',
      '    return combinators.indexOf(a.keyword) < 0; });',
      # An anyOf over `type` reports both alternatives; the enum error names
      # the allowed values, so the sibling type error adds nothing.
      '  errors = errors.filter(function (a) { return a.keyword !== "type" ||',
      '    !errors.some(function (b) { return b !== a && b.keyword !== "type" &&',
      '      b.instancePath === a.instancePath; }); });',
      # Ancestor errors only restate a deeper failure in the same subtree.
      '  errors = errors.filter(function (a) { return !errors.some(function (b) {',
      '    return b.instancePath.indexOf(a.instancePath + "/") === 0; }); });',
      '  var seen = {}, out = [];',
      '  errors.forEach(function (a) {',
      '    var detail = a.params.allowedValues || a.params.additionalProperty ||',
      '      a.params.unevaluatedProperty;',
      '    var message = a.message + (detail === undefined ? "" :',
      '      ": " + [].concat(detail).join(", "));',
      '    var key = a.instancePath + " " + message;',
      '    if (!seen[key]) { seen[key] = true;',
      '      out.push({pointer: a.instancePath, message: message}); }',
      '  });',
      '  return out;',
      '}'
    ),
    read('openapi-3.1-dialect.json'),
    read('openapi-3.1-meta.json'),
    read('swagger-2.0.json'),
    read('openapi-3.0.json'),
    oas31
  ))
  schema_validation_state$v8 <- v8
  v8
}

validate_schema <- function(file) {
  config_string(file, 'schema file')
  file <- normalizePath(file, winslash = '/', mustWork = TRUE)
  report <- list(
    source = file,
    source_sha256 = digest::digest(file = file, algo = 'sha256'),
    schema_version = '',
    validator = paste0(
      'jsonvalidate ',
      utils::packageVersion('jsonvalidate'),
      ' (ajv)'
    ),
    status = 'invalid',
    reason = '',
    operations = list(),
    findings = list()
  )
  result <- function(status, reason) {
    report$status <- status
    report$reason <- reason
    report
  }
  document <- tryCatch(
    read_schema_document(file, resolve_references = FALSE),
    error = identity
  )
  if (inherits(document, 'error')) {
    return(result('invalid', 'Cannot parse the local schema document.'))
  }
  if (!is.list(document) || is.null(names(document))) {
    return(result('invalid', 'Schema root must be an object.'))
  }
  operations <- schema_validation_operations(document)
  duplicate_keys <- function(node) {
    is.list(node) &&
      (anyDuplicated(names(node)) > 0L ||
        any(vapply(node, duplicate_keys, logical(1))))
  }
  if (duplicate_keys(document)) {
    return(result('invalid', 'Duplicate schema object keys are ambiguous.'))
  }
  report$operations <- operations
  version <- document$openapi %or% document$swagger %or% ''
  if (
    !is.character(version) ||
      length(version) != 1L ||
      is.na(version) ||
      !grepl('^(2[.]0$|3[.][01][.])', version)
  ) {
    return(result(
      'unsupported',
      'Validation covers Swagger 2.0 and OpenAPI 3.0 and 3.1 only.'
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
    return(result(
      'unsupported',
      'Validation requires a self-contained schema; bundle external references before generation.'
    ))
  }
  # Parsed maps, sequences and empty containers stay distinct, so the JSON
  # matches the source for JSON and YAML alike.
  json <- jsonlite::toJSON(
    document,
    auto_unbox = TRUE,
    null = 'null',
    digits = NA
  )
  v8 <- schema_validator()
  v8$assign('document', V8::JS(json))
  errors <- v8$get(
    sprintf('validate_document("%s", document)', substr(version, 1L, 3L)),
    simplifyVector = FALSE
  )
  report$findings <- schema_validation_findings(errors, operations)
  if (length(report$findings)) {
    result(
      'invalid',
      'The schema does not conform to its OpenAPI specification.'
    )
  } else {
    result('passed', 'The schema conforms to its OpenAPI specification.')
  }
}

schema_validation_policy <- function(policy) {
  if (!is.logical(policy) || length(policy) != 1L || is.na(policy)) {
    stop(
      'validation must be true or false; validator_url, cache_dir and timeout ',
      'were removed because validation now runs locally'
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
      report$status %in% c('invalid', 'unsupported')
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
      guidance = 'Correct or bundle the source before generation; request mappings cannot bypass schema validation.'
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
