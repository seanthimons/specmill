# Reviewed local captures only: importing never fetches a service directory.
arcgis_detect <- function(path, document) {
  if (!is.list(document)) {
    return(0)
  }
  if (!is.null(document$arcgis_capture_version)) {
    return(1)
  }
  if (
    is.numeric(document$currentVersion) &&
      any(c('layers', 'fields', 'services', 'folders') %in% names(document))
  ) {
    return(0.5)
  }
  0
}

arcgis_capture <- function(path) {
  capture <- jsonlite::read_json(path)
  if (!identical(capture$arcgis_capture_version, '1')) {
    cli::cli_abort(
      'ArcGIS import requires a reviewed capture with arcgis_capture_version: \'1\', kind, url, document and layers'
    )
  }
  if (!identical(capture$kind, 'service')) {
    cli::cli_abort(
      'Select a service capture; expand directory captures with configure_apis()'
    )
  }
  if (
    !valid_server_url(capture$url) ||
      !grepl('/(FeatureServer|MapServer)$', capture$url)
  ) {
    cli::cli_abort(
      'ArcGIS capture requires a reviewed FeatureServer or MapServer URL'
    )
  }
  if (
    !is.null(capture$requires_token) &&
      !isTRUE(capture$requires_token) &&
      !isFALSE(capture$requires_token)
  ) {
    cli::cli_abort(
      'requires_token must be true or false in a reviewed ArcGIS capture'
    )
  }
  if (!is.list(capture$document) || !is.null(capture$document$error)) {
    cli::cli_abort('Invalid ArcGIS service metadata')
  }
  ids <- vapply(
    capture$layers,
    function(layer) {
      id <- layer$document$id
      if (
        !is.numeric(id) ||
          length(id) != 1L ||
          !is.finite(id) ||
          id < 0 ||
          id != trunc(id)
      ) {
        cli::cli_abort('ArcGIS layer id must be a nonnegative integer')
      }
      if (!identical(layer$url, paste0(capture$url, '/', id))) {
        cli::cli_abort('Captured layer URL does not match its service and id')
      }
      as.character(id)
    },
    character(1)
  )
  if (anyDuplicated(ids)) {
    cli::cli_abort('Duplicate ArcGIS layer capture')
  }
  advertised <- Filter(
    function(layer) is.null(layer$subLayerIds),
    c(capture$document$layers, capture$document$tables)
  )
  missing <- setdiff(
    vapply(advertised, function(layer) as.character(layer$id), character(1)),
    ids
  )
  if (length(missing)) {
    cli::cli_abort(
      'Missing local ArcGIS layer captures: {paste(missing, collapse = ", ")}'
    )
  }
  capture
}

arcgis_discover <- function(path) {
  document <- jsonlite::read_json(path)
  if (!identical(document$arcgis_capture_version, '1')) {
    cli::cli_abort('Unsupported ArcGIS directory capture version')
  }
  if (!identical(document$kind, 'directory')) {
    return(list(files = path, diagnostics = list()))
  }
  files <- vapply(
    document$services,
    function(file) project_path(dirname(path), file),
    character(1)
  )
  for (file in files) {
    arcgis_capture(file)
  }
  list(files = files, diagnostics = document$diagnostics %or% list())
}

arcgis_field_type <- function(field) {
  name <- field$type
  base <- switch(
    name,
    esriFieldTypeOID = list(kind = 'scalar', name = 'integer'),
    esriFieldTypeSmallInteger = list(
      kind = 'scalar',
      name = 'integer',
      bits = 16L
    ),
    esriFieldTypeInteger = list(kind = 'scalar', name = 'integer', bits = 32L),
    esriFieldTypeBigInteger = list(
      kind = 'scalar',
      name = 'integer',
      bits = 64L,
      lossy = list('int64_precision')
    ),
    esriFieldTypeSingle = list(kind = 'scalar', name = 'float', bits = 32L),
    esriFieldTypeDouble = list(kind = 'scalar', name = 'float', bits = 64L),
    esriFieldTypeString = list(kind = 'scalar', name = 'string'),
    esriFieldTypeGUID = list(kind = 'scalar', name = 'uuid'),
    esriFieldTypeGlobalID = list(kind = 'scalar', name = 'uuid'),
    esriFieldTypeDate = list(
      kind = 'scalar',
      name = 'integer',
      bits = 64L,
      native_format = 'unix-milliseconds'
    ),
    list(kind = 'any', lossy = list('arcgis_field_type'))
  )
  if (
    length(field$domain$codedValues) &&
      !is.null(base$name) &&
      base$name %in% c('string', 'integer', 'float')
  ) {
    base <- list(
      kind = 'enum',
      base = base$name,
      values = lapply(field$domain$codedValues, function(value) {
        list(value = value$code)
      })
    )
  }
  base$native_type <- name
  base$native <- list(field = field)
  if (
    identical(base$name, 'string') &&
      is.numeric(field$length) &&
      field$length > 0
  ) {
    base$max_length <- field$length
  }
  if (isTRUE(field$nullable)) {
    base$nullable <- TRUE
  }
  base
}

