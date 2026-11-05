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


# OpenAPI/Swagger compatibility readers and source-backed accessors.
# Keep public bind_tools() function names and signatures intact.

# Native implementation retained for the compatibility context: extract_referenced_schemas.
extract_referenced_schemas <- function(paths) {
  refs <- character(0)

  for (route in names(paths)) {
    path_item <- paths[[route]]

    for (method in intersect(
      names(path_item),
      c("get", "post", "put", "patch", "delete", "head", "options", "trace")
    )) {
      op <- path_item[[method]]

      # Extract from requestBody
      if (!is.null(op$requestBody) && is.list(op$requestBody)) {
        content <- op$requestBody[["content"]] %||% list()
        json_schema <- content[["application/json"]][["schema"]] %||% list()
        if (!is.null(json_schema[["$ref"]])) {
          ref <- json_schema[["$ref"]]
          schema_name <- stringr::str_replace(ref, "#/components/schemas/", "")
          refs <- c(refs, schema_name)
        }
      }
    }
  }

  unique(refs)
}


# Native implementation retained for the compatibility context: filter_components_by_refs.
filter_components_by_refs <- function(components, refs) {
  schemas <- components[["schemas"]] %||% list()

  # Keep only schemas that match refs
  keep_schemas <- intersect(names(schemas), refs)

  # Update components
  components$schemas <- schemas[keep_schemas]
  components
}


# Native implementation retained for the compatibility context: preprocess_schema.
preprocess_schema <- function(schema_file, exclude_endpoints = character()) {
  # Load schema
  openapi <- read_schema_document(schema_file)

  # Filter out unwanted endpoints (preflight, health checks, etc.)
  paths <- openapi$paths
  if (!is.null(paths) && length(paths) > 0 && length(exclude_endpoints) > 0) {
    keep_paths <- names(paths)[
      !stringr::str_detect(names(paths), exclude_endpoints)
    ]
    openapi$paths <- paths[keep_paths]
  }

  # Keep all components/definitions intact - aggressive filtering caused

  # regression issues with nested references (e.g., array items, response schemas)
  # that weren't caught by extract_referenced_schemas()

  openapi
}


# Native implementation retained for the compatibility context: validate_schema_ref.
validate_schema_ref <- function(ref, endpoint_context = NULL) {
  # Must be a non-empty string
  if (!is.character(ref) || !nzchar(ref)) {
    cli::cli_abort(c(
      "x" = "Invalid schema reference: empty or non-character",
      "i" = if (!is.null(endpoint_context)) {
        paste0(
          "Endpoint: ",
          endpoint_context$method,
          " ",
          endpoint_context$route
        )
      } else {
        NULL
      }
    ))
  }

  # Must start with #/ (internal reference)
  if (!grepl("^#/", ref)) {
    cli::cli_abort(c(
      "x" = "Invalid reference format: {.val {ref}}",
      "i" = "References must start with {.code #/}",
      "i" = "External file references are not supported",
      "i" = if (!is.null(endpoint_context)) {
        paste0(
          "Endpoint: ",
          endpoint_context$method,
          " ",
          endpoint_context$route
        )
      } else {
        NULL
      }
    ))
  }

  # Check for external file refs (not supported)
  if (grepl("\\.(json|yaml|yml)#", ref)) {
    cli::cli_abort(c(
      "x" = "External file reference not supported: {.val {ref}}",
      "i" = "All schemas must be in single file",
      "i" = if (!is.null(endpoint_context)) {
        paste0(
          "Endpoint: ",
          endpoint_context$method,
          " ",
          endpoint_context$route
        )
      } else {
        NULL
      }
    ))
  }

  # Check for valid path prefixes
  valid_prefixes <- c("#/components/schemas/", "#/definitions/")
  has_valid_prefix <- any(purrr::map_lgl(
    valid_prefixes,
    ~ grepl(paste0("^", .x), ref)
  ))

  if (!has_valid_prefix) {
    cli::cli_warn(c(
      "!" = "Unusual reference path: {.val {ref}}",
      "i" = "Expected {.code #/components/schemas/} or {.code #/definitions/}",
      "i" = "Proceeding with caution"
    ))
  }

  # Extract and validate schema name
  schema_name <- stringr::str_replace(
    ref,
    "^#/(components/schemas|definitions)/",
    ""
  )
  if (!nzchar(schema_name)) {
    cli::cli_abort(c(
      "x" = "Missing schema name in reference: {.val {ref}}",
      "i" = "Reference path is incomplete (trailing slash only)",
      "i" = if (!is.null(endpoint_context)) {
        paste0(
          "Endpoint: ",
          endpoint_context$method,
          " ",
          endpoint_context$route
        )
      } else {
        NULL
      }
    ))
  }

  TRUE
}


# Native implementation retained for the compatibility context: resolve_schema_ref.
resolve_schema_ref <- function(
  schema_ref,
  components,
  schema_version = NULL,
  max_depth = 3,
  depth = 0,
  endpoint_context = NULL
) {
  # If schema_ref is actual schema (not a reference), just return it
  if (!is.character(schema_ref)) {
    return(schema_ref)
  }

  # Validate reference format
  validate_schema_ref(schema_ref, endpoint_context)

  # Check depth limit (REF-03)
  if (depth > max_depth) {
    cli::cli_abort(c(
      "x" = "Reference depth limit exceeded: {.val {max_depth}}",
      "i" = "Current reference: {.val {schema_ref}}",
      "i" = "This may indicate circular references or overly complex schema",
      "i" = if (!is.null(endpoint_context)) {
        paste0(
          "Endpoint: ",
          endpoint_context$method,
          " ",
          endpoint_context$route
        )
      } else {
        NULL
      }
    ))
  }

  # Sanitize ref_key for use as variable name in R environment
  sanitized_key <- gsub("[^a-zA-Z0-9]", "_", schema_ref)

  # Check for circular reference - only error if we're going DEEPER
  if (exists(sanitized_key, envir = resolve_stack)) {
    existing_depth <- get(sanitized_key, envir = resolve_stack)
    if (depth > existing_depth) {
      cli::cli_warn(c(
        "!" = "Circular reference detected: {.val {schema_ref}}",
        "i" = "Current depth: {depth}, Previous depth: {existing_depth}",
        "i" = "Returning partial schema"
      ))
      return(list(type = "circular_ref", ref = schema_ref))
    }
  }

  # Track reference for cleanup on exit
  assign(sanitized_key, depth, envir = resolve_stack)
  on.exit(
    {
      if (exists(sanitized_key, envir = resolve_stack)) {
        rm(list = sanitized_key, envir = resolve_stack)
      }
    },
    add = TRUE
  )

  # Determine primary and secondary paths based on version (REF-01)
  if (!is.null(schema_version) && identical(schema_version$type, "swagger")) {
    # Swagger 2.0: definitions first, then components
    primary_path <- "#/definitions/"
    secondary_path <- "#/components/schemas/"
    # For Swagger 2.0, components may be normalized definitions (from 07-02)
    primary_container <- components # May be definitions directly or components$schemas
    secondary_container <- components[["schemas"]] %||% list()
  } else {
    # OpenAPI 3.0 or unknown: components first, then definitions
    primary_path <- "#/components/schemas/"
    secondary_path <- "#/definitions/"
    primary_container <- components[["schemas"]] %||% list()
    secondary_container <- components # May have definitions at root
  }

  # Extract schema name from reference
  schema_name <- NULL
  if (grepl(paste0("^", gsub("/", "\\\\/", primary_path)), schema_ref)) {
    schema_name <- stringr::str_replace(
      schema_ref,
      paste0("^", primary_path),
      ""
    )
  } else if (
    grepl(paste0("^", gsub("/", "\\\\/", secondary_path)), schema_ref)
  ) {
    schema_name <- stringr::str_replace(
      schema_ref,
      paste0("^", secondary_path),
      ""
    )
  } else {
    # Unusual path - try extracting from either known prefix
    schema_name <- stringr::str_replace(
      schema_ref,
      "^#/(components/schemas|definitions)/",
      ""
    )
  }

  # Try primary location
  schema_def <- NULL
  if (!is.null(schema_name) && nzchar(schema_name)) {
    schema_def <- primary_container[[schema_name]]
  }

  # Try secondary location (fallback)
  if (is.null(schema_def) || !is.list(schema_def)) {
    fallback_def <- secondary_container[[schema_name]]
    if (!is.null(fallback_def) && is.list(fallback_def)) {
      # Log fallback usage (always, not just verbose)
      cli::cli_alert_info(c(
        "Reference resolved via fallback",
        "i" = "Reference: {.val {schema_ref}}",
        "i" = "Primary location not found: {.path {primary_path}{schema_name}}",
        "i" = "Resolved from: {.path {secondary_path}{schema_name}}"
      ))
      schema_def <- fallback_def
    }
  }

  # Both failed - fatal error
  if (is.null(schema_def) || !is.list(schema_def)) {
    cli::cli_abort(c(
      "x" = "Cannot resolve schema reference: {.val {schema_ref}}",
      "i" = "Tried: {.path {primary_path}{schema_name}}, {.path {secondary_path}{schema_name}}",
      "i" = "Available in primary: {.val {names(primary_container)}}",
      "i" = if (!is.null(endpoint_context)) {
        paste0(
          "Endpoint: ",
          endpoint_context$method,
          " ",
          endpoint_context$route
        )
      } else {
        NULL
      }
    ))
  }

  # Warn if resolved schema is empty
  if (
    length(schema_def) == 0 ||
      (is.null(schema_def$type) &&
        is.null(schema_def$properties) &&
        is.null(schema_def[["$ref"]]))
  ) {
    cli::cli_warn(c(
      "!" = "Resolved schema is empty: {.val {schema_ref}}",
      "i" = "Schema exists but has no type, properties, or nested $ref",
      "i" = "Treating as valid but may indicate schema authoring issue"
    ))
  }

  # Handle schema composition (allOf, oneOf, anyOf) - recurse with depth tracking
  if (!is.null(schema_def[["allOf"]])) {
    return(resolve_schema_ref(
      schema_def[["allOf"]][[1]],
      components,
      schema_version,
      max_depth,
      depth + 1,
      endpoint_context
    ))
  }

  # Handle nested $ref in resolved schema
  if (!is.null(schema_def[["$ref"]])) {
    return(resolve_schema_ref(
      schema_def[["$ref"]],
      components,
      schema_version,
      max_depth,
      depth + 1,
      endpoint_context
    ))
  }

  # Return resolved schema
  schema_def
}


# Native implementation retained for the compatibility context: detect_schema_version.
detect_schema_version <- function(schema) {
  # Check swagger field first (Swagger 2.0)
  if (
    !is.null(schema$swagger) && grepl("^2\\.", as.character(schema$swagger))
  ) {
    return(list(version = as.character(schema$swagger), type = "swagger"))
  }
  # Check openapi field (OpenAPI 3.x)
  if (
    !is.null(schema$openapi) && grepl("^3\\.", as.character(schema$openapi))
  ) {
    return(list(version = as.character(schema$openapi), type = "openapi"))
  }
  # Unknown version
  return(list(version = "unknown", type = "unknown"))
}


