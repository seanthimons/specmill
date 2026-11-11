# Transitional JSON Schema views for the existing renderer (#279). Source-format
# interpretation stays in importers; this bridge reads only neutral IR types.
ir_scalar_schema <- function(type) {
  format <- switch(
    type$name,
    bytes = if (identical(type$encoding, 'raw')) 'binary' else 'byte',
    date = 'date',
    datetime = 'date-time',
    time = 'time',
    duration = 'duration',
    uuid = 'uuid',
    uri = 'uri',
    NULL
  )
  c(
    list(
      type = switch(
        type$name,
        boolean = 'boolean',
        integer = 'integer',
        float = 'number',
        decimal = 'number',
        null = 'null',
        'string'
      )
    ),
    if (!is.null(format)) list(format = format)
  )
}

# `types` holds the named types of the operation's source. A named type that
# refers back to itself cannot be expanded, so it stays an open object.
ir_request_schema <- function(type, types = list(), seen = character()) {
  nested <- function(child) ir_request_schema(child, types, seen)
  schema <- switch(
    type$kind,
    ref = if (is.null(types[[type$name]]) || type$name %in% seen) {
      list(type = 'object')
    } else {
      ir_request_schema(types[[type$name]], types, c(seen, type$name))
    },
    any = list(),
    scalar = ir_scalar_schema(type),
    enum = list(
      type = if (type$base == 'float') 'number' else type$base,
      enum = lapply(type$values, `[[`, 'value')
    ),
    record = list(
      type = 'object',
      properties = stats::setNames(
        lapply(type$fields, function(field) nested(field$type)),
        vapply(type$fields, `[[`, character(1), 'name')
      ),
      required = unname(lapply(
        Filter(function(field) isTRUE(field$required), type$fields),
        `[[`,
        'name'
      ))
    ),
    list = list(type = 'array', items = nested(type$items)),
    map = list(
      type = 'object',
      additionalProperties = nested(type$value)
    ),
    cli::cli_abort(
      'Unsupported request type in IR compatibility bridge: {type$kind}'
    )
  )
  keywords <- c(
    default = 'default',
    minimum = 'minimum',
    maximum = 'maximum',
    min_length = 'minLength',
    max_length = 'maxLength',
    pattern = 'pattern',
    description = 'description'
  )
  for (name in intersect(names(keywords), names(type))) {
    schema[keywords[[name]]] <- type[name]
  }
  schema
}

ir_request_records <- function(ir, view) {
  result <- list(
    operations = list(),
    inventory = list(),
    diagnostics = list(),
    exclusion_errors = character()
  )
  for (op in ir$operations) {
    source <- ir$sources[[match(
      op$source,
      vapply(ir$sources, `[[`, character(1), 'id')
    )]]
    review <- view$operation(op$key, op$binding$path, op$binding$method)
    selected <- !length(review$reason)
    inventory <- list(
      id = review$id,
      key = op$key,
      service = view$service,
      method = op$binding$method,
      path = op$binding$path,
      source = source$file,
      source_hash = source$hash$value,
      status = if (selected) 'selected' else 'excluded',
      reason = paste(review$reason, collapse = '; '),
      classification = if (selected) 'ready' else 'policy_exclusion',
      source_location = op$source_location$pointer %or% '#',
      guidance = 'Verify generated requests against the reviewed capture.'
    )
    result$inventory[[length(result$inventory) + 1L]] <- inventory
    if (!selected) {
      next
    }
    for (setting in c(
      'response_correction',
      'path_correction',
      'media_correction',
      'body_correction',
      'opaque_body'
    )) {
      if (!is.null(review$setting(setting))) {
        cli::cli_abort(
          'OpenAPI-specific corrections cannot be applied to imported IR requests: {setting}'
        )
      }
    }
    parameters <- lapply(op$parameters, function(p) {
      list(
        name = p$name,
        location = p$location,
        required = p$required,
        schema = ir_request_schema(p$type, source$types),
        allow_empty = FALSE,
        style = p$style %or% 'form',
        explode = p$explode %or% TRUE,
        collection_format = NULL,
        example = list(),
        source_location = op$source_location$pointer %or% '#'
      )
    })
    excluded <- review$setting('excluded_parameters')
    if (
      length(setdiff(excluded, vapply(parameters, `[[`, character(1), 'name')))
    ) {
      result$exclusion_errors <- c(
        result$exclusion_errors,
        paste('Unknown parameter for', op$key)
      )
    }
    parameters <- Filter(function(p) !p$name %in% excluded, parameters)
    query <- Filter(function(p) p$location == 'query', parameters)
    path <- Filter(function(p) p$location == 'path', parameters)
    body <- if (is.null(op$body)) {
      NULL
    } else {
      ir_request_schema(op$body$type, source$types)
    }
    record <- list(
      key = op$key,
      id = review$id,
      service = view$service,
      name = review$name(op$name),
      operationId = op$name,
      method = op$binding$method,
      path = op$binding$path,
      route = op$binding$path,
      summary = op$summary %or% op$name,
      description = op$description %or% '',
      deprecated = FALSE,
      parameters = parameters,
      body = body,
      body_required = isTRUE(op$body$required),
      body_media = op$body$media %or% 'application/json',
      body_encoding = list(),
      body_example = list(),
      text_encoding = 'scalar',
      has_body = !is.null(body),
      params = paste(
        vapply(parameters, `[[`, character(1), 'name'),
        collapse = ', '
      ),
      path_params = paste(
        vapply(path, `[[`, character(1), 'name'),
        collapse = ', '
      ),
      query_params = paste(
        vapply(query, `[[`, character(1), 'name'),
        collapse = ', '
      ),
      body_params = paste(names(body$properties), collapse = ', '),
      num_path_params = length(path),
      num_body_params = length(body$properties),
      path_param_metadata = list(),
      query_param_metadata = list(),
      body_param_metadata = list(),
      content_type = op$body$media %or% '',
      body_schema_type = body$type %or% 'unknown',
      body_schema_full = body %or% list(type = 'unknown', properties = list()),
      body_item_type = NA,
      response = op$responses,
      response_schema_type = 'object',
      request_type = if (is.null(body)) 'query_only' else 'body',
      pagination_strategy = 'none',
      pagination_metadata = list(strategy = 'none'),
      server = op$server %or% source$servers[[1L]],
      server_relative = NULL,
      security = op$security,
      security_schemes = source$auth_schemes,
      ir_auth_schemes = source$auth_schemes,
      source = source$file,
      source_hash = source$hash$value,
      schema_version = source$format_version,
      transport_diagnostics = character(),
      ir_operation = op
    )
    result$operations[[length(result$operations) + 1L]] <- record
  }
  result
}

