source(
  if (file.exists('tests/deferral-lifecycle.R')) {
    'tests/deferral-lifecycle.R'
  } else {
    'deferral-lifecycle.R'
  }
)

# Names the new operation by editing the policy, as a maintainer would.
name_extra <- function(root) {
  path <- file.path(root, 'service.yml')
  lines <- readLines(path)
  at <- grep('GET /other', lines, fixed = TRUE)
  writeLines(append(lines, '  GET /extra: demo_extra', at), path)
}

deferral_preservation_acceptance <- function() {
  id <- 'demo GET /bad'
  enroll <- list(enroll = c('demo GET /bad' = 'Missing response description'))
  # 1. Existing wrapper survives enrollment untouched while siblings update.
  root <- deferral_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  deferral_schema(root, bad = FALSE)
  stopifnot(!inherits(deferral_run(root, 'apply'), 'error'))
  wrapper <- file.path(root, 'R/demo_bad.R')
  kept <- readLines(wrapper)
  name_extra(root)
  deferral_schema(root, bad = TRUE, extra = TRUE)
  applied <- deferral_run(root, 'apply', deferrals = enroll)
  stopifnot(
    !inherits(applied, 'error'),
    identical(kept, readLines(wrapper)),
    file.exists(file.path(root, 'R/demo_extra.R')),
    !is.null(deferral_manifest(root)$deferrals[[id]])
  )
  # 2. A grouped file keeps the deferred function when a healthy sibling rewrites it.
  grouped <- deferral_fixture('defaults: {file: R/group.R}')
  on.exit(unlink(grouped, recursive = TRUE), add = TRUE)
  deferral_schema(grouped, bad = FALSE)
  stopifnot(!inherits(deferral_run(grouped, 'apply'), 'error'))
  group <- file.path(grouped, 'R/group.R')
  stopifnot(grepl(
    'demo_bad <- function',
    paste(readLines(group), collapse = '\n'),
    fixed = TRUE
  ))
  name_extra(grouped)
  deferral_schema(grouped, bad = TRUE, extra = TRUE)
  applied <- deferral_run(grouped, 'apply', deferrals = enroll)
  text <- paste(readLines(group), collapse = '\n')
  stopifnot(
    !inherits(applied, 'error'),
    grepl('demo_bad <- function', text, fixed = TRUE),
    grepl('demo_extra <- function', text, fixed = TRUE),
    grepl('demo_good <- function', text, fixed = TRUE)
  )
  # 3. A never-generated deferred operation leaves no placeholder, and an
  # all-deferred new project still persists the enrollment.
  only <- deferral_fixture()
  on.exit(unlink(only, recursive = TRUE), add = TRUE)
  writeLines(
    c(
      'id: demo',
      'schemas: {files: [api.yml]}',
      'helper: request_helper',
      'names:',
      '  GET /bad: demo_bad'
    ),
    file.path(only, 'service.yml')
  )
  yaml::write_yaml(
    list(
      swagger = '2.0',
      info = list(title = 'Only', version = '1'),
      paths = list(
        '/bad' = list(
          get = list(
            operationId = 'bad',
            responses = list('200' = list(schema = list(type = 'string')))
          )
        )
      )
    ),
    file.path(only, 'api.yml')
  )
  applied <- deferral_run(only, 'apply', deferrals = enroll)
  manifest <- file.path(only, '.specmill/manifest.json')
  stopifnot(
    !inherits(applied, 'error'),
    file.exists(manifest),
    !is.null(deferral_manifest(only)$deferrals[[id]]),
    !file.exists(file.path(only, 'R/demo_bad.R'))
  )
  before <- readLines(manifest)
  again <- deferral_run(only, 'apply')
  stopifnot(!inherits(again, 'error'), identical(before, readLines(manifest)))
  cat(
    'Deferral preservation: existing wrapper, grouped file, all-deferred project passed.\n'
  )
}

if (sys.nframe() == 0L) {
  deferral_preservation_acceptance()
}
