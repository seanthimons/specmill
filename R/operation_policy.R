validate_request_body_correction <- function(correction) {
  config_fields(correction, c('omit', 'reason'), 'request_body_correction')
  config_string(correction$reason, 'request_body_correction reason')
  if (!isTRUE(correction$omit)) {
    stop('request_body_correction supports omit: true only')
  }
}

validate_path_parameters_correction <- function(correction) {
  config_fields(
    correction,
    c('parameters', 'reason'),
    'path_parameters_correction'
  )
  config_string(correction$reason, 'path_parameters_correction reason')
  config_fields(
    correction$parameters,
    names(correction$parameters),
    'path_parameters_correction parameters'
  )
  if (
    !length(correction$parameters) ||
      anyDuplicated(names(correction$parameters))
  ) {
    stop('path_parameters_correction requires unique named parameter schemas')
  }
  for (schema in correction$parameters) {
    config_fields(
      schema,
      names(schema),
      'path_parameters_correction parameter schema'
    )
    if (any(c('name', 'in', 'required') %in% names(schema))) {
      stop(
        'Path correction schemas cannot override parameter name, location or requiredness'
      )
    }
  }
}

operation_selection_reason <- function(key, path, method, policy) {
  if (key %in% policy$validation_blocked_keys) {
    return('Blocked by schema validation')
  }
  reason <- character()
  if (key %in% names(policy$claimed)) {
    reason <- paste('Claimed by service', policy$claimed[[key]])
  } else if (!is.null(policy$include) && !key %in% policy$include) {
    reason <- 'Not in service include'
  } else {
    if (
      !method %in%
        (policy$methods %or%
          c(
            'GET',
            'POST',
            'PUT',
            'PATCH',
            'DELETE',
            'HEAD',
            'OPTIONS',
            'TRACE'
          ))
    ) {
      reason <- if (
        !is.null(policy$project_methods) &&
          !method %in% policy$project_methods
      ) {
        'Prohibited by project methods'
      } else if (
        !is.null(policy$api_methods) &&
          !method %in% policy$api_methods
      ) {
        paste('Prohibited by API methods:', policy$api)
      } else {
        'Prohibited by service methods'
      }
    }
    for (pattern in policy[['exclude']] %or% character()) {
      if (exclusion_matches(pattern, path, method)) {
        level <- if (pattern %in% policy$project_exclude) {
          'project'
        } else if (pattern %in% policy$api_exclude) {
          paste('API', policy$api)
        } else {
          'service'
        }
        reason <- c(
          reason,
          paste('Matches', level, 'exclusion:', pattern)
        )
      }
    }
  }
  reason
}

# Validate reviewed settings before opening any schema documents.
prepare_operation_policy <- function(policy) {
  opaque_bodies <- Filter(Negate(is.null), policy$opaque_bodies %or% list())
  config_fields(opaque_bodies, names(opaque_bodies), 'opaque_bodies')
  for (review in opaque_bodies) {
    validate_opaque_body(review)
  }
  policy$override_keys <- union(policy$override_keys, names(opaque_bodies))
  response_corrections <- Filter(
    Negate(is.null),
    policy$response_corrections %or% list()
  )
  config_fields(
    response_corrections,
    names(response_corrections),
    'response_corrections'
  )
  for (correction in response_corrections) {
    validate_response_correction(correction)
  }
  policy$override_keys <- union(
    policy$override_keys,
    names(response_corrections)
  )
  body_corrections <- Filter(
    Negate(is.null),
    policy$request_body_corrections %or% list()
  )
  config_fields(
    body_corrections,
    names(body_corrections),
    'request_body_corrections'
  )
  for (correction in body_corrections) {
    validate_request_body_correction(correction)
  }
  policy$override_keys <- union(policy$override_keys, names(body_corrections))
  path_corrections <- Filter(
    Negate(is.null),
    policy$path_parameters_corrections %or% list()
  )
  config_fields(
    path_corrections,
    names(path_corrections),
    'path_parameters_corrections'
  )
  for (correction in path_corrections) {
    validate_path_parameters_correction(correction)
  }
  policy$override_keys <- union(policy$override_keys, names(path_corrections))
  policy$query_array_style <- query_array_style(policy$query_array_style)
  query_array_style_overrides <- policy$query_array_style_overrides %or% list()
  config_fields(
    query_array_style_overrides,
    names(query_array_style_overrides),
    'query_array_style_overrides'
  )
  for (key in names(query_array_style_overrides)) {
    query_array_style(
      query_array_style_overrides[[key]],
      paste('query_array_style for', key)
    )
  }
  policy$query_array_style_overrides <- query_array_style_overrides
  policy$override_keys <- union(
    policy$override_keys %or% character(),
    union(
      names(query_array_style_overrides),
      names(policy$exclude_parameters_overrides)
    )
  )
  patterns <- policy[['exclude']] %or% character()
  for (pattern in patterns) {
    stringr::str_detect('', exclusion_parts(pattern)$pattern)
  }
  policy
}

operation_policy_name <- function(candidate, key, policy) {
  name <- policy$names[[key]] %or% candidate
  if (!identical(make.names(name), name) || name %in% c('...', '')) {
    stop('Invalid operation name')
  }
  name
}

