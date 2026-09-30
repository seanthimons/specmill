# Run from the Specmill checkout:
# Rscript dev/check_amos_validator.R /path/to/chemi-amos-prod.json
# Uploads the supplied schema to the public Swagger validator.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, file.exists(args[[1L]]))
pkgload::load_all('.', quiet = TRUE)
source <- normalizePath(args[[1L]], winslash = '/')
bytes <- readBin(source, 'raw', n = file.info(source)$size)
document <- jsonlite::fromJSON(rawToChar(bytes), simplifyVector = FALSE)
stopifnot(identical(document$swagger, '2.0'))
url <- 'https://validator.swagger.io/validator/debug'
request <- httr2::request(url) %>%
  httr2::req_body_raw(bytes, type = 'application/json') %>%
  httr2::req_headers(Accept = 'application/json') %>%
  httr2::req_timeout(30)
response <- httr2::req_perform(request)
report <- httr2::resp_body_json(response, simplifyVector = FALSE)
alternate_response <- httr2::req_perform(httr2::req_url_query(
  request, legacyJsonSchemaValidation = 'false'
))
alternate <- httr2::resp_body_json(alternate_response, simplifyVector = FALSE)
alternate_errors <- Filter(
  function(x) identical(x$level, 'error'), alternate$schemaValidationMessages
)
stopifnot(length(alternate_errors) > 0L)
errors <- Filter(
  function(x) identical(x$level, 'error'),
  report$schemaValidationMessages
)
# Both channels matter: the AMOS snapshot returns only semantic messages.
stopifnot(length(report$messages) > 0L || length(errors) > 0L)
methods <- c('get', 'post', 'put', 'patch', 'delete', 'head', 'options', 'trace')
keys <- unlist(lapply(names(document$paths), function(path) {
  verbs <- intersect(names(document$paths[[path]]), methods)
  if (length(verbs)) paste(toupper(verbs), path) else character()
}), use.names = FALSE)
parsed <- specmill::read_operations(
  source,
  policy = list(names = stats::setNames(
    as.list(paste0('operation_', seq_along(keys))),
    keys
  ))
)
stopifnot(length(parsed$diagnostics) > 0L)
output <- 'dev/audits/swagger-validator'
dir.create(output, recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(
  list(
    source = source,
    source_sha256 = digest::digest(bytes, algo = 'sha256', serialize = FALSE),
    checked_at = format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC'),
    validator_url = url,
    http_status = httr2::resp_status(response),
    report = report
  ),
  file.path(output, 'amos-production-validator.json'),
  pretty = TRUE, auto_unbox = TRUE, null = 'null'
)
jsonlite::write_json(
  list(
    source = source,
    source_sha256 = digest::digest(bytes, algo = 'sha256', serialize = FALSE),
    checked_at = format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC'),
    validator_url = paste0(url, '?legacyJsonSchemaValidation=false'),
    http_status = httr2::resp_status(alternate_response),
    report = alternate
  ),
  file.path(output, 'amos-production-validator-alternate.json'),
  pretty = TRUE, auto_unbox = TRUE, null = 'null'
)
jsonlite::write_json(
  list(
    source = source,
    naming_policy = 'Unique synthetic names isolate schema diagnostics from public-name collisions.',
    operation_count = length(parsed$operations),
    diagnostics = parsed$diagnostics,
    inventory = parsed$inventory
  ),
  file.path(output, 'amos-production-specmill.json'),
  pretty = TRUE, auto_unbox = TRUE, null = 'null'
)
cat('Swagger messages:', length(report$messages), 'schema errors:', length(errors), '\n')
cat('Alternate backend messages:', length(alternate$messages),
    'schema errors:', length(alternate_errors), '\n')
cat('Specmill inventory:', length(parsed$inventory), 'candidates:',
    length(parsed$operations), 'blocked:', length(parsed$diagnostics), '\n')