# Native implementation retained for the compatibility context: extract_swagger2_body_schema.
extract_swagger2_body_schema <- function(parameters, definitions) {
  if (is.null(parameters) || !is.list(parameters) || length(parameters) == 0) {
    return(list(type = "unknown", properties = list()))
  }

  # Find body parameters (in="body")
  body_params <- purrr::keep(parameters, ~ identical(.x[["in"]], "body"))

  # Find formData parameters for mutual exclusivity check
  formData_params <- purrr::keep(
    parameters,
    ~ identical(.x[["in"]], "formData")
  )

  # BODY-06: Validate body/formData mutual exclusivity
  if (length(body_params) > 0 && length(formData_params) > 0) {
    cli::cli_alert_warning(
      "Swagger 2.0 spec violation: both body and formData parameters present. Using body parameter."
    )
  }

  # BODY-05: Validate single body parameter constraint
  if (length(body_params) > 1) {
    cli::cli_alert_warning(
      "Swagger 2.0 spec violation: multiple body parameters found ({length(body_params)}). Using first body parameter."
    )
  }

  if (length(body_params) == 0) {
    return(list(type = "unknown", properties = list()))
  }

  # Use first body parameter
  body_param <- body_params[[1]]
  body_schema <- body_param[["schema"]] %||% list()

  if (length(body_schema) == 0) {
    return(list(type = "unknown", properties = list()))
  }

  # Check for $ref to #/definitions/
  if (!is.null(body_schema[["$ref"]])) {
    ref <- body_schema[["$ref"]]
    # BODY-03: Resolve $ref to #/definitions/{SchemaName}
    resolved <- resolve_swagger2_definition_ref(ref, definitions)
    if (!is.null(resolved)) {
      body_schema <- resolved
    }
  }

  # Now extract properties from resolved schema (same logic as OpenAPI 3.0)
  schema_type <- body_schema[["type"]] %||% NA

  # BODY-04: Handle object schemas with properties
  # In Swagger 2.0, schemas with properties often omit the explicit type="object"
  has_properties <- !is.null(body_schema[["properties"]]) &&
    length(body_schema[["properties"]]) > 0
  is_object <- schema_type_is(schema_type, "object") ||
    (!length(schema_type) || all(is.na(schema_type))) && has_properties

  if (is_object && has_properties) {
    required_fields <- body_schema[["required"]] %||% character(0)
    metadata <- purrr::imap(
      body_schema[["properties"]],
      function(prop, prop_name) {
        list(
          name = prop_name,
          type = prop[["type"]] %||% NA,
          format = prop[["format"]] %||% NA,
          description = prop[["description"]] %||% "",
          enum = prop[["enum"]] %||% NULL,
          default = prop[["default"]] %||% NA,
          required = prop_name %in% required_fields,
          example = prop[["example"]] %||% prop[["default"]] %||% NA
        )
      }
    )
    names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
    return(list(type = "object", properties = metadata))
  }

  # Handle array type
  if (
    schema_type_is(schema_type, "array") &&
      !is.null(body_schema[["items"]])
  ) {
    items <- body_schema[["items"]]

    # Resolve items $ref if present
    if (!is.null(items[["$ref"]])) {
      resolved_items <- resolve_swagger2_definition_ref(
        items[["$ref"]],
        definitions
      )
      if (
        !is.null(resolved_items) && !is.null(resolved_items[["properties"]])
      ) {
        required_fields <- resolved_items[["required"]] %||% character(0)
        metadata <- purrr::imap(
          resolved_items[["properties"]],
          function(prop, prop_name) {
            list(
              name = prop_name,
              type = prop[["type"]] %||% NA,
              format = prop[["format"]] %||% NA,
              description = prop[["description"]] %||% "",
              enum = prop[["enum"]] %||% NULL,
              default = prop[["default"]] %||% NA,
              required = prop_name %in% required_fields,
              example = prop[["example"]] %||% prop[["default"]] %||% NA
            )
          }
        )
        names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
        ref_type <- stringr::str_replace(items[["$ref"]], "#/definitions/", "")
        return(list(
          type = "array",
          item_schema = list(ref_type = ref_type, properties = metadata)
        ))
      }
    }

    # Inline array items
    item_type <- items[["type"]] %||% NA
    if (schema_type_is(item_type, "string")) {
      metadata <- list(
        query = list(
          name = "query",
          type = "array",
          item_type = "string",
          format = NA,
          description = body_schema[["description"]] %||% "Array of strings",
          enum = NULL,
          default = NA,
          required = TRUE,
          example = items[["example"]] %||% NA
        )
      )
      return(list(
        type = "string_array",
        item_type = "string",
        properties = metadata
      ))
    }
  }

  # Handle simple string type
  if (schema_type_is(schema_type, "string")) {
    metadata <- list(
      query = list(
        name = "query",
        type = "string",
        format = body_schema[["format"]] %||% NA,
        description = body_schema[["description"]] %||% "Query string",
        enum = body_schema[["enum"]] %||% NULL,
        default = body_schema[["default"]] %||% NA,
        required = TRUE,
        example = body_schema[["example"]] %||% NA
      )
    )
    return(list(type = "string", properties = metadata))
  }

  list(type = "unknown", properties = list())
}


# Native implementation retained for the compatibility context: resolve_swagger2_definition_ref.
resolve_swagger2_definition_ref <- function(ref, definitions) {
  if (is.null(ref) || !nzchar(ref)) {
    return(NULL)
  }

  # Parse #/definitions/{SchemaName}
  if (!grepl("^#/definitions/", ref)) {
    return(NULL)
  }

  schema_name <- stringr::str_replace(ref, "#/definitions/", "")

  if (is.null(definitions) || !is.list(definitions)) {
    return(NULL)
  }

  schema_def <- definitions[[schema_name]]
  if (is.null(schema_def) || !is.list(schema_def)) {
    return(NULL)
  }

  schema_def
}


# Native implementation retained for the compatibility context: extract_body_properties.
extract_body_properties <- function(
  request_body,
  components,
  schema_version = NULL
) {
  if (is.null(request_body) || !is.list(request_body)) {
    return(list())
  }

  # If schema_version indicates Swagger 2.0 and request_body is parameters array,
  # delegate to Swagger 2.0 extraction and return early
  if (!is.null(schema_version) && identical(schema_version$type, "swagger")) {
    # For Swagger 2.0: request_body is actually parameters, components is definitions
    return(extract_swagger2_body_schema(request_body, components))
  }

  # Navigate: requestBody -> content -> application/json -> schema
  content <- request_body[["content"]] %||% list()
  json_schema <- content[["application/json"]][["schema"]] %||% list()

  if (length(json_schema) == 0) {
    return(list())
  }

  # Resolve reference if present
  if (!is.null(json_schema[["$ref"]])) {
    json_schema <- resolve_schema_ref(
      json_schema[["$ref"]],
      components,
      schema_version,
      max_depth = 3
    )
  }

  if (!is.null(json_schema[["oneOf"]])) {
    variants <- lapply(json_schema[["oneOf"]], function(variant) {
      if (!is.null(variant[["$ref"]])) {
        variant <- tryCatch(
          resolve_schema_ref(
            variant[["$ref"]],
            components,
            schema_version,
            max_depth = 3
          ),
          error = function(...) NULL
        )
      }
      if (
        is.null(variant) ||
          !identical(variant[["type"]], "object") ||
          is.null(variant[["properties"]]) ||
          length(variant[["properties"]]) == 0
      ) {
        return(NULL)
      }
      variant
    })
    if (length(variants) == 0 || any(vapply(variants, is.null, logical(1)))) {
      return(list(type = "unknown", properties = list()))
    }

    required_by_variant <- lapply(variants, function(variant) {
      unlist(variant[["required"]] %||% character(0), use.names = FALSE)
    })
    required_fields <- Reduce(intersect, required_by_variant)
    properties <- list()
    for (variant in variants) {
      for (prop_name in names(variant[["properties"]])) {
        if (is.null(properties[[prop_name]])) {
          prop <- variant[["properties"]][[prop_name]]
          properties[[prop_name]] <- list(
            name = prop_name,
            type = prop[["type"]] %||% NA,
            format = prop[["format"]] %||% NA,
            description = prop[["description"]] %||% "",
            enum = prop[["enum"]] %||% NULL,
            default = prop[["default"]] %||% NA,
            required = prop_name %in% required_fields,
            example = prop[["example"]] %||% prop[["default"]] %||% NA
          )
        }
      }
    }
    return(list(
      type = "one_of",
      properties = properties,
      required_by_variant = required_by_variant
    ))
  }

  # Check schema type
  type <- json_schema[["type"]] %||% NA

  has_named_properties <- !is.null(json_schema[["properties"]]) &&
    length(json_schema[["properties"]]) > 0
  additional_properties <- json_schema[["additionalProperties"]]
  if (
    identical(type, "object") &&
      !has_named_properties &&
      !is.null(additional_properties) &&
      !identical(additional_properties, FALSE)
  ) {
    return(list(
      type = "unsupported_map",
      properties = list(),
      additional_properties = additional_properties
    ))
  }

  # Handle simple string type
  if (schema_type_is(type, "string")) {
    # Create synthetic parameter metadata for the string body
    metadata <- list(
      query = list(
        name = "query",
        type = "string",
        format = json_schema[["format"]] %||% NA,
        description = json_schema[["description"]] %||%
          "Query string to search for",
        enum = json_schema[["enum"]] %||% NULL,
        default = json_schema[["default"]] %||% NA,
        required = TRUE,
        example = json_schema[["example"]] %||% NA
      )
    )

    return(list(
      type = "string",
      properties = metadata
    ))
  }

  # If array, extract item type
  if (schema_type_is(type, "array") && !is.null(json_schema[["items"]])) {
    items <- json_schema[["items"]]

    # If items is a reference, resolve it
    if (!is.null(items[["$ref"]])) {
      resolved <- resolve_schema_ref(
        items[["$ref"]],
        components,
        schema_version,
        max_depth = 3
      )

      # If resolved is object with properties, extract them
      if (!is.null(resolved[["properties"]])) {
        required_fields <- resolved[["required"]] %||% character(0)
        metadata <- purrr::imap(
          resolved[["properties"]],
          function(prop, prop_name) {
            list(
              name = prop_name,
              type = prop[["type"]] %||% NA,
              format = prop[["format"]] %||% NA,
              description = prop[["description"]] %||% "",
              enum = prop[["enum"]] %||% NULL,
              default = prop[["default"]] %||% NA,
              required = prop_name %in% required_fields,
              example = prop[["example"]] %||% prop[["default"]] %||% NA
            )
          }
        )
        names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
        return(list(
          type = "array",
          item_schema = list(
            ref_type = stringr::str_replace(
              items[["$ref"]],
              "#/components/schemas/",
              ""
            ),
            properties = metadata
          )
        ))
      }
    }

    # Array with inline object items (no $ref, but has type: object with properties)
    item_type <- items[["type"]] %||% NA
    if (
      schema_type_is(item_type, "object") &&
        !is.null(items[["properties"]])
    ) {
      required_fields <- items[["required"]] %||% character(0)
      metadata <- purrr::imap(items[["properties"]], function(prop, prop_name) {
        list(
          name = prop_name,
          type = prop[["type"]] %||% NA,
          format = prop[["format"]] %||% NA,
          description = prop[["description"]] %||% "",
          enum = prop[["enum"]] %||% NULL,
          default = prop[["default"]] %||% NA,
          required = prop_name %in% required_fields,
          example = prop[["example"]] %||% prop[["default"]] %||% NA
        )
      })
      names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
      return(list(
        type = "object_array",
        item_schema = list(
          inline = TRUE,
          properties = metadata
        )
      ))
    }

    # Simple array (e.g., string array)
    if (schema_type_is(item_type, "string")) {
      # String array - create query parameter metadata
      metadata <- list(
        query = list(
          name = "query",
          type = "array",
          item_type = "string",
          format = json_schema[["format"]] %||% NA,
          description = json_schema[["description"]] %||%
            "Array of strings to search for",
          enum = json_schema[["enum"]] %||% NULL,
          default = json_schema[["default"]] %||% NA,
          required = TRUE,
          example = json_schema[["example"]] %||% items[["example"]] %||% NA
        )
      )

      return(list(
        type = "string_array",
        item_type = "string",
        properties = metadata
      ))
    }

    # Non-string arrays without object items
    return(list(
      type = "array",
      item_type = item_type,
      properties = list()
    ))
  }

  # If object, extract properties
  if (schema_type_is(type, "object") && !is.null(json_schema[["properties"]])) {
    required_fields <- json_schema[["required"]] %||% character(0)

    metadata <- purrr::imap(
      json_schema[["properties"]],
      function(prop, prop_name) {
        list(
          name = prop_name,
          type = prop[["type"]] %||% NA,
          format = prop[["format"]] %||% NA,
          description = prop[["description"]] %||% "",
          enum = prop[["enum"]] %||% NULL,
          default = prop[["default"]] %||% NA,
          required = prop_name %in% required_fields,
          example = prop[["example"]] %||% prop[["default"]] %||% NA
        )
      }
    )

    names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
    return(list(
      type = "object",
      properties = metadata
    ))
  }

  # Unknown schema type
  list(type = "unknown", properties = list())
}


