configuration_words <- function(x) {
  x <- gsub('([A-Z]+)([A-Z][a-z])', '\\1_\\2', x)
  x <- gsub('([a-z0-9])([A-Z])', '\\1_\\2', x)
  x <- tolower(gsub('[^A-Za-z0-9]+', '_', x))
  gsub('^_+|_+$', '', x)
}

configuration_case <- function(x, name_case) {
  if (name_case == 'asis') {
    return(x)
  }
  words <- strsplit(configuration_words(x), '_', fixed = TRUE)[[1L]]
  if (name_case == 'snake_case') {
    return(paste(words, collapse = '_'))
  }
  if (name_case == 'screaming_snake_case') {
    return(toupper(paste(words, collapse = '_')))
  }
  if (name_case == 'dot_case') {
    return(paste(words, collapse = '.'))
  }
  camel <- paste0(
    words[[1L]],
    paste0(
      toupper(substring(words[-1L], 1L, 1L)),
      substring(words[-1L], 2L),
      collapse = ''
    )
  )
  if (name_case == 'camel_case') {
    return(camel)
  }
  paste0(toupper(substring(camel, 1L, 1L)), substring(camel, 2L))
}

configuration_name_diagnostics <- function(operations, package) {
  public_names <- vapply(operations, `[[`, character(1), 'name')
  collisions <- duplicated(tolower(public_names)) |
    duplicated(tolower(public_names), fromLast = TRUE) |
    public_names %in%
      c(
        'api_request',
        'run_hook',
        paste0(package, c('_run_verbose', '_dry_run'))
      )
  lapply(which(collisions), function(i) {
    diagnostic <- list(
      key = operations[[i]]$key,
      code = 'name_collision',
      message = paste('Choose a distinct public name for:', public_names[[i]])
    )
    if (!is.null(operations[[i]]$api)) {
      diagnostic$api <- operations[[i]]$api
    }
    diagnostic
  })
}

