retired_ownership_acceptance <- function() {
  root <- tempfile('retired-ownership-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  retired <- 'tests/testthat/test-contract-retired.R'
  unrelated <- 'R/missing.R'
  specmill::apply_files(
    root,
    setNames(list('test <- TRUE', 'missing <- TRUE'), c(retired, unrelated)),
    mode = 'apply'
  )
  unlink(file.path(root, c(retired, unrelated)))
  manifest_path <- file.path(root, '.specmill/manifest.json')
  before <- readLines(manifest_path)
  for (mode in c('plan', 'check')) {
    plan <- specmill::apply_files(root, list(), remove = retired, mode = mode)
    changes <- Filter(function(x) x$action == 'write', plan)
    stopifnot(
      length(changes) == 1L,
      changes[[1L]]$file == '.specmill/manifest.json',
      identical(before, readLines(manifest_path))
    )
  }
  specmill::apply_files(root, list(), remove = retired, mode = 'apply')
  manifest <- jsonlite::read_json(manifest_path)
  stopifnot(
    is.null(manifest$files[[retired]]),
    !is.null(manifest$files[[unrelated]])
  )
  before <- readLines(manifest_path)
  again <- specmill::apply_files(root, list(), remove = retired, mode = 'apply')
  stopifnot(
    all(vapply(again, function(x) x$action == 'unchanged', logical(1))),
    identical(before, readLines(manifest_path))
  )
  # Explicit retirement still protects a file edited after generation.
  owned <- 'R/edited.R'
  specmill::apply_files(
    root,
    setNames(list('edited <- TRUE'), owned),
    mode = 'apply'
  )
  writeLines('edited <- FALSE', file.path(root, owned))
  before <- readLines(manifest_path)
  plan <- specmill::apply_files(root, list(), remove = owned, mode = 'apply')
  stopifnot(
    plan[[1L]]$action == 'retained',
    identical(readLines(file.path(root, owned)), 'edited <- FALSE'),
    identical(before, readLines(manifest_path))
  )
  cat(
    'Retired ownership: missing selected outputs reconcile, unselected entries and edited files remain protected, and repeated apply is a no-op.\n'
  )
}
if (sys.nframe() == 0L) {
  retired_ownership_acceptance()
}
