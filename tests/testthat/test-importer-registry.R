importer_registry_acceptance <- function() {
  internal <- function(name) utils::getFromNamespace(name, 'specmill')
  resolve <- internal('resolve_importer')
  root <- tempfile('registry-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  fail <- function(expr, pattern) {
    error <- tryCatch(force(expr), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  source <- system.file('catalogue/schema.json', package = 'specmill')
  file.copy(source, file.path(root, 'api.json'))
  path <- file.path(root, 'api.json')
  stopifnot(identical(resolve(path)$format, 'openapi'))
  imported <- internal('import_description')(path)
  stopifnot(!length(internal('validate_ir')(imported$ir)))
  reviewed <- internal('import_description')(
    path,
    policy = list(methods = 'GET')
  )
  stopifnot(all(vapply(
    reviewed$ir$operations,
    function(op) op$binding$method == 'GET',
    logical(1)
  )))
  fail(specmill::read_operations(path, format = 'swagger'), 'does not declare')
  fail(resolve(path, 'missing'), 'Supported formats: openapi, swagger')
  for (extension in c('graphql', 'proto', 'wsdl', 'raml', 'apib')) {
    file <- file.path(root, paste0('known.', extension))
    writeLines('description', file)
    fail(resolve(file), 'No importer implemented.*Supported formats')
    unlink(file)
  }
  for (text in c(
    'type Query { hello: String }',
    'syntax = "proto3";',
    '#%RAML 1.0',
    'FORMAT: 1A',
    '<definitions xmlns="http://schemas.xmlsoap.org/wsdl/"/>'
  )) {
    file <- file.path(root, 'source.txt')
    writeLines(text, file)
    fail(resolve(file), 'No importer implemented')
  }
  file <- file.path(root, 'postman.json')
  jsonlite::write_json(
    list(info = list('_postman_id' = 'local-fixture')),
    file,
    auto_unbox = TRUE
  )
  fail(resolve(file), 'postman.*Supported formats')
  unlink(file)
  writeLines('unrecognized', file.path(root, 'source.txt'))
  fail(
    resolve(file.path(root, 'source.txt')),
    'Unknown schema format.*Supported formats'
  )
  # Registry values are explicit: independent callers cannot mutate the defaults.
  fake <- list(
    version = 'test-1',
    detect = function(path, document) 0.9,
    import = function(path, policy) list(ir = imported$ir, diagnostics = list())
  )
  custom <- list(toy = fake)
  metadata <- internal('importer_catalogue_source')(
    file.path(root, 'source.txt'),
    'source.txt',
    registry = custom
  )
  stopifnot(
    metadata$source_format == 'toy',
    metadata$importer_version == 'test-1',
    identical(
      names(internal('importer_registry')()),
      c('openapi', 'swagger', 'arcgis-rest', 'google-discovery', 'graphql')
    )
  )
  fail(
    resolve(path, registry = list(a = fake, b = fake)),
    'Ambiguous.*Set format'
  )
  stopifnot(
    resolve(path, 'b', registry = list(a = fake, b = fake))$format == 'b'
  )
  invalid <- fake
  invalid$detect <- function(path, document) NA_real_
  fail(resolve(path, registry = list(bad = invalid)), 'finite confidence')
  invalid$import <- function(path, policy) list(ir = list())
  fail(
    internal('import_description')(
      path,
      format = 'bad',
      registry = list(bad = invalid)
    ),
    'invalid IR'
  )
  unlink(file.path(root, 'source.txt'))
  choices <- data.frame(
    schema = 'api.json',
    format = 'openapi',
    base_url = 'https://registry.invalid'
  )
  table <- specmill::configure_apis(
    root,
    choices = choices,
    review = FALSE,
    mode = 'apply'
  )
  stopifnot(
    table$format == 'openapi',
    table$source_format == 'openapi',
    table$importer_version == '1'
  )
  saved <- yaml::read_yaml(file.path(root, 'specmill-apis.yml'))$apis[[1L]]
  stopifnot(
    saved$format == 'openapi',
    saved$source_format == 'openapi',
    saved$importer_version == '1'
  )
  repeated <- specmill::configure_apis(root, review = FALSE)
  stopifnot(
    repeated$format == 'openapi',
    identical(
      table[setdiff(names(table), 'status')],
      repeated[setdiff(names(repeated), 'status')]
    )
  )
  renamed_path <- file.path(root, 'renamed.json')
  file.copy(path, renamed_path)
  renamed <- specmill::configure_apis(
    root,
    schemas = renamed_path,
    review = FALSE
  )
  stopifnot(renamed$format == 'openapi', renamed$api == table$api)
  unlink(renamed_path)
  client <- root
  specmill::initialize_client(
    client,
    table,
    package = 'registryclient',
    title = 'Registry client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT'
  )
  api <- yaml::read_yaml(file.path(client, 'apis', paste0(table$api, '.yml')))
  stopifnot(api$format == 'openapi')
  specmill::generate_client(
    client,
    config = 'specmill.yml',
    mode = 'apply',
    validation = FALSE
  )
  manifest <- jsonlite::read_json(file.path(client, '.specmill/manifest.json'))
  stopifnot(
    length(manifest$importers) == 1L,
    manifest$importers[[1L]]$source_format == 'openapi',
    manifest$importers[[1L]]$importer_version == '1'
  )
  # Every importer retains its source under a name the setup scripts can find.
  samples <- list(
    openapi = source,
    'arcgis-rest' = test_path('fixtures', 'arcgis/conductivity.json'),
    'google-discovery' = test_path('fixtures', 'discovery/monitoring.json'),
    graphql = test_path('fixtures', 'graphql/monitoring.json')
  )
  entries <- internal('importer_registry')()
  pattern <- internal('importer_artifact_pattern')()
  stopifnot(
    setequal(c(names(samples), 'swagger'), names(entries)),
    all(vapply(
      entries,
      function(entry) {
        is.character(entry$artifact) &&
          length(entry$artifact) == 1L &&
          is.character(entry$companions)
      },
      logical(1)
    ))
  )
  for (format in names(samples)) {
    selected <- internal('resolve_importer')(samples[[format]])
    artifact <- internal('importer_configuration_source')(
      samples[[format]]
    )$artifact()$file
    stopifnot(
      selected$format == format,
      grepl(pattern, artifact),
      startsWith(artifact, paste0('schema/', entries[[format]]$artifact, '.'))
    )
  }
  cat(
    'Importer registry: confidence, overrides, known/unknown formats, IR validation, catalogue persistence, provenance and retained-source names passed.\n'
  )
}
test_that('importer registry recognizes and resolves source formats', {
  importer_registry_acceptance()
  succeed()
})
