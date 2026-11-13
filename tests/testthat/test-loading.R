loading_acceptance <- function() {
  directory <- tempfile('empty-working-directory-')
  dir.create(directory)
  old <- setwd(directory)
  on.exit(setwd(old), add = TRUE)
  # Load declared dependencies first, so dependency startup is not confused
  # with toolkit startup. The toolkit must add no client or process policy.
  for (package in c(
    'cli',
    'digest',
    'dplyr',
    'fs',
    'jsonlite',
    'purrr',
    'readr',
    'roxygen2',
    'stringr',
    'tibble',
    'tidyr',
    'yaml'
  )) {
    requireNamespace(package, quietly = TRUE)
  }
  previous_options <- options()
  previous_search <- search()
  # Checks the installed copy: callr starts a fresh process without load_all().
  stopifnot(requireNamespace('specmill', quietly = TRUE))
  stopifnot(
    identical(previous_options, options()),
    identical(previous_search, search()),
    !length(list.files(directory, all.files = TRUE, no.. = TRUE)),
    !any(c('ComptoxR', 'localcatalogue') %in% loadedNamespaces())
  )
  cat('Loading: no client, file generation, search path or option changes.\n')
}
test_that('loading specmill changes no options, search path, files or client state', {
  skip_if_not_installed('callr')
  fresh <- loading_acceptance
  # Run in a fresh process: specmill is already attached under test_check().
  environment(fresh) <- globalenv()
  callr::r(fresh)
  succeed()
})
