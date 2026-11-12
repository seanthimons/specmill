# Internal, explicit registry values avoid process-wide registration side effects.
# Third-party registration is deferred until the public importer contract settles.
importer_registry <- function() {
  entry <- function(format) {
    list(
      version = '1',
      detect = function(path, document) openapi_detect(document, format),
      family = 'openapi',
      artifact = 'openapi',
      companions = character(),
      check = function(path) openapi_assert_format(path, format),
      import = openapi_import_description,
      catalogue = openapi_catalogue_source,
      records = function(files, view) openapi_reviewed_records(files, view),
      references = openapi_reference_inputs
    )
  }
  list(
    openapi = entry('openapi'),
    swagger = entry('swagger'),
    'arcgis-rest' = list(
      version = '1',
      detect = arcgis_detect,
      family = 'arcgis-rest',
      artifact = 'arcgis',
      companions = c('pagination', 'arcgis'),
      import = importer_arcgis,
      records = arcgis_records,
      references = function(path) character(),
      discover = arcgis_discover,
      configuration = arcgis_configuration_source,
      validate = arcgis_validation_report
    ),
    'google-discovery' = list(
      version = '1',
      detect = discovery_detect,
      family = 'google-discovery',
      artifact = 'discovery',
      companions = c('pagination', 'discovery'),
      import = importer_discovery,
      records = discovery_records,
      references = function(path) character(),
      configuration = discovery_configuration_source,
      validate = discovery_validation_report
    ),
    graphql = list(
      version = '1',
      detect = graphql_detect,
      family = 'graphql',
      artifact = 'graphql',
      companions = 'graphql',
      import = importer_graphql,
      records = graphql_records,
      references = function(path) character(),
      configuration = graphql_configuration_source,
      validate = graphql_validation_report
    )
  )
}

# Importers retain their source as schema/<artifact>.<extension>. Setup scripts
# and multi-API initialization find it through this one pattern.
importer_artifact_pattern <- function(registry = importer_registry()) {
  stems <- unique(vapply(registry, `[[`, character(1), 'artifact'))
  paste0('^schema/(', paste(stems, collapse = '|'), ')[.]')
}

# Template companions add client-owned functions from inst/templates/<name>.R,
# named api_request_<name>_* for protocol callbacks.
importer_protocol_companions <- function(companions) {
  setdiff(companions, c('batching', 'pagination'))
}

importer_document <- function(path) {
  extension <- tolower(tools::file_ext(path))
  if (extension %in% c('json', 'yaml', 'yml')) {
    return(read_schema_document(path, resolve_references = FALSE))
  }
  text <- file_text(path)
  if (grepl('^\\s*[{[]', text)) {
    return(jsonlite::fromJSON(text, simplifyVector = FALSE))
  }
  text
}

importer_known_format <- function(path, document) {
  extension <- tolower(tools::file_ext(path))
  formats <- c(
    graphql = 'graphql',
    gql = 'graphql',
    proto = 'protobuf',
    wsdl = 'wsdl',
    raml = 'raml',
    apib = 'api-blueprint'
  )
  if (extension %in% names(formats)) {
    return(unname(formats[[extension]]))
  }
  if (
    is.list(document) &&
      is.list(document$info) &&
      (!is.null(document$info[['_postman_id']]) ||
        is.character(document$info$schema) &&
          length(document$info$schema) == 1L &&
          grepl(
            '^https://schema\\.(getpostman|postman)\\.com/',
            document$info$schema
          ))
  ) {
    return('postman')
  }
  if (!is.character(document) || length(document) != 1L) {
    document <- file_text(path)
  }
  if (is.character(document) && length(document) == 1L) {
    signatures <- c(
      graphql = '(?m)^\\s*(type|interface|schema|extend type)\\s+[A-Za-z_{]',
      protobuf = '(?m)^\\s*(syntax\\s*=|service\\s+[A-Za-z_])',
      wsdl = 'http://schemas\\.xmlsoap\\.org/wsdl/|http://www\\.w3\\.org/ns/wsdl',
      raml = '^#%RAML[[:space:]]',
      `api-blueprint` = '(?m)^FORMAT:[[:space:]]*1A'
    )
    matched <- names(signatures)[vapply(
      signatures,
      grepl,
      logical(1),
      x = document,
      perl = TRUE
    )]
    if (length(matched) == 1L) return(matched[[1L]])
  }
  NULL
}

