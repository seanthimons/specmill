helper_provenance_acceptance <- function() {
  root <- tempfile('helper-provenance-')
  schema <- system.file(
    'catalogue/schema.json',
    package = 'specmill',
    mustWork = TRUE
  )
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    root,
    schema,
    package = 'helperprobe',
    title = 'Helper Probe',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://example.invalid'
  )
  inspect <- function() specmill::inspect_client(root)$helpers$api_request
  api_file <- list.files(file.path(root, 'apis'), full.names = TRUE)[[1L]]
  settings <- yaml::read_yaml(api_file, handlers = list(seq = function(x) x))
  settings$defaults$specialization <- 'Service-specific text encoding requires client review.'
  yaml::write_yaml(settings, api_file)
  specialization <- specmill::inspect_client(root)$operations[[
    1L
  ]]$specialization
  stopifnot(
    specialization$status == 'requires client handling',
    grepl('text encoding', specialization$reason, fixed = TRUE)
  )
  known <- inspect()
  stopifnot(
    known$baseline == 'known',
    !known$customized,
    !known$upstream_changed,
    !length(known$missing_explicit_arguments)
  )
  path <- file.path(root, 'R/api_request.R')
  provenance <- file.path(root, '.specmill/helpers/api_request.json')
  record <- jsonlite::read_json(provenance, simplifyVector = TRUE)
  # Reconstruct the genuine earlier template's direct api_auth call.
  old <- sub(
    "  if (!base::is.null(auth)) {\n    authenticate <- base::get0('api_auth', envir = base::environment(), mode = 'function', inherits = TRUE)\n    if (base::is.null(authenticate)) base::stop('Authentication scaffolding is missing')\n    request <- authenticate(request, auth)\n  }",
    '  if (!base::is.null(auth)) request <- api_auth(request, auth)',
    record$baseline,
    fixed = TRUE
  )
  stopifnot(!identical(old, record$baseline))
  record$baseline <- old
  record$baseline_hash <- specmill:::text_hash(old)
  jsonlite::write_json(
    record,
    provenance,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = 'null'
  )
  writeLines(old, path)
  stopifnot(inspect()$upstream_changed, !inspect()$customized)
  custom <- paste(
    old,
    '# Client-owned plain-text extension is retained.',
    sep = '\n'
  )
  writeLines(custom, path)
  before <- readBin(path, 'raw', file.info(path)$size)
  comparison <- inspect()
  stopifnot(
    comparison$customized,
    comparison$upstream_changed,
    identical(comparison, inspect()),
    identical(before, readBin(path, 'raw', file.info(path)$size)),
    grepl('Client-owned plain-text', comparison$comparison$local, fixed = TRUE),
    grepl('authenticate <-', comparison$comparison$proposed, fixed = TRUE)
  )
  # Manual adoption preserves the extension; comparisons remain read-only.
  writeLines(
    paste(
      comparison$comparison$proposed,
      '# Client-owned plain-text extension is retained.',
      sep = '\n'
    ),
    path
  )
  stopifnot(identical(inspect(), inspect()))
  unlink(provenance)
  stopifnot(inspect()$baseline == 'unknown')
  env <- new.env(parent = baseenv())
  sys.source(path, env)
  Sys.setenv(HELPERPROBE_DRY_RUN = 'true')
  on.exit(Sys.unsetenv('HELPERPROBE_DRY_RUN'), add = TRUE)
  request <- env$api_request('GET', '/probe', list(), list(), NULL)
  stopifnot(
    inherits(request, 'httr2_request'),
    request$url == 'https://example.invalid/probe'
  )
  failure <- tryCatch(
    env$api_request('GET', '/probe', list(), list(), NULL, auth = list()),
    error = identity
  )
  stopifnot(
    inherits(failure, 'error'),
    grepl('Authentication scaffolding', conditionMessage(failure))
  )
  # A lifecycle-protected file remains while an independent output proceeds.
  guarded <- "#' `r lifecycle::badge('stable')`\nkept <- function() 1"
  writeLines(guarded, file.path(root, 'R/kept.R'))
  result <- specmill::apply_files(
    root,
    list(
      'R/kept.R' = 'kept <- function() 2',
      'R/independent.R' = 'independent <- function() TRUE'
    ),
    mode = 'apply'
  )
  stopifnot(
    result[[1L]]$action == 'retained',
    file.exists(file.path(root, 'R/independent.R')),
    identical(specmill:::file_text(file.path(root, 'R/kept.R')), guarded)
  )
  for (status in c(
    'stable',
    'maturing',
    'superseded',
    'deprecated',
    'defunct'
  )) {
    writeLines(
      sprintf("#' `r lifecycle::badge('%s')`\nkept <- function() 1", status),
      file.path(root, 'R/kept.R')
    )
    stopifnot(
      specmill::apply_files(root, list(), remove = 'R/kept.R', mode = 'apply')[[
        1L
      ]]$action ==
        'retained'
    )
  }
  cat(
    'Helper provenance, read-only comparison, manual adoption, authentication and lifecycle retention passed.\n'
  )
}
if (sys.nframe() == 0L) {
  helper_provenance_acceptance()
}