importer_arcgis <- function(path, policy = list()) {
  capture <- arcgis_capture(path)
  document <- capture$document
  service_id <- policy$service %or%
    configuration_words(sub(
      '^.*/([^/]+)/(FeatureServer|MapServer)$',
      '\\1',
      capture$url
    ))
  title <- document$name %or%
    utils::URLdecode(sub(
      '^.*/([^/]+)/(FeatureServer|MapServer)$',
      '\\1',
      capture$url
    ))
  source_id <- 'arcgis-service'
  token <- list(
    kind = 'session_token',
    'in' = 'query',
    name = 'token',
    description = 'Reviewed ArcGIS token supplied by the client; token acquisition and refresh remain client-owned.',
    native = list(auth_info = document$authInfo %or% list())
  )
  token_url <- document$authInfo$tokenServicesUrl
  if (!is.null(token_url)) {
    if (!valid_server_url(token_url)) {
      cli::cli_abort('Invalid reviewed ArcGIS token service URL')
    }
    token_url <- sub('/+$', '', token_url)
    if (!endsWith(token_url, '/generateToken')) {
      token_url <- paste0(token_url, '/generateToken')
    }
    token$token_url <- token_url
    token$flows <- list(
      generate_token = list(token_url = token_url, method = 'POST')
    )
  }
  security <- if (isTRUE(capture$requires_token)) {
    list(list(arcgis_token = list()))
  } else {
    list()
  }
  source <- list(
    id = source_id,
    format = 'arcgis-rest',
    format_version = as.character(document$currentVersion %or% ''),
    importer_version = '1',
    file = normalizePath(path, winslash = '/', mustWork = TRUE),
    hash = list(
      algorithm = 'sha256',
      value = digest::digest(file = path, algo = 'sha256')
    ),
    servers = list(list(url = capture$url)),
    auth_schemes = list(arcgis_token = token),
    native = list(metadata = document),
    types = stats::setNames(list(), character())
  )
  operations <- list()
  diagnostics <- list()
  parameter <- function(
    name,
    type = 'string',
    default = NULL,
    required = FALSE,
    minimum = NULL,
    maximum = NULL
  ) {
    tree <- list(kind = 'scalar', name = type)
    if (!is.null(default)) {
      tree$default <- default
    }
    if (!is.null(minimum)) {
      tree$minimum <- minimum
    }
    if (!is.null(maximum)) {
      tree$maximum <- maximum
    }
    list(name = name, location = 'query', required = required, type = tree)
  }
  format <- parameter('f', default = 'json')
  format$type <- list(
    kind = 'enum',
    base = 'string',
    default = 'json',
    values = list(list(value = 'json'), list(value = 'pjson'))
  )
  add <- function(
    native_name,
    route,
    parameters,
    summary,
    response = list(kind = 'any'),
    paging = NULL,
    body = NULL,
    at = '#'
  ) {
    method <- if (is.null(body)) 'GET' else 'POST'
    key <- paste(method, route)
    op <- list(
      key = key,
      id = paste(service_id, key),
      name = if (route == '/identify') {
        'identify'
      } else {
        paste0(
          configuration_words(native_name),
          '_layer_',
          strsplit(route, '/', fixed = TRUE)[[1L]][[2L]]
        )
      },
      native_name = native_name,
      summary = summary,
      paradigm = 'rest',
      source = source_id,
      binding = list(method = method, path = route),
      parameters = unname(c(parameters, list(format))),
      responses = list(list(
        status = '200',
        media = 'application/json',
        type = response
      )),
      errors = list(list(
        when = list(status = '200', body_path = list('error'), present = TRUE),
        code_path = list('error', 'code'),
        message_path = list('error', 'message')
      )),
      security = security,
      source_location = list(file = source$file, pointer = at)
    )
    if (!is.null(paging)) {
      op$pagination <- paging
    }
    if (!is.null(body)) {
      op$body <- body
    }
    operations[[length(operations) + 1L]] <<- op
  }
  capabilities <- function(value) {
    trimws(strsplit(value %or% '', ',', fixed = TRUE)[[1L]])
  }
  for (index in seq_along(capture$layers)) {
    layer <- capture$layers[[index]]$document
    id <- layer$id
    fields <- vapply(layer$fields, `[[`, character(1), 'name')
    if (anyDuplicated(fields) || !all(nzchar(fields))) {
      cli::cli_abort('Invalid or duplicate ArcGIS field names')
    }
    attributes <- list(
      kind = 'record',
      fields = unname(lapply(layer$fields, function(field) {
        list(
          name = field$name,
          required = FALSE,
          type = arcgis_field_type(field)
        )
      }))
    )
    feature <- list(
      kind = 'record',
      fields = list(
        list(name = 'attributes', required = TRUE, type = attributes),
        list(
          name = 'geometry',
          required = FALSE,
          type = list(
            kind = 'any',
            native_type = layer$geometryType %or% 'esriGeometry'
          )
        )
      )
    )
    feature$native <- list(
      layer = layer[intersect(
        c(
          'id',
          'name',
          'type',
          'supportedOperations',
          'maxRecordCount',
          'advancedQueryCapabilities'
        ),
        names(layer)
      )]
    )
    type_name <- paste0('Layer', id, 'Feature')
    source$types[[type_name]] <- feature
    response <- list(
      kind = 'record',
      fields = list(
        list(
          name = 'features',
          required = TRUE,
          type = list(
            kind = 'list',
            items = list(kind = 'ref', name = type_name)
          )
        ),
        list(
          name = 'exceededTransferLimit',
          required = FALSE,
          type = list(kind = 'scalar', name = 'boolean')
        )
      )
    )
    caps <- capabilities(layer$capabilities %or% document$capabilities)
    declared <- layer$supportedOperations %or% document$supportedOperations
    if (!is.null(declared)) {
      declared <- tolower(unlist(
        if (is.character(declared)) {
          strsplit(declared, ',', fixed = TRUE)
        } else {
          declared
        },
        use.names = FALSE
      ))
      declared <- gsub('[[:space:]_-]', '', declared)
      for (unsupported in setdiff(
        declared,
        c('query', 'queryrelatedrecords', 'applyedits', 'identify')
      )) {
        diagnostics[[length(diagnostics) + 1L]] <- list(
          code = 'arcgis_operation',
          classification = 'capability_gap',
          reason = paste('ArcGIS operation is not imported:', unsupported),
          source_location = list(
            file = source$file,
            pointer = paste0(
              '#/layers/',
              index - 1L,
              '/document/supportedOperations'
            )
          )
        )
      }
    }
    supported <- function(operation, inferred) {
      if (is.null(declared)) inferred else tolower(operation) %in% declared
    }
    size <- layer$maxRecordCount %or% document$maxRecordCount
    paged <- isTRUE(layer$advancedQueryCapabilities$supportsPagination)
    if (
      (paged ||
        isTRUE(
          layer$advancedQueryCapabilities$supportsQueryRelatedPagination
        )) &&
        (!is.numeric(size) ||
          length(size) != 1L ||
          !is.finite(size) ||
          size < 1 ||
          size != trunc(size) ||
          size > .Machine$integer.max)
    ) {
      cli::cli_abort(
        'ArcGIS pagination requires a positive integer maxRecordCount'
      )
    }
    paging <- function(enabled) {
      if (enabled) {
        list(
          strategy = 'offset',
          offset_parameter = 'resultOffset',
          limit_parameter = 'resultRecordCount',
          more_path = list('exceededTransferLimit'),
          more_when = TRUE,
          max_page_size = as.integer(size)
        )
      } else {
        NULL
      }
    }
    page_parameters <- function(enabled) {
      if (enabled) {
        list(
          parameter('resultOffset', 'integer', 0L, minimum = 0L),
          parameter(
            'resultRecordCount',
            'integer',
            as.integer(size),
            minimum = 1L,
            maximum = size
          )
        )
      } else {
        list()
      }
    }
    at <- paste0('#/layers/', index - 1L, '/document')
    if (supported('query', 'Query' %in% caps)) {
      args <- c(
        list(
          parameter('where', default = '1=1'),
          parameter('outFields', default = '*'),
          parameter('returnGeometry', 'boolean', TRUE)
        ),
        page_parameters(paged)
      )
      add(
        'query',
        paste0('/', id, '/query'),
        args,
        paste('Query', layer$name),
        response,
        paging(paged),
        at = at
      )
    }
    related_paged <- isTRUE(
      layer$advancedQueryCapabilities$supportsQueryRelatedPagination
    ) &&
      !is.null(size)
    if (
      supported(
        'queryRelatedRecords',
        length(layer$relationships) > 0L &&
          (if (endsWith(capture$url, '/MapServer')) 'Data' else 'Query') %in%
            caps
      )
    ) {
      add(
        'queryRelatedRecords',
        paste0('/', id, '/queryRelatedRecords'),
        c(
          list(
            parameter('objectIds', required = TRUE),
            parameter(
              'relationshipId',
              'integer',
              required = TRUE,
              minimum = 0L
            ),
            parameter('outFields', default = '*')
          ),
          page_parameters(related_paged)
        ),
        paste('Query related records for', layer$name),
        paging = paging(related_paged),
        at = at
      )
    }
    if (
      endsWith(capture$url, '/FeatureServer') &&
        supported('applyEdits', any(c('Create', 'Update', 'Delete') %in% caps))
    ) {
      edits <- intersect(c('Create', 'Update', 'Delete'), caps)
      properties <- c(
        stats::setNames(
          lapply(edits, function(x) {
            list(
              kind = 'scalar',
              name = 'string',
              native_format = if (x == 'Delete') {
                'comma-separated-ids'
              } else {
                'json-text'
              }
            )
          }),
          c(Create = 'adds', Update = 'updates', Delete = 'deletes')[edits]
        ),
        list()
      )
      body <- list(
        media = 'application/x-www-form-urlencoded',
        required = TRUE,
        type = list(
          kind = 'record',
          fields = lapply(names(properties), function(name) {
            list(name = name, required = FALSE, type = properties[[name]])
          })
        )
      )
      add(
        'applyEdits',
        paste0('/', id, '/applyEdits'),
        list(),
        paste('Apply edits to', layer$name),
        body = body,
        at = at
      )
    }
  }
  service_operations <- document$supportedOperations
  if (!is.null(service_operations)) {
    service_operations <- tolower(gsub(
      '[[:space:]_-]',
      '',
      unlist(
        if (is.character(service_operations)) {
          strsplit(service_operations, ',', fixed = TRUE)
        } else {
          service_operations
        },
        use.names = FALSE
      )
    ))
  }
  if (
    endsWith(capture$url, '/MapServer') &&
      'Map' %in% capabilities(document$capabilities) &&
      (is.null(service_operations) || 'identify' %in% service_operations)
  ) {
    add(
      'identify',
      '/identify',
      list(
        parameter('geometry', required = TRUE),
        parameter('geometryType', default = 'esriGeometryPoint'),
        parameter('tolerance', 'integer', required = TRUE, minimum = 0L),
        parameter('mapExtent', required = TRUE),
        parameter('imageDisplay', required = TRUE),
        parameter('layers', default = 'all')
      ),
      paste('Identify features in', title)
    )
  }
  ir <- list(
    ir_version = '1',
    paradigm = 'rest',
    service = list(id = service_id, title = title),
    sources = list(source),
    operations = operations,
    diagnostics = diagnostics
  )
  problems <- validate_ir(ir)
  if (length(problems)) {
    cli::cli_abort('Invalid ArcGIS IR: {paste(problems, collapse = "; ")}')
  }
  list(ir = ir, diagnostics = diagnostics)
}

