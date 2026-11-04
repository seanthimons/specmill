# Policy-free OpenAPI/Swagger to IR boundary. Native request normalization is
# shared with read_operations() during the staged migration (#229). Policy
# resolves explicit native reviews before the IR view is built; importer_openapi()
# accepts no policy. Compatibility JSON Schema fragments follow in #279.
# Shared native source reader. Keeping this step ahead of selection preserves
# the existing document errors while operation validation remains selection-aware.
openapi_read_source <- function(file) {
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
  list(
    document = document,
    hash = source_hash,
    schemes = security_schemes,
    version = version
  )
}

openapi_ir_object <- function(x = list()) {
  if (length(x)) x else stats::setNames(list(), character())
}

openapi_ir_location <- function(context, pointer) {
  list(file = context$file, pointer = pointer)
}

# Only structural schema slots are traversed. Defaults, examples and enum
# values are data, even when they contain keys named '$ref' or 'properties'.
openapi_ir_type <- function(schema, context, at = '#', depth = 0L) {
  native <- schema
  annotations <- list(
    source_location = openapi_ir_location(context, at),
    native = list(schema = native)
  )
  if (identical(schema, TRUE)) {
    return(c(list(kind = 'any'), annotations))
  }
  if (
    !is.list(schema) ||
      (is.null(names(schema)) &&
        is.null(attr(schema, 'specmill_ref', exact = TRUE))) ||
      depth > 100L
  ) {
    return(c(
      list(kind = 'any', lossy = list('unsupported_schema')),
      annotations
    ))
  }
  names_map <- c(
    title = 'title',
    description = 'description',
    default = 'default',
    const = 'const',
    example = 'example',
    examples = 'examples',
    deprecated = 'deprecated',
    readOnly = 'read_only',
    writeOnly = 'write_only'
  )
  for (name in intersect(names(names_map), names(schema))) {
    annotations[names_map[[name]]] <- list(schema[[name]])
  }
  type <- unlist(schema$type, use.names = FALSE)
  if (
    isTRUE(schema$nullable) &&
      !startsWith(context$version, '3.1') ||
      'null' %in% type && length(type) > 1L
  ) {
    annotations$nullable <- TRUE
  }
  type <- setdiff(type, if (length(type) > 1L) 'null')
  if (
    !is.null(schema$format) &&
      (!is.character(schema$format) ||
        length(schema$format) != 1L ||
        is.na(schema$format))
  ) {
    return(c(
      list(kind = 'any', lossy = list('unsupported_schema')),
      annotations
    ))
  }
  if (length(schema$format)) {
    annotations$native_format <- schema$format
  }
  descend <- function(node, pointer) {
    openapi_ir_type(node, context, pointer, depth + 1L)
  }
  ref <- schema[['$ref']] %or% attr(schema, 'specmill_ref', exact = TRUE)
  if (!is.null(ref)) {
    if (!is.character(ref) || length(ref) != 1L || is.na(ref)) {
      return(c(
        list(kind = 'any', lossy = list('invalid_reference')),
        annotations
      ))
    }
    target <- context$refs[[ref]]
    base <- if (is.null(target)) {
      list(kind = 'any', lossy = list('unresolved_reference'))
    } else {
      list(kind = 'ref', name = target)
    }
    siblings <- schema[setdiff(names(schema), c('$ref', names(names_map)))]
    if (startsWith(context$version, '3.1') && length(siblings)) {
      base <- list(
        kind = 'intersection',
        members = list(base, descend(siblings, at))
      )
    }
    return(c(base, annotations))
  }
  # A type with unsupported assertions stays explicitly lossy. The untouched
  # source spelling remains available to the importer for later migration.
  unsupported <- intersect(
    names(schema),
    c(
      'not',
      'prefixItems',
      'contains',
      'minContains',
      'maxContains',
      'if',
      'then',
      'else',
      'dependentSchemas',
      'dependentRequired',
      'unevaluatedProperties',
      'unevaluatedItems',
      'propertyNames'
    )
  )
  if (length(unsupported)) {
    return(c(
      list(kind = 'any', lossy = list('unsupported_keyword')),
      annotations
    ))
  }
  composition <- intersect(c('oneOf', 'anyOf', 'allOf'), names(schema))
  if (length(composition)) {
    members <- lapply(composition, function(name) {
      variants <- lapply(seq_along(schema[[name]]), function(i) {
        descend(
          schema[[name]][[i]],
          schema_location(schema_location(at, name), i - 1L)
        )
      })
      if (name == 'allOf') {
        list(kind = 'intersection', members = variants)
      } else {
        list(
          kind = 'union',
          mode = if (name == 'oneOf') 'one_of' else 'any_of',
          variants = variants
        )
      }
    })
    siblings <- schema[setdiff(
      names(schema),
      c(composition, names(names_map), 'discriminator')
    )]
    if (length(siblings)) {
      members <- c(members, list(descend(siblings, at)))
    }
    base <- if (length(members) == 1L) {
      members[[1L]]
    } else {
      list(kind = 'intersection', members = members)
    }
  } else if (length(type) > 1L) {
    base <- list(
      kind = 'union',
      mode = 'any_of',
      variants = lapply(type, function(name) {
        member <- schema
        member$type <- name
        descend(member, at)
      })
    )
  } else if (length(schema$enum)) {
    values <- as.list(schema$enum)
    present <- Filter(Negate(is.null), values)
    kinds <- unique(vapply(
      present,
      function(value) {
        if (length(value) != 1L || is.list(value)) {
          'any'
        } else if (is.character(value)) {
          'string'
        } else if (is.logical(value)) {
          'boolean'
        } else if (is.numeric(value)) {
          if (value == trunc(value)) 'integer' else 'float'
        } else {
          'any'
        }
      },
      character(1)
    ))
    if (setequal(kinds, c('integer', 'float'))) {
      kinds <- 'float'
    }
    if (length(kinds) == 1L && kinds != 'any') {
      base <- list(
        kind = 'enum',
        base = kinds,
        values = unname(lapply(values, function(value) list(value = value)))
      )
      if (length(present) < length(values)) annotations$nullable <- TRUE
    } else {
      base <- list(kind = 'any', lossy = list('non_scalar_enum'))
    }
  } else if (identical(type, 'array')) {
    base <- list(
      kind = 'list',
      items = descend(
        schema$items %or% openapi_ir_object(),
        schema_location(at, 'items')
      )
    )
    for (name in intersect(
      c('minItems', 'maxItems', 'uniqueItems'),
      names(schema)
    )) {
      mapped <- c(
        minItems = 'min_items',
        maxItems = 'max_items',
        uniqueItems = 'unique'
      )[[name]]
      base[[mapped]] <- schema[[name]]
    }
  } else if (
    identical(type, 'object') ||
      !is.null(schema$properties) ||
      !is.null(schema$additionalProperties)
  ) {
    properties <- schema$properties %or% list()
    if (
      !length(properties) &&
        is.list(schema$additionalProperties) &&
        !length(schema$patternProperties)
    ) {
      base <- list(
        kind = 'map',
        value = descend(
          schema$additionalProperties,
          schema_location(at, 'additionalProperties')
        )
      )
    } else {
      base <- list(
        kind = 'record',
        fields = unname(lapply(names(properties), function(name) {
          list(
            name = name,
            required = name %in% unlist(schema$required, use.names = FALSE),
            type = descend(
              properties[[name]],
              schema_location(schema_location(at, 'properties'), name)
            )
          )
        }))
      )
      if (!is.null(schema$additionalProperties)) {
        base$additional <- if (is.logical(schema$additionalProperties)) {
          schema$additionalProperties
        } else {
          descend(
            schema$additionalProperties,
            schema_location(at, 'additionalProperties')
          )
        }
      }
      if (length(schema$patternProperties)) {
        base$pattern_properties <- stats::setNames(
          lapply(names(schema$patternProperties), function(name) {
            descend(
              schema$patternProperties[[name]],
              schema_location(schema_location(at, 'patternProperties'), name)
            )
          }),
          names(schema$patternProperties)
        )
      }
    }
    for (name in intersect(
      c('minProperties', 'maxProperties'),
      names(schema)
    )) {
      base[[c(
        minProperties = 'min_properties',
        maxProperties = 'max_properties'
      )[[name]]]] <- schema[[name]]
    }
  } else if (
    length(type) == 1L &&
      type %in% c('string', 'number', 'integer', 'boolean', 'null')
  ) {
    name <- if (type == 'number') 'float' else type
    format <- schema$format %or% ''
    formats <- c(
      'date-time' = 'datetime',
      date = 'date',
      time = 'time',
      duration = 'duration',
      uuid = 'uuid',
      uri = 'uri',
      byte = 'bytes',
      binary = 'bytes'
    )
    if (type == 'string' && format %in% names(formats)) {
      name <- formats[[format]]
    }
    base <- list(kind = 'scalar', name = name)
    if (name == 'bytes') {
      base$encoding <- if (format == 'byte') 'base64' else 'raw'
    }
    if (type == 'integer' && format %in% c('int32', 'int64')) {
      base$bits <- if (format == 'int32') 32L else 64L
      base$signed <- TRUE
      if (format == 'int64') base$lossy <- list('int64_precision')
    }
    if (type == 'number' && format %in% c('float', 'double')) {
      base$bits <- if (format == 'float') 32L else 64L
    }
    constraints <- c(
      minimum = 'minimum',
      maximum = 'maximum',
      multipleOf = 'multiple_of',
      minLength = 'min_length',
      maxLength = 'max_length',
      pattern = 'pattern'
    )
    for (key in intersect(names(constraints), names(schema))) {
      base[[constraints[[key]]]] <- schema[[key]]
    }
    for (bound in c('minimum', 'maximum')) {
      exclusive <- paste0(
        'exclusive',
        if (bound == 'minimum') 'Minimum' else 'Maximum'
      )
      value <- schema[[exclusive]]
      if (isTRUE(value) && !is.null(schema[[bound]])) {
        base[[paste0('exclusive_', bound)]] <- schema[[bound]]
        base[[bound]] <- NULL
      } else if (is.numeric(value)) {
        base[[paste0('exclusive_', bound)]] <- value
      }
    }
  } else {
    base <- list(kind = 'any')
  }
  if (identical(base$kind, 'union') && is.list(schema$discriminator)) {
    discriminator <- schema$discriminator
    if (
      is.character(discriminator$propertyName) &&
        length(discriminator$propertyName) == 1L
    ) {
      base$discriminator <- list(property = discriminator$propertyName)
      if (length(discriminator$mapping)) {
        targets <- lapply(discriminator$mapping, function(ref) {
          if (!is.character(ref) || length(ref) != 1L || is.na(ref)) {
            return(NULL)
          }
          context$refs[[ref]] %or%
            if (ref %in% names(context$schemas)) ref else NULL
        })
        if (!any(vapply(targets, is.null, logical(1)))) {
          base$discriminator$mapping <- targets
        } else {
          base$lossy <- as.list(unique(c(
            unlist(base$lossy),
            'unresolved_discriminator'
          )))
        }
      }
    }
  }
  # Report constraints that this particular node could not express. Keeping a
  # native copy alone must not imply that the neutral type enforces them.
  assertion_keys <- c(
    'enum',
    'properties',
    'required',
    'additionalProperties',
    'patternProperties',
    'minProperties',
    'maxProperties',
    'items',
    'minItems',
    'maxItems',
    'uniqueItems',
    'minimum',
    'maximum',
    'exclusiveMinimum',
    'exclusiveMaximum',
    'multipleOf',
    'minLength',
    'maxLength',
    'pattern',
    'discriminator'
  )
  represented <- switch(
    base$kind,
    enum = 'enum',
    scalar = c(
      'minimum',
      'maximum',
      'exclusiveMinimum',
      'exclusiveMaximum',
      'multipleOf',
      'minLength',
      'maxLength',
      'pattern'
    ),
    record = c(
      'properties',
      'required',
      'additionalProperties',
      'patternProperties',
      'minProperties',
      'maxProperties'
    ),
    map = c('additionalProperties', 'minProperties', 'maxProperties'),
    list = c('items', 'minItems', 'maxItems', 'uniqueItems'),
    union = if (!is.null(base$discriminator)) 'discriminator',
    intersection = assertion_keys,
    character()
  )
  if (
    identical(base$kind, 'enum') &&
      length(type) &&
      !all(
        vapply(
          as.list(schema$enum),
          fixture_type_matches,
          logical(1),
          schema = schema
        )
      )
  ) {
    base$lossy <- as.list(unique(c(
      unlist(base$lossy),
      'type_enum_contradiction'
    )))
  }
  if (length(setdiff(intersect(names(schema), assertion_keys), represented))) {
    base$lossy <- as.list(unique(c(unlist(base$lossy), 'unsupported_keyword')))
  }
  c(base, annotations)
}