# Client-facing override and namespace checks follow native request parsing.
# Importers do not enforce wrapper-name uniqueness: IR identity is key/id.
finish_operation_policy <- function(records, policy) {
  operations <- records$operations
  inventory <- records$inventory
  exclusion_errors <- records$exclusion_errors
  include <- policy$include
  indexed_keys <- vapply(inventory, `[[`, character(1), 'key')
  unknown <- setdiff(
    union(union(names(policy$names), policy$override_keys), include),
    indexed_keys
  )
  if (length(unknown)) {
    if (!identical(policy$absent_override_mode, 'warn')) {
      stop('Unknown operation override: ', paste(unknown, collapse = ', '))
    }
    # Opt-in (#266): keys for operations missing from this schema match nothing.
    warning(
      'Skipping overrides for operations absent from the schema: ',
      paste(unknown, collapse = ', '),
      call. = FALSE
    )
  }
  if (length(exclusion_errors)) {
    stop(
      'Invalid exclude_parameters: ',
      paste(exclusion_errors, collapse = '; '),
      call. = FALSE
    )
  }
  operation_names <- vapply(operations, `[[`, character(1), 'name')
  if (anyDuplicated(operation_names)) {
    collisions <- unique(operation_names[duplicated(operation_names)])
    keys <- vapply(operations, `[[`, character(1), 'key')
    details <- vapply(
      collisions,
      function(name) {
        paste0(
          '  ',
          name,
          ':\n    ',
          paste(keys[operation_names == name], collapse = '\n    ')
        )
      },
      character(1)
    )
    conflicting <- which(operation_names %in% collisions)
    examples <- make.unique(operation_names, sep = '_')
    overrides <- vapply(
      conflicting,
      function(i) {
        paste0('  ', r_literal(keys[[i]]), ' = ', r_literal(examples[[i]]))
      },
      character(1)
    )
    stop(
      'Operation name collision; supply reviewed name overrides:\n',
      paste(details, collapse = '\n'),
      '\nReview these example names and pass policy = list(names = list(\n',
      paste(overrides, collapse = ',\n'),
      '\n)).\nFor a generated client, edit the service YAML names: map ',
      'written by initialize_client() before calling generate_client(). ',
      'configure_client() reports collisions for review.',
      call. = FALSE
    )
  }
  operation_records_result(records)
}

# Keep both supported and unsupported request metadata available to importers.
operation_records_result <- function(records) {
  operations <- records$operations
  inventory <- records$inventory
  diagnostics <- records$diagnostics
  operation_names <- vapply(operations, `[[`, character(1), 'name')
  names(operations) <- operation_names
  unsupported <- vapply(diagnostics, `[[`, character(1), 'id')
  inventory <- lapply(inventory, function(x) {
    if (x$id %in% unsupported) {
      x$status <- 'unsupported'
      x$reason <- diagnostics[[match(x$id, unsupported)]]$reason
      fields <- c('classification', 'code', 'source_location', 'guidance')
      x[fields] <- diagnostics[[match(x$id, unsupported)]][fields]
    }
    x
  })
  supported <- vapply(
    operations,
    function(op) !length(op$transport_diagnostics),
    logical(1)
  )
  list(
    operations = operations[supported],
    unsupported_operations = operations[!supported],
    diagnostics = diagnostics,
    body_diagnostics = lapply(
      Filter(function(op) !is.null(op$opaque_body), operations),
      function(op) {
        c(op[c('id', 'service', 'key', 'source')], op$opaque_body)
      }
    ),
    fixture_diagnostics = unlist(
      lapply(operations, fixture_diagnostics),
      recursive = FALSE
    ),
    server_diagnostics = lapply(
      Filter(function(op) !is.null(op$server$diagnostic), operations),
      function(op) {
        c(
          op[c('id', 'key', 'source')],
          list(code = 'server_selection', reason = op$server$diagnostic)
        )
      }
    ),
    inventory = inventory
  )
}

# Resolve reviewed settings at the point native parsing needs them. Keeping the
# setting resolver lazy preserves error precedence and leaves excluded request
# bodies/transport declarations unevaluated. No YAML policy enters the importer.
operation_review_context <- function(policy) {
  service <- policy$service %or% 'default'
  list(
    service = service,
    # Reviewed opaque bodies replace verified recursive request schemas before
    # any operation is parsed.
    document = function(file) {
      opaque_body_document(file, policy$opaque_bodies, policy = policy)
    },
    operation = function(key, path, method) {
      list(
        id = paste(service, key),
        reason = operation_selection_reason(key, path, method, policy),
        name = function(candidate) {
          operation_policy_name(candidate, key, policy)
        },
        setting = function(name) {
          switch(
            name,
            excluded_parameters = as.character(unlist(
              policy$exclude_parameters_overrides[[key]],
              use.names = FALSE
            )),
            routes = policy[['routes_overrides']][[key]],
            response_correction = policy$response_corrections[[key]],
            path_correction = policy$path_parameters_corrections[[key]],
            media_correction = policy$body_media_corrections[[key]],
            text_encoding = policy$text_encoding_overrides[[key]] %or%
              policy$text_encoding %or%
              'scalar',
            preferred_media = policy$body_media_overrides[[key]] %or%
              policy[['body_media']],
            explicit_media = !is.null(policy$body_media_overrides[[key]]),
            body_correction = policy$request_body_corrections[[key]],
            query_array_style = policy$query_array_style_overrides[[key]] %or%
              policy$query_array_style,
            cli::cli_abort('Unknown native review setting: {name}')
          )
        }
      )
    },
    duplicates = function() policy$duplicate_response_overrides %or% list(),
    absent_override_mode = policy$absent_override_mode
  )
}
