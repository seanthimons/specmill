prune_fixture <- function() {
  root <- tempfile('prune-')
  dir.create(root)
  dir.create(file.path(root, 'R'))
  writeLines(
    'request_helper <- function(...) list(...)',
    file.path(root, 'R/helper.R')
  )
  writeLines(
    c('config_version: 1', 'services: [service.yml]'),
    file.path(root, 'specmill.yml')
  )
  writeLines(
    c(
      'id: demo',
      'schemas: {files: [api.yml]}',
      'helper: request_helper',
      'names:',
      '  GET /good: demo_good',
      '  GET /other: demo_other'
    ),
    file.path(root, 'service.yml')
  )
  path <- function(name) {
    list(
      get = list(
        operationId = name,
        responses = list('200' = list(description = 'OK'))
      )
    )
  }
  yaml::write_yaml(
    list(
      swagger = '2.0',
      info = list(title = 'Prune', version = '1'),
      paths = list('/good' = path('good'), '/other' = path('other'))
    ),
    file.path(root, 'api.yml')
  )
  root
}

prune_run <- function(root, mode, ...) {
  tryCatch(
    suppressMessages(specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = mode,
      ...
    )),
    error = identity
  )
}

prune_owned <- function(root) {
  names(jsonlite::read_json(file.path(root, '.specmill/manifest.json'))$files)
}

prune_acceptance <- function() {
  root <- prune_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  other <- file.path(root, 'R/demo_other.R')
  manifest <- file.path(root, '.specmill/manifest.json')
  stopifnot(!inherits(prune_run(root, 'apply'), 'error'))
  # Deferral preserves output by default.
  defer <- list(enroll = c('demo GET /other' = 'retired'))
  stopifnot(!inherits(prune_run(root, 'apply', deferrals = defer), 'error'))
  stopifnot(file.exists(other), 'R/demo_other.R' %in% prune_owned(root))
  # Bad requests.
  stopifnot(
    inherits(prune_run(root, 'plan', prune = 'demo GET /nope'), 'error'),
    inherits(prune_run(root, 'plan', prune = 'demo GET /good'), 'error'),
    inherits(prune_run(root, 'plan', prune = c('all', 'x')), 'error'),
    inherits(prune_run(root, 'plan', prune = 'all', confirm = 'y'), 'error')
  )
  # Plan and check do not write.
  before <- readLines(manifest)
  plan <- prune_run(root, 'plan', prune = 'demo GET /other')
  removed <- vapply(
    Filter(function(x) x$action == 'remove', plan$files),
    `[[`,
    '',
    'file'
  )
  stopifnot(
    'R/demo_other.R' %in% removed,
    !'R/demo_good.R' %in% removed,
    file.exists(other),
    identical(before, readLines(manifest))
  )
  # An edited output is retained, not deleted.
  original <- readLines(other)
  writeLines(c(original, '# hand edit'), other)
  edited <- prune_run(root, 'plan', prune = 'demo GET /other')
  stopifnot(
    !'R/demo_other.R' %in%
      vapply(
        Filter(function(x) x$action == 'remove', edited$files),
        `[[`,
        '',
        'file'
      )
  )
  writeLines(original, other)
  # Apply removes the file and ownership; the next run is a no-op.
  stopifnot(!inherits(
    prune_run(root, 'apply', prune = 'demo GET /other'),
    'error'
  ))
  stopifnot(
    !file.exists(other),
    !'R/demo_other.R' %in% prune_owned(root),
    'R/demo_good.R' %in% prune_owned(root),
    file.exists(file.path(root, 'R/demo_good.R'))
  )
  stopifnot(!inherits(prune_run(root, 'check'), 'error'))

  # prune = 'all': plan first, confirmation required, hand-written files stay.
  owned <- prune_owned(root)
  stopifnot(length(owned) > 0L)
  planned <- prune_run(root, 'plan', prune = 'all')
  stopifnot(
    !inherits(planned, 'error'),
    all(file.exists(file.path(root, owned)))
  )
  # Non-interactive without confirm, and an explicit refusal, change nothing.
  stopifnot(
    inherits(prune_run(root, 'apply', prune = 'all'), 'error'),
    inherits(prune_run(root, 'apply', prune = 'all', confirm = FALSE), 'error'),
    inherits(prune_run(root, 'apply', prune = 'all', confirm = 'y'), 'error'),
    all(file.exists(file.path(root, owned)))
  )
  stopifnot(!inherits(
    prune_run(root, 'apply', prune = 'all', confirm = TRUE),
    'error'
  ))
  stopifnot(
    !any(file.exists(file.path(root, owned))),
    file.exists(file.path(root, 'R/helper.R')),
    length(prune_owned(root)) == 0L
  )
  # Re-running is a no-op and needs no confirmation.
  stopifnot(!inherits(prune_run(root, 'apply', prune = 'all'), 'error'))
  cat('prune ok\n')
}