# Native implementation retained for the compatibility context: extract_query_params_with_refs.
extract_query_params_with_refs <- function(
  parameters,
  components,
  schema_version = NULL,
  max_depth = 3
) {
  result_names <- character(0)
  result_metadata <- list()

  for (param in parameters) {
    if (is.null(param) || !is.list(param)) {
      next
    }

    param_name <- param[["name"]] %||% ""
    param_in <- param[["in"]] %||% ""

    # Only process query parameters
    if (param_in != "query") {
      next
    }

    schema <- param[["schema"]] %||% list()

    # Check if parameter has $ref
    schema_ref <- schema[["$ref"]]

    if (!is.null(schema_ref) && nzchar(schema_ref)) {
      # Resolve the schema reference
      resolved <- resolve_schema_ref(
        schema_ref,
        components,
        schema_version,
        max_depth,
        depth = 0
      )

      # Check if resolved schema has properties (object)
      properties <- resolved[["properties"]] %||% list()
      required_fields <- resolved[["required"]] %||% character(0)

      if (length(properties) == 0) {
        # Simple type (string, integer, boolean, etc.)
        result_names <- c(result_names, param_name)
        result_metadata[[param_name]] <- list(
          name = param_name,
          type = schema[["type"]] %||% resolved[["type"]] %||% NA,
          format = schema[["format"]] %||% resolved[["format"]] %||% NA,
          description = param[["description"]] %||%
            resolved[["description"]] %||%
            "",
          enum = schema[["enum"]] %||% resolved[["enum"]] %||% NULL,
          default = schema[["default"]] %||% resolved[["default"]] %||% NA,
          required = param[["required"]] %||% FALSE,
          example = param[["example"]] %||% schema[["default"]] %||% NA
        )
      } else {
        # Object with properties - flatten into individual params
        # Use dot notation for nested properties
        for (prop_name in names(properties)) {
          prop <- properties[[prop_name]]

          # Check if property has $ref and resolve it
          prop_ref <- prop[["$ref"]]
          if (!is.null(prop_ref) && nzchar(prop_ref)) {
            # Resolve the nested $ref
            prop <- resolve_schema_ref(
              prop_ref,
              components,
              schema_version,
              max_depth,
              1
            )
          }

          # Extract property metadata first
          prop_type <- prop[["type"]] %||% NA
          prop_format <- prop[["format"]] %||% NA
          prop_desc <- prop[["description"]] %||% ""
          prop_enum <- prop[["enum"]] %||% NULL
          prop_default <- prop[["default"]] %||% NA
          prop_required <- prop_name %in% required_fields
          prop_example <- prop[["example"]] %||% prop_default %||% NA

          # Handle nested objects with dot notation
          if (
            schema_type_is(prop_type, "object") &&
              !is.null(prop[["properties"]])
          ) {
            # This is a nested object - recurse with dot notation
            # DON'T add the parent object to result_names, only the nested properties
            nested_props <- prop[["properties"]]
            nested_required <- prop[["required"]] %||% character(0)

            for (nested_name in names(nested_props)) {
              nested_prop <- nested_props[[nested_name]]
              nested_flat_name <- paste0(
                param_name,
                ".",
                prop_name,
                ".",
                nested_name
              )
              result_names <- c(result_names, nested_flat_name)

              result_metadata[[nested_flat_name]] <- list(
                name = nested_flat_name,
                type = nested_prop[["type"]] %||% NA,
                format = nested_prop[["format"]] %||% NA,
                description = nested_prop[["description"]] %||% "",
                enum = nested_prop[["enum"]] %||% NULL,
                default = nested_prop[["default"]] %||% NA,
                required = nested_name %in% nested_required,
                example = nested_prop[["example"]] %||%
                  nested_prop[["default"]] %||%
                  NA
              )
            }
          } else {
            # Simple property or array (not an object with nested properties)
            flat_name <- paste0(param_name, ".", prop_name)

            # Check if array type and reject binary arrays
            if (schema_type_is(prop_type, "array")) {
              items <- prop[["items"]] %||% list()
              items_type <- items[["type"]] %||% NA
              items_format <- items[["format"]] %||% NA

              # REJECT binary arrays (e.g., files[])
              if (!is.na(items_format) && items_format == "binary") {
                # Skip binary arrays - don't include in query params
                next
              }

              # Support non-binary arrays
              result_names <- c(result_names, flat_name)
              result_metadata[[flat_name]] <- list(
                name = flat_name,
                type = "array",
                item_type = items_type,
                format = prop_format,
                description = prop_desc,
                enum = prop_enum,
                default = prop_default,
                required = prop_required,
                example = prop_example
              )
            } else {
              # Simple property
              result_names <- c(result_names, flat_name)
              result_metadata[[flat_name]] <- list(
                name = flat_name,
                type = prop_type,
                format = prop_format,
                description = prop_desc,
                enum = prop_enum,
                default = prop_default,
                required = prop_required,
                example = prop_example
              )
            }
          }
        }
      }
    } else {
      # No $ref - simple parameter with inline schema
      # REJECT binary arrays (e.g., files[])
      schema_type <- schema[["type"]] %||% NA
      schema_format <- schema[["format"]] %||% NA
      if (schema_type_is(schema_type, "array")) {
        items <- schema[["items"]] %||% list()
        items_format <- items[["format"]] %||% NA
        if (!is.na(items_format) && items_format == "binary") {
          # Skip binary arrays - don't include in query params
          next
        }
      }

      result_names <- c(result_names, param_name)
      result_metadata[[param_name]] <- list(
        name = param_name,
        type = schema_type,
        format = schema_format,
        description = param[["description"]] %||% "",
        enum = schema[["enum"]] %||% NULL,
        default = schema[["default"]] %||% NA,
        required = param[["required"]] %||% FALSE,
        example = param[["example"]] %||% schema[["default"]] %||% NA
      )
    }
  }

  list(names = result_names, metadata = result_metadata)
}


# Native implementation retained for the compatibility context: dedup_params.
dedup_params <- function(params) {
  if (!length(params)) {
    return(list())
  }
  keys <- purrr::map_chr(
    params,
    ~ paste(.x[["name"]] %||% "", .x[["in"]] %||% "", sep = "@")
  )
  params[!duplicated(keys)]
}


# Native implementation retained for the compatibility context: param_names.
param_names <- function(params, where, exclude_pattern = "^files\\[\\]$") {
  purrr::map_chr(
    purrr::keep(
      params,
      ~ identical(.x[["in"]], where) &&
        !grepl(exclude_pattern, .x[["name"]] %||% "")
    ),
    ~ .x[["name"]] %||% ""
  ) -> nm
  nm[nzchar(nm)]
}


# Native implementation retained for the compatibility context: param_metadata.
param_metadata <- function(params, where, exclude_pattern = "^files\\[\\]$") {
  relevant_params <- purrr::keep(
    params,
    ~ identical(.x[["in"]], where) &&
      !grepl(exclude_pattern, .x[["name"]] %||% "")
  )
  if (length(relevant_params) == 0) {
    return(list())
  }

  metadata <- purrr::map(relevant_params, function(p) {
    schema <- p[["schema"]] %||% list()

    list(
      name = p[["name"]] %||% "",
      example = p[["example"]] %||% schema[["default"]] %||% NA, # Fallback to default
      description = p[["description"]] %||% schema[["description"]] %||% "", # Check schema too
      default = schema[["default"]] %||% NA, # Explicit default field
      enum = schema[["enum"]] %||% NULL, # Allowed values
      type = schema[["type"]] %||% NA, # Data type
      required = p[["required"]] %||% FALSE # Required status
    )
  })

  # Filter out params with no name
  metadata <- purrr::keep(metadata, ~ nzchar(.x$name))

  # Convert to named list for easier lookup
  names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
  metadata
}


# Native implementation retained for the compatibility context: get_response_schema_type.
get_response_schema_type <- function(responses, openapi_spec) {
  if (is.null(responses) || !is.list(responses)) {
    return("unknown")
  }

  # Look for successful response codes
  success_codes <- intersect(
    names(responses),
    c("200", "201", "202", "204", "default")
  )
  if (length(success_codes) == 0) {
    return("unknown")
  }

  # Check first successful response
  resp <- responses[[success_codes[1]]]
  content <- resp$content %||% list()

  # Check for binary/image content types first
  if (
    any(grepl("^image/", names(content))) ||
      any(grepl("octet-stream", names(content)))
  ) {
    return("binary")
  }

  # Check application/json response
  json_schema <- content[["application/json"]]$schema %||% list()

  # If no JSON schema, return unknown
  if (length(json_schema) == 0) {
    return("unknown")
  }

  # Check for $ref - need to resolve it
  if (!is.null(json_schema[["$ref"]])) {
    ref <- json_schema[["$ref"]]
    ref_parts <- strsplit(ref, "/", fixed = TRUE)[[1]]
    if (
      length(ref_parts) >= 4 &&
        ref_parts[2] == "components" &&
        ref_parts[3] == "schemas"
    ) {
      schema_name <- ref_parts[4]
      components <- openapi_spec[["components"]] %||% list()
      schemas <- components[["schemas"]] %||% list()
      json_schema <- schemas[[schema_name]] %||% list()
    }
  }

  # Determine type from schema
  schema_type <- json_schema[["type"]] %||% ""

  if (schema_type_is(schema_type, "array")) {
    return("array")
  }
  if (schema_type_is(schema_type, "object")) {
    return("object")
  }
  if (
    any(vapply(
      c("string", "number", "integer", "boolean"),
      function(value) schema_type_is(schema_type, value),
      logical(1)
    ))
  ) {
    return("scalar")
  }

  # Default to unknown
  return("unknown")
}


# Native implementation retained for the compatibility context: extract_body_schema_metadata.
extract_body_schema_metadata <- function(request_body, openapi_spec) {
  if (is.null(request_body) || !is.list(request_body)) {
    return(list())
  }

  # Navigate: requestBody -> content -> application/json -> schema -> $ref
  content <- request_body[["content"]] %||% list()
  json_schema <- content[["application/json"]][["schema"]] %||% list()

  # Check if this is a schema reference
  ref <- json_schema[["$ref"]]
  if (is.null(ref) || !nzchar(ref)) {
    return(list())
  }

  # Parse the reference (e.g., "#/components/schemas/LookupRequest")
  # Format: #/components/schemas/{SchemaName}
  ref_parts <- strsplit(ref, "/", fixed = TRUE)[[1]]
  if (
    length(ref_parts) < 4 ||
      ref_parts[2] != "components" ||
      ref_parts[3] != "schemas"
  ) {
    return(list())
  }

  schema_name <- ref_parts[4]

  # Resolve the schema from components
  components <- openapi_spec[["components"]] %||% list()
  schemas <- components[["schemas"]] %||% list()
  schema_def <- schemas[[schema_name]]

  if (is.null(schema_def) || !is.list(schema_def)) {
    return(list())
  }

  # Extract properties
  properties <- schema_def[["properties"]] %||% list()
  required_fields <- schema_def[["required"]] %||% character(0)

  # Build metadata for each property
  metadata <- purrr::imap(properties, function(prop, prop_name) {
    list(
      name = prop_name,
      description = prop[["description"]] %||% "",
      type = prop[["type"]] %||% NA,
      enum = prop[["enum"]] %||% NULL,
      default = prop[["default"]] %||% NA,
      required = prop_name %in% required_fields,
      example = prop[["example"]] %||% prop[["default"]] %||% NA
    )
  })

  # Filter and return as named list
  metadata <- purrr::keep(metadata, ~ nzchar(.x$name))
  names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
  metadata
}