configuration_proposal <- function(
  schema,
  package,
  naming,
  group_by,
  name_case = 'asis',
  reviewed_names = list(),
  naming_options = NULL,
  api = NULL,
  origin = NULL
) {
  naming <- match.arg(naming, c('operation_id', 'tag_prefix', 'path'))
  naming_options <- validate_naming_options(naming, naming_options)
  group_by <- match.arg(group_by, c('tag', 'none'))
  name_case <- match.arg(
    name_case,
    c(
      'asis',
      'snake_case',
      'camel_case',
      'pascal_case',
      'screaming_snake_case',
      'dot_case'
    )
  )
  config_string(package, 'package')
  if (!grepl('^[A-Za-z][A-Za-z0-9.]*$', package) || endsWith(package, '.')) {
    stop('Invalid R package name')
  }
  source <- importer_configuration_source(schema)
  records <- list()
  diagnostics <- list()
  report <- function(key, code, message) {
    diagnostics[[length(diagnostics) + 1L]] <<- list(
      key = key,
      code = code,
      message = message
    )
  }
  source$operations(
    function(metadata) {
      key <- metadata$key
      path <- metadata$path
      method <- metadata$method
      tags <- metadata$tags
      tag <- if (length(tags)) tags[[1L]] else 'default'
      if (!length(tags)) {
        report(key, 'missing_tag', 'Assigned to default')
      }
      if (length(tags) > 1L) {
        report(key, 'multiple_tags', paste('Assigned to first tag:', tag))
      }
      group <- configuration_words(tag)
      if (!nzchar(group)) {
        group <- 'group'
      }
      if (
        grepl('^[0-9]|^(con|prn|aux|nul|com[0-9]|lpt[0-9]|api_request)$', group)
      ) {
        group <- paste0('group_', group)
      }
      prefix <- group
      if (group_by == 'none') {
        group <- 'default'
      }
      name <- metadata$name
      if (naming == 'path') {
        # The route alone decides the name, so operationId is not consulted.
        name <- path_operation_name(
          toupper(method),
          path,
          naming_options,
          api
        )
      } else if (
        is.null(name) ||
          !is.character(name) ||
          length(name) != 1L ||
          is.na(name) ||
          !nzchar(name) ||
          !identical(make.names(name), name) ||
          name == '...'
      ) {
        name <- paste(method, configuration_words(path), sep = '_')
        report(key, 'derived_name', paste('Derived name:', name))
      }
      if (naming == 'tag_prefix') {
        words <- strsplit(configuration_words(name), '_', fixed = TRUE)[[1L]]
        # Only exact tag tokens and their simple plural are removed; no synonyms.
        words <- words[!words %in% c(prefix, paste0(prefix, 's'))]
        name <- paste(c(prefix, words), collapse = '_')
      }
      raw <- name
      name <- make.names(configuration_case(name, name_case))
      records[[length(records) + 1L]] <<- list(
        key = key,
        tag = tag,
        group = group,
        name = name,
        raw = raw,
        method = toupper(method),
        path = path
      )
    },
    report
  )
  if (!length(records)) {
    stop('Schema contains no operations')
  }
  if (naming == 'path') {
    resolved <- resolve_path_name_collisions(
      records,
      naming_options,
      function(raw) make.names(configuration_case(raw, name_case))
    )
    records <- lapply(resolved$records, function(record) {
      record$name <- make.names(configuration_case(record$raw, name_case))
      record
    })
    for (diagnostic in resolved$diagnostics) {
      report(diagnostic$key, diagnostic$code, diagnostic$message)
    }
  }
  keys <- vapply(records, `[[`, character(1), 'key')
  groups <- vapply(records, `[[`, character(1), 'group')
  tags <- vapply(records, `[[`, character(1), 'tag')
  public_names <- vapply(records, `[[`, character(1), 'name')
  for (key in intersect(names(reviewed_names), keys)) {
    name <- config_string(reviewed_names[[key]], paste(key, 'reviewed name'))
    if (!identical(make.names(name), name) || name == '...') {
      stop('Invalid reviewed operation name: ', key)
    }
    public_names[[match(key, keys)]] <- name
    records[[match(key, keys)]]$name <- name
  }
  members <- split(seq_along(groups), groups)
  for (group in names(members)) {
    if (group_by == 'tag' && length(unique(tags[members[[group]]])) > 1L) {
      report(
        group,
        'group_collision',
        'Distinct tags produce the same service filename'
      )
    }
  }
  diagnostics <- c(
    diagnostics,
    configuration_name_diagnostics(records, package)
  )
  # Diagnostic parsing must not fail early on the very name collisions we report.
  parsed <- read_operations(
    schema,
    list(names = as.list(setNames(paste0('operation_', seq_along(keys)), keys)))
  )
  for (diagnostic in parsed$diagnostics) {
    report(diagnostic$key, 'unsupported', diagnostic$reason)
    fields <- c('classification', 'source_location', 'guidance')
    diagnostics[[length(diagnostics)]][fields] <- diagnostic[fields]
    diagnostics[[length(diagnostics)]]$diagnostic_code <- diagnostic$code
  }
  encode <- function(x, comments = list()) {
    text <- sub('\n$', '', yaml::as.yaml(x))
    for (field in names(comments)) {
      text <- sub(
        paste0('(?m)^', field, ':'),
        paste0(comments[[field]], '\n', field, ':'),
        text,
        perl = TRUE
      )
    }
    text
  }
  services <- sort(unique(groups), method = 'radix')
  artifact <- source$artifact()
  schema_file <- artifact$file
  files <- setNames(list(artifact$text), schema_file)
  project <- list(
    config_version = 1L,
    package = package,
    services = as.list(paste0('apis/', services, '.yml')),
    selection = list(
      methods = as.list(c(
        'GET',
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
        'HEAD',
        'OPTIONS',
        'TRACE'
      )),
      exclude = list()
    ),
    helper = 'api_request',
    documentation = TRUE,
    defaults = list(
      implementation = 'generated',
      request_controls = list(
        timeout = 30L,
        max_retries = 0L,
        retry_writes = FALSE
      ),
      batch = list(max_items = NULL, max_bytes = NULL)
    )
  )
  if (
    source$security_declared() ||
      any(vapply(
        parsed$operations,
        function(op) !is.null(op[['security']]),
        logical(1)
      ))
  ) {
    project$authentication <- source$authentication(package)
  }
  files[['specmill.yml']] <- paste(
    encode(
      project,
      list(
        package = '# Package identity; keep consistent with DESCRIPTION.',
        services = '# Service configuration files, relative to the package root.',
        selection = '# Package-wide limits: services cannot re-enable these excluded methods or paths.',
        helper = '# Default runtime helper; services may override it.',
        documentation = '# Generate help and exports unless a service overrides this setting.',
        defaults = '# Shared settings; service defaults and individual overrides take precedence.\n# Request controls: seconds per attempt, retries after the first attempt, and explicit write replay permission.\n# Runtime package.request options override these generated defaults.\n# Keep function names and output files in service YAML.',
        authentication = paste(
          '# Schema security scheme -> environment variable name. Never put tokens here.',
          '# API keys and bearer tokens map to environment variables; OAuth sign-in needs a reviewed oauth entry.',
          sep = '\n'
        )
      )
    ),
    if (is.null(project$authentication)) {
      '# authentication: {} # Opt in to generated auth when the schema declares security.'
    },
    '# Optional formatting: uncomment and use your exact installed air version.',
    '# formatter: {name: air, version: "0.9.0"}',
    '# Callback source files to fingerprint; pass their functions via callbacks, too.',
    'callback_files: []',
    sep = '\n'
  )
  for (group in services) {
    selected <- members[[group]]
    service <- list(
      id = if (group == 'default' && length(services) == 1L) package else group,
      schemas = c(
        list(files = list(schema_file)),
        if (!is.null(origin)) list(origin = origin),
        list(patterns = list(), exclude = list())
      ),
      selection = list(
        methods = as.list(c(
          'GET',
          'POST',
          'PUT',
          'PATCH',
          'DELETE',
          'HEAD',
          'OPTIONS',
          'TRACE'
        )),
        exclude = list(),
        include = as.list(keys[selected])
      ),
      names = as.list(setNames(public_names[selected], keys[selected]))
    )
    # Untagged schemas retain the existing per-function source layout.
    service$defaults <- setNames(list(), character())
    if (group != 'default') {
      service$defaults <- c(
        service$defaults,
        list(
          file = paste0('R/', group, '.R'),
          docs = list(
            tags = list(family = paste(unique(tags[selected]), 'endpoints'))
          )
        )
      )
    }
    service$operations <- setNames(list(), character())
    for (op in parsed$operations) {
      if (
        op$key %in%
          keys[selected] &&
          identical(op$body$type, 'array') &&
          !is.null(op$body$maxItems)
      ) {
        service$operations[[op$key]] <- list(
          batch = list(max_items = op$body$maxItems)
        )
      }
    }
    files[[paste0('apis/', group, '.yml')]] <- paste(
      encode(
        service,
        list(
          schemas = paste(
            '# Local schema files; patterns are file globs, exclude matches basenames by regex.',
            '# All paths resolve from the package root.',
            sep = '\n'
          ),
          selection = paste(
            '# An operation must pass methods AND include AND not match exclude (path regexes).',
            '# Keep only GET and POST below to omit PUT/PATCH/DELETE wrappers.',
            '# Leave their include/name entries in place; regeneration removes unchanged owned output.',
            '# An empty include selects nothing; remove include to allow every matching operation.',
            sep = '\n'
          ),
          helper = '# Runtime request helper, defined in R/.',
          documentation = '# Generate roxygen, help pages, and NAMESPACE exports.',
          names = '# Edit the public R function names here; keys stay METHOD /original/path.',
          defaults = paste(
            '# Shared operation settings. Per-operation settings below override these.',
            '# file groups wrappers in one R file; omit it for one file per function.',
            if (group == 'default') {
              '# Example: add file: R/endpoints.R under defaults.'
            },
            '# docs can set title, description, return, parameters, examples, tags and lifecycle.',
            sep = '\n'
          ),
          operations = paste(
            '# Optional overrides keyed by METHOD /original/path. Replace {} with entries.',
            '# Each entry can set file, helper, parameters, parameter_order and docs.',
            '# parameters keys use the original location and name, e.g. "query limit".',
            '# Example parameter setting: {name: max_results, default: 10, description: Maximum results.}',
            '# Advanced facades use inputs, extra_parameters and request.arguments mappings.',
            sep = '\n'
          )
        )
      ),
      '# Inherited from specmill.yml; uncomment to override for this service:',
      '# helper: api_request',
      '# documentation: true',
      '# Optional hooks: define client functions before enabling these settings.',
      '# hooks: {} # Public wrapper name -> pre_request/post_response/post_combine hook-name sequences.',
      '# hook_callback: run_hook',
      '# Optional paging: one wrapper call requests every page. Opt in explicitly; nothing is inferred from parameter names.',
      '# pagination: {} # e.g. {mode: page, parameter: pageNumber, start: 1, max_pages: 100}; under defaults it applies to every operation that has that parameter.',
      '# hook_config: inst/hooks.yml # Alternative to inline hooks, not both.',
      '# prepare: prepare_operation # Development callback; pass an explicit callbacks environment.',
      '# policy_version: "1" # Your review label, recorded in generation metadata.',
      '# Optional fixed request expectations for generated tests:',
      '# contracts: {} # Public wrapper name -> fixed request expectations.',
      '# contracts_file: tests/testthat/contracts.rds',
      '# response_fixture: {} # Mock response used by inline single-call contracts.',
      '# testing: {file: tests/testthat/fixtures/testing.yml} # Cassette scenarios, gaps and unrecorded routes.',
      '# Full configuration examples: https://seanthimons.github.io/specmill/articles/configuration.html',
      sep = '\n'
    )
  }
  records <- lapply(records, function(record) {
    record[c('key', 'tag', 'group', 'name')]
  })
  if (is.function(source$decorate)) {
    files <- source$decorate(files, parsed)
  }
  list(files = files, operations = records, diagnostics = diagnostics)
}