client_operation_authentication <- function(operation, envvars) {
  if (is.null(operation$ir_auth_schemes)) {
    return(operation_authentication(operation, envvars))
  }
  lapply(operation$security %or% list(), function(requirement) {
    lapply(names(requirement), function(id) {
      scheme <- operation$ir_auth_schemes[[id]]
      if (is.null(scheme)) {
        cli::cli_abort('Undefined IR authentication scheme: {id}')
      }
      # The client reports an unsupported alternative only when no other applies.
      if (!scheme$kind %in% c('session_token', 'api_key')) {
        return(list(scheme = id, type = scheme$kind))
      }
      envvar <- config_string(
        envvars[[id]],
        paste('authentication environment variable for', id)
      )
      if (!grepl('^[A-Za-z_][A-Za-z0-9_]*$', envvar)) {
        cli::cli_abort('Invalid credential environment variable')
      }
      list(
        scheme = id,
        type = 'apiKey',
        location = scheme[['in']],
        name = scheme$name,
        envvar = envvar
      )
    })
  })
}

# Compatibility records for importers that emit IR directly from one document.
ir_source_records <- function(files, view, import, label) {
  if (length(files) != 1L) {
    cli::cli_abort('Use one {label} per service configuration')
  }
  ir_request_records(import(files)$ir, view)
}

# Configuration metadata for importers that emit IR directly. `tags` groups an
# operation, `pagination` returns reviewed paging policy for an operation or
# NULL, and `diagnostic_key` names what an import diagnostic is reported against.
ir_configuration_source <- function(
  ir,
  path,
  format,
  artifact,
  tags,
  authentication,
  pagination,
  security_declared = TRUE,
  response_policy = NULL,
  diagnostic_key = function(diagnostic) 'SERVICE'
) {
  list(
    operations = function(visit, report) {
      for (op in ir$operations) {
        visit(list(
          key = op$key,
          path = op$binding$path,
          method = tolower(op$binding$method),
          name = op$name,
          tags = tags(op)
        ))
      }
      for (diagnostic in ir$diagnostics) {
        report(diagnostic_key(diagnostic), diagnostic$code, diagnostic$reason)
      }
    },
    artifact = function() list(file = artifact, text = file_text(path)),
    security_declared = function() security_declared,
    authentication = authentication,
    decorate = function(files, parsed) {
      for (name in names(files)[startsWith(names(files), 'apis/')]) {
        service <- yaml::yaml.load(
          files[[name]],
          handlers = list(seq = function(x) x),
          eval.expr = FALSE
        )
        service$format <- format
        if (!is.null(response_policy)) {
          service$defaults$response_policy <- response_policy
        }
        for (op in ir$operations) {
          if (
            !op$key %in% unlist(service$selection$include, use.names = FALSE)
          ) {
            next
          }
          paging <- pagination(op)
          if (!is.null(paging)) {
            service$operations[[op$key]]$pagination <- paging
          }
        }
        files[[name]] <- sub('\n$', '', yaml::as.yaml(service))
      }
      files
    }
  )
}

# Source validation for importers that emit IR directly: the document is valid
# when it imports and the IR passes its contract.
ir_validation_report <- function(path, import, validator, code) {
  report <- list(
    source = normalizePath(path, winslash = '/', mustWork = TRUE),
    source_sha256 = digest::digest(file = path, algo = 'sha256'),
    schema_version = '',
    validator = validator,
    status = 'invalid',
    reason = '',
    operations = list(),
    findings = list()
  )
  result <- tryCatch(import(path), error = identity)
  if (inherits(result, 'error')) {
    report$reason <- conditionMessage(result)
    report$findings <- list(list(
      scope = 'document',
      level = 'error',
      code = code,
      classification = 'schema_defect',
      message = report$reason,
      keys = list()
    ))
    return(report)
  }
  report$schema_version <- result$ir$sources[[1L]]$format_version
  report$status <- 'valid'
  report$operations <- lapply(result$ir$operations, function(op) {
    list(key = op$key, method = op$binding$method, path = op$binding$path)
  })
  report
}
