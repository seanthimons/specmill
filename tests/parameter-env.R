# Arguments bound to an environment variable (parameters.<name>.env): the
# wrapper reads the value at call time, never stores it, and replay treats it
# like a credential.

parameter_env_acceptance <- function() {
  workspace <- tempfile('parameter-env-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  string <- list(type = 'string')
  schema <- file.path(workspace, 'schema.json')
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Env', version = '1'),
      paths = list(
        '/items/{item_id}' = list(
          get = list(
            operationId = 'get_item',
            parameters = list(
              list(
                name = 'item_id',
                `in` = 'path',
                required = TRUE,
                schema = string
              ),
              list(
                name = 'email',
                `in` = 'query',
                required = TRUE,
                schema = string
              ),
              list(name = 'tag', `in` = 'query', schema = string),
              list(
                name = 'page',
                `in` = 'query',
                schema = list(type = 'integer')
              )
            ),
            responses = list('200' = list(description = 'OK'))
          )
        ),
        '/coded' = list(
          get = list(
            operationId = 'get_coded',
            parameters = list(list(
              name = 'code',
              `in` = 'query',
              required = TRUE,
              schema = list(type = 'string', pattern = '^[0-9]+$')
            )),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  root <- file.path(workspace, 'client')
  specmill::initialize_client(
    root,
    schema,
    package = 'envclient',
    title = 'Env Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'http://127.0.0.1:1'
  )
  service_path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
  configure <- function(overrides) {
    x <- service
    x$operations <- overrides
    yaml::write_yaml(x, service_path)
  }
  generate <- function() {
    specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = 'apply'
    )
  }
  fails <- function(overrides, expected) {
    configure(overrides)
    message <- tryCatch(
      {
        generate()
        'no error'
      },
      error = conditionMessage
    )
    if (!grepl(expected, message, fixed = TRUE)) {
      stop('Expected "', expected, '", got: ', message)
    }
  }
  bind <- function(...) {
    list('GET /items/{item_id}' = list(parameters = list(...)))
  }
  for (case in list(
    list(
      bind('query email' = list(env = 'ENV_EMAIL', default = 'x')),
      'parameter env replaces default, exclude and required'
    ),
    list(
      bind('query email' = list(env = 'ENV_EMAIL', required = TRUE)),
      'parameter env replaces default, exclude and required'
    ),
    list(
      bind('query email' = list(env = 'ENV_EMAIL', exclude = TRUE)),
      'parameter env replaces default, exclude and required'
    ),
    list(
      bind('query email' = list(env = '1BAD')),
      'parameter env must name an environment variable'
    ),
    list(
      bind('query page' = list(env = 'ENV_PAGE')),
      'parameter env needs a scalar string'
    ),
    list(
      list(
        'GET /items/{item_id}' = list(
          parameters = list('query tag' = list(env = 'ENV_TAG')),
          pagination = list(mode = 'page', parameter = 'tag')
        )
      ),
      'parameter env needs a scalar string'
    )
  )) {
    fails(case[[1L]], case[[2L]])
  }

  # The value is read at call time: generation never stores it.
  withr::local_envvar(
    ENV_EMAIL = 'secret-address@example.org',
    ENV_TAG = 'secret-tag'
  )
  configure(bind(
    'query email' = list(env = 'ENV_EMAIL'),
    'query tag' = list(env = 'ENV_TAG')
  ))
  generate()
  files <- list.files(
    root,
    recursive = TRUE,
    all.files = TRUE,
    full.names = TRUE
  )
  text <- paste(unlist(lapply(files, readLines, warn = FALSE)), collapse = '\n')
  stopifnot(
    !grepl('secret-address', text, fixed = TRUE),
    !grepl('secret-tag', text, fixed = TRUE),
    grepl(
      'email = base::Sys.getenv("ENV_EMAIL", unset = "")',
      text,
      fixed = TRUE
    ),
    grepl('Defaults to the ENV_EMAIL environment variable.', text, fixed = TRUE)
  )
  client <- new.env(parent = baseenv())
  for (path in list.files(file.path(root, 'R'), '\\.R$', full.names = TRUE)) {
    sys.source(path, envir = client)
  }
  captured <- NULL
  client$api_request <- function(...) {
    captured <<- list(...)
    list()
  }
  call <- function(...) {
    captured <<- NULL
    tryCatch(
      {
        client$get_item(...)
        captured$query
      },
      error = conditionMessage
    )
  }
  stopifnot(
    identical(
      call('a'),
      list(
        email = 'secret-address@example.org',
        tag = 'secret-tag',
        page = NULL
      )
    ),
    # An explicit value wins over the variable.
    identical(call('a', email = 'given@example.org')$email, 'given@example.org')
  )
  withr::local_envvar(ENV_EMAIL = NA, ENV_TAG = NA)
  stopifnot(
    identical(call('a'), 'Supply email or set ENV_EMAIL'),
    identical(call('a', email = NULL), 'Supply email or set ENV_EMAIL'),
    identical(
      call('a', email = NA_character_),
      'Supply email or set ENV_EMAIL'
    ),
    # An optional input with its variable unset is omitted.
    is.null(call('a', email = 'given@example.org')$tag)
  )

  # Replay sends a dummy in place of the value, so it must pass the schema.
  description <- read.dcf(file.path(root, 'DESCRIPTION'))
  description[1L, 'Suggests'] <- paste(
    description[1L, 'Suggests'],
    'vcr, withr, yaml',
    sep = ', '
  )
  write.dcf(description, file.path(root, 'DESCRIPTION'))
  dir.create(file.path(root, 'tests/testthat/fixtures'), recursive = TRUE)
  writeLines(
    'scenarios: {}',
    file.path(root, 'tests/testthat/fixtures/testing.yml')
  )
  service$testing <- list(file = 'tests/testthat/fixtures/testing.yml')
  fails(
    list(
      'GET /coded' = list(
        parameters = list('query code' = list(env = 'ENV_CODE'))
      )
    ),
    'The replay dummy does not satisfy the schema of query code bound to ENV_CODE'
  )
}

if (sys.nframe() == 0L) {
  parameter_env_acceptance()
}
