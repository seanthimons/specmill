source_origin_schema <- function() {
  get <- function(id, servers = NULL) {
    op <- list(
      operationId = id,
      summary = id,
      responses = list('200' = list(description = 'OK'))
    )
    if (!is.null(servers)) {
      op$servers <- lapply(servers, function(url) list(url = url))
    }
    list(get = op)
  }
  things <- get('listThings')
  things$servers <- list(list(url = '/v2'))
  list(
    openapi = '3.0.3',
    info = list(title = 'Origins', version = '1'),
    servers = list(list(url = '/api/v1')),
    paths = list(
      '/items' = get('listItems'),
      '/things' = things,
      '/deep' = get('deepLink', '/'),
      '/abs' = get('absolute', 'https://other.invalid/base')
    )
  )
}

source_origin_init <- function(root, origin = NULL, base_url = NULL) {
  schema <- tempfile(fileext = '.json')
  jsonlite::write_json(source_origin_schema(), schema, auto_unbox = TRUE)
  invisible(specmill::initialize_client(
    root,
    schema,
    package = 'origintest',
    title = 'Origin Test',
    license = 'MIT + file LICENSE',
    author = list(given = 'A', family = 'B', email = 'a@example.org'),
    base_url = base_url,
    origin = origin
  ))
}

# Request URL each wrapper would send, from a dry run in a fresh process.
source_origin_urls <- function(root, controls = NULL) {
  callr::r(
    function(root, controls) {
      suppressMessages(pkgload::load_all(root, quiet = TRUE))
      options(origintest.dry_run = TRUE)
      if (!is.null(controls)) {
        options(origintest.request = controls)
      }
      vapply(
        c('listItems', 'listThings', 'deepLink', 'absolute'),
        function(name) get(name)()$url,
        character(1)
      )
    },
    args = list(root, controls)
  )
}

test_that('a reviewed origin resolves relative servers with their precedence', {
  for (package in c('httr2', 'callr', 'pkgload')) {
    skip_if_not_installed(package)
  }
  origin <- 'https://example.invalid/docs/openapi.json'
  root <- file.path(withr::local_tempdir(), 'origintest')
  source_origin_init(root, origin = origin)

  service <- readLines(file.path(root, 'apis', 'default.yml'))
  expect_true(any(grepl(paste0('origin: ', origin), service, fixed = TRUE)))
  init <- readLines(file.path(root, 'dev', 'init.R'))
  expect_true(any(grepl(paste0('origin = "', origin, '"'), init, fixed = TRUE)))
  expect_true(any(grepl('base_url = NULL', init, fixed = TRUE)))
  provenance <- jsonlite::read_json(file.path(
    root,
    '.specmill',
    'helpers',
    'api_request.json'
  ))
  # The origin sets the default base URL; it is not recorded as an override.
  expect_null(provenance$settings$base_url_override)
  expect_identical(
    provenance$settings$base_url,
    'https://example.invalid/api/v1'
  )

  result <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  expect_length(result$diagnostics, 0L)
  expect_length(result$server_diagnostics, 0L)
  expect_identical(
    source_origin_urls(root),
    c(
      listItems = 'https://example.invalid/api/v1/items',
      listThings = 'https://example.invalid/v2/things',
      deepLink = 'https://example.invalid/deep',
      absolute = 'https://other.invalid/base/abs'
    )
  )
  # The schema copy is the original document.
  expect_identical(
    jsonlite::read_json(file.path(root, 'schema', 'openapi.json'))$servers[[
      1L
    ]]$url,
    '/api/v1'
  )
  # Regeneration is stable.
  expect_no_error(specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'check'
  ))
  # A runtime base_url still overrides every server.
  expect_true(all(startsWith(
    source_origin_urls(root, list(base_url = 'https://override.invalid')),
    'https://override.invalid/'
  )))
})

test_that('without an origin relative servers keep their diagnostics', {
  skip_if_not_installed('httr2')
  root <- file.path(withr::local_tempdir(), 'origintest')
  source_origin_init(root)
  result <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  expect_length(result$server_diagnostics, 3L)
  expect_true(all(grepl(
    'recorded origin',
    vapply(result$server_diagnostics, `[[`, character(1), 'reason')
  )))
  expect_false(any(grepl(
    'origin = ',
    readLines(file.path(root, 'dev', 'init.R')),
    fixed = TRUE
  )))
})

test_that('invalid origins are rejected', {
  skip_if_not_installed('httr2')
  for (origin in c(
    '/relative',
    'ftp://example.invalid/',
    'https://user:secret@example.invalid/',
    'https://example.invalid/?q=1',
    'https://example.invalid/#part'
  )) {
    expect_error(
      source_origin_init(file.path(withr::local_tempdir(), 'x'), origin),
      'absolute HTTP\\(S\\) origin'
    )
  }
  root <- file.path(withr::local_tempdir(), 'origintest')
  source_origin_init(root, origin = 'https://example.invalid/')
  service <- file.path(root, 'apis', 'default.yml')
  lines <- readLines(service)
  lines <- sub('origin: https://example.invalid/', 'origin: /relative', lines)
  writeLines(lines, service)
  expect_error(
    specmill::generate_client(root, config = 'specmill.yml', mode = 'plan'),
    'schemas origin must be an absolute'
  )
})

test_that('a Swagger 2 schema without host or schemes resolves against the origin', {
  for (package in c('httr2', 'callr', 'pkgload')) {
    skip_if_not_installed(package)
  }
  document <- list(
    swagger = '2.0',
    info = list(title = 'Legacy', version = '1'),
    basePath = '/api/v2',
    paths = list(
      '/items' = list(
        get = list(
          operationId = 'listItems',
          summary = 'List items',
          responses = list('200' = list(description = 'OK'))
        )
      )
    )
  )
  schema <- tempfile(fileext = '.json')
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  root <- file.path(withr::local_tempdir(), 'origintest')
  specmill::initialize_client(
    root,
    schema,
    package = 'origintest',
    title = 'Origin Test',
    license = 'MIT + file LICENSE',
    author = list(given = 'A', family = 'B', email = 'a@example.org'),
    origin = 'https://legacy.invalid/spec/swagger.json'
  )
  result <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  expect_length(result$server_diagnostics, 0L)
  url <- callr::r(
    function(root) {
      suppressMessages(pkgload::load_all(root, quiet = TRUE))
      options(origintest.dry_run = TRUE)
      listItems()$url
    },
    args = list(root)
  )
  expect_identical(url, 'https://legacy.invalid/api/v2/items')
})

test_that('configure_client keeps a recorded origin on rerun', {
  skip_if_not_installed('httr2')
  origin <- 'https://example.invalid/docs/openapi.json'
  root <- file.path(withr::local_tempdir(), 'origintest')
  source_origin_init(root, origin = origin)
  schema <- file.path(root, 'schema', 'openapi.json')
  plan <- specmill::configure_client(root, schema)
  actions <- vapply(plan$changes, `[[`, character(1), 'action')
  expect_true(all(actions == 'unchanged'))
  expect_error(
    specmill::configure_client(root, schema, origin = 'ftp://example.invalid/'),
    'absolute HTTP\\(S\\) origin'
  )
})
