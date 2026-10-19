source_dir <- if (dir.exists('tests')) 'tests' else '.'
source(file.path(source_dir, 'deferral-lifecycle.R'))

deferral_safety_acceptance <- function() {
  id <- 'demo GET /bad'
  enroll <- list(enroll = c('demo GET /bad' = 'Known bad declaration'))
  generated <- function(root, ...) file.exists(file.path(root, ...))

  # 9. Clearing retries an unchanged revision; a toolkit change alone does not.
  root <- deferral_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  deferral_schema(root)
  deferral_run(root, 'apply', deferrals = enroll)
  manifest <- deferral_manifest(root)
  manifest$toolkit_version <- '0.0.1'
  jsonlite::write_json(
    manifest,
    file.path(root, '.specmill/manifest.json'),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  stopifnot(identical(
    deferral_run(root, 'plan')$deferrals[[id]]$state,
    'deferred'
  ))
  stopifnot(inherits(
    deferral_run(root, 'plan', deferrals = list(clear = 'demo GET /nope')),
    'error'
  ))
  cleared <- deferral_run(root, 'plan', deferrals = list(clear = id))
  stopifnot(
    identical(cleared$deferrals[[id]]$state, 'cleared'),
    length(cleared$diagnostics) == 1L
  )
  stopifnot(inherits(
    deferral_run(root, 'apply', deferrals = list(clear = id)),
    'error'
  ))
  stopifnot(!is.null(deferral_manifest(root)$deferrals[[id]]))

  # 8. Automatic re-enrollment is opt-in, typed, and committed only on apply.
  deferral_schema(root, note = 'second')
  stopifnot(inherits(deferral_run(root, 'apply'), 'error'))
  writeLines(
    c(
      readLines(file.path(root, 'service.yml')),
      'deferral:',
      '  automatic: [schema_validation_invalid]'
    ),
    file.path(root, 'service.yml')
  )
  fingerprint <- deferral_manifest(root)$deferrals[[id]]$fingerprint
  plan <- deferral_run(root, 'plan')
  stopifnot(
    identical(plan$deferrals[[id]]$state, 'auto_enrolled'),
    identical(deferral_manifest(root)$deferrals[[id]]$fingerprint, fingerprint)
  )
  stopifnot(inherits(deferral_run(root, 'check'), 'error'))
  stopifnot(identical(
    deferral_manifest(root)$deferrals[[id]]$fingerprint,
    fingerprint
  ))
  deferral_run(root, 'apply')
  moved <- deferral_manifest(root)$deferrals[[id]]
  stopifnot(
    !identical(moved$fingerprint, fingerprint),
    grepl('^Automatic \\(schema_validation_invalid\\)', moved$reason),
    !inherits(deferral_run(root, 'check'), 'error')
  )
  # A code outside the opted-in list is not absorbed.
  writeLines(
    sub(
      'schema_validation_invalid',
      'duplicate_parameter',
      readLines(file.path(root, 'service.yml'))
    ),
    file.path(root, 'service.yml')
  )
  deferral_schema(root, note = 'third')
  stopifnot(identical(
    deferral_run(root, 'plan')$deferrals[[id]]$state,
    'retry_blocked'
  ))
  stopifnot(inherits(deferral_run(root, 'apply'), 'error'))

  # 12. Legacy or incompatible metadata fails safely and is never repaired.
  # A record that is not an object cannot be matched, so apply stays strict.
  for (case in 1:4) {
    damage <- list(
      function(m) {
        m$deferrals[[id]]$version <- NULL
        m
      },
      function(m) {
        m$deferrals[[id]]$version <- 99L
        m
      },
      function(m) {
        m$deferrals[[id]]$fingerprint <- 'v2:abc'
        m
      },
      function(m) {
        m$deferrals[[id]] <- 'legacy'
        m
      }
    )[[case]]
    damaged <- tempfile('damaged-')
    dir.create(damaged)
    file.copy(
      list.files(root, all.files = TRUE, full.names = TRUE, no.. = TRUE),
      damaged,
      recursive = TRUE
    )
    path <- file.path(damaged, '.specmill/manifest.json')
    jsonlite::write_json(
      damage(jsonlite::read_json(path)),
      path,
      auto_unbox = TRUE,
      pretty = TRUE
    )
    before <- readLines(path)
    stopifnot(
      identical(
        deferral_run(damaged, 'plan')$deferrals[[id]]$state,
        'uncertain'
      ),
      inherits(deferral_run(damaged, 'check'), 'error'),
      identical(inherits(deferral_run(damaged, 'apply'), 'error'), case == 4L)
    )
    after <- jsonlite::read_json(path)$deferrals[[id]]
    stopifnot(identical(
      after,
      jsonlite::parse_json(paste(before, collapse = '\n'))$deferrals[[id]]
    ))
    if (case == 4L) {
      # Re-enrolling replaces the unusable record.
      reenroll <- deferral_run(
        damaged,
        'apply',
        deferrals = list(enroll = c('demo GET /bad' = 'Re-enrolled'))
      )
      stopifnot(
        !inherits(reenroll, 'error'),
        identical(deferral_manifest(damaged)$deferrals[[id]]$reason, 'Re-enrolled')
      )
    }
    unlink(damaged, recursive = TRUE)
  }
  cat(
    'Deferral safety: clearing, automatic policy and damaged metadata passed.\n'
  )
}

if (sys.nframe() == 0L) {
  deferral_safety_acceptance()
}