prune_documentation_acceptance <- function() {
  root <- tempfile('prune-docs-')
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    root,
    system.file('catalogue/schema.json', package = 'specmill'),
    package = 'prunetest',
    title = 'Prune Test',
    author = list(given = 'Test', family = 'Maintainer', email = 'test@example.org'),
    license = 'MIT + file LICENSE',
    base_url = 'https://example.invalid'
  )
  run <- function(mode, ...) {
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = mode,
      validation = FALSE,
      artifacts = c('wrappers', 'documentation'),
      ...
    )
  }
  suppressMessages(run('apply'))
  namespace <- function() readLines(file.path(root, 'NAMESPACE'))
  stopifnot(
    file.exists(file.path(root, 'R/get_item.R')),
    file.exists(file.path(root, 'man/get_item.Rd')),
    'export(get_item)' %in% namespace()
  )
  id <- unique(grep('/items/\\{item_id\\}$', unlist(lapply(
      jsonlite::read_json(file.path(root, '.specmill/manifest.json'))$files,
      function(x) unlist(x$operations)
    )), value = TRUE))
  stopifnot(length(id) == 1L)
  defer <- list(enroll = stats::setNames('retired', id))
  suppressMessages(run('apply', deferrals = defer))
  stopifnot(file.exists(file.path(root, 'R/get_item.R')))
  suppressMessages(run('apply', prune = id))
  stopifnot(
    !file.exists(file.path(root, 'R/get_item.R')),
    !file.exists(file.path(root, 'man/get_item.Rd')),
    !'export(get_item)' %in% namespace(),
    !'R/get_item.R' %in% prune_owned(root),
    !'man/get_item.Rd' %in% prune_owned(root)
  )
  cat('prune documentation ok\n')
}

prune_services <- function(root, ids) {
  writeLines(
    c('config_version: 1', paste0('services: [', paste0(ids, '.yml', collapse = ', '), ']')),
    file.path(root, 'specmill.yml')
  )
  for (id in ids) {
    route <- if (id == 'old' || id == 'new') '/other' else '/good'
    writeLines(
      c(
        paste0('id: ', id),
        'schemas: {files: [api.yml]}',
        'helper: request_helper',
        paste0('selection: {include: [GET ', route, ']}'),
        'names:',
        paste0('  GET ', route, ': demo_', substring(route, 2L))
      ),
      file.path(root, paste0(id, '.yml'))
    )
  }
}

prune_retired_service_acceptance <- function() {
  root <- prune_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  other <- file.path(root, 'R/demo_other.R')
  prune_services(root, c('keep', 'old'))
  stopifnot(!inherits(prune_run(root, 'apply'), 'error'))
  # The owning service is replaced by one that defers the same route.
  prune_services(root, c('keep', 'new'))
  defer <- list(enroll = c('new GET /other' = 'retired'))
  stopifnot(!inherits(prune_run(root, 'apply', deferrals = defer), 'error'))
  stopifnot(file.exists(other), 'R/demo_other.R' %in% prune_owned(root))
  # The deferral ID resolves to the single retired owner of the route.
  stopifnot(!inherits(
    prune_run(root, 'apply', prune = 'new GET /other'),
    'error'
  ))
  stopifnot(
    !file.exists(other),
    !'R/demo_other.R' %in% prune_owned(root),
    file.exists(file.path(root, 'R/demo_good.R'))
  )
  # An ID from a service that is no longer configured prunes by ownership.
  prune_services(root, c('keep', 'old'))
  stopifnot(!inherits(prune_run(root, 'apply'), 'error'))
  prune_services(root, 'keep')
  stopifnot(file.exists(other))
  stopifnot(!inherits(
    prune_run(root, 'apply', prune = 'old GET /other'),
    'error'
  ))
  stopifnot(!file.exists(other), file.exists(file.path(root, 'R/demo_good.R')))
  cat('prune retired service ok\n')
}

prune_path_acceptance <- function() {
  root <- prune_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  stopifnot(!inherits(prune_run(root, 'apply'), 'error'))
  # Stale entries that own no operations: two files gone, one hand-edited.
  edited <- file.path(root, 'R/edited.R')
  specmill::apply_files(
    root,
    list('R/ghost.R' = 'a <- 1', 'R/other_ghost.R' = 'a <- 1', 'R/edited.R' = 'a <- 1'),
    mode = 'apply'
  )
  unlink(file.path(root, c('R/ghost.R', 'R/other_ghost.R')))
  writeLines('a <- 2', edited)
  stopifnot(inherits(prune_run(root, 'apply', prune = 'R/demo_good.R'), 'error'))
  stopifnot(!inherits(prune_run(root, 'plan', prune = 'R/ghost.R'), 'error'))
  stopifnot('R/ghost.R' %in% prune_owned(root))
  stopifnot(!inherits(prune_run(root, 'apply', prune = c('R/ghost.R', 'R/edited.R')), 'error'))
  owned <- prune_owned(root)
  stopifnot(
    !'R/ghost.R' %in% owned,
    'R/other_ghost.R' %in% owned,
    file.exists(edited),
    identical(readLines(edited), 'a <- 2'),
    file.exists(file.path(root, 'R/demo_good.R'))
  )
  # Re-running without prune is a no-op.
  stopifnot(!inherits(prune_run(root, 'apply'), 'error'))
  stopifnot(identical(prune_owned(root), owned))
  cat('prune path ok\n')
}

if (sys.nframe() == 0L) {
  prune_acceptance()
  prune_retired_service_acceptance()
  prune_documentation_acceptance()
  prune_path_acceptance()
}
