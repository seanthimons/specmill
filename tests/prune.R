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

if (sys.nframe() == 0L) {
  prune_acceptance()
  prune_documentation_acceptance()
}
