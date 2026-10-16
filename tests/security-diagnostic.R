security_diagnostic_acceptance <- function() {
  workspace <- tempfile('security-diagnostic-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  op <- function(id, security) {
    value <- list(
      operationId = id,
      responses = list('200' = list(description = 'ok'))
    )
    if (!is.null(security)) {
      value$security <- security
    }
    list(get = value)
  }
  build <- function(name, paths) {
    schema <- file.path(workspace, paste0(name, '.json'))
    jsonlite::write_json(
      list(
        openapi = '3.0.3',
        info = list(title = name, version = '1'),
        servers = list(list(url = 'http://127.0.0.1')),
        components = list(
          securitySchemes = list(
            api_key = list(type = 'apiKey', name = 'x-api-key', `in` = 'header')
          )
        ),
        paths = paths
      ),
      schema,
      auto_unbox = TRUE
    )
    root <- file.path(workspace, name)
    specmill::initialize_client(
      root,
      schema,
      package = name,
      title = name,
      author = list(
        given = 'Test',
        family = 'Maintainer',
        email = 'test@example.org'
      ),
      license = 'MIT + file LICENSE',
      base_url = 'http://127.0.0.1'
    )
    warnings <- character()
    withCallingHandlers(
      specmill::generate_client(
        validation = FALSE,
        root,
        config = 'specmill.yml',
        mode = 'apply'
      ),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart('muffleWarning')
      }
    )
    warnings
  }
  secured <- list(list(api_key = list()))
  mixed <- build(
    'mixed',
    list(
      '/a' = op('a', secured),
      '/b' = op('b', NULL)
    )
  )
  stopifnot(
    length(mixed) == 1L,
    grepl('without security', mixed),
    grepl('/b', mixed, fixed = TRUE),
    !grepl('/a', mixed, fixed = TRUE)
  )
  # Fully public, fully protected, and an explicit public override stay quiet.
  stopifnot(
    !length(build('public', list('/a' = op('a', NULL), '/b' = op('b', NULL)))),
    !length(build(
      'protected',
      list('/a' = op('a', secured), '/b' = op('b', secured))
    )),
    !length(build(
      'explicit',
      list('/a' = op('a', secured), '/b' = op('b', list()))
    ))
  )
  cat(
    'Security diagnostic: mixed schemas warn once; public, protected and explicit-public schemas stay quiet.\n'
  )
}
if (sys.nframe() == 0L) {
  security_diagnostic_acceptance()
}
