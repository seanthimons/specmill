# Policy-free OpenAPI/Swagger to IR boundary. The legacy operation reader still
# supplies its normalized request metadata during the staged migration (#229).
# Reviewed policy is deliberately not accepted here. Post-import JSON Schema
# consumers remain on the compatibility path until #279.
# Shared native source reader. Keeping this step ahead of selection preserves
# the existing document errors while operation validation remains selection-aware.
openapi_read_source <- function(file, document = read_schema_document(file)) {
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
  if (length(schema$format)) {
    annotations$native_format <- schema$format
  }
  descend <- function(node, pointer) {
    openapi_ir_type(node, context, pointer, depth + 1L)
  }
  ref <- schema[['$ref']] %or% attr(schema, 'specmill_ref', exact = TRUE)
  if (!is.null(ref)) {
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
  kind <- switch(
    scheme$type %or% '',
    apiKey = 'api_key',
    basic = 'http_basic',
    oauth2 = 'oauth2',
    openIdConnect = 'openid_connect',
    mutualTLS = 'mutual_tls',
    http = switch(
      tolower(scheme$scheme %or% ''),
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

openapi_ir_responses <- function(responses, context, at, produces = NULL) {
  if (!length(responses)) {
    return(list())
  }
  unlist(
    lapply(names(responses), function(status) {
      pointer <- schema_location(at, status)
      response <- local_ref(
        responses[[status]],
        context$document,
        source_location = pointer
      )
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
              header <- local_ref(
                response$headers[[header_name]],
                context$document,
                source_location = header_at
              )
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
  parsed <- read_operations(files)
  sources <- list()
  contexts <- list()
  for (i in seq_along(files)) {
    file <- files[[i]]
    document <- read_schema_document(file)
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
      hash = list(algorithm = 'md5', value = unname(tools::md5sum(file))),
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