reviewed_configuration_names <- function(root, proposal) {
  reviewed <- list()
  add <- function(api, service) {
    mappings <- service$names %or% list()
    for (key in names(service$operations %or% list())) {
      name <- service$operations[[key]]$name
      if (!is.null(name)) {
        mappings[[key]] <- name
      }
    }
    for (key in names(mappings)) {
      id <- if (nzchar(api)) paste(api, key) else key
      if (is.null(reviewed[[id]])) {
        reviewed[[id]] <<- mappings[[key]]
      } else if (!identical(reviewed[[id]], mappings[[key]])) {
        # Groups may wrap one route several times; a proposal has one slot.
        warning(
          'Reviewed operation ',
          id,
          ' has several names; the proposal keeps only ',
          reviewed[[id]],
          ' (also: ',
          mappings[[key]],
          ')',
          call. = FALSE
        )
      }
    }
  }
  for (file in grep('^apis/', names(proposal$files), value = TRUE)) {
    path <- file.path(root, file)
    if (!file.exists(path)) {
      next
    }
    config <- read_config_yaml(path)
    if ('groups' %in% names(config)) {
      for (group in config$groups) {
        add(config$api, group)
      }
    } else {
      add('', config)
    }
  }
  reviewed
}

# The one schemas.origin shared by a project's existing service files, if any.
existing_schema_origin <- function(root, files) {
  origins <- unique(unlist(lapply(
    grep('^apis/.*[.]ya?ml$', files, value = TRUE),
    function(file) {
      path <- file.path(root, file)
      if (file.exists(path)) read_config_yaml(path)$schemas$origin
    }
  )))
  if (length(origins) == 1L && valid_server_url(origins)) origins
}