# Native implementation retained for the compatibility context: openapi_to_spec.
openapi_to_spec <- function(
  openapi,
  default_base_url = NULL,
  name_strategy = c("operationId", "method_path"),
  preprocess = TRUE
) {
  if (!requireNamespace("purrr", quietly = TRUE)) {
    stop("Package 'purrr' is required.")
  }
  if (!requireNamespace("tibble", quietly = TRUE)) {
    stop("Package 'tibble' is required.")
  }
  if (!requireNamespace("stringr", quietly = TRUE)) {
    stop("Package 'stringr' is required.")
  }

  name_strategy <- match.arg(name_strategy)

  # Preprocess schema if requested
  if (preprocess && is.character(openapi) && file.exists(openapi)) {
    openapi <- preprocess_schema(openapi)
  }

  # Detect schema version (Swagger 2.0 vs OpenAPI 3.0)
  schema_version <- detect_schema_version(openapi)
  cli::cli_alert_info(
    "Detected schema version: {schema_version$type} {schema_version$version}"
  )

  # Get schema definitions/components based on version
  # Swagger 2.0 uses "definitions", OpenAPI 3.0 uses "components/schemas"
  if (identical(schema_version$type, "swagger")) {
    definitions <- openapi[["definitions"]] %||% list()
    # For Swagger 2.0, we'll pass definitions to body extraction
    components <- list(schemas = definitions) # Normalize for resolve_schema_ref compatibility
  } else {
    definitions <- NULL
    components <- openapi[["components"]] %||% list()
  }

  base_url <- default_base_url %||%
    {
      srv <- openapi$servers
      if (is.list(srv) && length(srv) && !is.null(srv[[1]]$url)) {
        srv[[1]]$url
      } else {
        "https://example.com"
      }
    }

  paths <- openapi$paths
  if (!is.list(paths) || !length(paths)) {
    stop("OpenAPI object has no 'paths'.")
  }

  purrr::imap_dfr(paths, function(path_item, route) {
    path_level_params <- path_item$parameters %||% list()
    # The calling context supplies the supported method set.
    meths <- intersect(names(path_item), supported_methods)

    purrr::map_dfr(meths, function(method) {
      op <- path_item[[method]]
      op_params <- op$parameters %||% list()
      parameters <- dedup_params(c(path_level_params, op_params))

      path_names <- order_path_by_route(param_names(parameters, "path"), route)

      # Extract query parameters with $ref resolution
      components <- openapi[["components"]] %||% list()
      query_result <- extract_query_params_with_refs(
        parameters,
        components,
        schema_version
      )
      query_names <- query_result$names # Use resolved/flattened parameter names
      query_meta <- query_result$metadata # Use enhanced metadata from resolved schemas

      # Extract parameter metadata (examples and descriptions)
      path_meta <- param_metadata(parameters, "path")

      # Extract request body schema metadata for POST/PUT/PATCH
      body_props <- if (method %in% c("post", "put", "patch")) {
        if (identical(schema_version$type, "swagger")) {
          # Swagger 2.0: body is in parameters array, resolve against definitions
          extract_body_properties(
            op$parameters,
            definitions,
            schema_version = schema_version
          )
        } else {
          # OpenAPI 3.0: body is in requestBody object
          extract_body_properties(op$requestBody, components)
        }
      } else {
        list(type = "unknown", properties = list())
      }

      # Extract body parameter names (ordered by required first, then alphabetically)
      body_names <- if (
        body_props$type %in%
          c("object", "one_of") &&
          length(body_props$properties) > 0
      ) {
        required_names <- names(purrr::keep(
          body_props$properties,
          ~ .x$required
        ))
        optional_names <- names(purrr::keep(
          body_props$properties,
          ~ !.x$required
        ))
        c(required_names, optional_names)
      } else if (
        body_props$type %in%
          c("array", "object_array") &&
          !is.null(body_props$item_schema)
      ) {
        # For array bodies with object items (ref or inline), extract object properties
        item_properties <- body_props$item_schema$properties
        if (length(item_properties) > 0) {
          required_names <- names(purrr::keep(item_properties, ~ .x$required))
          optional_names <- names(purrr::keep(item_properties, ~ !.x$required))
          c(required_names, optional_names)
        } else {
          character(0)
        }
      } else if (
        body_props$type %in%
          c("string", "string_array") &&
          length(body_props$properties) > 0
      ) {
        # Simple body types (string or string_array) - extract synthetic parameter names
        names(body_props$properties)
      } else {
        character(0)
      }

      # Create simplified body_meta for backward compatibility
      body_meta <- if (length(body_names) > 0) {
        purrr::map(body_names, function(name) {
          if (body_props$type %in% c("object", "one_of")) {
            body_props$properties[[name]]
          } else if (
            body_props$type %in%
              c("array", "object_array") &&
              !is.null(body_props$item_schema)
          ) {
            body_props$item_schema$properties[[name]]
          } else if (body_props$type %in% c("string", "string_array")) {
            # Simple body types - use the synthetic parameter metadata
            body_props$properties[[name]]
          } else {
            list(
              name = name,
              type = NA,
              description = "",
              enum = NULL,
              default = NA,
              required = FALSE,
              example = NA
            )
          }
        })
      } else {
        list()
      }
      names(body_meta) <- body_names

      # Combine all parameters (path parameters first, then query parameters)
      combined <- c(path_names, query_names)

      # Detect if endpoint has request body
      has_body <- if (identical(schema_version$type, "swagger")) {
        # Swagger 2.0: check for body parameter in parameters array
        any(purrr::map_lgl(
          op$parameters %||% list(),
          ~ identical(.x[["in"]], "body")
        ))
      } else {
        # OpenAPI 3.0: check for requestBody object
        !is.null(op$requestBody)
      }
      operationId <- op$operationId %||% paste(method, route)
      summary <- op$summary %||% ""

      # Extract deprecated status
      deprecated <- op$deprecated %||% FALSE

      # Extract description for enhanced documentation
      description <- op$description %||% ""

      needs_resolver <- if (method %in% c("post", "put", "patch") && has_body) {
        if (identical(schema_version$type, "swagger")) {
          FALSE
        } else {
          body_requires_resolution(op$requestBody, openapi)
        }
      } else {
        FALSE
      }

      # Get body schema type for more specific code generation
      body_schema_type <- if (
        method %in% c("post", "put", "patch") && has_body
      ) {
        if (identical(schema_version$type, "swagger")) {
          # Use the type from body_props which was already extracted
          body_props$type %||% "unknown"
        } else {
          if (isTRUE(body_props$type %in% c("one_of", "unsupported_map"))) {
            body_props$type
          } else {
            get_body_schema_type(op$requestBody, openapi)
          }
        }
      } else {
        "unknown"
      }

      # Detect response schema type for enhanced documentation
      response_schema_type <- get_response_schema_type(op$responses, openapi)

      # Extract response content types
      response_content_types <- character(0)
      if (!is.null(op$responses)) {
        # Look for successful responses (200, 201, etc.)
        success_codes <- intersect(
          names(op$responses),
          c("200", "201", "202", "204", "default")
        )
        for (code in success_codes) {
          resp <- op$responses[[code]]
          if (!is.null(resp$content) && is.list(resp$content)) {
            response_content_types <- c(
              response_content_types,
              names(resp$content)
            )
          }
        }
      }
      response_content_types <- unique(response_content_types)
      content_type <- if (length(response_content_types) > 0) {
        paste(response_content_types, collapse = ", ")
      } else {
        ""
      }

      # Detect pagination strategy (PAG-01, PAG-03)
      pagination_info <- detect_pagination(
        route = route,
        path_params = if (length(path_names) > 0) {
          paste(path_names, collapse = ",")
        } else {
          ""
        },
        query_params = if (length(query_names) > 0) {
          paste(query_names, collapse = ",")
        } else {
          ""
        },
        body_params = if (length(body_names) > 0) {
          paste(body_names, collapse = ",")
        } else {
          ""
        }
      )

      fn <- if (name_strategy == "operationId") {
        sanitize_name(operationId)
      } else {
        sanitize_name(method_path_name(route, method))
      }

      tibble::tibble(
        route = route,
        method = toupper(method),
        summary = summary,
        has_body = has_body,
        params = if (length(combined) > 0) {
          paste(combined, collapse = ",")
        } else {
          ""
        },
        # Separate path and query parameters for flexible stub generation
        path_params = if (length(path_names) > 0) {
          paste(path_names, collapse = ",")
        } else {
          ""
        },
        query_params = if (length(query_names) > 0) {
          paste(query_names, collapse = ",")
        } else {
          ""
        },
        body_params = if (length(body_names) > 0) {
          paste(body_names, collapse = ",")
        } else {
          ""
        },
        num_path_params = length(path_names),
        num_body_params = length(body_names),
        # Parameter metadata with examples and descriptions
        path_param_metadata = list(path_meta),
        query_param_metadata = list(query_meta),
        body_param_metadata = list(body_meta),
        # Response content type(s)
        content_type = content_type,
        needs_resolver = needs_resolver,
        body_schema_type = body_schema_type,
        # Deprecated status and description
        deprecated = deprecated,
        description = description,
        # Response schema type for enhanced documentation
        response_schema_type = response_schema_type,
        # NEW: Schema type classification
        # - "json": POST/PUT/PATCH with request body
        # - "path": GET with path parameters (appends to URL)
        # - "query_only": GET without path parameters (static endpoint, params via query string)
        # NOTE: method is already uppercased at this point, so compare with uppercase
        request_type = if (
          toupper(method) %in% c("POST", "PUT", "PATCH") && has_body
        ) {
          "json"
        } else if (length(path_names) > 0) {
          "path"
        } else {
          "query_only"
        },
        # NEW: Body schema full information
        body_schema_full = list(body_props),
        # NEW: Body item type for array schemas
        body_item_type = if (!is.null(body_props$item_type)) {
          body_props$item_type
        } else if (!is.null(body_props$item_schema)) {
          body_props$item_schema$ref_type
        } else {
          NA
        },
        # Pagination detection (Phase 19)
        pagination_strategy = pagination_info$strategy,
        pagination_metadata = list(pagination_info)
      )
    })
  })
}


# Native implementation retained for the compatibility context: endpoint_records.
endpoint_records <- function(document, operations) {
  context <- new.env(parent = asNamespace('specmill'))
  context[['%||%']] <- function(x, y) {
    if (is.null(x) || is.atomic(x) && length(x) == 1L && is.na(x)) y else x
  }
  context$supported_methods <- c(
    'get',
    'post',
    'put',
    'patch',
    'delete',
    'head',
    'options',
    'trace'
  )
  context$PAGINATION_REGISTRY <- list()
  context$body_requires_resolution <- function(...) FALSE
  context$get_body_schema_type <- function(body, document) {
    body <- local_ref(body, document)
    content <- body$content %||% list()
    media <- intersect(
      c(
        'application/json',
        'application/octet-stream',
        'application/x-www-form-urlencoded',
        'multipart/form-data'
      ),
      names(content)
    )
    if (
      !length(media) ||
        media[[1L]] %in%
          c(
            'application/x-www-form-urlencoded',
            'multipart/form-data'
          )
    ) {
      return('unknown')
    }
    schema <- content[[media[[1L]]]]$schema
    if (is.null(schema) || !is.list(schema)) {
      return('unknown')
    }
    schema <- local_ref(schema, document)
    if (schema_type_is(schema$type, 'object')) {
      'simple_object'
    } else if (
      is.character(schema$type) &&
        length(schema$type) == 1L &&
        !is.na(schema$type)
    ) {
      schema$type
    } else {
      'unknown'
    }
  }
  bind_tools('schema', context)
  bind_tools('parser', context)
  # Pagination inference is client policy. A neutral page parameter remains
  # an ordinary scalar input and must not trigger EPA-specific diagnostics.
  context$detect_pagination <- function(...) list(strategy = 'none')
  # Unsupported operations must not be sent to the compatibility parser.
  paths <- list()
  for (op in operations) {
    path <- document$paths[[op$path]]
    paths[[op$path]][[tolower(op$method)]] <- path[[tolower(op$method)]]
    paths[[op$path]]$parameters <- path$parameters
  }
  document$paths <- paths
  parse <- function(input) {
    suppressMessages(context$openapi_to_spec(
      input,
      preprocess = FALSE
    ))
  }
  record <- function(table, op) {
    keys <- paste(table$method, table$route)
    row <- match(op$key, keys)
    if (is.na(row)) {
      stop(
        'Supported operation was not represented by the shared parser: ',
        op$key
      )
    }
    output <- lapply(table[row, , drop = FALSE], `[[`, 1L)
    output$needs_resolver <- NULL
    utils::modifyList(output, op, keep.null = TRUE)
  }
  table <- tryCatch(parse(document), error = identity)
  if (!inherits(table, 'error')) {
    records <- lapply(operations, function(op) {
      tryCatch(record(table, op), error = identity)
    })
    if (!any(vapply(records, inherits, logical(1), 'error'))) {
      return(records)
    }
  }

  # Keep one malformed compatibility record from aborting its document. The
  # normal path above still parses the document only once.
  diagnostics <- list()
  records <- lapply(operations, function(op) {
    item <- document$paths[[op$path]]
    one <- document
    one$paths <- list()
    one$paths[[op$path]] <- list()
    one$paths[[op$path]]$parameters <- item$parameters
    one$paths[[op$path]][[tolower(op$method)]] <- item[[tolower(op$method)]]
    parsed <- tryCatch(parse(one), error = identity)
    if (!inherits(parsed, 'error')) {
      parsed <- tryCatch(record(parsed, op), error = identity)
      if (!inherits(parsed, 'error')) {
        return(parsed)
      }
    }
    op$parser_failure <- conditionMessage(parsed)
    diagnostics[[length(diagnostics) + 1L]] <<- list(
      key = op$key,
      code = 'parser_failure',
      reason = op$parser_failure
    )
    op
  })
  attr(records, 'parser_diagnostics') <- diagnostics
  records
}


