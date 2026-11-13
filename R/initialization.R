#' Initialize a new client package
#'
#' Create absent package scaffold files, a local schema copy, project policy, a client-owned httr2 request helper, and session controls.
#'
#' This function writes immediately and refuses any existing-file conflict. Supply package, title, author (given, family, email), and license for a new package. Existing DESCRIPTION metadata is retained; it must already declare httr2 and jsonlite, which the default transport needs for HTTP and JSON. Adding a new default transport also requires curl for form uploads. Without an explicit override, generated wrappers use operation, path, then root servers, resolving variable defaults. Ambiguous or unsupported selection produces server_diagnostics and fails before HTTP unless a runtime override is supplied. Baseline YAML defaults.request_controls exposes timeout, max_retries, and retry_writes. Regeneration passes these inherited defaults into helper calls without editing the client-owned helper. Runtime options override these fields. The helper reads the lowercase dry-run prefix plus .request as an R option containing base_url, timeout (default 30 seconds per attempt), max_retries (default 0), and retry_writes (default FALSE). Enabled retries cover transient HTTP responses for GET, HEAD, OPTIONS, PUT and DELETE; other methods need explicit write permission. Retry-After is honored. Normal generation never updates this helper. Initialization does not generate wrappers or tests: follow with generate_client(). The helper is client runtime code and does not import specmill.
#'
#' Initialization also emits client-owned `dev/init.R` and
#' `dev/generate.R`, excluded from package builds. Source the first and call
#' `init_main(root)` with an absent destination to recreate the initial
#' scaffold from local schema copies. Later policy and helper edits are not replayed.
#' Source the second and call `generate_main(args = "--plan")` to preview
#' maintenance; `"--check"` checks and no flag applies. Both locate their
#' source package independently of the working directory. Regeneration preserves
#' these scripts. For prompted setup, see `setup_client()`.
#'
#' New clients also receive client-owned `R/api_options.R` with
#' \code{<package>_run_verbose(verbose = FALSE)} and
#' \code{<package>_dry_run(enabled = FALSE)}. Function prefixes preserve the exact
#' package name; no unprefixed control aliases are exported.
#' These set package-prefixed `run_verbose` and `dry_run` R options.
#' Both default to off. An explicit dry-run option overrides the legacy dry-run
#' environment flag. Dry runs return prepared httr2 requests without sending them;
#' input validation and authentication still apply, and returned requests may
#' contain credentials. Verbose messages contain method and HTTP status only.
#' Multi-API clients share one set of controls. Existing helpers and clients require
#' manual adoption; regeneration never overwrites client-owned runtime files.
#' @param root Destination client directory; it may be created when absent.
#' @param schema Local JSON, YAML, or YML schema, or a reviewed data frame returned by configure_apis for multiple APIs. Multi-API setup requires an existing root containing those schemas, and a new package. Each included API receives a separate request helper, namespaced function names and credential identities.
#' @param package New R package name, for example `catalogueclient`. Must agree with an existing DESCRIPTION when supplied.
#' @param title Human-readable package title, required for a new package.
#' @param author Named list with `given`, `family`, and `email` strings, required for a new package.
#' @param license Explicit license string for a new package. \code{MIT + file LICENSE} also creates an MIT license metadata file.
#' @param base_url Optional absolute HTTP(S) override for all operations in the new client-owned transport. Overrides schema servers; a runtime option can override it.
#' @param naming Preserve operationId names by default, or propose tag-prefixed snake_case names. Or path, which derives names from the route. See configure_client.
#' @param group_by Group operations by first tag (default), or use one default group with none. Multi-API initialization writes one YAML file per API with nested groups; single-schema initialization keeps flat group files.
#' @param companions Optional selection of `batching`, `pagination`, `arcgis`, `discovery`, `graphql` and/or `cache`. ArcGIS captures, Google API Discovery documents and GraphQL introspection results automatically include their protocol callbacks, and the first two include pagination. Batching and pagination emit reusable, exported helper-prefixed companions; arcgis, discovery and graphql add internal protocol callbacks. cache adds the response cache functions that the `response_cache` setting needs and puts cachem and rlang in new-client Imports; an existing DESCRIPTION must declare them. Their client-owned baseline is recorded. Empty by default. Pagination adds digest to new-client Imports; an existing DESCRIPTION must declare it.
#' @param naming_options Options for naming = 'path': prefix, drop_segments, strip_stem, collision_suffix, by_param. See configure_client.
#' @param name_case Case convention for proposed names. Choices are as-is, snake_case, camelCase, PascalCase, SCREAMING_SNAKE_CASE, and dot.case. See configure_client.
#' @return A list of applied file records, each containing file, path, and action. The configuration attribute contains proposed files, operation assignments, and diagnostics. Stops before application for invalid metadata, tag filename collisions, or conflicting scaffold paths.
#' @note Service YAML includes explicit operation allowlists and editable names, including unsupported operations. Name collisions and unsupported transports require review before wrapper generation; initialization does not resolve them. Inspect attr(result, 'configuration')$diagnostics, or preview with configure_client() before initialization.
#' @seealso `configure_hooks` for optional client-owned pre/post execution. [Step-by-step guide](https://seanthimons.github.io/specmill/articles/specmill.html).
#' @export
initialize_client <- function(
  root,
  schema,
  package = NULL,
  title = NULL,
  author = NULL,
  license = NULL,
  base_url = NULL,
  naming = c('operation_id', 'tag_prefix', 'path'),
  group_by = c('tag', 'none'),
  name_case = c(
    'asis',
    'snake_case',
    'camel_case',
    'pascal_case',
    'screaming_snake_case',
    'dot_case'
  ),
  companions = character(),
  naming_options = NULL
) {
  companions <- validate_companions(companions)
  if (is.data.frame(schema)) {
    return(initialize_apis(
      root,
      schema,
      package,
      title,
      author,
      license,
      match.arg(naming),
      match.arg(group_by),
      match.arg(name_case),
      companions,
      validate_naming_options(match.arg(naming), naming_options)
    ))
  }
  schema <- normalizePath(schema, winslash = '/', mustWork = TRUE)
  naming <- match.arg(naming)
  naming_options <- validate_naming_options(naming, naming_options)
  name_case <- match.arg(name_case)
  group_by <- match.arg(group_by)
  source <- importer_initialization_source(schema)
  companions <- union(companions, source$companions)
  base_url_override <- base_url
  if (!is.null(base_url) && !valid_server_url(base_url)) {
    stop(
      'Supply an absolute HTTP(S) base_url without credentials, query, or fragment'
    )
  }
  if (is.null(base_url)) {
    base_url <- source$server()
  }
  if (isTRUE(source$base_url_required) && !nzchar(base_url %or% '')) {
    stop(
      'The schema names no server; supply base_url. For GraphQL, use the ',
      'endpoint URL without its last path segment'
    )
  }
  description <- file.path(root, 'DESCRIPTION')
  existing <- file.exists(description)
  if (existing) {
    metadata <- read.dcf(description)[1L, ]
    if (
      !is.null(package) && !identical(package, unname(metadata[['Package']]))
    ) {
      stop('Package metadata conflicts with DESCRIPTION')
    }
    package <- unname(metadata[['Package']])
  } else {
    config_string(package, 'package')
    config_string(title, 'title')
    config_string(license, 'license')
    config_fields(author, c('given', 'family', 'email'), 'author')
    for (field in c('given', 'family', 'email')) {
      config_string(author[[field]], paste('author', field))
    }
    metadata <- c(
      Package = package,
      Title = title,
      Version = '0.0.0.9000',
      'Authors@R' = paste0(
        'person(',
        r_literal(author$given),
        ', ',
        r_literal(author$family),
        ', email = ',
        r_literal(author$email),
        ", role = c('aut', 'cre'))"
      ),
      Description = paste(title, 'Client generated from a local API schema.'),
      License = license,
      Encoding = 'UTF-8',
      Imports = paste(
        c(
          'httr2 (>= 1.3.0)',
          'jsonlite',
          'curl',
          if ('pagination' %in% companions) 'digest',
          if ('cache' %in% companions) c('cachem', 'rlang')
        ),
        collapse = ', '
      ),
      # Cassette scenario tests need these (vcr 2 for local cassettes); hooks
      # move yaml to Imports.
      Suggests = 'testthat, vcr (>= 2.0.0), withr, yaml'
    )
  }
  if (!grepl('^[A-Za-z][A-Za-z0-9.]*$', package) || endsWith(package, '.')) {
    stop('Invalid R package name')
  }
  imports <- trimws(sub(
    ' *\\(.*',
    '',
    strsplit(
      metadata[['Imports']] %or% '',
      ',',
      fixed = TRUE
    )[[1L]]
  ))
  needs_helper <- !file.exists(file.path(root, 'R', 'api_request.R'))
  if (existing && !all(c('httr2', 'jsonlite') %in% imports)) {
    stop(
      'Existing DESCRIPTION must declare httr2 and jsonlite before adding the default transport'
    )
  }
  if (existing && needs_helper && !'curl' %in% imports) {
    stop(
      'Existing DESCRIPTION must declare curl before adding the default transport'
    )
  }
  if (existing && 'pagination' %in% companions && !'digest' %in% imports) {
    stop(
      'Existing DESCRIPTION must declare digest before adding pagination companions'
    )
  }
  if (
    existing &&
      'cache' %in% companions &&
      !all(c('cachem', 'rlang') %in% imports)
  ) {
    stop(
      'Existing DESCRIPTION must declare cachem and rlang before adding the cache companion'
    )
  }
  scaffold <- request_helper_scaffold(
    'api_request',
    base_url,
    base_url_override,
    dry_run_env(package),
    companions
  )
  proposal <- configuration_proposal(
    schema,
    package,
    naming,
    group_by,
    name_case,
    naming_options = naming_options
  )
  if (
    any(vapply(
      proposal$diagnostics,
      function(x) x$code == 'group_collision',
      logical(1)
    ))
  ) {
    stop('Tag groups collide; inspect configure_client() before initialization')
  }
  output <- c(
    proposal$files,
    list(
      'R/api_request.R' = scaffold$code,
      'R/api_options.R' = gsub(
        'CLIENT_PREFIX',
        package,
        gsub(
          'OPTION_PREFIX',
          r_literal(tolower(sub('_DRY_RUN$', '', dry_run_env(package)))),
          file_text(system.file(
            'templates/options.R',
            package = 'specmill',
            mustWork = TRUE
          )),
          fixed = TRUE
        ),
        fixed = TRUE
      ),
      '.specmill/helpers/api_request.json' = scaffold$provenance,
      '.Rbuildignore' = '^specmill\\.yml$\n^apis$\n^schema$\n^\\.specmill$\n^dev$'
    )
  )
  output <- c(
    output,
    initialization_scripts(
      grep(importer_artifact_pattern(), names(proposal$files), value = TRUE),
      list(
        package = package,
        title = title,
        author = author,
        license = license,
        base_url = base_url_override,
        naming = naming,
        group_by = group_by,
        name_case = name_case,
        companions = companions,
        naming_options = naming_options
      )
    )
  )
  if (!existing) {
    dcf <- character()
    connection <- textConnection('dcf', 'w', local = TRUE)
    write.dcf(as.list(metadata), connection)
    close(connection)
    output[['DESCRIPTION']] <- paste(dcf, collapse = '\n')
    output[['NAMESPACE']] <- '# Generated by roxygen2: do not edit by hand'
    if (license == 'MIT + file LICENSE') {
      output[['LICENSE']] <- paste0(
        'YEAR: ',
        format(Sys.Date(), '%Y'),
        '\nCOPYRIGHT HOLDER: ',
        author$given,
        ' ',
        author$family
      )
    }
  }
  conflicts <- names(output)[file.exists(file.path(root, names(output)))]
  if (length(conflicts)) {
    stop(
      'Initialization conflicts with existing files: ',
      paste(conflicts, collapse = ', ')
    )
  }
  if (!dir.exists(root) && !dir.create(root, recursive = TRUE)) {
    stop('Cannot create client root')
  }
  result <- apply_files(root, output, mode = 'apply')
  attr(result, 'configuration') <- proposal
  result
}