openapi_ir_context <- function(document, file) {
  version <- document$openapi %or% document$swagger
  schemas <- document$components$schemas %or%
    document$definitions %or%
    openapi_ir_object()
  prefix <- if (identical(version, '2.0')) {
    '#/definitions'
  } else {
    '#/components/schemas'
  }
  pointers <- vapply(
    names(schemas),
    function(name) schema_location(prefix, name),
    character(1)
  )
  list(
    file = normalizePath(file, winslash = '/', mustWork = TRUE),
    version = version,
    document = document,
    schemas = schemas,
    refs = stats::setNames(as.list(names(schemas)), pointers)
  )
}

openapi_ir_auth <- function(scheme, context, at) {
  scheme <- local_ref(scheme, context$document, source_location = at)
  type <- scheme$type
  if (!is.character(type) || length(type) != 1L || is.na(type)) {
    type <- ''
  }
  http_scheme <- scheme$scheme
  if (
    !is.character(http_scheme) ||
      length(http_scheme) != 1L ||
      is.na(http_scheme)
  ) {
    http_scheme <- ''
  }
  kind <- switch(
    type,
    apiKey = 'api_key',
    basic = 'http_basic',
    oauth2 = 'oauth2',
    openIdConnect = 'openid_connect',
    mutualTLS = 'mutual_tls',
    http = switch(
      tolower(http_scheme),
      basic = 'http_basic',
      bearer = 'http_bearer',
      'custom'
    ),
    'custom'
  )
  result <- list(
    kind = kind,
    source_location = openapi_ir_location(context, at),
    native = scheme
  )
  mapping <- c(
    name = 'name',
    description = 'description',
    bearerFormat = 'bearer_format',
    flows = 'flows',
    tokenUrl = 'token_url'
  )
  for (name in intersect(names(mapping), names(scheme))) {
    result[[mapping[[name]]]] <- scheme[[name]]
  }
  if (kind == 'api_key') {
    result[['in']] <- scheme[['in']]
  }
  result
}

