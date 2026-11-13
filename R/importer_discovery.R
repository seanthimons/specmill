# Google API Discovery documents (`discovery#restDescription`) to IR. Sources are
# reviewed local documents; nothing is fetched. Media upload, batch endpoints and
# OAuth token acquisition are not implemented.
discovery_detect <- function(path, document) {
  if (
    is.list(document) && identical(document$kind, 'discovery#restDescription')
  ) {
    1
  } else {
    0
  }
}

# Discovery schemas are a JSON Schema draft-03 dialect: `required` sits on the
# property, bounds are spelled as strings, and `$ref` is a bare schema id.
discovery_type <- function(schema, file, at) {
  if (!is.list(schema) || is.null(names(schema))) {
    return(list(kind = 'any', lossy = list('unsupported_schema')))
  }
  type <- if (!is.null(schema[['$ref']])) {
    list(kind = 'ref', name = schema[['$ref']])
  } else if (length(schema$enum)) {
    descriptions <- schema$enumDescriptions
    list(
      kind = 'enum',
      base = 'string',
      values = lapply(seq_along(schema$enum), function(i) {
        description <- if (i <= length(descriptions)) descriptions[[i]]
        c(
          list(value = schema$enum[[i]]),
          if (is.character(description) && nzchar(description)) {
            list(description = description)
          }
        )
      })
    )
  } else {
    format <- schema$format %or% ''
    switch(
      schema$type %or% 'any',
      string = {
        name <- switch(
          format,
          'date-time' = ,
          'google-datetime' = 'datetime',
          date = 'date',
          byte = 'bytes',
          # 64-bit integers, durations and field masks travel as strings.
          'string'
        )
        c(
          list(kind = 'scalar', name = name),
          if (name == 'bytes') list(encoding = 'base64')
        )
      },
      integer = list(
        kind = 'scalar',
        name = 'integer',
        bits = 32L,
        signed = !startsWith(format, 'u')
      ),
      number = c(
        list(kind = 'scalar', name = 'float'),
        if (format %in% c('float', 'double')) {
          list(bits = if (format == 'float') 32L else 64L)
        }
      ),
      boolean = list(kind = 'scalar', name = 'boolean'),
      array = list(
        kind = 'list',
        items = discovery_type(
          schema$items %or% list(type = 'any'),
          file,
          paste0(at, '/items')
        )
      ),
      object = if (length(schema$properties)) {
        c(
          list(
            kind = 'record',
            fields = unname(lapply(names(schema$properties), function(name) {
              property <- schema$properties[[name]]
              list(
                name = name,
                required = isTRUE(property$required),
                type = discovery_type(
                  property,
                  file,
                  paste0(at, '/properties/', name)
                )
              )
            }))
          ),
          if (is.list(schema$additionalProperties)) {
            list(
              additional = discovery_type(
                schema$additionalProperties,
                file,
                paste0(at, '/additionalProperties')
              )
            )
          }
        )
      } else {
        list(
          kind = 'map',
          value = if (is.list(schema$additionalProperties)) {
            discovery_type(
              schema$additionalProperties,
              file,
              paste0(at, '/additionalProperties')
            )
          } else {
            list(kind = 'any')
          }
        )
      },
      any = list(kind = 'any'),
      list(kind = 'any', lossy = list('unsupported_type'))
    )
  }
  if (identical(type$kind, 'scalar')) {
    if (!is.null(schema$format)) {
      type$native_format <- schema$format
    }
    if (is.character(schema$pattern) && length(schema$pattern) == 1L) {
      type$pattern <- schema$pattern
    }
    if (type$name %in% c('integer', 'float')) {
      for (bound in c('minimum', 'maximum')) {
        value <- suppressWarnings(as.numeric(schema[[bound]] %or% NA))
        if (length(value) == 1L && !is.na(value)) {
          type[[bound]] <- value
        }
      }
    }
  }
  if (is.character(schema$description) && length(schema$description) == 1L) {
    type$description <- schema$description
  }
  default <- schema[['default']]
  if (is.character(default) && length(default) == 1L) {
    # Defaults are spelled as strings whatever the declared type.
    if (
      identical(type$kind, 'scalar') && type$name %in% c('integer', 'float')
    ) {
      default <- suppressWarnings(as.numeric(default))
    } else if (identical(type$kind, 'scalar') && type$name == 'boolean') {
      default <- if (default %in% c('true', 'false')) default == 'true' else NA
    }
    if (!is.na(default)) {
      type$default <- default
    }
  }
  if (isTRUE(schema$readOnly)) {
    type$read_only <- TRUE
  }
  if (isTRUE(schema$deprecated)) {
    type$deprecated <- TRUE
  }
  type$source_location <- list(file = file, pointer = at)
  type
}

