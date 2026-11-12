# Source from an interactive session at the repository root. This development
# utility makes explicit metadata captures; package imports never crawl services.
capture_arcgis <- function(urls, output, max_resources = 100L) {
  valid_url <- utils::getFromNamespace('valid_server_url', 'specmill')
  words <- utils::getFromNamespace('configuration_words', 'specmill')
  if (
    !is.character(urls) ||
      !length(urls) ||
      !all(vapply(urls, valid_url, logical(1)))
  ) {
    stop('Supply public HTTP(S) metadata URLs without queries or credentials')
  }
  if (
    dir.exists(output) &&
      length(list.files(output, all.files = TRUE, no.. = TRUE))
  ) {
    stop('Capture output must be new or empty')
  }
  if (
    !is.numeric(max_resources) ||
      length(max_resources) != 1L ||
      !is.finite(max_resources) ||
      max_resources < 1
  ) {
    stop('max_resources must be positive')
  }
  dir.create(
    file.path(output, 'services'),
    recursive = TRUE,
    showWarnings = FALSE
  )
  seen <- new.env(parent = emptyenv())
  directories <- list()
  services <- character()
  diagnostics <- list()
  count <- 0L
  select <- function(document, keys) document[intersect(keys, names(document))]
  report <- function(url, reason) {
    diagnostics[[length(diagnostics) + 1L]] <<- list(url = url, reason = reason)
  }
  fetch <- function(url) {
    count <<- count + 1L
    if (count > max_resources) {
      stop('Capture resource limit exceeded')
    }
    response <- httr2::req_perform(httr2::req_timeout(
      httr2::request(paste0(url, '?f=pjson')),
      30
    ))
    raw <- httr2::resp_body_raw(response)
    document <- tryCatch(
      jsonlite::fromJSON(rawToChar(raw), simplifyVector = FALSE),
      error = identity
    )
    if (inherits(document, 'error')) {
      stop('Metadata endpoint returned non-JSON content')
    }
    if (!is.null(document$error)) {
      stop('Metadata endpoint returned an ArcGIS error')
    }
    list(
      url = url,
      sha256 = digest::digest(raw, serialize = FALSE, algo = 'sha256'),
      document = document
    )
  }
  visit <- function(url, depth = 0L) {
    if (depth > 8L) {
      stop('Capture folder-depth limit exceeded')
    }
    if (!is.null(seen[[url]])) {
      return(invisible(NULL))
    }
    seen[[url]] <- TRUE
    resource <- tryCatch(fetch(url), error = identity)
    if (inherits(resource, 'error')) {
      report(url, conditionMessage(resource))
      return(invisible(NULL))
    }
    document <- resource$document
    if (grepl('/(MapServer|FeatureServer)$', url)) {
      resource$arcgis_capture_version <- '1'
      resource$kind <- 'service'
      resource$document <- select(
        document,
        c(
          'currentVersion',
          'name',
          'mapName',
          'capabilities',
          'supportedOperations',
          'maxRecordCount',
          'layers',
          'tables',
          'authInfo'
        )
      )
      layers <- Filter(
        function(layer) is.null(layer$subLayerIds),
        c(document$layers, document$tables)
      )
      resource$layers <- lapply(layers, function(layer) {
        result <- fetch(paste0(url, '/', layer$id))
        raw <- result$document
        result$document <- select(
          raw,
          c(
            'id',
            'name',
            'type',
            'geometryType',
            'currentVersion',
            'capabilities',
            'supportedOperations',
            'maxRecordCount',
            'advancedQueryCapabilities',
            'objectIdField',
            'objectIdFieldName',
            'relationships'
          )
        )
        result$document$fields <- lapply(
          raw$fields,
          select,
          keys = c('name', 'type', 'alias', 'nullable', 'length', 'domain')
        )
        result$document$relationships <- lapply(
          raw$relationships,
          select,
          keys = c(
            'id',
            'name',
            'relatedTableId',
            'keyField',
            'cardinality',
            'role'
          )
        )
        result
      })
      name <- paste0(
        'services/',
        words(sub('^.*/([^/]+)/(FeatureServer|MapServer)$', '\\1', url)),
        '-',
        substr(digest::digest(url, serialize = FALSE, algo = 'sha256'), 1L, 8L),
        '.json'
      )
      jsonlite::write_json(
        resource,
        file.path(output, name),
        auto_unbox = TRUE,
        pretty = TRUE,
        null = 'null'
      )
      services <<- c(services, name)
    } else {
      resource$document <- select(
        document,
        c('currentVersion', 'folders', 'services')
      )
      directories[[length(directories) + 1L]] <<- resource
      catalog <- sub('(/rest/services)(/.*)?$', '\\1', url)
      if (identical(catalog, url) && !endsWith(url, '/rest/services')) {
        stop('Expected an ArcGIS service-directory URL')
      }
      for (service in document$services) {
        next_url <- paste0(
          catalog,
          '/',
          utils::URLencode(service$name, reserved = FALSE),
          '/',
          service$type
        )
        if (!service$type %in% c('MapServer', 'FeatureServer')) {
          report(
            next_url,
            paste('Unsupported ArcGIS service type:', service$type)
          )
        } else {
          visit(next_url, depth + 1L)
        }
      }
      for (folder in document$folders) {
        visit(
          paste0(catalog, '/', utils::URLencode(folder, reserved = FALSE)),
          depth + 1L
        )
      }
    }
    invisible(NULL)
  }
  for (url in sub('/+$', '', urls)) {
    visit(url)
  }
  index <- list(
    arcgis_capture_version = '1',
    kind = 'directory',
    urls = as.list(urls),
    retrieved = format(Sys.time(), tz = 'UTC', usetz = TRUE),
    directories = directories,
    services = as.list(sort(unique(services))),
    diagnostics = diagnostics
  )
  jsonlite::write_json(
    index,
    file.path(output, 'directory.json'),
    auto_unbox = TRUE,
    pretty = TRUE,
    null = 'null'
  )
  cli::cli_alert_success(
    'Captured {length(services)} services in {count} metadata requests; {length(diagnostics)} diagnostics'
  )
  invisible(index)
}