openapi_ir_diagnostic <- function(diagnostic) {
  result <- diagnostic[intersect(
    names(diagnostic),
    c('code', 'classification', 'reason', 'guidance', 'key', 'id', 'status')
  )]
  result$code <- result$code %or% 'unsupported_operation'
  result$source_location <- list(
    file = diagnostic$source,
    pointer = diagnostic$source_location %or% '#'
  )
  result
}

openapi_ir_unrepresented <- function(node, context, at, code) {
  list(
    kind = 'any',
    lossy = list(code),
    source_location = openapi_ir_location(context, at),
    native = list(schema = node)
  )
}

openapi_ir_responses <- function(responses, context, at, produces = NULL) {
  if (!length(responses)) {
    return(list())
  }
  unlist(
    lapply(names(responses), function(status) {
      pointer <- schema_location(at, status)
      response <- tryCatch(
        local_ref(
          responses[[status]],
          context$document,
          source_location = pointer
        ),
        specmill_schema_problem = identity
      )
      if (inherits(response, 'specmill_schema_problem')) {
        return(list(list(
          status = status,
          source_location = openapi_ir_location(context, pointer),
          type = openapi_ir_unrepresented(
            responses[[status]],
            context,
            pointer,
            response$code
          )
        )))
      }
      content <- response$content
      if (identical(context$version, '2.0')) {
        media <- as.character(unlist(
          produces %or% 'application/json',
          use.names = FALSE
        ))
        content <- stats::setNames(
          rep(list(list(schema = response$schema)), length(media)),
          media
        )
      }
      media <- if (length(content)) names(content) else ''
      lapply(media, function(name) {
        result <- list(
          status = status,
          source_location = openapi_ir_location(context, pointer)
        )
        if (!is.null(response$description)) {
          result$description <- response$description
        }
        if (nzchar(name)) {
          result$media <- name
        }
        schema <- if (nzchar(name)) content[[name]]$schema else NULL
        if (!is.null(schema)) {
          schema_at <- if (identical(context$version, '2.0')) {
            schema_location(pointer, 'schema')
          } else {
            schema_location(
              schema_location(schema_location(pointer, 'content'), name),
              'schema'
            )
          }
          result$type <- openapi_ir_type(schema, context, schema_at)
        }
        if (length(response$headers)) {
          result$headers <- stats::setNames(
            lapply(names(response$headers), function(header_name) {
              header_at <- schema_location(
                schema_location(pointer, 'headers'),
                header_name
              )
              header <- tryCatch(
                local_ref(
                  response$headers[[header_name]],
                  context$document,
                  source_location = header_at
                ),
                specmill_schema_problem = identity
              )
              if (inherits(header, 'specmill_schema_problem')) {
                return(openapi_ir_unrepresented(
                  response$headers[[header_name]],
                  context,
                  header_at,
                  header$code
                ))
              }
              openapi_ir_type(header$schema %or% header, context, header_at)
            }),
            names(response$headers)
          )
        }
        result
      })
    }),
    recursive = FALSE,
    use.names = FALSE
  )
}