resolve_importer <- function(
  path,
  format = NULL,
  registry = importer_registry()
) {
  supported <- paste(names(registry), collapse = ', ')
  if (!is.null(format)) {
    config_string(format, 'format')
    if (!format %in% names(registry)) {
      stop(
        'Unsupported format: ',
        format,
        '. Supported formats: ',
        supported,
        call. = FALSE
      )
    }
    if (is.function(registry[[format]]$check)) {
      registry[[format]]$check(path)
    }
    return(list(format = format, importer = registry[[format]]))
  }
  document <- importer_document(path)
  scores <- vapply(
    registry,
    function(entry) {
      score <- entry$detect(path, document)
      if (
        !is.numeric(score) ||
          length(score) != 1L ||
          is.na(score) ||
          !is.finite(score) ||
          score < 0 ||
          score > 1
      ) {
        stop(
          'Importer detect() must return one finite confidence between 0 and 1'
        )
      }
      score
    },
    numeric(1)
  )
  matches <- names(scores)[scores > 0 & scores == max(c(0, scores))]
  if (length(matches) > 1L) {
    stop(
      'Ambiguous schema format: ',
      paste(matches, collapse = ', '),
      '. Set format explicitly. Supported formats: ',
      supported,
      call. = FALSE
    )
  }
  if (!length(matches)) {
    known <- importer_known_format(path, document)
    stop(
      if (is.null(known)) {
        'Unknown schema format'
      } else {
        paste('No importer implemented for', known)
      },
      ': ',
      path,
      '. Supported formats: ',
      supported,
      call. = FALSE
    )
  }
  list(format = matches[[1L]], importer = registry[[matches[[1L]]]])
}

import_description <- function(
  path,
  policy = list(),
  format = NULL,
  registry = importer_registry()
) {
  selected <- resolve_importer(path, format, registry)
  result <- selected$importer$import(path, policy)
  problems <- validate_ir(result$ir)
  if (length(problems)) {
    stop('Importer returned invalid IR: ', paste(problems, collapse = '; '))
  }
  result
}

importer_catalogue_source <- function(
  path,
  label,
  format = NULL,
  registry = importer_registry()
) {
  selected <- resolve_importer(path, format, registry)
  entry <- selected$importer
  source <- if (is.function(entry$catalogue)) {
    entry$catalogue(path, label)
  } else {
    result <- import_description(
      path,
      format = selected$format,
      registry = registry
    )
    ir <- result$ir
    urls <- unique(unlist(
      lapply(ir$sources, function(source) {
        vapply(
          source$servers,
          function(server) server$url %or% '',
          character(1)
        )
      }),
      use.names = FALSE
    ))
    list(
      title = ir$service$title %or% 'Unnamed API',
      hash = digest::digest(file = path, algo = 'sha256'),
      server = function(origin) if (length(urls) == 1L) urls[[1L]] else ''
    )
  }
  source$source_format <- selected$format
  source$importer_version <- entry$version
  source
}

importer_records <- function(files, view, format = NULL) {
  if (!length(files)) {
    return(openapi_reviewed_records(files, view))
  }
  selected <- lapply(files, resolve_importer, format = format)
  formats <- unique(vapply(selected, `[[`, character(1), 'format'))
  # OpenAPI and Swagger share one normalization/duplicate-merging implementation.
  families <- unique(vapply(
    selected,
    function(selection) {
      selection$importer$family %or% selection$format
    },
    character(1)
  ))
  if (length(families) > 1L) {
    stop(
      'Cannot merge different importer families: ',
      paste(formats, collapse = ', ')
    )
  }
  reader <- selected[[1L]]$importer$records
  if (!is.function(reader)) {
    stop('Importer does not support compatibility records: ', formats[[1L]])
  }
  reader(files, view)
}

importer_source_provenance <- function(files, labels, services = list()) {
  stats::setNames(
    lapply(files, function(path) {
      overrides <- unique(unlist(
        lapply(services, function(service) {
          if (path %in% service$files) service[['format']]
        }),
        use.names = FALSE
      ))
      if (length(overrides) > 1L) {
        stop('Conflicting format overrides for ', path)
      }
      selected <- resolve_importer(path, if (length(overrides)) overrides[[1L]])
      list(
        source_format = selected$format,
        importer_version = selected$importer$version
      )
    }),
    labels
  )
}

importer_configuration_source <- function(path) {
  selected <- resolve_importer(path)
  if (is.function(selected$importer$configuration)) {
    return(selected$importer$configuration(path))
  }
  openapi_configuration_source(path)
}

importer_initialization_source <- function(path) {
  selected <- resolve_importer(path)
  if (identical(selected$importer$family, 'openapi')) {
    return(openapi_initialization_source(path))
  }
  source <- importer_catalogue_source(path, basename(path))
  list(
    server = function() source$server(''),
    companions = selected$importer$companions,
    # A source that names no server, such as GraphQL introspection, needs one.
    base_url_required = TRUE
  )
}

importer_operation_keys <- function(path) {
  selected <- resolve_importer(path)
  if (selected$format %in% c('openapi', 'swagger')) {
    return(openapi_operation_keys(path))
  }
  vapply(import_description(path)$ir$operations, `[[`, character(1), 'key')
}

importer_servers <- function(path) {
  selected <- resolve_importer(path)
  if (selected$format %in% c('openapi', 'swagger')) {
    return(schema_servers(path))
  }
  unlist(
    lapply(import_description(path)$ir$sources, function(source) {
      vapply(source$servers, `[[`, character(1), 'url')
    }),
    use.names = FALSE
  )
}
