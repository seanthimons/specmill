# Verify the original archived AQS fixture without downloading or calling the API.
local({
  root <- tempfile('aqs-schema-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE))
  prefix <- 'specmill-testing/additional-schemas/epa/'
  utils::unzip(
    'dev/proving-ground-schemas/specmill-testing-base-schemas.zip',
    files = paste0(prefix, c('aqs_api_specification.json', 'manifest.json')),
    exdir = root
  )
  schema <- file.path(root, prefix, 'aqs_api_specification.json')
  manifest <- jsonlite::read_json(file.path(root, prefix, 'manifest.json'))
  entry <- Filter(function(x) x$file == 'aqs_api_specification.json', manifest$files)
  hash <- digest::digest(file = schema, algo = 'sha256')
  stopifnot(
    length(entry) == 1L,
    identical(hash, '9bea55cacfff11a04e56b8e18a7477d6af3ea284042d10d7322da049413a092b'),
    identical(hash, entry[[1]]$sha256)
  )
  document <- jsonlite::read_json(schema)
  stopifnot(is.null(document[['security']]), length(document$securityDefinitions) == 1L)
  error <- tryCatch(specmill::read_operations(schema), error = identity)
  stopifnot(inherits(error, 'error'), grepl('Operation name collision', conditionMessage(error)))
  parsed <- specmill::read_operations(schema, policy = list(names = list(
    'GET /qaAnnualPerformanceEvaluations/bySite' = 'qa_annual_performance_evaluations_by_site',
    'GET /qaAnnualPerformanceEvaluations/byPQAO' = 'qa_annual_performance_evaluations_by_pqao'
  )))
  stopifnot(length(parsed$operations) == 79L, !length(parsed$diagnostics))
  for (op in parsed$operations) {
    auth <- specmill:::operation_authentication(op, list(aqs_api_auth = 'AQS_TEST_KEY'))
    if (op$path == '/serviceAvailable') stopifnot(is.null(op[['security']]), !length(auth))
    if (op$path == '/list/states') stopifnot(length(auth) == 1L, auth[[1]][[1]]$name == 'key')
  }
  cat('Original AQS checksum, duplicate-ID overrides, and security resolution for 79 operations passed.\n')
})
