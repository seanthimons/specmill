coverage_schema_acceptance <- function() {
  # --- Counting rules on synthetic inspections -----------------------------------
  entry <- function(service, key, source = '/schemas/ccd.json', status = 'selected') {
    list(id = paste(service, key), service = service, key = key, source = source, status = status)
  }
  wrapped <- function(service, key) {
    parts <- strsplit(key, ' ', fixed = TRUE)[[1L]]
    list(id = paste(service, key), service = service, method = parts[[1L]], path = parts[[2L]], implemented = TRUE)
  }
  counts <- function(inventory, operations, members, exclude = character()) {
    specmill:::coverage_schema_counts(
      list(inventory = inventory, operations = operations),
      members,
      exclude,
      '/schemas'
    )
  }
  # The -full and -rebuild services share one schema: each operation counts once, and
  # an operation wrapped by either service is wrapped.
  inventory <- list(
    entry('full', 'GET /a'),
    entry('full', 'GET /b'),
    entry('full', 'GET /health', status = 'excluded'),
    entry('rebuild', 'GET /a'),
    entry('rebuild', 'GET /b', status = 'excluded'),
    entry('rebuild', 'GET /health', status = 'excluded')
  )
  operations <- list(wrapped('full', 'GET /a'), wrapped('rebuild', 'GET /a'))
  shared <- counts(inventory, operations, c('full', 'rebuild'))
  stopifnot(
    shared$total == 3L,
    shared$implemented == 1L,
    identical(shared$gaps$key, c('GET /b', 'GET /health')),
    # Selected by any service counts as selected; excluded everywhere does not.
    identical(shared$gaps$status, c('selected', 'excluded')),
    identical(shared$gaps$services, c('full, rebuild', 'full, rebuild')),
    identical(shared$gaps$schema, c('ccd.json', 'ccd.json'))
  )
  # Deliberately skipped operations leave the denominator.
  skipped <- counts(inventory, operations, c('full', 'rebuild'), '^GET /health$')
  stopifnot(skipped$total == 2L, identical(skipped$gaps$key, 'GET /b'))
  stopifnot(counts(inventory, operations, 'full', c('^GET /health', '/b$'))$total == 1L)
  # Different schemas that share a route are different operations.
  two_apis <- counts(
    list(
      entry('ccd', 'GET /health', '/schemas/ccd.json'),
      entry('epi', 'GET /health', '/schemas/epi.json')
    ),
    list(wrapped('ccd', 'GET /health')),
    c('ccd', 'epi')
  )
  stopifnot(
    two_apis$total == 2L,
    two_apis$implemented == 1L,
    identical(two_apis$gaps$schema, 'epi.json')
  )
  # Services outside the group, an empty group and unparseable path items.
  stopifnot(counts(inventory, operations, 'other')$total == 0L)
  path_failure <- counts(
    list(entry('ccd', 'PATH /odd', status = 'unsupported'), entry('ccd', 'GET /a')),
    list(wrapped('ccd', 'GET /a')),
    'ccd'
  )
  stopifnot(path_failure$total == 2L, identical(path_failure$gaps$key, 'PATH /odd'))

  # --- End to end ------------------------------------------------------------------
  workspace <- tempfile('coverage-schema-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  schema <- file.path(workspace, 'schema.json')
  operation <- function(name) {
    list(operationId = name, responses = list('200' = list(description = 'OK')))
  }
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Coverage', version = '1'),
      servers = list(list(url = 'http://127.0.0.1:1')),
      paths = list(
        '/a' = list(get = operation('get_a')),
        '/b' = list(get = operation('get_b')),
        '/c' = list(post = operation('post_c')),
        '/health' = list(get = operation('get_health'))
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  root <- file.path(workspace, 'client')
  specmill::initialize_client(
    root,
    schema,
    package = 'coverageclient',
    title = 'Coverage Client',
    author = list(given = 'Test', family = 'Maintainer', email = 'test@example.org'),
    license = 'MIT + file LICENSE'
  )
  service_path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
  service$selection$exclude <- list('^/health$')
  yaml::write_yaml(service, service_path)
  specmill::generate_client(validation = FALSE, root, config = 'specmill.yml', mode = 'apply')
  report <- function(denominator = NULL, exclude = NULL, mode = 'plan') {
    group <- list(services = '^coverageclient$', label = 'Coverage', badge = 'badge.json')
    group$denominator <- denominator
    group$exclude <- exclude
    out <- utils::capture.output(
      result <- specmill::coverage_report(
        root,
        list(baseline = 'baseline.json', groups = list(all = group)),
        mode = mode
      )
    )
    list(result = result, output = out)
  }
  # The default is unchanged: the selected operations are the whole denominator.
  selected <- report()
  stopifnot(
    selected$result$baseline$all_endpoints == 3L,
    selected$result$baseline$all_coverage == 100,
    !length(selected$result$gaps),
    !any(grepl('schema operations', selected$output))
  )
  explicit <- report('selected')
  stopifnot(identical(explicit$result$baseline$all_endpoints, 3L))
  # Against the schema, the operation skipped by selection.exclude is a visible gap.
  against <- report('schema')
  gap <- against$result$gaps$all
  stopifnot(
    against$result$baseline$all_endpoints == 4L,
    against$result$baseline$all_functions == 3L,
    against$result$baseline$all_coverage == 75,
    against$result$outputs$all_coverage == '75.0',
    against$result$outputs$all_color == 'green',
    identical(gap$key, 'GET /health'),
    identical(gap$status, 'excluded'),
    identical(gap$schema, 'schema/openapi.json'),
    any(grepl('1 schema operations without a wrapper (1 not selected)', against$output, fixed = TRUE))
  )
  # `exclude` removes deliberately skipped operations from the denominator.
  trimmed <- report('schema', list('^GET /health$'))
  stopifnot(
    trimmed$result$baseline$all_endpoints == 3L,
    trimmed$result$baseline$all_coverage == 100,
    !nrow(trimmed$result$gaps$all),
    # An empty gap list keeps its column types.
    identical(
      vapply(trimmed$result$gaps$all, class, character(1)),
      c(key = 'character', schema = 'character', status = 'character', services = 'character')
    )
  )
  untouched <- report('schema', list('^DELETE '))
  stopifnot(untouched$result$baseline$all_endpoints == 4L)
  # Apply writes the same badge format and the baseline, and writes nothing in plan.
  stopifnot(!file.exists(file.path(root, 'badge.json')))
  report('schema', mode = 'apply')
  badge <- jsonlite::read_json(file.path(root, 'badge.json'))
  baseline <- jsonlite::read_json(file.path(root, 'baseline.json'))
  stopifnot(
    identical(names(badge), c('schemaVersion', 'label', 'message', 'color')),
    identical(badge$message, '75.0%'),
    identical(badge$color, 'green'),
    baseline$all_endpoints == 4L,
    baseline$all_functions == 3L
  )
  # Policy errors name the problem and write nothing.
  fails <- function(pattern, ...) {
    error <- tryCatch(report(...), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  fails('denominator must be selected or schema', 'everything')
  fails('exclude requires denominator: schema', exclude = list('^GET /health'))
  fails('exclude requires denominator: schema', 'selected', list('^GET /health'))
  fails('invalid regex', 'schema', list('('))
  fails('must be a nonempty string', 'schema', list(1L))
  cat('Coverage: schema denominator, exclusions, deduplication, gaps and badges passed.\n')
}

if (sys.nframe() == 0L) {
  coverage_schema_acceptance()
}
