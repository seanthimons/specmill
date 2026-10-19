deferral_fixture <- function(extra_service = character()) {
  root <- tempfile('deferral-')
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
      '  GET /bad: demo_bad',
      '  GET /other: demo_other',
      extra_service
    ),
    file.path(root, 'service.yml')
  )
  root
}

deferral_schema <- function(
  root,
  bad = TRUE,
  note = 'first',
  other = 'plain',
  definition = 'string',
  extra = FALSE
) {
  response <- function(ok) {
    schema <- list('$ref' = '#/definitions/Thing')
    list(
      '200' = if (ok) {
        list(description = 'OK', schema = schema)
      } else {
        list(schema = schema)
      }
    )
  }
  document <- list(
    swagger = '2.0',
    info = list(title = 'Deferral', version = '1'),
    paths = list(
      '/good' = list(
        get = list(
          operationId = 'good',
          responses = list('200' = list(description = 'OK'))
        )
      ),
      '/bad' = list(
        get = list(
          operationId = 'bad',
          description = note,
          responses = response(!bad)
        )
      ),
      '/other' = list(
        get = list(
          operationId = 'other',
          description = other,
          responses = list('200' = list(description = 'OK'))
        )
      )
    ),
    definitions = list(
      Thing = list(
        type = 'object',
        properties = list(value = list(type = definition))
      ),
      Unused = list(type = 'object', description = other)
    )
  )
  if (extra) {
    document$paths[['/extra']] <- list(
      get = list(
        operationId = 'extra',
        responses = list('200' = list(description = 'OK'))
      )
    )
  }
  yaml::write_yaml(document, file.path(root, 'api.yml'))
}

deferral_run <- function(root, mode, ...) {
  messages <- character()
  result <- withCallingHandlers(
    tryCatch(
      specmill::generate_client(
        root,
        config = 'specmill.yml',
        mode = mode,
        ...
      ),
      error = identity
    ),
    message = function(m) {
      messages <<- c(messages, conditionMessage(m))
      invokeRestart('muffleMessage')
    }
  )
  attr(result, 'messages') <- paste(messages, collapse = '\n')
  result
}

deferral_manifest <- function(root) {
  jsonlite::read_json(file.path(root, '.specmill/manifest.json'))
}

deferral_lifecycle_acceptance <- function() {
  root <- deferral_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  deferral_schema(root)
  id <- 'demo GET /bad'
  manifest_path <- file.path(root, '.specmill/manifest.json')
  # 1. Strict by default.
  strict <- deferral_run(root, 'apply')
  stopifnot(inherits(strict, 'error'), !file.exists(manifest_path))
  # 2. Plan and check cannot enroll; the request names no ID by hand.
  enroll <- list(enroll = c('demo GET /bad' = 'Missing response description'))
  plan <- deferral_run(root, 'plan', deferrals = enroll)
  stopifnot(
    !inherits(plan, 'error'),
    identical(plan$deferrals[[id]]$state, 'enrolled'),
    !file.exists(manifest_path),
    !file.exists(file.path(root, 'R/demo_bad.R'))
  )
  checked <- deferral_run(root, 'check', deferrals = enroll)
  stopifnot(inherits(checked, 'error'), !file.exists(manifest_path))
  # An unknown or excluded ID is refused.
  stopifnot(inherits(
    deferral_run(
      root,
      'plan',
      deferrals = list(enroll = c('demo GET /nope' = 'x'))
    ),
    'error'
  ))
  applied <- deferral_run(root, 'apply', deferrals = enroll)
  stopifnot(
    !inherits(applied, 'error'),
    file.exists(file.path(root, 'R/demo_good.R')),
    file.exists(file.path(root, 'R/demo_other.R')),
    !file.exists(file.path(root, 'R/demo_bad.R'))
  )
  record <- deferral_manifest(root)$deferrals[[id]]
  stopifnot(
    identical(record$reason, 'Missing response description'),
    grepl('^v1:[0-9a-f]{64}$', record$fingerprint),
    identical(record$source, 'api.yml'),
    identical(record$key, 'GET /bad')
  )
  # 3. Unchanged enrollment: repeated apply and check are no-ops with a summary.
  before <- readLines(manifest_path)
  again <- deferral_run(root, 'apply')
  checked <- deferral_run(root, 'check')
  stopifnot(
    !inherits(again, 'error'),
    !inherits(checked, 'error'),
    identical(before, readLines(manifest_path)),
    identical(checked$deferrals[[id]]$state, 'deferred'),
    grepl('awaiting contract change', attr(checked, 'messages'), fixed = TRUE),
    identical(
      checked$inventory[[which(
        vapply(checked$inventory, `[[`, '', 'id') == id
      )]]$status,
      'deferred'
    )
  )
  # 5. Formatting, key order and unrelated edits do not wake the enrollment.
  deferral_schema(root, other = 'changed elsewhere')
  quiet <- deferral_run(root, 'plan')
  stopifnot(identical(quiet$deferrals[[id]]$state, 'deferred'))
  deferral_schema(root, other = 'plain')
  # A relevant prose change retries without implying success.
  deferral_schema(root, note = 'second')
  retried <- deferral_run(root, 'plan')
  stopifnot(
    !inherits(retried, 'error'),
    identical(retried$deferrals[[id]]$state, 'retry_blocked'),
    length(retried$diagnostics) == 1L
  )
  stopifnot(inherits(deferral_run(root, 'apply'), 'error'))
  stopifnot(identical(before, readLines(manifest_path)))
  # A transitive definition change wakes the operation even with the fix absent.
  deferral_schema(root, definition = 'integer')
  stopifnot(identical(
    deferral_run(root, 'plan')$deferrals[[id]]$state,
    'retry_blocked'
  ))
  # 7. A repaired revision is a recovery candidate; apply advances state.
  deferral_schema(root, bad = FALSE, note = 'second')
  recovery <- deferral_run(root, 'plan')
  stopifnot(
    identical(recovery$deferrals[[id]]$state, 'retry_recovered'),
    any(vapply(
      recovery$files,
      function(x) x$file == 'R/demo_bad.R' && x$action == 'write',
      logical(1)
    ))
  )
  stopifnot(inherits(deferral_run(root, 'check'), 'error'))
  deferral_run(root, 'apply')
  final <- deferral_run(root, 'check')
  stopifnot(
    !inherits(final, 'error'),
    length(final$deferrals) == 0L,
    is.null(deferral_manifest(root)$deferrals),
    file.exists(file.path(root, 'R/demo_bad.R'))
  )
  cat(
    'Deferral lifecycle: strict default, enrollment, retry, recovery passed.\n'
  )
}

if (sys.nframe() == 0L) {
  deferral_lifecycle_acceptance()
}