#' Propose editable configuration from a schema
#'
#' Discover every operation, group by its first tag, and propose project and service YAML without generating endpoint functions.
#'
#' @param root Client directory. Planning does not create it.
#' @param schema Local OpenAPI 3.0, 3.1 or 3.2 or Swagger 2.0 JSON, YAML, or YML file, or a reviewed configure_apis data frame for multiple APIs.
#' @param package R package name; read from DESCRIPTION when present. A supplied name must agree with existing metadata.
#' @param naming Preserve valid operationId names, use tag-prefixed snake_case, or derive names from the route (path): path segments joined, without brace parameters, then name_case. Missing or invalid IDs get method/path names. Prefixing removes exact tag tokens and their simple plural, not synonyms.
#' @param group_by Group by first operation tag, or keep one default service. Missing tags use default. Untagged/default services keep per-function source files; other groups configure a shared R file and help family.
#' @param name_case Case convention applied to proposed names: preserve them as-is, or use snake_case, camelCase, PascalCase, SCREAMING_SNAKE_CASE, or dot.case. Exact names already reviewed in service YAML are preserved.
#' @param naming_options Only with `naming = 'path'`; a named list, all fields optional. `prefix`: a string, or a named list matched by exact API id, then by the API's family token (the part before the first underscore, which it replaces), then `default`, else the API id. A list rather than one string because a catalogue mixes families (for example `ctx_*`, `chemi_*`, `epi_*`) that need different heads. `drop_segments`: route segments left out of names (default 'api'). `strip_stem`: drop a leading segment equal to the service id or its remainder after the family (default TRUE); the id is used, not the schema file name, which is arbitrary. `collision_suffix`: upper-case HTTP method to name fragment, e.g. `list(POST = 'bulk')`. `by_param`: qualify same-method collisions with path parameters, e.g. reports_by_id (default TRUE). Names still equal afterwards stay a name_collision diagnostic; each rename is reported as name_collision_resolved.
#' @param origin Optional reviewed absolute HTTP(S) URL the schema was downloaded from; written to each service YAML as `schemas.origin` so relative servers resolve against it. When omitted, an origin already recorded in the existing service files is kept. Not for multiple APIs.
#' @param mode Preview by default. Apply creates absent files only; differing existing files or colliding tag filenames stop the entire write.
#' @return A list with named YAML/schema text in files, operation assignments in operations, diagnostics, and changes. Each change contains file, action (create, unchanged, conflict), before, and after. Schemas with security declarations get an authentication map from scheme names to proposed environment-variable names. It contains no tokens; names can be edited before generation. API keys and HTTP bearer tokens are supported; OAuth authorization-code sign-in needs a reviewed `oauth` credential (see the configuration guide).
#' @details The proposal includes a schema copy, specmill.yml, and apis/*.yml. Each service selects exact METHOD /path pairs through selection.include. Multiple tags use the first tag with a diagnostic. Names and tag filenames are checked for collisions; reserved runtime names are diagnosed. Name-collision diagnostics identify every contributing METHOD /path and use API-qualified names for multi-API proposals. Name collisions may be written for manual correction but block subsequent wrapper generation. Edit matching names entries in existing service YAML and rerun this function; reviewed names are reused across reruns and schema ordering. Noninteractive runs return diagnostics and never prompt or silently rename public functions. Unsupported operations stay in the configuration with their diagnostics. This does not supply transport implementations or resolve unsupported schema features.
#'
#' Existing files are never overwritten, even if originally generated. Only matching reviewed names, including deliberate operation-level name overrides, are carried into the proposal; other existing settings remain untouched. Review changes and manually incorporate the desired YAML edits. Apply with no new files is a no-op. This is initial scaffolding, not automatic schema-refresh reconciliation. No helper, package metadata, wrappers, or tests are created by this function; use initialize_client for a new package.
#' @note Schema copies retain the source format and extension; YAML inputs do not create converted JSON sidecars. For a reviewed multi-API data frame, the proposal contains one `apis/<api>.yml` per included API. Each file holds shared schema, selection, helper, authentication and default settings plus nested tag groups. Groups inherit API settings and cannot re-enable project- or API-excluded methods or paths. Existing flat service files remain supported.
#' @seealso `configure_hooks` for optional client-owned pre/post execution. `initialize_client`, `generate_client`, `load_project`
#' @examples
#' schema <- system.file('catalogue/schema.json', package = 'specmill')
#' proposal <- configure_client(tempfile(), schema, package = 'catalogueclient')
#' proposal$files[['apis/default.yml']]
#' @export
configure_client <- function(
  root,
  schema,
  package = NULL,
  naming = c('operation_id', 'tag_prefix', 'path'),
  group_by = c('tag', 'none'),
  mode = c('plan', 'apply'),
  name_case = c(
    'asis',
    'snake_case',
    'camel_case',
    'pascal_case',
    'screaming_snake_case',
    'dot_case'
  ),
  naming_options = NULL,
  origin = NULL
) {
  mode <- match.arg(mode)
  if (!is.null(origin) && !valid_server_url(origin)) {
    stop(
      'Supply an absolute HTTP(S) origin without credentials, query, or fragment'
    )
  }
  if (!is.null(origin) && is.data.frame(schema)) {
    stop('Record origins for multiple APIs as schemas.origin in each API file')
  }
  if (
    !is.null(origin) && !isTRUE(importer_initialization_source(schema)$origin)
  ) {
    stop('origin applies only to OpenAPI and Swagger schemas')
  }
  naming <- match.arg(naming)
  naming_options <- validate_naming_options(naming, naming_options)
  name_case <- match.arg(name_case)
  group_by <- match.arg(group_by)
  description <- file.path(root, 'DESCRIPTION')
  if (file.exists(description)) {
    existing <- unname(read.dcf(description)[1L, 'Package'])
    if (!is.null(package) && !identical(package, existing)) {
      stop('Package metadata conflicts with DESCRIPTION')
    }
    package <- existing
  }
  proposal <- if (is.data.frame(schema)) {
    multi_api_proposal(
      root,
      schema,
      package,
      naming,
      group_by,
      name_case,
      naming_options = naming_options
    )
  } else {
    configuration_proposal(
      schema,
      package,
      naming,
      group_by,
      name_case,
      naming_options = naming_options,
      origin = origin
    )
  }
  if (is.null(origin) && !is.data.frame(schema)) {
    # Keep a reviewed origin that initialization wrote, so reruns compare equal.
    origin <- existing_schema_origin(root, names(proposal$files))
    if (!is.null(origin)) {
      proposal <- configuration_proposal(
        schema,
        package,
        naming,
        group_by,
        name_case,
        naming_options = naming_options,
        origin = origin
      )
    }
  }
  reviewed <- reviewed_configuration_names(root, proposal)
  if (length(reviewed)) {
    proposal <- if (is.data.frame(schema)) {
      multi_api_proposal(
        root,
        schema,
        package,
        naming,
        group_by,
        name_case,
        reviewed,
        naming_options = naming_options
      )
    } else {
      configuration_proposal(
        schema,
        package,
        naming,
        group_by,
        name_case,
        reviewed,
        naming_options = naming_options,
        origin = origin
      )
    }
  }
  proposal$changes <- lapply(names(proposal$files), function(file) {
    path <- if (dir.exists(root)) {
      project_path(root, file)
    } else {
      file.path(root, file)
    }
    before <- if (file.exists(path)) file_text(path) else NULL
    list(
      file = file,
      action = if (is.null(before)) {
        'create'
      } else if (identical(before, proposal$files[[file]])) {
        'unchanged'
      } else {
        'conflict'
      },
      before = before,
      after = proposal$files[[file]]
    )
  })
  if (mode == 'apply') {
    conflicts <- vapply(
      Filter(function(x) x$action == 'conflict', proposal$changes),
      `[[`,
      character(1),
      'file'
    )
    if (length(conflicts)) {
      stop(
        'Existing configuration differs; review the plan: ',
        paste(conflicts, collapse = ', ')
      )
    }
    if (
      any(vapply(
        proposal$diagnostics,
        function(x) x$code == 'group_collision',
        logical(1)
      ))
    ) {
      stop('Tag groups collide; review the plan before writing')
    }
    new <- vapply(
      Filter(function(x) x$action == 'create', proposal$changes),
      `[[`,
      character(1),
      'file'
    )
    if (length(new)) {
      dir.create(root, recursive = TRUE, showWarnings = FALSE)
      apply_files(root, proposal$files[new], mode = 'apply')
    }
  }
  proposal
}