# Native implementation retained for the compatibility context: input_schema.
input_schema <- function(
  schema,
  document,
  seen = character(),
  source_location = '#',
  parameter_items = FALSE,
  recursive_body = FALSE,
  optional = FALSE
) {
  fail <- function(
    code,
    message,
    classification = 'schema_defect',
    at = source_location
  ) {
    schema_problem(code, classification, message, at)
  }
  if (is.null(schema)) {
    return(stats::setNames(list(), character()))
  }
  if (!is.list(schema) || is.null(names(schema))) {
    if (
      is.logical(schema) &&
        length(schema) == 1L &&
        startsWith(document$openapi %or% '', '3.1')
    ) {
      fail(
        'boolean_schema',
        'Unsupported boolean input schema',
        'capability_gap'
      )
    }
    fail('invalid_schema', 'Input schema must be an object')
  }
  ref <- schema[['$ref']]
  # Only optional property back-edges belong to the finite request-body slice.
  if (
    recursive_body &&
      optional &&
      length(ref) == 1L &&
      ref %in% seen &&
      identical(names(schema), '$ref')
  ) {
    target <- local_ref(schema, document, schema_context = TRUE)
    marker <- target[intersect(names(target), c('readOnly', 'writeOnly'))]
    return(structure(marker, specmill_ref = ref))
  }
  if (!is.null(ref) && !identical(names(schema), '$ref')) {
    recursive_body <- FALSE
  }
  schema <- local_ref(
    schema,
    document,
    seen,
    source_location,
    schema_context = TRUE
  )
  if (!is.null(ref)) {
    source_location <- ref
  }
  if (is.null(names(schema))) {
    fail('invalid_schema', 'Input schema must be an object')
  }
  seen <- c(seen, ref)
  type <- unlist(schema$type, use.names = FALSE)
  if (
    length(type) &&
      (!is.character(type) ||
        !all(
          type %in%
            c(
              'string',
              'integer',
              'number',
              'boolean',
              'object',
              'array',
              'null'
            )
        ))
  ) {
    fail(
      'invalid_type',
      'Invalid input schema type',
      at = schema_location(source_location, 'type')
    )
  }
  version <- document$openapi %or% document$swagger
  if ('type' %in% names(schema)) {
    if (
      !length(type) ||
        anyDuplicated(type) ||
        (!startsWith(version, '3.1') &&
          (length(type) != 1L || 'null' %in% type))
    ) {
      fail(
        'invalid_type',
        'Invalid input schema type for this schema version',
        at = schema_location(source_location, 'type')
      )
    }
    schema$type <- type
  }
  # OpenAPI 3.1 uses JSON Schema null types; nullable is not an assertion.
  if (startsWith(version, '3.1')) {
    schema$nullable <- NULL
  }
  # An untyped enum takes the one scalar type its values share (#95).
  if (!'type' %in% names(schema) && length(schema$enum)) {
    values <- as.list(schema$enum)
    present <- values[!vapply(values, is.null, logical(1))]
    kinds <- unique(vapply(
      present,
      function(value) {
        if (length(value) != 1L || is.na(value)) {
          NA_character_
        } else if (is.character(value)) {
          'string'
        } else if (is.logical(value)) {
          'boolean'
        } else if (is.numeric(value)) {
          if (value == round(value)) 'integer' else 'number'
        } else {
          NA_character_
        }
      },
      character(1)
    ))
    if (setequal(kinds, c('integer', 'number'))) {
      kinds <- 'number'
    }
    if (length(kinds) == 1L && !is.na(kinds)) {
      nullable <- length(present) < length(values) && startsWith(version, '3.1')
      schema$type <- c(kinds, if (nullable) 'null')
    }
  }
  for (field in intersect(names(schema), c('readOnly', 'writeOnly'))) {
    value <- schema[[field]]
    if (!is.logical(value) || length(value) != 1L || is.na(value)) {
      fail(
        'invalid_property_direction',
        paste(field, 'must be a boolean'),
        at = schema_location(source_location, field)
      )
    }
  }
  if (isTRUE(schema$readOnly) && isTRUE(schema$writeOnly)) {
    fail(
      'invalid_property_direction',
      'A property cannot be both readOnly and writeOnly'
    )
  }
  if (
    identical(schema$type, 'array') &&
      is.null(schema$items) &&
      (startsWith(version, '3.0') ||
        (identical(version, '2.0') && parameter_items))
  ) {
    fail(
      'missing_array_items',
      'Array schema requires items in this schema version and parameter context',
      at = schema_location(source_location, 'items')
    )
  }
  if (!is.null(schema$properties)) {
    if (!is.list(schema$properties) || is.null(names(schema$properties))) {
      fail('invalid_properties', 'Invalid input properties')
    }
    schema$properties <- stats::setNames(
      lapply(
        names(schema$properties),
        function(name) {
          input_schema(
            schema$properties[[name]],
            document,
            seen,
            schema_location(
              schema_location(source_location, 'properties'),
              name
            ),
            recursive_body = recursive_body,
            optional = !name %in% unlist(schema$required)
          )
        }
      ),
      names(schema$properties)
    )
  }
  required <- unlist(schema$required, use.names = FALSE)
  if (
    length(required) &&
      (!is.character(required) ||
        anyNA(required) ||
        anyDuplicated(required) ||
        !all(nzchar(required)))
  ) {
    fail('invalid_required', 'Invalid required input fields')
  }
  if (length(schema$properties) && length(required)) {
    read_only <- names(schema$properties)[vapply(
      schema$properties,
      function(property) isTRUE(property$readOnly),
      logical(1)
    )]
    schema$required <- schema$required[!required %in% read_only]
  }
  if (!is.null(schema$items)) {
    schema$items <- input_schema(
      schema$items,
      document,
      seen,
      schema_location(source_location, 'items'),
      parameter_items,
      recursive_body = recursive_body
    )
  }
  for (field in intersect(names(schema), c('oneOf', 'anyOf', 'allOf'))) {
    branches <- schema[[field]]
    if (!is.list(branches) || !length(branches) || !is.null(names(branches))) {
      fail('invalid_composition', 'Invalid input schema composition')
    }
    schema[[field]] <- lapply(
      seq_along(branches),
      function(i) {
        input_schema(
          branches[[i]],
          document,
          seen,
          schema_location(schema_location(source_location, field), i - 1L),
          recursive_body = recursive_body
        )
      }
    )
  }
  if (
    'additionalProperties' %in%
      names(schema) &&
      !is.list(schema$additionalProperties) &&
      !(is.logical(schema$additionalProperties) &&
        length(schema$additionalProperties) == 1L &&
        !is.na(schema$additionalProperties))
  ) {
    fail(
      'invalid_additional_properties',
      'additionalProperties must be a boolean or schema object'
    )
  }
  if (is.list(schema$additionalProperties)) {
    schema$additionalProperties <- input_schema(
      schema$additionalProperties,
      document,
      seen,
      schema_location(source_location, 'additionalProperties'),
      recursive_body = recursive_body
    )
  }
  if (
    length(schema$enum) &&
      length(type) &&
      !any(vapply(
        schema$enum,
        fixture_type_matches,
        logical(1),
        schema = schema
      ))
  ) {
    attr(schema, 'specmill_enum_location') <- attr(
      schema,
      'specmill_enum_location'
    ) %or%
      schema_location(source_location, 'enum')
  }
  if (recursive_body && !is.null(ref)) {
    attr(schema, 'specmill_id') <- ref
  }
  schema
}


# Native implementation retained for the compatibility context: local_ref.
local_ref <- function(
  node,
  document,
  seen = character(),
  source_location = '#',
  schema_context = FALSE
) {
  fail <- function(code, message, classification = 'schema_defect') {
    schema_problem(code, classification, message, source_location)
  }
  if (!is.list(node)) {
    fail('invalid_reference_target', 'Reference target must be an object')
  }
  reference_error <- node[['x-specmill-reference-error']]
  if (!is.null(reference_error)) {
    fail(
      reference_error$code %or% 'external_reference',
      reference_error$message %or% 'Unresolved reference',
      'capability_gap'
    )
  }
  ref <- node[['$ref']]
  if (is.null(ref)) {
    return(node)
  }
  if (!is.character(ref) || length(ref) != 1L || is.na(ref)) {
    fail('invalid_reference', 'Reference must be a string')
  }
  if (!startsWith(ref, '#/')) {
    fail(
      if (startsWith(ref, '#')) 'local_reference' else 'external_reference',
      paste(
        if (startsWith(ref, '#')) {
          'Unsupported local reference fragment:'
        } else {
          'Unsupported external reference:'
        },
        ref
      ),
      'capability_gap'
    )
  }
  if (ref %in% seen) {
    fail(
      'recursive_reference',
      paste('Unsupported local recursive reference:', ref),
      'capability_gap'
    )
  }
  if (length(seen) >= 100L) {
    fail(
      'reference_depth',
      'Reference nesting exceeds 100 levels',
      'capability_gap'
    )
  }
  parts <- strsplit(sub('^#/', '', ref), '/', fixed = TRUE)[[1]]
  if (any(grepl('~([^01]|$)', parts))) {
    fail('invalid_reference', paste('Invalid reference escape:', ref))
  }
  parts <- gsub('~0', '~', gsub('~1', '/', parts, fixed = TRUE), fixed = TRUE)
  value <- document
  for (part in parts) {
    if (!is.list(value)) {
      fail('unresolved_reference', paste('Missing reference:', ref))
    }
    value <- value[[part]]
  }
  if (is.null(value)) {
    fail('unresolved_reference', paste('Missing reference:', ref))
  }
  value <- local_ref(value, document, c(seen, ref), ref, schema_context)
  siblings <- node[setdiff(names(node), '$ref')]
  if (
    schema_context &&
      startsWith(document$openapi %or% '', '3.1') &&
      length(siblings)
  ) {
    annotations <- names(siblings) %in%
      c(
        'title',
        'description',
        'summary',
        'example',
        'examples',
        'default',
        'deprecated'
      ) |
      startsWith(names(siblings), 'x-')
    assertions <- siblings[!annotations]
    if (length(assertions)) {
      value <- list(allOf = list(value, assertions))
    }
    value[names(siblings)[annotations]] <- siblings[annotations]
  }
  value
}


# Native implementation retained for the compatibility context: supported_body.
supported_body <- function(
  body,
  document,
  seen = character(),
  source_location = '#',
  allow_composition = TRUE,
  in_composition = FALSE
) {
  fail <- function(
    code,
    message,
    classification = 'capability_gap',
    at = source_location
  ) {
    schema_problem(code, classification, message, at)
  }
  if (!is.list(body)) {
    fail('body_shape', 'Unsupported body shape')
  }
  if (!is.null(attr(body, 'specmill_ref'))) {
    return(body)
  }
  ref <- body[['$ref']]
  body <- local_ref(body, document, seen, source_location)
  if (!is.null(ref)) {
    source_location <- ref
  }
  seen <- c(seen, ref)
  composition <- intersect(names(body), c('oneOf', 'anyOf', 'allOf'))
  composed <- in_composition || length(composition) || length(body$type) > 1L
  if (length(composition) && !allow_composition) {
    fail('body_composition', 'Unsupported body composition')
  }
  if (allow_composition) {
    known <- c(
      '$ref',
      'type',
      'properties',
      'required',
      'additionalProperties',
      'items',
      'oneOf',
      'anyOf',
      'allOf',
      'enum',
      'const',
      'minimum',
      'maximum',
      'exclusiveMinimum',
      'exclusiveMaximum',
      'multipleOf',
      'minLength',
      'maxLength',
      'pattern',
      'minItems',
      'maxItems',
      'uniqueItems',
      'minProperties',
      'maxProperties',
      'title',
      'description',
      'default',
      'example',
      'examples',
      'nullable',
      'readOnly',
      'writeOnly',
      'deprecated',
      'format',
      'discriminator',
      'xml',
      '$id',
      '$schema',
      '$comment',
      'externalDocs',
      'contentEncoding',
      'contentMediaType'
    )
    unknown <- setdiff(names(body), known)
    unknown <- unknown[!startsWith(unknown, 'x-')]
    if (length(unknown)) {
      fail(
        'body_keyword',
        paste('Unsupported body validation keyword:', unknown[[1L]]),
        at = schema_location(source_location, unknown[[1L]])
      )
    }
    for (field in intersect(
      names(body),
      c(
        'minimum',
        'maximum',
        'exclusiveMinimum',
        'exclusiveMaximum',
        'multipleOf',
        'minLength',
        'maxLength',
        'minItems',
        'maxItems',
        'minProperties',
        'maxProperties',
        'uniqueItems',
        'nullable',
        'pattern',
        'enum'
      )
    )) {
      value <- body[[field]]
      boolean <- field %in%
        c('uniqueItems', 'nullable') ||
        (field %in%
          c('exclusiveMinimum', 'exclusiveMaximum') &&
          !startsWith(document$openapi %or% '', '3.1'))
      valid <- if (boolean) {
        is.logical(value) && length(value) == 1L && !is.na(value)
      } else if (field == 'pattern') {
        is.character(value) && length(value) == 1L && !is.na(value)
      } else if (field == 'enum') {
        is.list(value) && is.null(names(value))
      } else {
        is.numeric(value) && length(value) == 1L && is.finite(value)
      }
      if (
        valid &&
          field %in%
            c(
              'minLength',
              'maxLength',
              'minItems',
              'maxItems',
              'minProperties',
              'maxProperties'
            )
      ) {
        valid <- value >= 0 && value == trunc(value)
      }
      if (valid && field == 'multipleOf') {
        valid <- value > 0
      }
      if (!valid) {
        fail(
          'invalid_constraint',
          paste('Invalid body constraint:', field),
          'schema_defect',
          schema_location(source_location, field)
        )
      }
    }
  }
  recurse <- function(schema, at) {
    supported_body(schema, document, seen, at, allow_composition, composed)
  }
  if (is.list(body$items)) {
    body$items <- recurse(body$items, schema_location(source_location, 'items'))
  }
  if (is.list(body$additionalProperties)) {
    body$additionalProperties <- recurse(
      body$additionalProperties,
      schema_location(source_location, 'additionalProperties')
    )
  }
  if (is.list(body$properties)) {
    if (
      is.null(names(body$properties)) || !all(nzchar(names(body$properties)))
    ) {
      fail('invalid_properties', 'Invalid body properties', 'schema_defect')
    }
    body$properties <- stats::setNames(
      lapply(names(body$properties), function(name) {
        recurse(
          body$properties[[name]],
          schema_location(schema_location(source_location, 'properties'), name)
        )
      }),
      names(body$properties)
    )
  }
  for (field in composition) {
    branches <- body[[field]]
    if (!is.list(branches) || !length(branches) || !is.null(names(branches))) {
      fail('invalid_composition', 'Invalid body composition', 'schema_defect')
    }
    body[[field]] <- lapply(seq_along(branches), function(i) {
      recurse(
        branches[[i]],
        schema_location(schema_location(source_location, field), i - 1L)
      )
    })
  }
  type <- unlist(body$type, use.names = FALSE)
  if (!composed && !length(type) && length(body$properties)) {
    body$type <- 'object'
    type <- 'object'
  }
  if ('array' %in% type && is.null(body$items)) {
    body$items <- list()
  }
  if ('object' %in% type) {
    required <- unlist(body$required, use.names = FALSE)
    if (
      length(required) &&
        (!is.character(required) ||
          (isFALSE(body$additionalProperties) &&
            !all(required %in% names(body$properties))))
    ) {
      fail('invalid_required', 'Invalid required body fields', 'schema_defect')
    }
  }
  if (
    !composed &&
      !length(type) &&
      !length(setdiff(
        names(body),
        c(
          'title',
          'description',
          'example',
          'default',
          'nullable',
          'readOnly',
          'writeOnly',
          'deprecated'
        )
      ))
  ) {
    return(body)
  }
  if (!composed && !length(type)) {
    fail('body_shape', 'Unsupported body shape')
  }
  if (!allow_composition && (length(type) != 1L || identical(type, 'null'))) {
    fail('body_shape', 'Unsupported body shape')
  }
  if (
    length(type) &&
      !all(
        type %in%
          c('string', 'integer', 'number', 'boolean', 'object', 'array', 'null')
      )
  ) {
    fail('body_shape', 'Unsupported body shape')
  }
  body
}