# Internal entry point: file identity and raw data are source-scoped. No YAML
# policy, exclusions, wrapper renames or service-specific corrections enter it.
importer_openapi <- function(files) {
  if (
    !is.character(files) ||
      !length(files) ||
      anyNA(files) ||
      anyDuplicated(normalizePath(files, mustWork = TRUE))
  ) {
    cli::cli_abort('Supply one or more distinct local OpenAPI schema files')
  }
  records <- openapi_read_records(
    files,
    operation_review_context(prepare_operation_policy(list()))
  )
  openapi_records_ir(
    files,
    operation_records_result(records),
    records$source_data
  )
}

# Materialize the neutral view from native normalization. The same source
# snapshot supplies request records, named types and provenance hashes.
openapi_records_ir <- function(files, parsed, source_data) {
  sources <- list()
  contexts <- list()
  for (i in seq_along(files)) {
    file <- files[[i]]
    document <- source_data[[i]]$document
    context <- openapi_ir_context(document, file)
    source_id <- paste0('source-', i)
    contexts[[normalizePath(file, winslash = '/')]] <- context
    schemes <- document$components$securitySchemes %or%
      document$securityDefinitions %or%
      openapi_ir_object()
    prefix <- if (identical(context$version, '2.0')) {
      '#/securityDefinitions'
    } else {
      '#/components/securitySchemes'
    }
    source <- list(
      id = source_id,
      format = if (identical(context$version, '2.0')) 'swagger' else 'openapi',
      format_version = context$version,
      importer_version = '1',
      file = context$file,
      hash = list(algorithm = 'md5', value = source_data[[i]]$hash),
      servers = list(effective_server(document)),
      auth_schemes = openapi_ir_object(stats::setNames(
        lapply(names(schemes), function(name) {
          openapi_ir_auth(
            schemes[[name]],
            context,
            schema_location(prefix, name)
          )
        }),
        names(schemes)
      )),
      types = openapi_ir_object(stats::setNames(
        lapply(names(context$schemas), function(name) {
          openapi_ir_type(
            context$schemas[[name]],
            context,
            schema_location(
              if (identical(context$version, '2.0')) {
                '#/definitions'
              } else {
                '#/components/schemas'
              },
              name
            )
          )
        }),
        names(context$schemas)
      )),
      native = list(document = document)
    )
    for (field in intersect(
      c('title', 'description', 'version'),
      names(document$info)
    )) {
      source[[field]] <- document$info[[field]]
    }
    sources[[i]] <- source
  }
  records <- c(unname(parsed$operations), unname(parsed$unsupported_operations))
  operations <- lapply(records, function(record) {
    context <- contexts[[record$source]]
    source <- sources[[match(
      record$source,
      vapply(sources, `[[`, character(1), 'file')
    )]]
    at <- schema_location(
      schema_location('#/paths', record$path),
      tolower(record$method)
    )
    operation <- list(
      key = record$key,
      id = record$id,
      name = record$name,
      paradigm = 'rest',
      source = source$id,
      binding = list(method = record$method, path = record$path),
      server = c(
        record$server,
        if (!is.null(record$server_relative)) {
          list(relative = record$server_relative)
        }
      ),
      parameters = unname(lapply(record$parameters, function(parameter) {
        result <- parameter[intersect(
          names(parameter),
          c(
            'name',
            'location',
            'required',
            'allow_empty_value',
            'style',
            'explode',
            'collection_format'
          )
        )]
        result <- result[!vapply(result, is.null, logical(1))]
        result$type <- openapi_ir_type(
          parameter$schema,
          context,
          parameter$source_location
        )
        if (!is.null(parameter$validation_schema)) {
          result$validation_type <- openapi_ir_type(
            parameter$validation_schema,
            context,
            parameter$source_location
          )
        }
        if ('example' %in% names(parameter$example)) {
          result['example'] <- parameter$example['example']
        }
        result$source_location <- openapi_ir_location(
          context,
          parameter$source_location
        )
        result
      })),
      responses = openapi_ir_responses(
        record$response,
        context,
        schema_location(at, 'responses'),
        record$source_operation$produces %or% context$document$produces
      ),
      source_location = openapi_ir_location(context, at),
      native = list(operation = record$source_operation)
    )
    if (!is.null(record$operationId)) {
      operation$native_name <- record$operationId
    }
    for (field in intersect(
      c('summary', 'description', 'deprecated'),
      names(record)
    )) {
      operation[[field]] <- record[[field]]
    }
    if (length(record$source_operation$tags)) {
      operation$tags <- unname(as.list(record$source_operation$tags))
    }
    if (!is.null(record$security)) {
      operation$security <- record$security
    }
    if (!is.null(record$body)) {
      operation$body <- list(
        media = record$body_media,
        required = record$body_required,
        type = openapi_ir_type(
          record$body,
          context,
          schema_location(at, 'requestBody')
        ),
        form_encoding = openapi_ir_object(record$body_encoding)
      )
      if ('example' %in% names(record$body_example)) {
        operation$body['example'] <- record$body_example['example']
      }
    }
    problems <- Filter(
      function(x) identical(x$id, record$id),
      parsed$diagnostics
    )
    if (length(problems)) {
      operation$transport_diagnostics <- lapply(problems, openapi_ir_diagnostic)
    }
    operation
  })
  list(
    ir_version = '1',
    paradigm = 'rest',
    service = list(id = 'default'),
    sources = sources,
    operations = unname(operations),
    diagnostics = unname(lapply(
      c(
        parsed$diagnostics,
        parsed$fixture_diagnostics,
        parsed$server_diagnostics
      ),
      openapi_ir_diagnostic
    ))
  )
}

