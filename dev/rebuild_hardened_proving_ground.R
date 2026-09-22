# Run after installing this checkout into an isolated library, e.g.
# R_LIBS=artifacts/toolkit-library Rscript dev/rebuild_hardened_proving_ground.R BASELINE RUN
args <- commandArgs(TRUE)
stopifnot(length(args) == 2L)
baseline <- normalizePath(args[[1L]], mustWork = TRUE)
run <- args[[2L]]
stopifnot(!dir.exists(run))
dir.create(run, recursive = TRUE)
run <- normalizePath(run)
library <- file.path(run, 'library')
dir.create(library)
.libPaths(c(library, .libPaths()))
writeLines(capture.output(sessionInfo()), file.path(run, 'session-info.txt'))
writeLines(
  c(find.package('specmill'), as.character(packageVersion('specmill'))),
  file.path(run, 'specmill-installed.txt')
)
jsonlite::write_json(
  list(
    installed_path = find.package('specmill'),
    version = as.character(packageVersion('specmill')),
    installed_code_sha256 = digest::digest(
      file = file.path(find.package('specmill'), 'R/specmill.rdb'),
      algo = 'sha256'
    ),
    checkout_commit = system2('git', c('rev-parse', 'HEAD'), stdout = TRUE)
  ),
  file.path(run, 'toolkit-provenance.json'),
  auto_unbox = TRUE,
  pretty = TRUE
)
# Preserve exact baseline input bytes and audit implementation.
stopifnot(file.copy(file.path(baseline, 'inputs'), run, recursive = TRUE))
stopifnot(file.copy(file.path(baseline, 'audit_testing_specs.R'), run))
source(file.path(run, 'audit_testing_specs.R'))
policies <- list(
  'schema/chet.json' = list(
    names = list(
      'OPTIONS /reaction/batchsearch' = 'default_api_reaction_batchsearch_options'
    )
  )
)
audit <- audit_testing_specs(
  native_root = file.path(run, 'inputs/specmill-testing'),
  output = file.path(run, 'audit'),
  policies = policies
)
saveRDS(audit, file.path(run, 'audit.rds'))
# Reuse original initialization workflow, replacing only its output root.
setup <- readLines(file.path(baseline, 'build.R'))
setup <- setup[-1L]
eval(parse(text = setup), envir = .GlobalEnv)
# Match the reviewed configuration bytes, including full selection/exclusions.
for (file in list.files(
  file.path(baseline, 'full-selection-apis'),
  full.names = TRUE
)) {
  stopifnot(file.copy(
    file,
    file.path(root, 'apis', basename(file)),
    overwrite = TRUE
  ))
}
stopifnot(file.copy(
  file.path(baseline, 'provingground/specmill.yml'),
  file.path(root, 'specmill.yml'),
  overwrite = TRUE
))
full <- specmill::generate_client(root, config = 'specmill.yml', mode = 'plan')
saveRDS(full, file.path(run, 'generation-plan.rds'))
stopifnot(file.copy(file.path(root, 'apis'), run, recursive = TRUE))
stopifnot(file.rename(
  file.path(run, 'apis'),
  file.path(run, 'full-selection-apis')
))
allow <- read.csv(file.path(baseline, 'test-only-allowlist.csv'))
write.csv(allow, file.path(run, 'test-only-allowlist.csv'), row.names = FALSE)
for (f in list.files(file.path(root, 'apis'), full.names = TRUE)) {
  y <- yaml::read_yaml(f, handlers = list(seq = function(x) x))
  for (g in names(y$groups)) {
    y$groups[[g]]$selection$include <- as.list(allow$key[allow$service == g])
  }
  yaml::write_yaml(y, f)
}
plan <- specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
saveRDS(plan, file.path(run, 'supported-plan.rds'))
fresh <- specmill::generate_client(
  root,
  config = 'specmill.yml',
  mode = 'check'
)
stopifnot(all(vapply(
  fresh$files,
  function(x) x$action %in% c('unchanged', 'retained'),
  logical(1)
)))
archive <- pkgbuild::build(root, dest_path = run, manual = FALSE)
checked <- rcmdcheck::rcmdcheck(
  archive,
  args = '--no-manual',
  error_on = 'never',
  check_dir = file.path(run, 'check')
)
saveRDS(checked, file.path(run, 'package-check.rds'))
utils::install.packages(archive, repos = NULL, type = 'source', lib = library)
stopifnot(identical(
  normalizePath(find.package('provingground')),
  normalizePath(file.path(library, 'provingground'))
))
writeLines(
  find.package('provingground'),
  file.path(run, 'smoke-installed-path.txt')
)
Sys.setenv(PROVINGGROUND_DRY_RUN = 'true')
project <- yaml::read_yaml(file.path(root, 'specmill.yml'))
if (length(project$authentication)) {
  vars <- unique(unlist(project$authentication))
  do.call(
    Sys.setenv,
    as.list(setNames(rep('offline-fixture-only', length(vars)), vars))
  )
}
stopifnot(
  !'specmill' %in% names(getNamespaceImports(asNamespace('provingground')))
)
schema_keys <- setNames(inputs$file, paste0(api, '.json'))
rows <- list()
for (mode in c('default', 'override', 'minimal')) {
  for (op in full$operations) {
    if (mode == 'override' && !grepl('query.*SDWISTablePage$', op$name)) {
      next
    }
    stage <- 'fixture'
    request <- NULL
    inputs <- list()
    overrides <- if (mode == 'override') {
      setNames(
        list(
          jsonlite::read_json(
            file.path(baseline, 'envirofacts-reviewed-fixtures.json'),
            simplifyVector = TRUE
          )[[op$name]]$args
        ),
        op$name
      )
    } else {
      list()
    }
    reason <- tryCatch(
      {
        inputs <- specmill::operation_fixtures(
          list(op),
          overrides,
          mode = if (mode == 'minimal') 'minimal' else 'default'
        )[[1L]]
        stage <- 'request'
        request <- do.call(getExportedValue('provingground', op$name), inputs)
        stopifnot(
          inherits(request, 'httr2_request'),
          identical(request$method, op$method),
          startsWith(request$url, 'https://example.invalid/')
        )
        ''
      },
      error = function(e) conditionMessage(e)
    )
    rows[[length(rows) + 1L]] <- data.frame(
      schema = unname(schema_keys[[basename(op$source)]]),
      service = op$service,
      name = op$name,
      key = op$key,
      mode = mode,
      stage = if (nzchar(reason)) stage else 'passed',
      reason = reason,
      omitted = paste(attr(inputs, 'omitted_inputs'), collapse = ';'),
      url = if (is.null(request)) '' else request$url
    )
  }
}
smoke <- dplyr::bind_rows(rows)
write.csv(smoke, file.path(run, 'installed-smoke-modes.csv'), row.names = FALSE)
source_diagnostics <- list()
for (file in list.files(file.path(root, 'schema'), full.names = TRUE)) {
  parsed <- specmill::read_operations(
    file,
    if (basename(file) == 'chet.json') {
      policies[['schema/chet.json']]
    } else {
      list()
    }
  )
  source_diagnostics <- c(source_diagnostics, parsed$fixture_diagnostics)
}
saveRDS(source_diagnostics, file.path(run, 'source-contradictions.rds'))
jsonlite::write_json(
  list(
    specmill = find.package('specmill'),
    version = as.character(packageVersion('specmill')),
    operations = length(plan$operations),
    blockers = length(full$diagnostics),
    errors = checked$errors,
    warnings = checked$warnings,
    notes = checked$notes,
    modes = as.data.frame(table(smoke$mode, smoke$stage))
  ),
  file.path(run, 'build-result.json'),
  auto_unbox = TRUE,
  pretty = TRUE
)
print(table(smoke$mode, smoke$stage))
