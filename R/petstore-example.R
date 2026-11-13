#' Build the Petstore configuration example
#'
#' Builds a complete client package, `petstoretrial`, for all 19 operations of
#' the Swagger Petstore. It uses the frozen Petstore schema shipped with
#' specmill and the reviewed configuration in
#' `system.file('examples', 'petstore', package = 'specmill')`: three service
#' files (`pet.yml`, `store.yml`, `user.yml`) that rename functions and
#' parameters, group generated source and help, and map array query and header
#' inputs, plus six client-owned functions and a localhost test of every
#' endpoint. Nothing is downloaded and no request is sent.
#'
#' @param path Directory for the new client package. It must not exist.
#' @return The [generate_client()] result for the configured client, invisibly.
#' @details The client is initialized from the frozen schema, its project YAML
#'   is replaced by the three example services, and wrappers and help are
#'   generated. The six client-owned functions are documented with roxygen2 in
#'   a temporary copy, and only their help pages are copied back, so the
#'   generated pages stay owned by specmill. Run the client's tests with
#'   `testthat::test_local(path)`; they need callr and httpuv.
#' @seealso The example's README:
#'   `system.file('examples', 'petstore', 'README.md', package = 'specmill')`.
#' @examples
#' \dontrun{
#' root <- file.path(tempdir(), 'petstoretrial')
#' petstore_example(root)
#' testthat::test_local(root)
#' }
#' @export
petstore_example <- function(path) {
  if (file.exists(path)) {
    stop('Choose a new directory: ', path)
  }
  example <- system.file(
    'examples',
    'petstore',
    package = 'specmill',
    mustWork = TRUE
  )
  initialize_client(
    path,
    system.file(
      'configuration',
      'petstore.json',
      package = 'specmill',
      mustWork = TRUE
    ),
    package = 'petstoretrial',
    title = 'Complete Petstore Configuration Example',
    license = 'MIT + file LICENSE',
    author = list(
      given = 'Example',
      family = 'Maintainer',
      email = 'you@example.org'
    ),
    base_url = 'https://petstore3.swagger.io/api/v3'
  )
  groups <- c('pet', 'store', 'user')
  yaml::write_yaml(
    list(
      config_version = 1L,
      package = 'petstoretrial',
      services = as.list(paste0('apis/', groups, '.yml'))
    ),
    file.path(path, 'specmill.yml')
  )
  copy <- function(from, to) {
    stopifnot(file.copy(file.path(example, from), to, overwrite = TRUE))
  }
  for (group in groups) {
    copy(paste0(group, '.yml'), file.path(path, 'apis'))
    copy(paste0(group, '_custom.R'), file.path(path, 'R'))
  }
  description <- read.dcf(file.path(path, 'DESCRIPTION'), keep.white = TRUE)
  description[, 'Suggests'] <- paste0(
    description[, 'Suggests'],
    ', callr, httpuv'
  )
  write.dcf(
    description,
    file.path(path, 'DESCRIPTION'),
    keep.white = colnames(description)
  )
  dir.create(file.path(path, 'tests', 'testthat'), recursive = TRUE)
  copy('test-http.R', file.path(path, 'tests', 'testthat'))
  writeLines(
    c(
      'library(testthat)',
      'library(petstoretrial)',
      "test_check('petstoretrial')"
    ),
    file.path(path, 'tests', 'testthat.R')
  )
  artifacts <- c('wrappers', 'documentation')
  generate_client(
    path,
    config = 'specmill.yml',
    mode = 'apply',
    artifacts = artifacts
  )
  # Client-owned functions own their help. Document them in a copy and bring
  # back only their pages; specmill writes the generated pages.
  stage <- tempfile('petstore-docs-')
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  file.copy(
    file.path(path, c('DESCRIPTION', 'LICENSE', 'R', 'NAMESPACE')),
    stage,
    recursive = TRUE
  )
  roxygen2::roxygenise(stage, roclets = 'rd')
  custom <- c(
    'pet_create',
    'pet_update',
    'pet_upload_image',
    'store_order_create',
    'user_create',
    'user_update'
  )
  stopifnot(file.copy(
    file.path(stage, 'man', paste0(custom, '.Rd')),
    file.path(path, 'man'),
    overwrite = TRUE
  ))
  invisible(generate_client(
    path,
    config = 'specmill.yml',
    mode = 'apply',
    artifacts = artifacts
  ))
}