# Native implementation retained for the compatibility context: effective_server.
effective_server <- function(
  document,
  item = list(),
  operation = list(),
  origin = ''
) {
  # Kept with the diagnostic so a configured client resolver can supply the host.
  relative <- NULL
  tryCatch(
    {
      if (identical(document$swagger, '2.0')) {
        schemes <- operation$schemes %or% document$schemes
        host <- document$host
        if (is.null(schemes) || !length(schemes) || is.null(host)) {
          if (!valid_server_url(origin)) {
            base_path <- document$basePath %or% '/'
            if (
              is.character(base_path) &&
                length(base_path) == 1L &&
                !is.na(base_path) &&
                startsWith(base_path, '/')
            ) {
              relative <- base_path
            }
            stop(
              'Swagger host/scheme requires a recorded origin or explicit base URL override'
            )
          }
          if (is.null(schemes) || !length(schemes)) {
            schemes <- sub('://.*$', '', origin)
          }
          if (is.null(host)) host <- sub('^https?://([^/]+).*$', '\\1', origin)
        }
        schemes <- unique(unlist(schemes))
        if (length(schemes) != 1L) {
          stop('Ambiguous Swagger schemes')
        }
        base_path <- document$basePath %or% '/'
        if (
          !is.character(base_path) ||
            length(base_path) != 1L ||
            is.na(base_path) ||
            !startsWith(base_path, '/')
        ) {
          stop('Invalid Swagger basePath')
        }
        urls <- paste0(schemes, '://', host, base_path)
      } else {
        servers <- if ('servers' %in% names(operation)) {
          operation$servers
        } else if ('servers' %in% names(item)) {
          item$servers
        } else {
          document$servers
        }
        if (!is.list(servers) && !is.null(servers)) {
          stop('Invalid server array')
        }
        urls <- vapply(
          servers,
          function(server) {
            if (!is.list(server)) {
              stop('Invalid server object')
            }
            url <- server$url
            if (!is.character(url) || length(url) != 1L || is.na(url)) {
              stop('Invalid server URL')
            }
            for (name in names(server$variables)) {
              variable <- server$variables[[name]]
              if (!is.list(variable)) {
                stop('Invalid server variable')
              }
              value <- variable$default
              if (!is.character(value) || length(value) != 1L || is.na(value)) {
                stop('Unresolved server variable default')
              }
              if (
                !is.null(variable$enum) && !value %in% unlist(variable$enum)
              ) {
                stop('Server variable default is outside its enum')
              }
              url <- gsub(paste0('{', name, '}'), value, url, fixed = TRUE)
            }
            url
          },
          character(1)
        )
        if (!length(urls)) urls <- '/'
      }
      if (any(grepl('[{}]', urls))) {
        stop('Unresolved server variables')
      }
      if (!all(grepl('^[A-Za-z][A-Za-z0-9+.-]*:', urls))) {
        if (!nzchar(origin)) {
          # Network-path references (//host) would replace the resolver's host.
          if (
            length(unique(urls)) == 1L &&
              grepl('^(/(?!/)|$)', urls[[1L]], perl = TRUE)
          ) {
            relative <- urls[[1L]]
          }
          stop(
            'Relative server URL requires a recorded origin or explicit base URL override'
          )
        }
        if (!valid_server_url(origin)) {
          stop('Invalid server origin')
        }
        if (!requireNamespace('httr2', quietly = TRUE)) {
          stop('Install httr2 to resolve schema origins')
        }
        urls <- tryCatch(
          vapply(
            urls,
            function(url) {
              httr2::url_build(httr2::url_parse(url, base_url = origin))
            },
            character(1)
          ),
          error = function(e) stop('Unsupported relative server URL')
        )
      }
      urls <- unique(urls)
      if (length(urls) != 1L) {
        stop('Ambiguous server selection: supply an explicit base URL override')
      }
      if (!valid_server_url(urls)) {
        stop(
          'Unsupported server URL: expected absolute HTTP(S) without credentials, query, or fragment'
        )
      }
      list(url = urls)
    },
    error = function(e) {
      c(
        list(diagnostic = conditionMessage(e)),
        if (!is.null(relative)) list(relative = relative)
      )
    }
  )
}


# Native implementation retained for the compatibility context: schema_server.
schema_server <- function(document, origin = '') {
  effective_server(document, origin = origin)$url %or% ''
}


# Native implementation retained for the compatibility context: authentication_envvars.
authentication_envvars <- function(document, package) {
  schemes <- document$components$securitySchemes %or%
    document$securityDefinitions %or%
    list()
  ids <- sort(names(schemes), method = 'radix')
  supported <- vapply(
    ids,
    function(id) {
      scheme <- local_ref(schemes[[id]], document)
      identical(scheme$type, 'apiKey') ||
        (identical(scheme$type, 'http') &&
          identical(tolower(scheme$scheme), 'bearer'))
    },
    logical(1)
  )
  ids <- ids[supported]
  if (!length(ids)) {
    return(setNames(list(), character()))
  }
  values <- toupper(paste(
    configuration_words(package),
    vapply(ids, configuration_words, character(1)),
    sep = '_'
  ))
  if (anyDuplicated(values)) {
    stop('Security scheme names produce colliding environment variables')
  }
  as.list(setNames(values, ids))
}


# Native implementation retained for the compatibility context: operation_authentication.
operation_authentication <- function(operation, envvars) {
  requirements <- operation$security %or% list()
  if (!is.list(requirements) || !is.null(names(requirements))) {
    stop('Security must be an array')
  }
  lapply(requirements, function(requirement) {
    if (
      !is.list(requirement) ||
        (length(requirement) && is.null(names(requirement)))
    ) {
      stop('Security requirement must be an object')
    }
    lapply(names(requirement), function(id) {
      scheme <- operation$security_schemes[[id]]
      if (is.null(scheme)) {
        stop('Undefined security scheme: ', id)
      }
      type <- scheme$type
      supported <- identical(type, 'apiKey') ||
        (identical(type, 'http') && identical(tolower(scheme$scheme), 'bearer'))
      if (!supported) {
        return(list(scheme = id, type = type %or% 'unsupported'))
      }
      envvar <- config_string(
        envvars[[id]],
        paste('authentication environment variable for', id)
      )
      if (!grepl('^[A-Za-z_][A-Za-z0-9_]*$', envvar)) {
        stop('Invalid credential environment variable')
      }
      # Role lists (valid in OpenAPI 3.1, common in 3.0) never reach the wire.
      if (type == 'apiKey') {
        location <- config_string(scheme[['in']], 'API key location')
        if (!location %in% c('header', 'query', 'cookie')) {
          stop('Unsupported API key location')
        }
        name <- config_string(scheme$name, 'API key name')
        if (grepl('[\r\n]', name)) stop('Invalid API key name')
      } else {
        location <- 'header'
        name <- 'Authorization'
      }
      list(
        scheme = id,
        type = if (type == 'http') 'bearer' else type,
        location = location,
        name = name,
        envvar = envvar
      )
    })
  })
}


# Native implementation retained for the compatibility context: response_corrected_operation.
response_corrected_operation <- function(
  operation,
  correction,
  version,
  at,
  produces = NULL
) {
  if (is.null(correction)) {
    return(operation)
  }
  validate_response_correction(correction)
  if (
    !is.list(operation$responses) ||
      length(operation$responses) ||
      is.null(names(operation$responses))
  ) {
    schema_problem(
      'response_correction',
      'review_required',
      'Response correction requires an explicitly empty responses object',
      at
    )
  }
  response <- list(description = correction$description)
  if (startsWith(version, '2.')) {
    media <- operation$produces %or% produces
    if (
      length(media) &&
        !correction$media_type %in% unlist(media, use.names = FALSE)
    ) {
      schema_problem(
        'response_correction',
        'review_required',
        'Response correction conflicts with declared media',
        at
      )
    }
    if (!length(media)) operation$produces <- list(correction$media_type)
  } else {
    response$content <- setNames(
      list(structure(list(), names = character())),
      correction$media_type
    )
  }
  operation$responses <- setNames(list(response), correction$status)
  operation
}


# Native implementation retained for the compatibility context: reviewed_response_validation.
reviewed_response_validation <- function(service, reports) {
  corrections <- Filter(
    Negate(is.null),
    service$policy$response_corrections %or% list()
  )
  views <- list()
  for (file in names(reports)) {
    if (!length(corrections)) {
      next
    }
    document <- tryCatch(
      read_schema_document(file, resolve_references = FALSE),
      error = identity
    )
    if (inherits(document, 'error')) {
      next
    }
    applied <- list()
    for (key in names(corrections)) {
      method <- tolower(sub(' .*', '', key))
      path <- sub('^[^ ]+ ', '', key)
      if (
        is.null(document$paths[[path]][[method]]) ||
          length(operation_selection_reason(
            key,
            path,
            toupper(method),
            service$policy
          ))
      ) {
        next
      }
      at <- schema_location(schema_location('#/paths', path), method)
      corrected <- tryCatch(
        response_corrected_operation(
          document$paths[[path]][[method]],
          corrections[[key]],
          document$openapi %or% document$swagger,
          at,
          document$produces
        ),
        error = identity
      )
      # Leave a rejected correction to the normal parser's operation diagnostic.
      if (inherits(corrected, 'error')) {
        next
      }
      document$paths[[path]][[method]] <- corrected
      applied[[key]] <- corrections[[key]]
    }
    if (!length(applied)) {
      next
    }
    report <- schema_validation_report(file, document)
    report$service <- service$id %or% 'default'
    report$response_corrections <- config_data(applied)
    views[[file]] <- report
    reports[[file]] <- report
  }
  list(reports = reports, views = views)
}


# Native implementation retained for the compatibility context: operation_contract.
operation_contract <- function(document, path, method) {
  canonical <- function(node, references) {
    if (!is.list(node)) {
      return(node)
    }
    if (!is.null(node[['$ref']])) {
      ref <- node[['$ref']]
      if (!exists(ref, references, inherits = FALSE)) {
        assign(ref, NULL, references)
        assign(
          ref,
          canonical(local_ref(node, document), references),
          references
        )
      }
    }
    node <- lapply(node, canonical, references = references)
    if (!is.null(names(node))) {
      node <- node[order(names(node), method = 'radix')]
    }
    node
  }
  item <- local_ref(document$paths[[path]], document)
  operation <- item[[tolower(method)]]
  references <- new.env(parent = emptyenv())
  contract <- canonical(
    list(
      operation = operation,
      parameters = item$parameters,
      servers = item$servers %or% document$servers,
      security = operation[['security']] %or% document[['security']],
      host = document$host,
      basePath = document$basePath,
      schemes = document$schemes
    ),
    references
  )
  list(root = contract, references = as.list(references, sorted = TRUE))
}


