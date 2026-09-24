hook_scaffold_acceptance <- function() {
  root <- tempfile('hook-scaffold-')
  library <- tempfile('hook-library-')
  dir.create(library)
  on.exit(unlink(c(root, library), recursive = TRUE), add = TRUE)
  fails <- function(expr, pattern) {
    error <- tryCatch(force(expr), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  specmill::initialize_client(
    root,
    system.file('catalogue/schema.json', package = 'specmill'),
    package = 'hooktestclient',
    title = 'Hook Test Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://example.invalid'
  )
  plan <- specmill::configure_hooks(root)
  stopifnot(
    identical(plan$missing_imports, 'yaml'),
    !file.exists(file.path(root, 'inst/hooks.yml'))
  )
  fails(specmill::configure_hooks(root, 'apply'), 'Imports')
  metadata <- read.dcf(file.path(root, 'DESCRIPTION'))
  metadata[1, 'Imports'] <- paste(metadata[1, 'Imports'], 'yaml', sep = ', ')
  write.dcf(metadata, file.path(root, 'DESCRIPTION'))
  writeLines('run_hook <- function(...) NULL', file.path(root, 'R/other.R'))
  stopifnot(length(specmill::configure_hooks(root)$collisions) == 1L)
  fails(specmill::configure_hooks(root, 'apply'), 'Existing hook executor')
  unlink(file.path(root, 'R/other.R'))
  specmill::configure_hooks(root, 'apply')
  stopifnot(all(vapply(
    specmill::configure_hooks(root, 'apply')$changes,
    function(x) x$action == 'unchanged',
    logical(1)
  )))
  writeLines(
    c(
      'get_item:',
      '  pre_request: [trim_id, check_id]',
      '  post_response: [extract_result]'
    ),
    file.path(root, 'inst/hooks.yml')
  )
  writeLines(
    c(
      'trim_id <- function(state) {',
      '  state$params$item_id <- trimws(state$params$item_id)',
      '  state',
      '}',
      'check_id <- function(state) {',
      '  if (!nzchar(state$params$item_id)) stop("empty ID")',
      '  state',
      '}',
      'extract_result <- function(state) state$result'
    ),
    file.path(root, 'R/hooks_items.R')
  )
  fails(specmill::configure_hooks(root, 'apply'), 'never overwritten')
  paths <- file.path(
    root,
    c('R/hook_registry.R', 'R/hooks_items.R', 'inst/hooks.yml')
  )
  before <- tools::md5sum(paths)
  service_path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
  service$hook_config <- 'inst/hooks.yml'
  yaml::write_yaml(service, service_path)
  specmill::generate_client(root, mode = 'apply', config = 'specmill.yml')
  specmill::generate_client(root, mode = 'check', config = 'specmill.yml')
  stopifnot(identical(before, tools::md5sum(paths)))
  status <- system2(
    file.path(R.home('bin'), 'R'),
    c('CMD', 'INSTALL', '-l', shQuote(library), shQuote(root)),
    stdout = TRUE,
    stderr = TRUE
  )
  stopifnot(is.null(attr(status, 'status')))
  callr::r(
    function(library) {
      .libPaths(c(library, .libPaths()))
      loadNamespace('hooktestclient')
      stopifnot(!'specmill' %in% loadedNamespaces())
      ns <- asNamespace('hooktestclient')
      run <- get('run_hook', ns)
      state <- run(
        'get_item',
        'pre_request',
        list(params = list(item_id = ' abc '))
      )
      stopifnot(
        identical(state$params$item_id, 'abc'),
        identical(run('get_item', 'post_response', list(result = 42)), 42),
        identical(run('absent', 'pre_request', state), state),
        identical(run('absent', 'post_response', list(result = 42)), 42)
      )
      error <- tryCatch(
        run('get_item', 'pre_request', list(params = list(item_id = ' '))),
        error = identity
      )
      stopifnot(
        inherits(error, 'client_hook_error'),
        identical(error$hook_name, 'check_id'),
        identical(conditionMessage(error$parent), 'empty ID')
      )
      get('hooktestclient_dry_run', ns)(TRUE)
      request <- get('get_item', ns)(' abc ')
      stopifnot(
        inherits(request, 'httr2_request'),
        grepl('/items/abc', request$url)
      )
    },
    args = list(library = library)
  )
  # Check malformed runtime policy and missing functions without altering an installed namespace.
  env <- new.env(parent = baseenv())
  sys.source(file.path(root, 'R/hook_registry.R'), env)
  env$read_hook_config <- function() {
    list(get_item = list(pre_request = list(1)))
  }
  fails(env$run_hook('get_item', 'pre_request', list()), 'sequence')
  env$read_hook_config <- function() list(get_item = list(transform = 'bad'))
  fails(env$run_hook('get_item', 'pre_request', list()), 'Invalid hook stages')
  env$read_hook_config <- function() {
    list(get_item = list(pre_request = 'missing_hook'))
  }
  fails(env$run_hook('get_item', 'pre_request', list()), 'missing_hook')
  fails(env$run_hook('get_item', 'transform', list()), 'Unsupported hook stage')
  cat(
    'Hook scaffold: safe setup, ordered chains, failures, regeneration and installed runtime passed.\n'
  )
}
if (sys.nframe() == 0L) {
  hook_scaffold_acceptance()
}