# Native compatibility view during the policy migration. Selection is decided
# before validating request declarations, so excluded malformed operations keep
# their established inventory status. Corrections/transport reviews still enter
# here through a resolved review context; importer_openapi() uses empty reviews.
openapi_read_records <- function(files, view) {
  source_data <- list()
  operations <- list()
  diagnostics <- list()
  inventory <- list()
  exclusion_errors <- character()
  for (file in files) {
    first_operation <- length(operations) + 1L
    source <- openapi_read_source(file)
    source_data[[length(source_data) + 1L]] <- source
    document <- source$document
    source_hash <- source$hash
    security_schemes <- source$schemes
    version <- source$version
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
            id = paste(view$service, key),
            key = key,
            service = view$service,
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
        review <- view$operation(key, path, toupper(method))
        id <- review$id
        operation_location <- schema_location(
          schema_location('#/paths', path),
          method
        )
        source_location <- operation_location
        diagnostic_context <- NULL
        path_problems <- NULL
        reason <- review$reason
        selected <- !length(reason)
        record <- list(
          id = id,
          key = key,
          service = view$service,
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
        # Reviewed schema parameters dropped before validation (#59), e.g. the
        # multipart upload variant Springdoc folds into JSON operations.
        excluded <- review$setting('excluded_parameters')
        if (selected && length(excluded)) {
          record$excluded_parameters <- excluded
        }
        routes <- review$setting('routes')
        if (selected && length(routes)) {
          record$routes <- routes
        }
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
            response_correction <- review$setting('response_correction')
            response_operation <- response_corrected_operation(
              op,
              response_correction,
              version,
              schema_location(operation_location, 'responses'),
              document$produces
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
            parameter_locations <- vapply(
              seq_along(raw_params),
              function(i) {
                raw_params[[i]][['$ref']] %or% parameter_locations[[i]]
              },
              character(1)
            )
            parameter_groups <- c(
              rep('path', length(item$parameters)),
              rep('operation', length(op$parameters))
            )
            if (!identical(version, '2.0')) {
              reserved <- vapply(
                params,
                function(p) {
                  identical(p[['in']], 'header') &&
                    length(p$name) == 1L &&
                    tolower(p$name) %in%
                      c('accept', 'content-type', 'authorization')
                },
                logical(1)
              )
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
            if (length(excluded)) {
              drop <- vapply(
                params,
                function(p) {
                  is.character(p$name) &&
                    length(p$name) == 1L &&
                    p$name %in% excluded
                },
                logical(1)
              )
              locations <- vapply(
                params[drop],
                function(p) as.character(p[['in']]),
                character(1)
              )
              unmatched <- setdiff(
                excluded,
                vapply(params[drop], `[[`, character(1), 'name')
              )
              if (length(unmatched)) {
                exclusion_errors <- c(
                  exclusion_errors,
                  paste0(key, ': no schema parameter ', unmatched)
                )
              }
              if (!all(locations %in% c('query', 'header', 'cookie'))) {
                exclusion_errors <- c(
                  exclusion_errors,
                  paste0(
                    key,
                    ': only query, header, and cookie parameters can be excluded'
                  )
                )
              }
              params <- params[!drop]
              parameter_locations <- parameter_locations[!drop]
            }
            path_correction <- review$setting('path_correction')
            if (!is.null(path_correction)) {
              # Replace only effective path declarations; keep the archived operation.
              keep <- !vapply(
                params,
                function(p) identical(p[['in']], 'path'),
                logical(1)
              )
              params <- params[keep]
              parameter_locations <- parameter_locations[keep]
              for (name in names(path_correction$parameters)) {
                schema <- config_data(path_correction$parameters[[name]])
                replacement <- list(name = name, `in` = 'path', required = TRUE)
                if (identical(version, '2.0')) {
                  replacement <- c(replacement, schema)
                } else {
                  replacement$schema <- schema
                }
                params <- c(params, list(replacement))
                parameter_locations <- c(
                  parameter_locations,
                  operation_location
                )
              }
            }
            body <- op$requestBody
            body_location <- schema_location(operation_location, 'requestBody')
            body_present <- !is.null(body)
            body_required <- FALSE
            body_media <- 'application/json'
            body_encoding <- list()
            media_correction <- review$setting('media_correction')
            if (
              !is.null(media_correction) &&
                !body_present &&
                !startsWith(version, '2.')
            ) {
              schema_problem(
                'body_media_correction',
                'review_required',
                'Body media correction requires a declared request body',
                body_location
              )
            }
            if (
              !is.null(media_correction) &&
                is.null(media_correction$from) &&
                !startsWith(version, '2.')
            ) {
              schema_problem(
                'body_media_correction',
                'review_required',
                'Missing-media declaration requires a Swagger body without declared media',
                body_location
              )
            }
            text_encoding <- review$setting('text_encoding')
            if (
              !is.character(text_encoding) ||
                length(text_encoding) != 1L ||
                is.na(text_encoding) ||
                !text_encoding %in% c('scalar', 'lines')
            ) {
              schema_problem(
                'text_encoding',
                'review_required',
                'Text encoding must be scalar or lines',
                body_location
              )
            }
            body_example <- list()
            preferred_media <- review$setting('preferred_media')
            body_correction <- review$setting('body_correction')
            if (!is.null(body_correction)) {
              reviewed_body <- if (body_present) {
                local_ref(body, document, source_location = body_location)
              } else {
                NULL
              }
              if (
                !body_present ||
                  startsWith(version, '2.') ||
                  !toupper(method) %in% c('GET', 'HEAD') ||
                  (!is.null(reviewed_body$required) &&
                    !identical(reviewed_body$required, FALSE)) ||
                  review$setting('explicit_media') ||
                  !is.null(media_correction)
              ) {
                schema_problem(
                  'request_body_correction',
                  'review_required',
                  'Body omission requires a declared optional OpenAPI GET/HEAD body and no media override',
                  body_location
                )
              }
              body <- NULL
              body_present <- FALSE
            }
            undefined_body_method <- body_present &&
              !identical(version, '2.0') &&
              toupper(method) %in% c('GET', 'HEAD', 'DELETE')
            if (undefined_body_method && startsWith(version, '3.0')) {
              body <- NULL
              body_present <- FALSE
            } else if (
              undefined_body_method &&
                !review$setting('explicit_media')
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
                  if (
                    length(field$enum) &&
                      length(field$type) &&
                      !any(vapply(
                        field$enum,
                        fixture_type_matches,
                        logical(1),
                        schema = field
                      ))
                  ) {
                    index <- which(vapply(
                      params,
                      function(candidate) identical(candidate, p),
                      logical(1)
                    ))[[1L]]
                    attr(field, 'specmill_enum_location') <- schema_location(
                      parameter_locations[[index]],
                      'enum'
                    )
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
                  body_location,
                  correction = media_correction
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
                body_location,
                correction = media_correction
              )
              schema_media <- media_correction$from %or% body_media
              body_encoding <- body$content[[schema_media]]$encoding %or% list()
              body_example <- body$content[[schema_media]][intersect(
                'example',
                names(body$content[[schema_media]])
              )]
              body_location <- schema_location(
                schema_location(
                  schema_location(body_location, 'content'),
                  schema_media
                ),
                'schema'
              )
              body <- body$content[[schema_media]]$schema
            }
            if (
              !is.null(media_correction) &&
                (!body_present || !identical(body_media, media_correction$to))
            ) {
              schema_problem(
                'body_media_correction',
                'review_required',
                'Body media correction requires a declared request body with the reviewed target media',
                body_location
              )
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
              validation_schema <- NULL
              encoding <- tryCatch(
                {
                  # Encode by the wire shape; validate against the original.
                  if (parameter_composed(schema)) {
                    schema <- supported_body(
                      schema,
                      document,
                      source_location = source_location
                    )
                    validation_schema <- schema
                    schema <- parameter_wire_schema(schema, source_location)
                  }
                  parameter_shape(
                    p,
                    schema,
                    version,
                    source_location,
                    review$setting('query_array_style')
                  )
                },
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
              c(
                list(
                  name = p$name,
                  location = location,
                  required = isTRUE(p$required),
                  allow_empty_value = isTRUE(p$allowEmptyValue),
                  schema = schema,
                  # Swagger 2 has no parameter example; Swagger UI's
                  # x-example convention fills that gap.
                  example = if (
                    identical(version, '2.0') &&
                      !'example' %in% names(p) &&
                      'x-example' %in% names(p)
                  ) {
                    list(example = p[['x-example']])
                  } else {
                    p[intersect('example', names(p))]
                  },
                  source_location = source_location,
                  style = encoding$style,
                  explode = encoding$explode,
                  collection_format = encoding$collection_format
                ),
                if (!is.null(validation_schema)) {
                  list(validation_schema = validation_schema)
                }
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
            for (name in unmatched) {
              i <- which(vapply(
                params,
                function(p) {
                  p$location == 'path' && p$name == name
                },
                logical(1)
              ))[[1L]]
              path_problems[[length(path_problems) + 1L]] <- list(
                code = 'unmatched_path_parameter',
                classification = 'schema_defect',
                message = paste('Unmatched path parameter:', name),
                source_location = parameter_locations[[i]]
              )
            }
            missing <- setdiff(templates, path_names)
            for (name in missing) {
              path_problems[[length(path_problems) + 1L]] <- list(
                code = 'missing_path_parameter',
                classification = 'schema_defect',
                message = paste('Missing path parameter:', name),
                source_location = schema_location('#/paths', path)
              )
            }
            if (length(path_problems)) {
              do.call(schema_problem, path_problems[[1L]])
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
                source_location = body_location,
                recursive_body = identical(body_media, 'application/json')
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
                  if (
                    body_media == 'text/plain' &&
                      (!identical(supported$type, 'string') ||
                        isTRUE(supported$format %in% c('binary', 'byte')) ||
                        length(intersect(
                          names(supported),
                          c('oneOf', 'anyOf', 'allOf')
                        )) ||
                        length(body_encoding))
                  ) {
                    schema_problem(
                      'text_body_schema',
                      'capability_gap',
                      'Plain-text bodies require a scalar string schema without media encoding',
                      body_location
                    )
                  }
                  if (text_encoding != 'scalar' && body_media != 'text/plain') {
                    schema_problem(
                      'text_encoding',
                      'review_required',
                      'Lines encoding requires text/plain media',
                      body_location
                    )
                  }
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
            if (text_encoding != 'scalar' && !body_present) {
              schema_problem(
                'text_encoding',
                'review_required',
                'Lines encoding requires a text/plain request body',
                body_location
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
            name <- review$name(candidate)
            server <- effective_server(document, item, op)
            list(
              key = key,
              id = paste(view$service, key),
              service = view$service,
              operationId = op$operationId,
              name = name,
              method = toupper(method),
              path = path,
              # Only a configured server resolver uses the relative path.
              server = server[names(server) != 'relative'],
              server_relative = server$relative,
              parameters = params,
              body = body,
              body_required = body_required,
              body_media = body_media,
              body_media_correction = config_data(media_correction),
              request_body_correction = config_data(body_correction),
              path_parameters_correction = config_data(path_correction),
              body_encoding = body_encoding,
              text_encoding = text_encoding,
              body_example = body_example,
              security = if ('security' %in% names(op)) {
                op[['security']]
              } else {
                document[['security']]
              },
              security_schemes = security_schemes,
              source = normalizePath(file, winslash = '/'),
              source_hash = source_hash,
              schema_version = version,
              transport_diagnostics = transport_diagnostics,
              source_operation = op,
              response = response_operation$responses,
              response_correction = config_data(response_correction),
              summary = op$summary %or% name
            )
          },
          error = function(e) {
            for (problem in path_problems %or% list(e)) {
              diagnostics[[length(diagnostics) + 1L]] <<- c(
                list(
                  id = id,
                  service = view$service,
                  key = key,
                  source = file,
                  status = 'unsupported',
                  reason = if (inherits(problem, 'condition')) {
                    conditionMessage(problem)
                  } else {
                    problem$message
                  }
                ),
                diagnostic_fields(problem, source_location)
              )
            }
            NULL
          }
        )
        if (!is.null(operation)) {
          if (length(routes)) {
            operation$routes <- routes
          }
          if (length(excluded)) {
            operation$excluded_parameters <- excluded
          }
          operations[[length(operations) + 1L]] <- operation
          if (length(operation$transport_diagnostics)) {
            diagnostics[[length(diagnostics) + 1L]] <- c(
              list(
                id = id,
                service = view$service,
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
  merged <- openapi_merge_duplicate_records(operations, inventory, view)
  list(
    operations = merged$operations,
    inventory = merged$inventory,
    diagnostics = diagnostics,
    exclusion_errors = exclusion_errors,
    source_data = source_data
  )
}

# Duplicate-response review depends on native response contracts. Keep that
# comparison inside the importer until its neutral response equivalent lands.
openapi_merge_duplicate_records <- function(operations, inventory, view) {
  ids <- vapply(operations, `[[`, character(1), 'id')
  duplicate_ids <- unique(ids[duplicated(ids)])
  duplicate_reviews <- view$duplicates()
  reviewed_duplicates <- Filter(
    Negate(is.null),
    duplicate_reviews
  )
  for (key in names(reviewed_duplicates)) {
    review <- reviewed_duplicates[[key]]
    config_fields(review, c('source', 'reason'), 'duplicate_response')
    config_string(review$source, 'duplicate_response.source')
    config_string(review$reason, 'duplicate_response.reason')
    # Absent operations are reported with the other unknown overrides below.
    if (
      identical(view$absent_override_mode, 'warn') &&
        !key %in% vapply(inventory, `[[`, character(1), 'key')
    ) {
      next
    }
    if (
      !key %in%
        vapply(operations[ids %in% duplicate_ids], `[[`, character(1), 'key')
    ) {
      stop('duplicate_response requires a loaded duplicate operation: ', key)
    }
  }
  for (id in duplicate_ids) {
    group <- operations[ids == id]
    reviewed <- duplicate_reviews[[group[[1L]]$key]]
    contract <- function(x) {
      x <- x[setdiff(names(x), c('source', 'source_hash'))]
      if (!is.null(reviewed)) {
        x <- x[setdiff(
          names(x),
          c('response', 'content_type', 'response_schema_type')
        )]
        x$source_operation$responses <- NULL
      }
      x
    }
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
    if (!is.null(reviewed)) {
      selected <- which(vapply(
        group,
        function(x) {
          identical(basename(x$source), reviewed$source) ||
            identical(x$source, reviewed$source)
        },
        logical(1)
      ))
      if (length(selected) != 1L) {
        stop(
          'duplicate_response.source must identify one loaded duplicate: ',
          reviewed$source
        )
      }
      record <- group[[selected]]
      record$response_sources <- list(
        selected = record$source,
        reason = reviewed$reason,
        sources = lapply(group, function(x) {
          x[c(
            'source',
            'source_hash',
            'content_type',
            'response_schema_type',
            'response'
          )]
        })
      )
      operations[[which(ids == id)[[1L]]]] <- record
      for (i in which(vapply(
        inventory,
        function(x) identical(x$id, id),
        logical(1)
      ))) {
        inventory[[i]]$response_sources <- record$response_sources
      }
    }
  }
  operations <- operations[!duplicated(ids)]
  list(operations = operations, inventory = inventory)
}


# Reviewed native patches are resolved before constructing this IR view. They
# never enter importer_openapi(), which remains a policy-free source reader.
openapi_reviewed_records <- function(files, view) {
  records <- openapi_read_records(files, view)
  if (!length(files)) {
    return(records)
  }
  parsed <- operation_records_result(records)
  # Preserve native interleaving of supported and unsupported operations. The
  # public result partitions them only after policy finalization.
  parsed$operations <- records$operations
  parsed$unsupported_operations <- list()
  ir <- openapi_records_ir(files, parsed, records$source_data)
  ir$service$id <- view$service
  ir_compatibility_records(ir, records)
}