arcgis_records <- function(files, view) {
  ir_source_records(files, view, importer_arcgis, 'ArcGIS service capture')
}

arcgis_configuration_source <- function(path) {
  ir_configuration_source(
    importer_arcgis(path)$ir,
    path,
    format = 'arcgis-rest',
    artifact = 'schema/arcgis.json',
    tags = function(op) {
      list(
        if (op$binding$path == '/identify') {
          'service'
        } else {
          paste0(
            'layer_',
            strsplit(op$binding$path, '/', fixed = TRUE)[[1L]][[2L]]
          )
        }
      )
    },
    authentication = function(package) {
      list(
        arcgis_token = paste0(
          toupper(configuration_words(package)),
          '_ARCGIS_TOKEN'
        )
      )
    },
    pagination = function(op) {
      if (is.null(op$pagination)) {
        return(NULL)
      }
      list(
        mode = 'offset',
        parameter = op$pagination$offset_parameter,
        size_parameter = op$pagination$limit_parameter,
        page_size = op$pagination$max_page_size,
        start = 0L,
        completed = if (op$native_name == 'queryRelatedRecords') {
          'api_request_arcgis_related_completed'
        } else {
          'api_request_arcgis_completed'
        },
        items = if (op$native_name == 'query') {
          'api_request_arcgis_features'
        } else {
          'api_request_arcgis_related'
        },
        stop_on_empty = FALSE
      )
    },
    response_policy = 'api_request_arcgis_response'
  )
}

arcgis_validation_report <- function(path) {
  ir_validation_report(
    path,
    importer_arcgis,
    'specmill ArcGIS capture/IR validation 1',
    'arcgis_capture'
  )
}
