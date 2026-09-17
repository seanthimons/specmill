read_operations <- function(files, policy = list()) {
  operations <- list()
  diagnostics <- list()
  inventory <- list()
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
    names(query_array_style_overrides)
  )
  methods <- policy$methods %or%
    c('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS', 'TRACE')
  patterns <- policy$exclude %or% character()
  include <- policy$include
  for (pattern in patterns) {
    stringr::str_detect('', pattern)
  }
  for (file in files) {
    first_operation <- length(operations) + 1L
    document <- read_schema_document(file)
    source_hash <- unname(tools::md5sum(file))
    security_schemes <- lapply(
      document$components$securitySchemes %or%
        document$securityDefinitions %or%
        list(),
      local_ref,
      document = document
    )
    version <- document$openapi %or% document$swagger
    if (is.null(version) || !grepl('^(3\\.[01]\\.|2\\.0$)', version)) {
      stop('Unsupported schema version in ', file, call. = FALSE)
    }
    if (!is.list(document$paths) || is.null(names(document$paths))) {
      stop('Missing paths: ', file)
    }
    for (path in names(document$paths)) {
      item <- tryCatch(
        local_ref(
          document$paths[[path]],
          document,
          source_location = schema_location('#/paths', path)
        ),
        error = identity
      )
      if (inherits(item, 'error')) {
        key <- paste('PATH', path)
        failure <- c(
          list(
            id = paste(policy$service %or% 'default', key),
            key = key,
            service = policy$service %or% 'default',
            source = file,
            status = 'unsupported',
            reason = conditionMessage(item)
          ),
          diagnostic_fields(item, schema_location('#/paths', path))
        )
        diagnostics[[length(diagnostics) + 1L]] <- failure
        inventory[[length(inventory) + 1L]] <- c(
          failure,
          list(method = 'PATH', path = path, source_hash = source_hash)
        )
        next
      }
      document$paths[[path]] <- item
      for (method in intersect(
        names(item),
        c('get', 'post', 'put', 'patch', 'delete', 'head', 'options', 'trace')
      )) {
        key <- paste(toupper(method), path)
        id <- paste(policy$service %or% 'default', key)
        operation_location <- schema_location(
          schema_location('#/paths', path),
          method
        )
        source_location <- operation_location
        diagnostic_context <- NULL
        reason <- character()
        if (!is.null(include) && !key %in% include) {
          reason <- 'Not in service include'
        } else {
          if (!toupper(method) %in% methods) {
            reason <- if (
              !is.null(policy$project_methods) &&
                !toupper(method) %in% policy$project_methods
            ) {
              'Prohibited by project methods'
            } else if (
              !is.null(policy$api_methods) &&
                !toupper(method) %in% policy$api_methods
            ) {
              paste('Prohibited by API methods:', policy$api)
            } else {
              'Prohibited by service methods'
            }
          }
          for (pattern in patterns) {
            if (stringr::str_detect(path, pattern)) {
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
        selected <- !length(reason)
        record <- list(
          id = id,
          key = key,
          service = policy$service %or% 'default',
          method = toupper(method),
          path = path,
          source = file,
          source_hash = source_hash,
          status = if (selected) 'selected' else 'excluded',
          reason = paste(reason, collapse = '; '),
          classification = if (selected) 'ready' else 'policy_exclusion',
          source_location = operation_location,
          guidance = if (selected) {
            'Verify generated requests before relying on live results.'
          } else {
            'Review project and service selection policy to reconsider this operation; its schema was not validated.'
          }
        )
        inventory[[length(inventory) + 1L]] <- record
        if (!selected) {
          next
        }
        operation <- tryCatch(
          {
            if (!startsWith(path, '/') || grepl('[\r\n]', path)) {
              stop('Invalid route')
            }
            op <- local_ref(
              item[[method]],
              document,
              source_location = operation_location
            )
            document$paths[[path]][[method]] <- op
            if (
              ('security' %in% names(op) && !is.list(op$security)) ||
                ('security' %in% names(document) && !is.list(document$security))
            ) {
              stop('Security requirements must be arrays, not null or scalars')
            }
            transport_diagnostics <- character()
            unsupported <- function(reason, problem = NULL) {
              transport_diagnostics <<- unique(c(transport_diagnostics, reason))
              if (is.null(diagnostic_context)) {
                diagnostic_context <<- problem %or%
                  list(
                    classification = 'capability_gap',
                    code = 'unsupported_transport',
                    source_location = source_location
                  )
              }
            }
            server_source <- if ('servers' %in% names(op)) {
              'operation'
            } else if ('servers' %in% names(item)) {
              'path'
            } else {
              'root'
            }
            servers <- if (identical(server_source, 'operation')) {
              op$servers
            } else if (identical(server_source, 'path')) {
              item$servers
            } else {
              document$servers
            }
            if (!identical(version, '2.0') && server_source != 'root') {
              server_location <- if (identical(server_source, 'operation')) {
                schema_location(operation_location, 'servers')
              } else {
                schema_location(schema_location('#/paths', path), 'servers')
              }
              unsupported(
                paste0(
                  tools::toTitleCase(server_source),
                  '-level server selection requires a reviewed base URL'
                ),
                list(
                  classification = 'capability_gap',
                  code = 'server_selection',
                  source_location = server_location
                )
              )
            } else if (!identical(version, '2.0') && length(servers) > 1L) {
              unsupported(
                'Multiple root servers require a reviewed base URL',
                list(
                  classification = 'capability_gap',
                  code = 'server_selection',
                  source_location = '#/servers'
                )
              )
            }
            raw_params <- c(item$parameters, op$parameters)
            parameter_locations <- c(
              vapply(
                seq_along(item$parameters),
                function(i) {
                  schema_location(
                    schema_location(
                      schema_location('#/paths', path),
                      'parameters'
                    ),
                    i - 1L
                  )
                },
                character(1)
              ),
              vapply(
                seq_along(op$parameters),
                function(i) {
                  schema_location(
                    schema_location(operation_location, 'parameters'),
                    i - 1L
                  )
                },
                character(1)
              )
            )
            params <- lapply(seq_along(raw_params), function(i) {
              local_ref(
                raw_params[[i]],
                document,
                source_location = parameter_locations[[i]]
              )
            })
            parameter_groups <- c(
              rep('path', length(item$parameters)),
              rep('operation', length(op$parameters))
            )
            if (!identical(version, '2.0')) {
              reserved <- vapply(params, function(p) {
                identical(p[['in']], 'header') &&
                  length(p$name) == 1L &&
                  tolower(p$name) %in%
                    c('accept', 'content-type', 'authorization')
              }, logical(1))
              params <- params[!reserved]
              parameter_locations <- parameter_locations[!reserved]
              parameter_groups <- parameter_groups[!reserved]
            }
            ids <- vapply(
              params,
              function(p) {
                name <- if (
                  !identical(version, '2.0') &&
                    identical(p[['in']], 'header')
                ) {
                  tolower(p$name)
                } else {
                  p$name
                }
                paste(p[['in']], name)
              },
              character(1)
            )
            duplicate <- duplicated(paste(parameter_groups, ids))
            if (any(duplicate)) {
              i <- which(duplicate)[[1L]]
              schema_problem(
                'duplicate_parameter',
                'schema_defect',
                paste('Duplicate parameter:', ids[[i]]),
                parameter_locations[[i]]
              )
            }
            keep <- !duplicated(ids, fromLast = TRUE)
            params <- params[keep]
            parameter_locations <- parameter_locations[keep]
            body <- op$requestBody
            body_location <- schema_location(operation_location, 'requestBody')
            body_present <- !is.null(body)
            body_required <- FALSE
            body_media <- 'application/json'
            body_encoding <- list()
            preferred_media <- policy$body_media_overrides[[key]] %or%
              policy$body_media
            undefined_body_method <- body_present &&
              !identical(version, '2.0') &&
              toupper(method) %in% c('GET', 'HEAD', 'DELETE')
            if (undefined_body_method && startsWith(version, '3.0')) {
              body <- NULL
              body_present <- FALSE
            } else if (
              undefined_body_method &&
                is.null(policy$body_media_overrides[[key]])
            ) {
              schema_problem(
                'request_body_method',
                'review_required',
                paste(
                  'OAS 3.1',
                  toupper(method),
                  'request body requires an explicit operation body_media review'
                ),
                body_location
              )
            } else if (undefined_body_method) {
              warning(
                'OAS 3.1 ',
                toupper(method),
                ' request body has undefined interoperability semantics',
                call. = FALSE
              )
            }
            if (startsWith(version, '2.')) {
              bodies <- Filter(function(p) identical(p[['in']], 'body'), params)
              if (length(bodies) > 1L) {
                stop('Multiple body parameters')
              }
              body_required <- length(bodies) == 1L &&
                isTRUE(bodies[[1]]$required)
              body_present <- length(bodies) == 1L
              if (body_present) {
                body_location <- schema_location(
                  parameter_locations[[which(vapply(
                    params,
                    function(p) identical(p[['in']], 'body'),
                    logical(1)
                  ))]],
                  'schema'
                )
              }
              body <- if (length(bodies)) bodies[[1]]$schema else NULL
              forms <- Filter(
                function(p) identical(p[['in']], 'formData'),
                params
              )
              if (length(forms)) {
                if (length(bodies)) {
                  stop('Body and formData parameters cannot be combined')
                }
                body_media <- request_body_media(
                  op$consumes %or% document$consumes %or% character(),
                  preferred_media,
                  body_location
                )
                if (!form_media(body_media)) {
                  stop('formData requires form request media')
                }
                fields <- lapply(forms, function(p) {
                  field <- p[setdiff(names(p), c('name', 'in', 'required'))]
                  if (identical(field$type, 'file')) {
                    field$type <- 'string'
                    field$format <- 'binary'
                  }
                  if (
                    identical(field$type, 'array') &&
                      identical(field$items$type, 'file')
                  ) {
                    field$items$type <- 'string'
                    field$items$format <- 'binary'
                  }
                  field
                })
                names(fields) <- vapply(forms, `[[`, character(1), 'name')
                body <- list(
                  type = 'object',
                  properties = fields,
                  required = as.list(vapply(
                    Filter(function(p) isTRUE(p$required), forms),
                    `[[`,
                    character(1),
                    'name'
                  ))
                )
                body_present <- TRUE
                body_required <- length(body$required) > 0L
                body_encoding <- setNames(
                  lapply(forms, function(p) {
                    if (identical(p$type, 'array')) {
                      list(collection_format = p$collectionFormat %or% 'csv')
                    } else {
                      list()
                    }
                  }),
                  names(fields)
                )
              } else if (body_present) {
                body_media <- request_body_media(
                  op$consumes %or% document$consumes %or% character(),
                  preferred_media,
                  body_location
                )
              }
              parameter_locations <- parameter_locations[vapply(
                params,
                function(p) !p[['in']] %in% c('body', 'formData'),
                logical(1)
              )]
              params <- Filter(
                function(p) !p[['in']] %in% c('body', 'formData'),
                params
              )
            } else if (!is.null(body)) {
              source_location <- body_location
              body <- local_ref(body, document, source_location = body_location)
              body_required <- isTRUE(body$required)
              body_media <- request_body_media(
                names(body$content),
                preferred_media,
                body_location
              )
              body_encoding <- body$content[[body_media]]$encoding %or% list()
              body_location <- schema_location(
                schema_location(
                  schema_location(body_location, 'content'),
                  body_media
                ),
                'schema'
              )
              body <- body$content[[body_media]]$schema
            }
            params <- lapply(seq_along(params), function(i) {
              p <- params[[i]]
              source_location <<- parameter_locations[[i]]
              location <- p[['in']]
              if (
                length(location) != 1L ||
                  !location %in%
                    c('path', 'query', 'header', 'cookie', 'formData')
              ) {
                stop('Invalid parameter location')
              }
              if (!location %in% c('path', 'query', 'header', 'cookie')) {
                unsupported('Unsupported parameter location')
              }
              if (
                !is.character(p$name) || length(p$name) != 1L || !nzchar(p$name)
              ) {
                stop('Invalid parameter name')
              }
              schema <- p$schema %or% p
              if (is.null(p$schema)) {
                schema$required <- NULL
              }
              if (!is.null(p$schema)) {
                source_location <<- schema_location(source_location, 'schema')
              }
              if (
                !(identical(version, '2.0') &&
                  location == 'formData' &&
                  identical(schema$type, 'file'))
              ) {
                schema <- input_schema(
                  schema,
                  document,
                  source_location = source_location,
                  parameter_items = identical(version, '2.0')
                )
              }
              encoding <- tryCatch(
                parameter_shape(
                  p,
                  schema,
                  version,
                  source_location,
                  policy$query_array_style_overrides[[key]] %or%
                    policy$query_array_style
                ),
                error = function(e) {
                  if (identical(e$classification, 'schema_defect')) {
                    stop(e)
                  }
                  unsupported(conditionMessage(e), e)
                  list(style = p$style, explode = p$explode)
                }
              )
              if (location == 'path' && !isTRUE(p$required)) {
                stop('Path parameter must be required')
              }
              list(
                name = p$name,
                location = location,
                required = isTRUE(p$required),
                allow_empty_value = isTRUE(p$allowEmptyValue),
                schema = schema,
                style = encoding$style,
                explode = encoding$explode,
                collection_format = encoding$collection_format
              )
            })
            templates <- unique(gsub(
              '^\\{|\\}$',
              '',
              regmatches(path, gregexpr('\\{[^{}]+\\}', path))[[1L]]
            ))
            path_names <- vapply(
              Filter(function(p) p$location == 'path', params),
              `[[`,
              character(1),
              'name'
            )
            unmatched <- setdiff(path_names, templates)
            if (length(unmatched)) {
              i <- which(vapply(
                params,
                function(p) {
                  p$location == 'path' && p$name == unmatched[[1L]]
                },
                logical(1)
              ))[[1L]]
              schema_problem(
                'unmatched_path_parameter',
                'schema_defect',
                paste('Unmatched path parameter:', unmatched[[1L]]),
                parameter_locations[[i]]
              )
            }
            missing <- setdiff(templates, path_names)
            if (length(missing)) {
              schema_problem(
                'missing_path_parameter',
                'schema_defect',
                paste('Missing path parameter:', missing[[1L]]),
                schema_location('#/paths', path)
              )
            }
            if (body_present) {
              source_location <- body_location
              if (is.null(body)) {
                problem <- list(
                  classification = if (identical(version, '2.0')) {
                    'schema_defect'
                  } else {
                    'capability_gap'
                  },
                  code = 'missing_schema',
                  source_location = body_location
                )
                if (identical(version, '2.0')) {
                  schema_problem(
                    'missing_schema',
                    'schema_defect',
                    'Missing body schema',
                    body_location
                  )
                }
                unsupported('Missing body schema', problem)
              }
              body <- input_schema(
                body,
                document,
                source_location = body_location
              )
              if (
                body_media == 'application/octet-stream' &&
                  !(identical(body$type, 'string') &&
                    identical(body$format, 'binary'))
              ) {
                unsupported('Unsupported binary body schema')
              }
              body <- tryCatch(
                {
                  supported <- supported_body(
                    body,
                    document,
                    source_location = body_location,
                    allow_composition = !form_media(body_media)
                  )
                  if (form_media(body_media)) {
                    body_encoding <- form_encoding(
                      supported,
                      body_encoding,
                      body_media,
                      body_location
                    )
                  }
                  supported
                },
                error = function(e) {
                  if (identical(e$classification, 'schema_defect')) {
                    stop(e)
                  }
                  unsupported(conditionMessage(e), e)
                  body
                }
              )
            }
            candidate <- op$operationId
            if (
              is.null(candidate) || !identical(make.names(candidate), candidate)
            ) {
              candidate <- make.names(paste(
                method,
                gsub('[^A-Za-z0-9]+', '_', path),
                sep = '_'
              ))
            }
            name <- policy$names[[key]] %or% candidate
            if (!identical(make.names(name), name) || name %in% c('...', '')) {
              stop('Invalid operation name')
            }
            list(
              key = key,
              id = paste(policy$service %or% 'default', key),
              service = policy$service %or% 'default',
              operationId = op$operationId,
              name = name,
              method = toupper(method),
              path = path,
              parameters = params,
              body = body,
              body_required = body_required,
              body_media = body_media,
              body_encoding = body_encoding,
              servers = servers,
              server_source = server_source,
              security = if ('security' %in% names(op)) {
                op$security
              } else {
                document$security
              },
              security_schemes = security_schemes,
              source = normalizePath(file, winslash = '/'),
              source_hash = source_hash,
              schema_version = version,
              transport_diagnostics = transport_diagnostics,
              source_operation = op,
              response = op$responses,
              summary = op$summary %or% name
            )
          },
          error = function(e) {
            diagnostics[[length(diagnostics) + 1L]] <<- c(
              list(
                id = id,
                service = policy$service %or% 'default',
                key = key,
                source = file,
                status = 'unsupported',
                reason = conditionMessage(e)
              ),
              diagnostic_fields(e, source_location)
            )
            NULL
          }
        )
        if (!is.null(operation)) {
          operations[[length(operations) + 1L]] <- operation
          if (length(operation$transport_diagnostics)) {
            diagnostics[[length(diagnostics) + 1L]] <- c(
              list(
                id = id,
                service = policy$service %or% 'default',
                key = key,
                source = file,
                status = 'unsupported',
                reason = paste(operation$transport_diagnostics, collapse = '; ')
              ),
              diagnostic_fields(diagnostic_context, source_location)
            )
          }
        }
      }
    }
    if (length(operations) >= first_operation) {
      indices <- seq.int(first_operation, length(operations))
      indices <- indices[vapply(
        operations[indices],
        function(op) !length(op$transport_diagnostics),
        logical(1)
      )]
      if (length(indices)) {
        records <- endpoint_records(document, operations[indices])
        operations[indices] <- records
        for (record in Filter(
          function(x) !is.null(x$parser_failure),
          records
        )) {
          diagnostics[[length(diagnostics) + 1L]] <- c(
            record[c('id', 'service', 'key', 'source')],
            list(
              status = 'unsupported',
              reason = record$parser_failure,
              classification = 'capability_gap',
              code = 'parser_failure',
              source_location = schema_location(
                schema_location('#/paths', record$path),
                tolower(record$method)
              ),
              guidance = 'Review the unsupported schema metadata or supply a complete request mapping.'
            )
          )
        }
        operations <- Filter(function(x) is.null(x$parser_failure), operations)
      }
    }
  }
  ids <- vapply(operations, `[[`, character(1), 'id')
  duplicate_ids <- unique(ids[duplicated(ids)])
  for (id in duplicate_ids) {
    group <- operations[ids == id]
    contract <- function(x) x[setdiff(names(x), c('source', 'source_hash'))]
    if (
      !all(vapply(
        group[-1L],
        function(x) identical(contract(x), contract(group[[1L]])),
        logical(1)
      ))
    ) {
      stop(
        'Conflicting duplicate operation ',
        id,
        ' in ',
        paste(vapply(group, `[[`, character(1), 'source'), collapse = ', ')
      )
    }
  }
  operations <- operations[!duplicated(ids)]
  indexed_keys <- vapply(inventory, `[[`, character(1), 'key')
  unknown <- setdiff(
    union(union(names(policy$names), policy$override_keys), include),
    indexed_keys
  )
  if (length(unknown)) {
    stop('Unknown operation override: ', paste(unknown, collapse = ', '))
  }
  operation_names <- vapply(operations, `[[`, character(1), 'name')
  if (anyDuplicated(operation_names)) {
    stop('Operation name collision; supply reviewed name overrides')
  }
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
    inventory = inventory
  )
}

compare_operations <- function(old, new) {
  identity <- function(op) {
    paste(op$service %or% basename(op$source %or% ''), op$key)
  }
  old <- setNames(
    old$operations,
    vapply(old$operations, identity, character(1))
  )
  new <- setNames(
    new$operations,
    vapply(new$operations, identity, character(1))
  )
  out <- list()
  add <- function(key, status, reason) {
    out[[length(out) + 1L]] <<- list(
      key = key,
      status = status,
      reason = reason
    )
  }
  for (key in setdiff(names(old), names(new))) {
    add(key, 'breaking', 'Operation removed')
  }
  for (key in setdiff(names(new), names(old))) {
    add(key, 'added', 'Operation added')
  }
  for (key in intersect(names(old), names(new))) {
    a <- old[[key]]
    b <- new[[key]]
    ids <- function(ps) {
      setNames(
        ps,
        vapply(ps, function(p) paste(p$location, p$name), character(1))
      )
    }
    ap <- ids(a$parameters)
    bp <- ids(b$parameters)
    for (id in setdiff(names(bp), names(ap))) {
      add(
        key,
        if (isTRUE(bp[[id]]$required)) 'breaking' else 'added',
        paste('Parameter added:', id)
      )
    }
    if (length(setdiff(names(ap), names(bp)))) {
      add(key, 'breaking', 'Parameter removed')
    }
    for (id in intersect(names(ap), names(bp))) {
      if (!identical(ap[[id]], bp[[id]])) {
        add(key, 'review', paste('Parameter contract changed:', id))
      }
    }
    if (
      !identical(a$body, b$body) ||
        !identical(a$body_required, b$body_required) ||
        !identical(a$body_media, b$body_media) ||
        !identical(a$body_encoding, b$body_encoding)
    ) {
      add(key, 'review', 'Body changed')
    }
    if (!identical(a$response, b$response)) {
      add(key, 'unknown', 'Response compatibility is not classified')
    }
    if (
      !identical(a$security, b$security) ||
        !identical(a$security_schemes, b$security_schemes)
    ) {
      add(key, 'review', 'Authentication requirements changed')
    }
    if (
      !identical(a$servers, b$servers) ||
        !identical(a$server_source, b$server_source)
    ) {
      add(key, 'review', 'Server selection changed')
    }
  }
  out
}