# Native implementation retained for the compatibility context: schema_report_operations.
schema_report_operations <- function(path, policy) {
  if (!file.exists(path)) {
    return(list())
  }
  document <- read_schema_document(path)
  # Diff identities are method/path pairs. Pending facade overrides must not
  # hide new operations or prevent reporting a removed operation.
  keys <- schema_operation_keys(document)
  policy$names <- stats::setNames(
    as.list(paste0('operation_', seq_along(keys))),
    keys
  )
  policy$override_keys <- NULL
  policy$exclude_parameters_overrides <- NULL
  parsed <- read_operations(path, policy)
  selected <- Filter(function(x) x$status != 'excluded', parsed$inventory)
  stats::setNames(
    lapply(selected, function(record) {
      item <- document$paths[[record$path]]
      list(
        route = record$path,
        method = record$method,
        summary = item[[tolower(record$method)]]$summary %or% '',
        contract = operation_contract(document, record$path, record$method)
      )
    }),
    vapply(selected, `[[`, character(1), 'key')
  )
}


# Native implementation retained for the compatibility context: schema_operation_keys.
schema_operation_keys <- function(document) {
  unlist(
    lapply(names(document$paths), function(path) {
      item <- local_ref(document$paths[[path]], document)
      methods <- intersect(
        names(item),
        c('get', 'post', 'put', 'patch', 'delete', 'head', 'options', 'trace')
      )
      if (length(methods)) paste(toupper(methods), path) else character()
    }),
    use.names = FALSE
  ) %or%
    character()
}


# Native implementation retained for the compatibility context: operation_fingerprint.
operation_fingerprint <- function(file, key) {
  document <- read_schema_document(file)
  method <- sub(' .*', '', key)
  path <- substring(key, nchar(method) + 2L)
  item <- document$paths[[path]]
  if (is.null(item)) {
    stop('Operation is absent from the schema: ', key)
  }
  item <- local_ref(item, document)
  if (!is.list(item[[tolower(method)]])) {
    stop('Operation is absent from the schema: ', key)
  }
  normalize <- function(node) {
    if (is.character(node)) {
      return(gsub('\r\n?', '\n', node))
    }
    if (is.list(node)) lapply(node, normalize) else node
  }
  contract <- normalize(operation_contract(document, path, method))
  json <- jsonlite::toJSON(
    list(key = key, contract = contract),
    auto_unbox = TRUE,
    null = 'null',
    digits = NA
  )
  paste0(
    'v',
    deferral_fingerprint_version,
    ':',
    digest::digest(
      enc2utf8(as.character(json)),
      algo = 'sha256',
      serialize = FALSE
    )
  )
}


# Native implementation retained for the compatibility context: provenance_references.
provenance_references <- function(x, document) {
  found <- list()
  pending <- character()
  collect <- function(node) {
    if (!is.list(node)) {
      return(invisible())
    }
    ref <- node[['$ref']]
    if (is.character(ref) && length(ref) == 1L && startsWith(ref, '#/')) {
      pending <<- c(pending, ref)
    }
    for (child in node) {
      collect(child)
    }
  }
  collect(x)
  while (length(pending)) {
    ref <- pending[[1L]]
    pending <- pending[-1L]
    if (ref %in% names(found)) {
      next
    }
    target <- document
    for (part in strsplit(sub('^#/', '', ref), '/', fixed = TRUE)[[1L]]) {
      part <- gsub('~0', '~', gsub('~1', '/', part, fixed = TRUE), fixed = TRUE)
      target <- if (is.list(target)) target[[part]] else NULL
    }
    # A missing target is recorded too, so it counts and is not looked up again.
    found[ref] <- list(target)
    collect(target)
  }
  # Radix order is locale-independent, so digests match across machines.
  found[order(names(found) %or% character(), method = 'radix')]
}


# Native implementation retained for the compatibility context: provenance_documents.
provenance_documents <- function() {
  cache <- new.env(parent = emptyenv())
  function(source) {
    if (is.null(cache[[source]])) {
      # External references are inlined; local ones stay for the walk above.
      cache[[source]] <- read_schema_document(
        source,
        resolve_references = TRUE
      )
    }
    cache[[source]]
  }
}


# Native implementation retained for the compatibility context: testing_response_schema.
testing_response_schema <- function(response) {
  if (is.null(response)) {
    return(list(media = NULL, schema = NULL))
  }
  if (!is.null(response$content)) {
    media <- names(response$content)
    json <- grep('^application/json|[+]json', media, value = TRUE)
    return(list(
      media = sort(media),
      schema = if (length(json)) response$content[[json[[1L]]]]$schema
    ))
  }
  # Swagger 2 keeps the schema directly on the response.
  list(media = NULL, schema = response$schema)
}


# Native implementation retained for the compatibility context: openapi_nullable.
openapi_nullable <- function(node) {
  if (!is.list(node)) {
    return(node)
  }
  node <- lapply(node, openapi_nullable)
  if (isTRUE(node$nullable)) {
    if (!is.null(node$type)) {
      node$type <- unique(c(unlist(node$type), 'null'))
    }
    if (!is.null(node$enum)) {
      node$enum <- c(node$enum, list(NULL))
    }
  }
  node
}


# Native implementation retained for the compatibility context: review_interaction.
review_interaction <- function(interaction, op, documents) {
  request <- interaction$request
  response <- interaction$response
  if (
    !identical(toupper(request$method %or% ''), op$method) ||
      !testing_path_matches(request$uri %or% '', op$path)
  ) {
    return(NULL)
  }
  status <- response$status
  status <- as.character(if (is.list(status)) status$status_code else status)
  body <- recorded_body(response$body)
  if (!is.character(body) || length(body) != 1L) {
    return(list(status = 'unchecked', reason = 'response body is not text'))
  }
  document <- documents(op$source)
  candidates <- c(status, paste0(substr(status, 1L, 1L), 'XX'), 'default')
  found <- intersect(candidates, names(op$response %or% list()))
  declared <- if (length(found)) op$response[[found[[1L]]]]
  # Shared responses are references into the document.
  for (i in seq_len(5L)) {
    ref <- declared[['$ref']]
    if (!is.character(ref) || !startsWith(ref, '#/')) {
      break
    }
    declared <- json_pointer(document, ref)
  }
  schema <- testing_response_schema(declared)$schema
  if (is.null(schema)) {
    return(list(status = 'unchecked', reason = 'no JSON response schema'))
  }
  dialect <- if (grepl('^3[.]1', document$openapi %or% '')) '2020' else '04'
  root <- list(allOf = list(schema))
  if (!is.null(document$components$schemas)) {
    root$components <- list(schemas = document$components$schemas)
  }
  if (!is.null(document$definitions)) {
    root$definitions <- document$definitions
  }
  root <- response_schema_clean(root)
  if (grepl('^3[.]0', document$openapi %or% '')) {
    root <- openapi_nullable(root)
  }
  result <- response_validator()$call(
    'validate_response',
    V8::JS(jsonlite::toJSON(
      root,
      auto_unbox = TRUE,
      null = 'null',
      digits = NA
    )),
    body,
    dialect
  )
  switch(
    result$status,
    agrees = list(status = 'agrees'),
    disagrees = list(
      status = 'disagrees',
      errors = paste0(
        ifelse(nzchar(result$errors$path), result$errors$path, '/'),
        ' ',
        result$errors$message
      )
    ),
    unparsed = list(status = 'unchecked', reason = 'response body is not JSON'),
    list(
      status = 'unchecked',
      reason = paste('response schema does not compile:', result$errors$message)
    )
  )
}


# Native implementation retained for the compatibility context: schema_servers.
schema_servers <- function(file) {
  document <- read_schema_document(file, resolve_references = FALSE)
  urls <- if (identical(document$swagger, '2.0')) {
    paste0(document$host %or% '', document$basePath %or% '/')
  } else {
    vapply(
      document$servers %or% list(),
      function(server) as.character(server$url %or% ''),
      character(1)
    )
  }
  urls <- sub('(?<=.)/+$', '', urls, perl = TRUE)
  urls[!nzchar(urls)] <- '/'
  if (!length(urls)) '/' else urls
}


# Source metadata for configuration review. Callbacks preserve the ordering of
# source diagnostics and policy decisions without exposing the native document.
openapi_configuration_source <- function(schema) {
  document <- read_schema_document(schema)
  version <- document$openapi %or% document$swagger
  if (is.null(version) || !grepl('^(3\\.[01]\\.|2\\.0$)', version)) {
    stop('Unsupported schema version')
  }
  if (!is.list(document$paths) || is.null(names(document$paths))) {
    stop('Missing paths')
  }
  list(
    operations = function(visit, report) {
      for (path in sort(names(document$paths), method = 'radix')) {
        item <- tryCatch(
          local_ref(
            document$paths[[path]],
            document,
            source_location = schema_location('#/paths', path)
          ),
          error = identity
        )
        if (inherits(item, 'error')) {
          report(paste('PATH', path), 'unsupported', conditionMessage(item))
          next
        }
        for (method in intersect(
          c(
            'get',
            'post',
            'put',
            'patch',
            'delete',
            'head',
            'options',
            'trace'
          ),
          names(item)
        )) {
          key <- paste(toupper(method), path)
          operation <- tryCatch(
            local_ref(
              item[[method]],
              document,
              source_location = schema_location(
                schema_location('#/paths', path),
                method
              )
            ),
            error = identity
          )
          if (inherits(operation, 'error')) {
            report(key, 'unsupported', conditionMessage(operation))
            next
          }
          tags <- operation$tags
          if (
            !is.null(tags) &&
              (!is.list(tags) ||
                !is.null(names(tags)) ||
                !all(vapply(
                  tags,
                  function(x) {
                    is.character(x) &&
                      length(x) == 1L &&
                      !is.na(x)
                  },
                  logical(1)
                )))
          ) {
            stop('Invalid tags for ', key)
          }
          tags <- Filter(function(tag) nzchar(trimws(tag)), tags)
          visit(list(
            key = key,
            path = path,
            method = method,
            tags = tags,
            name = operation$operationId
          ))
        }
      }
    },
    artifact = function() {
      extension <- tolower(tools::file_ext(schema))
      if (!extension %in% c('yaml', 'yml')) {
        extension <- 'json'
      }
      schema_file <- paste0('schema/openapi.', extension)
      schema_text <- if (
        !is.null(attr(document, 'specmill_reference_dependencies'))
      ) {
        plain <- function(x) {
          if (!is.list(x)) {
            return(x)
          }
          output <- lapply(unclass(x), plain)
          names(output) <- names(x)
          output
        }
        as.character(jsonlite::toJSON(
          plain(document),
          auto_unbox = TRUE,
          pretty = TRUE,
          digits = NA,
          null = 'null'
        ))
      } else {
        file_text(schema)
      }
      list(file = schema_file, text = schema_text)
    },
    security_declared = function() {
      length(
        document$components$securitySchemes %or% document$securityDefinitions
      ) >
        0L ||
        !is.null(document[['security']])
    },
    authentication = function(package) authentication_envvars(document, package)
  )
}

openapi_catalogue_source <- function(path, label) {
  document <- read_schema_document(path)
  version <- document$openapi %or% document$swagger %or% ''
  if (!grepl('^(3\\.[01]\\.|2\\.0$)', version) || is.null(document$paths)) {
    stop('Not a supported API schema: ', label)
  }
  list(
    hash = schema_identity(document),
    title = document$info$title %or% 'Unnamed API',
    server = function(origin) schema_server(document, origin)
  )
}

openapi_initialization_source <- function(path) {
  document <- read_schema_document(path)
  list(server = function() effective_server(document)$url)
}

openapi_reference_inputs <- function(path) {
  names(attr(
    read_schema_document(path),
    'specmill_reference_dependencies'
  )) %or%
    character()
}

openapi_operation_keys <- function(path) {
  schema_operation_keys(read_schema_document(path))
}

openapi_spec_tables <- function(files, parse) {
  documents <- lapply(files, read_schema_document)
  lapply(documents, function(document) suppressMessages(parse(document)))
}

openapi_response_documents <- function() {
  cache <- new.env(parent = emptyenv())
  function(source) {
    if (is.null(cache[[source]])) {
      cache[[source]] <- read_schema_document(
        source,
        resolve_references = FALSE
      )
    }
    cache[[source]]
  }
}

