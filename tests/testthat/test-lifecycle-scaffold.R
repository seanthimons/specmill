test_that('configure_lifecycle scaffolds client-owned load and attach stubs', {
  root <- tempfile('lifecycle-')
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    root,
    system.file('catalogue/schema.json', package = 'specmill'),
    package = 'lifecycleclient',
    title = 'Lifecycle Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://example.invalid'
  )
  actions <- function(result) {
    vapply(result$changes, `[[`, character(1), 'action')
  }
  zzz <- file.path(root, 'R/zzz.R')
  helper <- file.path(root, 'R/client_lifecycle.R')
  generate <- function(mode) {
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = mode,
      validation = FALSE
    )
  }
  generate('apply')

  # Plan writes nothing; .onLoad elsewhere blocks apply.
  expect_identical(
    actions(specmill::configure_lifecycle(root)),
    c('create', 'create')
  )
  expect_false(file.exists(zzz))
  stray <- file.path(root, 'R/startup.R')
  writeLines('.onLoad <- function(libname, pkgname) NULL', stray)
  expect_length(specmill::configure_lifecycle(root)$collisions, 1L)
  expect_error(specmill::configure_lifecycle(root, 'apply'), 'outside R/zzz.R')
  unlink(stray)

  specmill::configure_lifecycle(root, 'apply')
  expect_identical(
    actions(specmill::configure_lifecycle(root)),
    c('unchanged', 'unchanged')
  )

  # The client's edits to zzz.R are kept; an outdated helper file is updated.
  cat('# mine\n', file = zzz, append = TRUE)
  mine <- readLines(zzz)
  current <- readLines(helper)
  specmill::apply_files(
    root,
    list('R/client_lifecycle.R' = '# older template'),
    mode = 'apply'
  )
  expect_identical(
    actions(specmill::configure_lifecycle(root)),
    c('update', 'kept')
  )
  specmill::configure_lifecycle(root, 'apply')
  expect_identical(readLines(helper), current)
  expect_identical(readLines(zzz), mine)
  # A hand-edited helper file is not overwritten.
  cat('# edited\n', file = helper, append = TRUE)
  expect_error(specmill::configure_lifecycle(root, 'apply'), 'Protected')
  writeLines(current, helper)

  # Regeneration and its check leave both files alone.
  generate('apply')
  expect_no_error(generate('check'))
  expect_identical(readLines(zzz), mine)
  expect_identical(readLines(helper), current)

  # A full prune keeps the helpers while the client's zzz.R could call them.
  purge <- function(mode = 'apply') {
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = mode,
      validation = FALSE,
      prune = 'all',
      confirm = TRUE
    )
  }
  kept <- tempfile()
  file.copy(c(zzz, helper), c(kept, paste0(kept, '-helper')))
  expect_message(purge(), 'Keeping')
  expect_true(file.exists(helper))
  expect_no_error(suppressMessages(purge('check')))
  unlink(zzz)
  suppressMessages(purge())
  expect_false(file.exists(helper))
  file.copy(c(kept, paste0(kept, '-helper')), c(zzz, helper))

  # The helpers: unset-only defaults, quiet under load_all, no values reported.
  runtime <- new.env(parent = baseenv())
  sys.source(helper, runtime)
  sys.source(zzz, runtime)
  expect_null(runtime$.onLoad('lib', 'lifecycleclient'))
  expect_silent(runtime$.onAttach('lib', 'lifecycleclient'))
  withr::local_options(lifecycle.kept = 'user', lifecycle.fresh = NULL)
  runtime$lifecycle_option_defaults(list(
    lifecycle.kept = 'default',
    lifecycle.fresh = 'default'
  ))
  expect_identical(getOption('lifecycle.kept'), 'user')
  expect_identical(getOption('lifecycle.fresh'), 'default')
  withr::local_envvar(
    DEVTOOLS_LOAD = NA,
    LIFECYCLE_SET = 'secret-value',
    LIFECYCLE_UNSET = NA
  )
  expect_message(
    runtime$lifecycle_startup_message('hello'),
    'hello',
    class = 'packageStartupMessage'
  )
  expect_silent(suppressPackageStartupMessages(
    runtime$lifecycle_startup_message('hello')
  ))
  expect_identical(
    runtime$lifecycle_credential_status(c('LIFECYCLE_SET', 'LIFECYCLE_UNSET')),
    'LIFECYCLE_SET: set\nLIFECYCLE_UNSET: not set'
  )
  withr::local_envvar(DEVTOOLS_LOAD = 'lifecycleclient')
  expect_silent(runtime$lifecycle_startup_message('hello'))
})
