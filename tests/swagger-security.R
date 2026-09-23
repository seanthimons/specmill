swagger_security_acceptance <- function() {
  workspace <- tempfile('swagger-security-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  schema <- file.path(workspace, 'schema.json')
  requirement <- list(list(key = list()))
  document <- list(
    swagger = '2.0',
    info = list(title = 'Swagger security', version = '1'),
    schemes = list('https'), host = 'example.org', basePath = '/api',
    securityDefinitions = list(key = list(
      type = 'apiKey', name = 'key', 'in' = 'query'
    )),
    paths = list(
      '/public' = list(get = list(operationId = 'get_public')),
      '/private' = list(get = list(
        operationId = 'get_private', security = requirement
      )),
      '/anonymous' = list(get = list(
        operationId = 'get_anonymous', security = list()
      ))
    )
  )
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  parsed <- specmill::read_operations(schema)$operations
  stopifnot(
    is.null(parsed$get_public$security),
    identical(parsed$get_private$security, requirement),
    identical(parsed$get_anonymous$security, list())
  )
  report <- specmill:::schema_report_operations(schema, list())
  stopifnot(
    'GET /public' %in% names(report),
    is.null(report[['GET /public']]$contract$root$security)
  )

  root <- file.path(workspace, 'client')
  specmill::initialize_client(
    root, schema, package = 'swaggerauth', title = 'Swagger Auth Client',
    author = list(given = 'Test', family = 'User', email = 'test@example.org'),
    license = 'MIT + file LICENSE'
  )
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  withr::local_envvar(c(SWAGGERAUTH_DRY_RUN = 'true', SWAGGERAUTH_KEY = NA))
  stopifnot(identical(runtime$get_public()$url, 'https://example.org/api/public'))
  error <- tryCatch(runtime$get_private(), error = identity)
  stopifnot(inherits(error, 'error'), grepl('Authentication required', conditionMessage(error)))
  runtime$set_api_token('fixture-key')
  stopifnot(
    identical(runtime$get_private()$url, 'https://example.org/api/private?key=fixture-key'),
    identical(runtime$get_anonymous()$url, 'https://example.org/api/anonymous')
  )
  document$security <- requirement
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  parsed <- specmill::read_operations(schema)$operations
  stopifnot(
    identical(parsed$get_public$security, requirement),
    identical(parsed$get_private$security, requirement),
    identical(parsed$get_anonymous$security, list())
  )
  report <- specmill:::schema_report_operations(schema, list())
  stopifnot(
    identical(report[['GET /public']]$contract$root$security, requirement),
    identical(report[['GET /anonymous']]$contract$root$security, list())
  )
  cat('Swagger absent, inherited and explicit security; generated query authentication passed.\n')
}
if (sys.nframe() == 0L) swagger_security_acceptance()
