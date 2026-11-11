setup_acceptance <- function() {
  root <- tempfile('setup-client-')
  clone <- tempfile('setup-clone-')
  multi <- tempfile('setup-multi-')
  multi_clone <- tempfile('setup-multi-clone-')
  cancelled <- tempfile('setup-cancelled-')
  on.exit(
    unlink(c(root, clone, multi, multi_clone, cancelled), recursive = TRUE),
    add = TRUE
  )
  schema <- system.file(
    'catalogue/schema.json',
    package = 'specmill',
    mustWork = TRUE
  )
  metadata <- list(
    package = 'setupclient',
    title = 'Setup Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT',
    name_case = 'snake_case'
  )
  do.call(
    specmill::initialize_client,
    c(list(root = root, schema = schema), metadata)
  )
  scripts <- file.path(root, 'dev', c('init.R', 'generate.R'))
  stopifnot(
    all(file.exists(scripts)),
    '^dev$' %in% readLines(file.path(root, '.Rbuildignore'))
  )
  runtime <- new.env(parent = baseenv())
  before <- tools::md5sum(list.files(
    root,
    recursive = TRUE,
    all.files = TRUE,
    full.names = TRUE
  ))
  # Source from outside the package. Sourcing must define commands without writing.
  withr::with_dir(tempdir(), sys.source(scripts[[1L]], runtime))
  stopifnot(identical(before, tools::md5sum(names(before))))
  runtime$init_main(clone)
  stopifnot(identical(
    readLines(file.path(root, 'specmill.yml')),
    readLines(file.path(clone, 'specmill.yml'))
  ))
  error <- tryCatch(runtime$init_main(root), error = identity)
  stopifnot(
    inherits(error, 'error'),
    identical(before, tools::md5sum(names(before)))
  )
  withr::with_dir(tempdir(), sys.source(scripts[[2L]], runtime))
  plan <- runtime$generate_main(args = '--plan')
  stopifnot(
    length(plan$operations) == 4L,
    identical(before, tools::md5sum(names(before)))
  )
  runtime$generate_main(args = character())
  runtime$generate_main(args = '--check')
  write('custom_setting <- TRUE', file = scripts[[2L]], append = TRUE)
  customized <- readLines(scripts[[2L]])
  runtime$generate_main(args = character())
  stopifnot(identical(customized, readLines(scripts[[2L]])))
  # Multi-API replay uses the emitted schema paths, including YAML extensions.
  dir.create(multi)
  dir.create(file.path(multi, 'input'))
  file.copy(schema, file.path(multi, 'input/catalogue.json'))
  yaml::write_yaml(
    jsonlite::read_json(schema),
    file.path(multi, 'input/second.yml')
  )
  apis <- data.frame(
    schema = c('input/catalogue.json', 'input/second.yml'),
    api = c('first', 'second'),
    base_url = c('https://first.example.org', 'https://second.example.org'),
    include = TRUE
  )
  do.call(
    specmill::initialize_client,
    c(list(root = multi, schema = apis), metadata)
  )
  multi_runtime <- new.env(parent = baseenv())
  sys.source(file.path(multi, 'dev/init.R'), multi_runtime)
  multi_runtime$init_main(multi_clone)
  stopifnot(
    file.exists(file.path(multi_clone, 'schema/first.json')),
    file.exists(file.path(multi_clone, 'schema/second.yml')),
    identical(
      readLines(file.path(multi, 'specmill.yml')),
      readLines(file.path(multi_clone, 'specmill.yml'))
    )
  )
  # Scripted setup fails without reading stdin or writing files.
  stopifnot(inherits(
    tryCatch(specmill::setup_client(), error = identity),
    'error'
  ))
  interactive_setup <- function(destination, confirm) {
    answers <- c(
      schema,
      destination,
      'setupclient',
      'Setup Client',
      'Test',
      'Maintainer',
      'test@example.org',
      'MIT',
      '',
      confirm
    )
    testthat::local_mocked_bindings(
      interactive = function() TRUE,
      readline = function(prompt = '') {
        answer <- answers[[1L]]
        answers <<- answers[-1L]
        answer
      },
      .package = 'base'
    )
    specmill::setup_client()
  }
  stopifnot(is.null(interactive_setup(cancelled, 'n')), !dir.exists(cancelled))
  interactive_setup(cancelled, 'y')
  stopifnot(
    file.exists(file.path(cancelled, 'dev/init.R')),
    file.exists(file.path(cancelled, 'dev/generate.R'))
  )
  cat(
    'Setup: sourceable scripts, replay, maintenance, preservation, multi-API and interactive confirmation passed.\n'
  )
}
if (sys.nframe() == 0L) {
  setup_acceptance()
}