importer_discovery <- function(path, policy = list()) {
  document <- jsonlite::read_json(path)
  if (!isTRUE(discovery_detect(path, document) == 1)) {
    cli::cli_abort(
      'Discovery import requires a document of kind discovery#restDescription'
    )
  }
  file <- normalizePath(path, winslash = '/', mustWork = TRUE)
  name <- document$name
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    cli::cli_abort('Discovery document has no API name')
  }
  server <- sub(
    '/+$',
    '',
    paste0(document$rootUrl %or% '', document$servicePath %or% '')
  )
  if (!valid_server_url(server)) {
    cli::cli_abort('Discovery document has no valid rootUrl')
  }
  schemes <- list()
  if (!is.null(document$parameters[['key']])) {
    schemes$api_key <- list(
      kind = 'api_key',
      'in' = 'query',
      name = 'key',
      description = 'API key sent as the key query parameter.'
    )
  }
  scopes <- document$auth$oauth2$scopes
  if (length(scopes)) {
    schemes$oauth2 <- list(
      kind = 'oauth2',
      flows = list(scopes = scopes),
      description = 'OAuth 2.0 access token; acquisition and refresh are not generated.'
    )
  }
  source_id <- 'discovery'
  source <- list(
    id = source_id,
    format = 'google-discovery',
    format_version = as.character(document$discoveryVersion %or% ''),
    importer_version = '1',
    file = file,
    hash = list(
      algorithm = 'sha256',
      value = digest::digest(file = path, algo = 'sha256')
    ),
    servers = list(list(url = server)),
    auth_schemes = if (length(schemes)) {
      schemes
    } else {
      stats::setNames(list(), character())
    },
    types = if (length(document$schemas)) {
      stats::setNames(
        lapply(names(document$schemas), function(id) {
          discovery_type(
            document$schemas[[id]],
            file,
            paste0('/schemas/', id)
          )
        }),
        names(document$schemas)
      )
    } else {
      stats::setNames(list(), character())
    },
    # System parameters (alt, fields, key, ...) apply to every method and are
    # not repeated as operation parameters.
    native = list(
      revision = document$revision %or% '',
      parameters = if (length(document$parameters)) {
        document$parameters
      } else {
        stats::setNames(list(), character())
      }
    )
  )
  for (field in c('title', 'description', 'version')) {
    if (is.character(document[[field]]) && length(document[[field]]) == 1L) {
      source[[field]] <- document[[field]]
    }
  }
  service <- list(
    id = policy$service %or% configuration_words(name),
    title = document$title %or% name
  )
  operations <- list()
  diagnostics <- list()
  diagnose <- function(code, reason, key, at) {
    diagnostics[[length(diagnostics) + 1L]] <<- list(
      code = code,
      reason = reason,
      key = key,
      source_location = list(file = file, pointer = at)
    )
  }
  placeholders <- function(route) {
    gsub('[{}+]', '', regmatches(route, gregexpr('\\{[^}]+\\}', route))[[1L]])
  }
  add <- function(method, resource, at) {
    id <- method$id
    verb <- toupper(method$httpMethod %or% '')
    if (!is.character(id) || length(id) != 1L || !nzchar(verb)) {
      cli::cli_abort('Discovery method without id or httpMethod at {at}')
    }
    declared <- method$parameters %or% list()
    locations <- vapply(
      declared,
      function(p) p$location %or% '',
      character(1)
    )
    if (!all(locations %in% c('path', 'query'))) {
      cli::cli_abort('Discovery parameter with an unknown location: {id}')
    }
    in_path <- names(declared)[locations == 'path']
    route <- method$path %or% ''
    if (grepl('{+', route, fixed = TRUE)) {
      # Reserved expansion spans several segments; the request helper fills one
      # encoded segment per placeholder, so only an equivalent flatPath is used.
      flat <- method$flatPath %or% ''
      if (setequal(placeholders(flat), in_path)) {
        route <- flat
      } else {
        diagnose(
          'reserved_expansion',
          'The path uses reserved expansion without an equivalent flatPath.',
          paste(verb, paste0('/', sub('^/+', '', route))),
          at
        )
        return(invisible())
      }
    }
    if (!setequal(placeholders(route), in_path)) {
      cli::cli_abort('Discovery path and path parameters differ: {id}')
    }
    route <- paste0('/', sub('^/+', '', route))
    key <- paste(verb, route)
    order <- unlist(method$parameterOrder, use.names = FALSE)
    order <- c(
      intersect(order, names(declared)),
      sort(setdiff(names(declared), order), method = 'radix')
    )
    parameters <- lapply(order, function(parameter) {
      p <- declared[[parameter]]
      type <- discovery_type(
        p[setdiff(names(p), c('location', 'required', 'repeated'))],
        file,
        paste0(at, '/parameters/', parameter)
      )
      if (isTRUE(p$repeated)) {
        # The description documents the argument, not one of its values.
        type <- c(
          list(
            kind = 'list',
            items = type[setdiff(names(type), 'description')]
          ),
          type['description'][!is.null(type$description)]
        )
      }
      c(
        list(
          name = parameter,
          location = p$location,
          required = isTRUE(p$required) || p$location == 'path',
          type = type
        ),
        if (isTRUE(p$repeated)) list(style = 'form', explode = TRUE)
      )
    })
    security <- c(
      if (!is.null(schemes[['api_key']])) list(list(api_key = list())),
      if (!is.null(schemes[['oauth2']]) && length(method$scopes)) {
        list(list(oauth2 = as.list(unlist(method$scopes, use.names = FALSE))))
      }
    )
    op <- list(
      key = key,
      id = paste(service$id, key),
      name = gsub(
        '[^A-Za-z0-9]+',
        '_',
        sub(paste0('^', name, '[.]'), '', id)
      ),
      native_name = id,
      # The first sentence of the first line serves as the summary.
      summary = summary_text(NULL, method$description, id),
      paradigm = 'rest',
      source = source_id,
      binding = list(method = verb, path = route),
      parameters = parameters,
      errors = list(list(
        when = list(body_path = list('error'), present = TRUE),
        code_path = list('error', 'code'),
        message_path = list('error', 'message'),
        description = 'Google APIs report failures as an error object with a non-2xx status.'
      )),
      security = security %or% list(),
      source_location = list(file = file, pointer = at)
    )
    if (nzchar(method$description %or% '')) {
      op$description <- method$description
    }
    if (isTRUE(method$deprecated)) {
      op$deprecated <- TRUE
    }
    if (nzchar(resource)) {
      op$tags <- list(resource)
    }
    request <- method$request[['$ref']]
    if (!is.null(request)) {
      op$body <- list(
        media = 'application/json',
        required = TRUE,
        type = list(kind = 'ref', name = request)
      )
    }
    response <- method$response[['$ref']]
    if (!is.null(response)) {
      op$responses <- list(list(
        status = '200',
        media = if (isTRUE(method$supportsMediaDownload)) {
          '*/*'
        } else {
          'application/json'
        },
        type = list(kind = 'ref', name = response)
      ))
    }
    if (isTRUE(method$supportsMediaUpload)) {
      diagnose(
        'media_upload_unsupported',
        'Media upload is not generated; only the metadata request is available.',
        key,
        at
      )
    }
    token <- declared[['pageToken']]
    properties <- function(schema) {
      document$schemas[[schema %or% '']]$properties
    }
    next_token <- properties(response)[['nextPageToken']]
    if (
      identical(token$location, 'query') &&
        identical(token$type, 'string') &&
        !is.null(next_token)
    ) {
      limit <- intersect(c('pageSize', 'maxResults'), names(declared))
      op$pagination <- c(
        list(strategy = 'cursor', cursor_parameter = 'pageToken'),
        if (length(limit)) list(limit_parameter = limit[[1L]]),
        list(next_path = list('nextPageToken'))
      )
    } else if (
      !is.null(next_token) &&
        !is.null(properties(request)[['pageToken']])
    ) {
      diagnose(
        'body_page_token',
        'The page token travels in the request body; configure paging by review.',
        key,
        at
      )
    }
    operations[[length(operations) + 1L]] <<- op
    invisible()
  }
  walk <- function(node, resource, at) {
    for (id in names(node$methods)) {
      add(node$methods[[id]], resource, paste0(at, '/methods/', id))
    }
    for (id in names(node$resources)) {
      walk(
        node$resources[[id]],
        if (nzchar(resource)) resource else id,
        paste0(at, '/resources/', id)
      )
    }
  }
  walk(document, '', '')
  for (field in c('key', 'name')) {
    if (anyDuplicated(vapply(operations, `[[`, character(1), field))) {
      cli::cli_abort('Discovery document repeats a method route or name')
    }
  }
  ir <- list(
    ir_version = '1',
    paradigm = 'rest',
    service = service,
    sources = list(source),
    operations = operations,
    diagnostics = diagnostics
  )
  problems <- validate_ir(ir)
  if (length(problems)) {
    cli::cli_abort('Invalid Discovery IR: {paste(problems, collapse = "; ")}')
  }
  list(ir = ir, diagnostics = diagnostics)
}

discovery_records <- function(files, view) {
  ir_source_records(files, view, importer_discovery, 'Discovery document')
}

discovery_configuration_source <- function(path) {
  ir <- importer_discovery(path)$ir
  ir_configuration_source(
    ir,
    path,
    format = 'google-discovery',
    artifact = 'schema/discovery.json',
    tags = function(op) op$tags %or% list(),
    authentication = function(package) {
      list(
        api_key = paste0(toupper(configuration_words(package)), '_API_KEY')
      )
    },
    pagination = function(op) {
      if (is.null(op$pagination)) {
        return(NULL)
      }
      list(
        mode = 'cursor',
        parameter = op$pagination$cursor_parameter,
        next_cursor = 'api_request_discovery_next_page_token'
      )
    },
    security_declared = !is.null(ir$sources[[1L]]$auth_schemes[['api_key']]),
    diagnostic_key = function(diagnostic) diagnostic$key
  )
}

discovery_validation_report <- function(path) {
  ir_validation_report(
    path,
    importer_discovery,
    'specmill Discovery document/IR validation 1',
    'discovery_document'
  )
}