# Native parameter/body normalization: parameter_shape.
parameter_shape <- function(
  p,
  schema,
  version,
  at,
  query_array_style = 'schema'
) {
  fail <- function(code, message, classification = 'capability_gap') {
    schema_problem(code, classification, message, at)
  }
  location <- p[['in']]
  if (any(c('oneOf', 'anyOf', 'allOf') %in% names(schema))) {
    fail('parameter_composition', 'Unsupported parameter composition')
  }
  scalar <- function(s) {
    if (identical(s$format, 'binary')) {
      fail(
        'binary_parameter',
        'Binary parameter requires source contract review (#16)',
        'review_required'
      )
    }
    !any(c('oneOf', 'anyOf', 'allOf') %in% names(s)) &&
      length(s$type) >= 1L &&
      all(s$type %in% c('string', 'integer', 'number', 'boolean'))
  }
  if (identical(schema$type, 'array')) {
    if (!scalar(schema$items)) {
      fail('parameter_shape', 'Unsupported parameter array items')
    }
  } else if (identical(schema$type, 'object')) {
    children <- schema$properties
    if (is.list(schema$additionalProperties)) {
      children <- c(children, list(schema$additionalProperties))
    }
    if (
      any(vapply(children, function(s) length(s) && !scalar(s), logical(1)))
    ) {
      fail('nested_parameter', 'Unsupported nested parameter object')
    }
  } else if (!scalar(schema)) {
    fail('parameter_shape', 'Unsupported parameter type')
  }
  if (!location %in% c('path', 'query', 'header', 'cookie')) {
    fail('parameter_location', 'Unsupported parameter location')
  }
  if (!is.null(p$content) || isTRUE(p$allowReserved)) {
    fail('parameter_encoding', 'Unsupported parameter serialization')
  }
  query_array_style <- match.arg(query_array_style, c('schema', 'brackets'))
  if (
    identical(query_array_style, 'brackets') &&
      identical(location, 'query') &&
      identical(schema$type, 'array')
  ) {
    return(list(style = 'brackets', explode = TRUE, collection_format = NULL))
  }
  if (identical(version, '2.0')) {
    if (location == 'cookie' || identical(schema$type, 'object')) {
      fail(
        'parameter_location',
        'Unsupported Swagger parameter location or type',
        'schema_defect'
      )
    }
    collection <- p$collectionFormat %or% 'csv'
    if (
      identical(schema$type, 'array') &&
        (!collection %in% c('csv', 'ssv', 'tsv', 'pipes', 'multi') ||
          (collection == 'multi' && location != 'query'))
    ) {
      fail(
        'collection_format',
        'Invalid Swagger collectionFormat for parameter location',
        'schema_defect'
      )
    }
    style <- if (location == 'query') 'form' else 'simple'
    explode <- identical(schema$type, 'array') && collection == 'multi'
  } else {
    collection <- NULL
    style <- p$style %or%
      if (location %in% c('path', 'header')) 'simple' else 'form'
    explode <- p$explode %or% (style == 'form')
    allowed <- switch(
      location,
      path = c('simple', 'label', 'matrix'),
      query = c('form', 'spaceDelimited', 'pipeDelimited', 'deepObject'),
      header = 'simple',
      cookie = 'form'
    )
    if (
      length(style) != 1L ||
        !style %in% allowed ||
        !is.logical(explode) ||
        length(explode) != 1L ||
        is.na(explode) ||
        (style %in%
          c('spaceDelimited', 'pipeDelimited') &&
          !identical(schema$type, 'array')) ||
        (style == 'deepObject' &&
          (!identical(schema$type, 'object') || !explode))
    ) {
      fail('parameter_encoding', 'Unsupported parameter serialization')
    }
  }
  list(
    style = style,
    explode = explode,
    collection_format = if (identical(schema$type, 'array')) {
      collection
    } else {
      NULL
    }
  )
}


# Native parameter/body normalization: parameter_wire_schema.
parameter_wire_schema <- function(schema, at) {
  composition <- c('oneOf', 'anyOf', 'allOf')
  fail <- function(message) {
    schema_problem('parameter_composition', 'capability_gap', message, at)
  }
  # wire() leaves one container type or only scalar types.
  kind <- function(s) {
    type <- s$type
    if (!length(type)) {
      NA_character_
    } else if (identical(type, 'object')) {
      'object'
    } else if (identical(type, 'array')) {
      'array'
    } else {
      'scalar'
    }
  }
  # allOf: every branch applies.
  merge <- function(a, b) {
    if (length(a$type) && length(b$type)) {
      type <- intersect(a$type, b$type)
      if ('integer' %in% a$type && 'number' %in% b$type) {
        type <- union(type, 'integer')
      }
      if ('number' %in% a$type && 'integer' %in% b$type) {
        type <- union(type, 'integer')
      }
      if (!length(type)) {
        fail('allOf parameter branches share no type')
      }
      a$type <- type
    }
    for (field in c('items', 'additionalProperties')) {
      if (is.list(a[[field]]) && is.list(b[[field]])) {
        a[[field]] <- merge(a[[field]], b[[field]])
      }
    }
    if (isFALSE(b$additionalProperties)) {
      a$additionalProperties <- FALSE
    }
    for (name in intersect(names(a$properties), names(b$properties))) {
      a$properties[[name]] <- merge(a$properties[[name]], b$properties[[name]])
    }
    a$properties <- c(
      a$properties,
      b$properties[setdiff(names(b$properties), names(a$properties))]
    )
    required <- union(unlist(a$required), unlist(b$required))
    if (length(required)) {
      a$required <- required
    }
    if (identical(b$format, 'binary')) {
      a$format <- 'binary'
    }
    for (field in setdiff(names(b), names(a))) {
      a[[field]] <- b[[field]]
    }
    a
  }
  # anyOf/oneOf: any branch may apply, so keep only shared structure.
  union_of <- function(a, b) {
    kinds <- c(kind(a), kind(b))
    if (anyNA(kinds)) {
      return(list())
    }
    if ('object' %in% kinds && !all(kinds == 'object')) {
      fail('Parameter composition mixes object and non-object branches')
    }
    if (all(kinds == 'object')) {
      properties <- a$properties
      for (name in names(b$properties)) {
        properties[[name]] <- if (name %in% names(properties)) {
          union_of(properties[[name]], b$properties[[name]])
        } else {
          b$properties[[name]]
        }
      }
      extra <- list(a$additionalProperties, b$additionalProperties)
      required <- intersect(unlist(a$required), unlist(b$required))
      return(c(
        list(type = 'object', properties = properties),
        if (length(required)) list(required = required),
        if (all(vapply(extra, isFALSE, logical(1)))) {
          list(additionalProperties = FALSE)
        } else if (all(vapply(extra, is.list, logical(1)))) {
          list(additionalProperties = union_of(extra[[1L]], extra[[2L]]))
        }
      ))
    }
    if (all(kinds == 'scalar')) {
      return(c(
        list(type = union(a$type, b$type)),
        if (identical(a$format, b$format)) list(format = a$format)
      ))
    }
    items <- function(s) if (kind(s) == 'array') s$items %or% list() else s
    list(type = 'array', items = union_of(items(a), items(b)))
  }
  # Returns NULL for a schema that only admits null.
  wire <- function(s) {
    if (!is.list(s)) {
      return(s)
    }
    out <- s[setdiff(names(s), composition)]
    if ('type' %in% names(s)) {
      type <- setdiff(unlist(s$type), 'null')
      if (!length(type)) {
        return(NULL)
      }
      out$type <- type
    }
    if (is.list(out$items)) {
      out$items <- wire(out$items) %or% list()
    }
    if (is.list(out$additionalProperties)) {
      out$additionalProperties <- wire(out$additionalProperties) %or% list()
    }
    if (length(out$properties)) {
      out$properties <- lapply(out$properties, function(p) wire(p) %or% list())
    }
    # A JSON Schema 2020-12 type list such as [string, array].
    if (length(out$type) > 1L && any(out$type %in% c('array', 'object'))) {
      if ('object' %in% out$type) {
        fail('Parameter type mixes object and non-object values')
      }
      out <- c(
        out[setdiff(names(out), c('type', 'items'))],
        union_of(
          list(type = setdiff(out$type, 'array')),
          list(type = 'array', items = out$items %or% list())
        )
      )
    }
    for (branch in s$allOf) {
      branch <- wire(branch)
      if (is.null(branch)) {
        fail('allOf parameter branch only admits null')
      }
      out <- merge(out, branch)
    }
    for (field in intersect(c('anyOf', 'oneOf'), names(s))) {
      branches <- Filter(Negate(is.null), lapply(s[[field]], wire))
      if (!length(branches)) {
        return(NULL)
      }
      out <- merge(out, Reduce(union_of, branches))
    }
    out
  }
  wire(schema) %or% fail('Parameter schema only admits null')
}


# Native parameter/body normalization: parameter_composed.
parameter_composed <- function(schema) {
  if (!is.list(schema)) {
    return(FALSE)
  }
  any(c('oneOf', 'anyOf', 'allOf') %in% names(schema)) ||
    (length(schema$type) > 1L && 'null' %in% schema$type) ||
    any(vapply(
      c(
        list(schema$items, schema$additionalProperties),
        unname(schema$properties)
      ),
      parameter_composed,
      logical(1)
    ))
}


# Native parameter/body normalization: form_encoding.
form_encoding <- function(schema, encoding, media, at) {
  fail <- function(message) {
    schema_problem('form_encoding', 'capability_gap', message, at)
  }
  if (!identical(schema$type, 'object')) {
    fail('Form body must be an object')
  }
  if (is.list(schema$additionalProperties)) {
    fail('Dynamic form fields are unsupported')
  }
  if (length(setdiff(names(encoding), names(schema$properties)))) {
    fail('Encoding names an undeclared form property')
  }
  for (name in names(schema$properties)) {
    field <- schema$properties[[name]]
    enc <- encoding[[name]] %or% list()
    if (length(enc$headers)) {
      fail('Multipart part headers require an explicit request mapping')
    }
    if (media == 'application/x-www-form-urlencoded') {
      if (
        identical(field$format, 'binary') ||
          identical(field$items$format, 'binary')
      ) {
        fail('Binary form fields require multipart/form-data')
      }
      if (
        identical(field$type, 'object') || identical(field$items$type, 'object')
      ) {
        fail('Nested URL-encoded form fields are unsupported')
      }
      if (!is.null(enc$contentType)) {
        fail('Content-Type encoding for URL-encoded fields is unsupported')
      }
      p <- c(
        list(name = name, 'in' = 'query'),
        enc[c('style', 'explode', 'allowReserved')]
      )
      # NULL entries do not override the parameter defaults.
      if (!is.null(enc$collection_format)) {
        p$collectionFormat <- enc$collection_format
        parameter_shape(p, field, '2.0', at)
      } else {
        parameter_shape(p, field, '3.0.3', at)
      }
    } else {
      type <- if (identical(field$type, 'array')) field$items else field
      content <- enc$contentType
      if (
        !is.null(enc$collection_format) &&
          !enc$collection_format %in% c('csv', 'ssv', 'tsv', 'pipes', 'multi')
      ) {
        fail('Unsupported form collectionFormat')
      }
      if (
        identical(field$type, 'array') &&
          identical(field$items$format, 'binary') &&
          !is.null(enc$collection_format) &&
          enc$collection_format != 'multi'
      ) {
        fail('Binary multipart arrays require collectionFormat multi')
      }
      if (
        !is.null(content) &&
          (!is.character(content) ||
            length(content) != 1L ||
            !grepl('^[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+$', content))
      ) {
        fail('Multipart encoding requires one concrete Content-Type')
      }
      if (
        identical(type$type, 'object') &&
          !is.null(content) &&
          content != 'application/json'
      ) {
        fail('Multipart object parts require application/json')
      }
      if (identical(type$type, 'array') || is.null(type$type)) {
        fail('Unsupported multipart part shape')
      }
    }
  }
  encoding %or% list()
}

# Format detection belongs beside native interpretation, not in the catalogue.
openapi_detect <- function(document, format) {
  if (!is.list(document)) {
    return(0)
  }
  value <- if (format == 'swagger') document$swagger else document$openapi
  if (is.character(value) && length(value) == 1L && !is.na(value)) 1 else 0
}

openapi_import_description <- function(path, policy = list()) {
  ir <- if (!length(policy)) {
    importer_openapi(path)
  } else {
    prepared <- prepare_operation_policy(policy)
    view <- operation_review_context(prepared)
    records <- openapi_read_records(path, view)
    finish_operation_policy(records, prepared)
    parsed <- operation_records_result(records)
    output <- openapi_records_ir(path, parsed, records$source_data)
    output$service$id <- view$service
    output
  }
  list(ir = ir, diagnostics = ir$diagnostics %or% list())
}

openapi_assert_format <- function(path, format) {
  document <- read_schema_document(path, resolve_references = FALSE)
  if (
    openapi_detect(document, format) == 0 ||
      openapi_detect(
        document,
        if (format == 'swagger') 'openapi' else 'swagger'
      ) >
        0
  ) {
    stop('Document does not declare an unambiguous ', format, ' format: ', path)
  }
  invisible(NULL)
}
