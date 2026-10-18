ownership_reconciliation_acceptance <- function() {
  root <- tempfile('ownership-reconciliation-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  original <- list('R/example.R' = 'example <- function() 1')
  changed <- list('R/example.R' = 'example <- function() 2')
  unrelated <- list('R/unrelated.R' = 'unrelated <- TRUE')
  specmill::apply_files(root, c(original, unrelated), mode = 'apply')
  specmill::apply_files(root, changed, mode = 'apply')
  writeLines(original[[1L]], file.path(root, names(original)))
  manifest_path <- file.path(root, '.specmill/manifest.json')
  before <- readLines(manifest_path)
  unrelated_before <- jsonlite::read_json(manifest_path)$files[[
    'R/unrelated.R'
  ]]
  for (mode in c('plan', 'check')) {
    plan <- specmill::apply_files(root, original, mode = mode)
    stopifnot(
      plan[[1L]]$action == 'unchanged',
      length(plan) == 2L,
      plan[[2L]]$file == '.specmill/manifest.json',
      plan[[2L]]$action == 'write',
      identical(before, readLines(manifest_path))
    )
  }
  specmill::apply_files(root, original, mode = 'apply')
  manifest <- jsonlite::read_json(manifest_path)
  stopifnot(
    identical(
      manifest$files[[names(original)]]$hash,
      digest::digest(original[[1L]], algo = 'sha256', serialize = FALSE)
    ),
    identical(manifest$files[['R/unrelated.R']], unrelated_before),
    identical(readLines(file.path(root, names(original))), original[[1L]])
  )
  before <- readLines(manifest_path)
  again <- specmill::apply_files(root, original, mode = 'apply')
  stopifnot(
    length(again) == 1L,
    again[[1L]]$action == 'unchanged',
    identical(before, readLines(manifest_path))
  )
  # Matching client files without ownership still require explicit adoption.
  unowned <- list('R/manual.R' = 'manual <- TRUE')
  writeLines(unowned[[1L]], file.path(root, names(unowned)))
  specmill::apply_files(root, unowned, mode = 'apply')
  stopifnot(is.null(jsonlite::read_json(manifest_path)$files[[names(unowned)]]))
  # Desired output must match before an edited owned file can be reconciled.
  writeLines('example <- function() 3', file.path(root, names(original)))
  plan <- specmill::apply_files(root, original, mode = 'plan')
  stopifnot(plan[[1L]]$action == 'protected')
  cat(
    'Ownership reconciliation: restored desired bytes repair stale ownership, preserve unrelated files, and apply idempotently.\n'
  )
}
if (sys.nframe() == 0L) {
  ownership_reconciliation_acceptance()
}
