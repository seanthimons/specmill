schema_identity <- function(document) {
  canonical <- function(x) {
    if (!is.list(x)) {
      return(x)
    }
    if (!is.null(names(x))) {
      x <- x[sort(names(x), method = 'radix')]
    }
    lapply(x, canonical)
  }
  digest::digest(canonical(document), algo = 'sha256')
}

# Conservative base URLs: no credentials, query, fragment, or URI templates.
valid_server_url <- function(url) {
  is.character(url) &&
    length(url) == 1L &&
    !is.na(url) &&
    grepl(
      '^https?://([A-Za-z0-9.-]+|\\[[0-9A-Fa-f:]+\\])(:[0-9]+)?(/[^?#]*)?$',
      url
    ) &&
    !grepl('[[:space:]{}\\\\]', url) &&
    !grepl('%(?![0-9A-Fa-f]{2})', url, perl = TRUE) &&
    !is.null(tryCatch(curl::curl_parse_url(url), error = function(e) NULL)) &&
    !grepl(':0(/|$)', sub('^https?://([^/]+).*$', '\\1', url))
}

#' Review and save names and servers for multiple APIs
#'
#' Discover local schemas and review API names, server URLs and inclusion in one table. Names are proposed from schema titles rather than filenames.
#'
#' @param root Existing project directory.
#' @param schemas Local schema paths inside root. Discovery includes JSON, YAML, GraphQL, protobuf, WSDL, RAML and API Blueprint extensions directly inside root, excluding specmill project and catalogue configuration files.
#' @param origins Optional character vector of download URLs, named by schema path relative to root. Used to resolve relative servers.
#' @param choices Optional data frame keyed by schema with api, base_url, include or format columns for scripted review. A format override is resolved before review; blank means automatic detection. Registered formats currently include openapi, swagger, arcgis-rest, google-discovery, and graphql. Local ArcGIS directory captures expand into service rows with source diagnostics for inaccessible or unsupported entries. Recognition of other formats reports an unimplemented importer.
#' @param review Open the table in R's data editor for one review of names, base URLs and include flags. Requires an interactive session. NULL opens the editor only for new or changed schemas in an interactive session; saved unchanged choices do not prompt again.
#' @param mode Plan returns the table without writing. Apply saves validated selections to specmill-apis.yml.
#' @return A data frame with schema, title, api, base_url, include, origin, hash, format, source_format, importer_version and status columns.
#' @details Saved selections are reused by schema path, or by canonical content hash after renaming a file. Equivalent JSON and YAML documents with reordered object keys have the same identity. New duplicate content is deselected; distinct schemas with duplicate titles receive hash suffixes for review. Ambiguous or missing servers require an explicit choice. Explicit format overrides are saved and copied into API configuration during initialization. The detected source format and importer version are recorded in the catalogue and generated ownership provenance. Third-party registration remains internal while the contract settles. This catalogue prepares multi-API setup; it does not itself generate wrappers or request helpers.
#' @export
configure_apis <- function(
  root,
  schemas = NULL,
  origins = NULL,
  choices = NULL,
  review = NULL,
  mode = c('plan', 'apply')
) {
  mode <- match.arg(mode)
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  if (is.null(schemas)) {
    schemas <- list.files(
      root,
      '\\.(json|ya?ml|graphql|gql|proto|wsdl|raml|apib)$',
      full.names = TRUE,
      ignore.case = TRUE
    )
    schemas <- schemas[
      !tolower(basename(schemas)) %in%
        c(
          'specmill.yml',
          'specmill.yaml',
          'specmill-apis.yml',
          'specmill-apis.yaml'
        )
    ]
  }
  if (!length(schemas)) {
    stop('No schema files found')
  }
  source_diagnostics <- list()
  expanded <- FALSE
  schemas <- unlist(
    lapply(schemas, function(path) {
      selected <- tryCatch(resolve_importer(path), error = function(e) NULL)
      if (is.null(selected) || !is.function(selected$importer$discover)) {
        return(path)
      }
      discovery <- selected$importer$discover(path)
      if (!identical(discovery$files, path)) {
        expanded <<- TRUE
      }
      source_diagnostics <<- c(source_diagnostics, discovery$diagnostics)
      discovery$files
    }),
    use.names = FALSE
  )
  if (expanded) {
    schemas <- unique(schemas)
  }
  if (!length(schemas)) {
    cli::cli_abort(
      'No supported service captures in the selected local directories; inspect their source diagnostics.'
    )
  }
  paths <- normalizePath(schemas, winslash = '/', mustWork = TRUE)
  if (!all(startsWith(paths, paste0(root, '/')))) {
    stop('Schemas must be inside the project root')
  }
  relative <- substring(paths, nchar(root) + 2L)
  if (anyDuplicated(relative)) {
    stop('Duplicate schema path')
  }
  if (
    !is.null(origins) &&
      (is.null(names(origins)) ||
        anyDuplicated(names(origins)) ||
        !all(names(origins) %in% relative))
  ) {
    stop('origins must be named by relative schema path')
  }
  catalog_path <- project_path(root, 'specmill-apis.yml')
  prior_hash <- if (file.exists(catalog_path)) {
    output_hash(catalog_path)
  } else {
    NULL
  }
  previous <- if (file.exists(catalog_path)) {
    data <- read_config_yaml(catalog_path)
    config_fields(data, c('catalog_version', 'apis'), 'API catalogue')
    if (!identical(data$catalog_version, 1L)) {
      stop('Unsupported API catalogue version')
    }
    config_data(data$apis)
  } else {
    list()
  }
  if (
    !is.null(choices) &&
      (!is.data.frame(choices) ||
        !'schema' %in% names(choices) ||
        anyDuplicated(choices$schema) ||
        !all(choices$schema %in% relative) ||
        !all(
          names(choices) %in%
            c('schema', 'api', 'base_url', 'include', 'format')
        ))
  ) {
    stop(
      'choices must be a data frame with schema and optional api, base_url, include, format columns'
    )
  }
  rows <- lapply(seq_along(paths), function(i) {
    prior_path <- Filter(
      function(record) identical(record$schema, relative[[i]]),
      previous
    )
    override <- if (length(prior_path) == 1L) {
      prior_path[[1L]][['format']]
    } else {
      NULL
    }
    reviewed_format <- !is.null(choices) &&
      'format' %in% names(choices) &&
      relative[[i]] %in% choices$schema
    if (reviewed_format) {
      override <- choices$format[[match(relative[[i]], choices$schema)]]
    }
    if (identical(override, '')) {
      override <- NULL
    }
    source <- importer_catalogue_source(paths[[i]], relative[[i]], override)
    hash <- source$hash
    matches <- Filter(
      function(record) identical(record$schema, relative[[i]]),
      previous
    )
    if (!length(matches)) {
      matches <- Filter(function(record) identical(record$hash, hash), previous)
    }
    prior <- if (length(matches) == 1L) matches[[1L]] else list()
    # Content identity also retains an explicit override after a file rename.
    if (
      !reviewed_format && is.null(override) && nzchar(prior[['format']] %or% '')
    ) {
      override <- prior[['format']]
      source <- importer_catalogue_source(paths[[i]], relative[[i]], override)
    }
    title <- source$title
    suggested <- configuration_words(sub(
      ' (API|Module)$',
      '',
      sub('^.* - ', '', title)
    ))
    if (
      !nzchar(suggested) ||
        grepl('^[0-9]|^(con|prn|aux|nul|com[0-9]|lpt[0-9])$', suggested)
    ) {
      suggested <- paste0('api_', suggested)
    }
    origin <- if (relative[[i]] %in% names(origins)) {
      origins[[relative[[i]]]]
    } else {
      prior$origin %or% ''
    }
    base_url <- prior$base_url %or% source$server(origin)
    data.frame(
      schema = relative[[i]],
      title = title,
      api = prior$api %or% suggested,
      base_url = base_url,
      include = prior$include %or% TRUE,
      origin = origin,
      hash = hash,
      format = override %or% '',
      source_format = source$source_format,
      importer_version = source$importer_version,
      saved = identical(prior$hash, hash) &&
        identical(
          prior$source_format %or% source$source_format,
          source$source_format
        ) &&
        identical(
          prior$importer_version %or% source$importer_version,
          source$importer_version
        ),
      stringsAsFactors = FALSE
    )
  })
  table <- do.call(rbind, rows)
  # Equal schema content is a duplicate even when formatting or filenames differ.
  duplicate <- duplicated(table$hash)
  table$include[duplicate & !table$saved] <- FALSE
  unique_rows <- !duplicated(table$hash)
  conflict_names <- table$api[unique_rows][duplicated(table$api[unique_rows])]
  conflicts <- table$api %in% conflict_names
  table$api[conflicts & !table$saved] <- paste0(
    table$api[conflicts & !table$saved],
    '_',
    substr(table$hash[conflicts & !table$saved], 1L, 8L)
  )
  table$status <- ifelse(
    duplicate,
    'Duplicate schema content',
    ifelse(
      !nzchar(table$base_url),
      'Needs base URL or download origin',
      'Ready for review'
    )
  )
  if (is.null(review)) {
    review <- interactive() && !all(table$saved)
  }
  table$saved <- NULL
  before <- table
  if (!is.null(choices)) {
    if (
      !is.data.frame(choices) ||
        !'schema' %in% names(choices) ||
        anyDuplicated(choices$schema) ||
        !all(choices$schema %in% table$schema) ||
        !all(
          names(choices) %in%
            c('schema', 'api', 'base_url', 'include', 'format')
        )
    ) {
      stop(
        'choices must be a data frame with schema and optional api, base_url, include columns'
      )
    }
    for (field in setdiff(names(choices), c('schema', 'format'))) {
      table[match(choices$schema, table$schema), field] <- choices[[field]]
    }
  }
  if (review) {
    if (!interactive()) {
      stop(
        'Interactive review requires an R session; use review = FALSE to preview'
      )
    }
    message(
      'Review API names, base URLs and include flags together. Close the editor to continue.'
    )
    table <- utils::edit(table)
  }
  if (
    !is.data.frame(table) ||
      !identical(names(table), names(before)) ||
      !identical(
        table[c(
          'schema',
          'title',
          'origin',
          'hash',
          'status',
          'format',
          'source_format',
          'importer_version'
        )],
        before[c(
          'schema',
          'title',
          'origin',
          'hash',
          'status',
          'format',
          'source_format',
          'importer_version'
        )]
      )
  ) {
    stop('Only api, base_url and include may be edited')
  }
  if (!is.logical(table$include) || anyNA(table$include)) {
    stop('include must contain TRUE or FALSE')
  }
  selected <- table[table$include, , drop = FALSE]
  if (
    !is.character(table$api) ||
      anyNA(table$api) ||
      !all(grepl('^[a-z][a-z0-9_]*$', table$api)) ||
      anyDuplicated(selected$api)
  ) {
    stop(
      'Included APIs need distinct lowercase names using letters, digits and underscores'
    )
  }
  if (!is.character(table$base_url) || anyNA(table$base_url)) {
    stop('base_url must contain strings')
  }
  if (mode == 'apply') {
    if (!nrow(selected)) {
      stop('Select at least one API')
    }
    if (
      !all(grepl('^https?://[^/]+', selected$base_url)) ||
        any(grepl('[{}]', selected$base_url))
    ) {
      stop('Supply an absolute base URL for every included API before saving')
    }
    records <- lapply(seq_len(nrow(table)), function(i) {
      as.list(table[
        i,
        c(
          'schema',
          'hash',
          'api',
          'base_url',
          'include',
          'origin',
          'format',
          'source_format',
          'importer_version'
        )
      ])
    })
    if (file.exists(catalog_path)) {
      # The catalogue is explicitly maintained here; abort if another writer changed it during review.
      current <- config_data(read_config_yaml(catalog_path)$apis)
      if (!identical(current, previous)) {
        stop('API catalogue changed during review; retry')
      }
    }
    apply_files(
      root,
      list(
        'specmill-apis.yml' = sub(
          '\n$',
          '',
          yaml::as.yaml(list(catalog_version = 1L, apis = records))
        )
      ),
      mode = 'apply',
      owned = function(path) identical(output_hash(path), prior_hash)
    )
  }
  if (length(source_diagnostics)) {
    attr(table, 'source_diagnostics') <- source_diagnostics
    warning(
      paste(
        vapply(
          source_diagnostics,
          function(x) paste(x$url, x$reason, sep = ': '),
          character(1)
        ),
        collapse = '\n'
      ),
      call. = FALSE
    )
  }
  table
}
