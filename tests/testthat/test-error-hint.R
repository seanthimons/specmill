error_hint_contract <- function() {
  root <- tempfile('error-hint-')
  dir.create(root)
  schema <- tempfile('error-hint-', fileext = '.json')
  on.exit(unlink(c(root, schema), recursive = TRUE), add = TRUE)
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Hint', version = '1'),
      paths = list(
        '/items' = list(
          get = list(
            operationId = 'list_items',
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  # Port 9 (discard) is closed on localhost, so requests fail before a response.
  invisible(specmill::initialize_client(
    root,
    schema,
    package = 'hintclient',
    title = 'Hint Test',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'http://127.0.0.1:9'
  ))
  config <- file.path(root, 'specmill.yml')
  original <- readLines(config)
  set_hint <- function(value) {
    writeLines(
      sub(
        '^    retry_writes: no$',
        paste0('    retry_writes: no\n    error_hint: ', value),
        original
      ),
      config
    )
  }
  generate <- function() {
    specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = 'apply'
    )
  }
  fails <- function(pattern, expr) {
    message <- tryCatch(
      {
        expr
        ''
      },
      error = conditionMessage
    )
    if (!grepl(pattern, message, fixed = TRUE)) {
      stop('Expected error "', pattern, '", got "', message, '"')
    }
  }
  set_hint("''")
  fails('request_controls.error_hint must be a nonempty string', generate())
  # A helper from an older template would drop the hint silently.
  helper_path <- file.path(root, 'R/api_request.R')
  helper <- readLines(helper_path)
  writeLines(gsub('error_hint', 'old_hint', helper, fixed = TRUE), helper_path)
  set_hint('Run hintclient_sitrep().')
  fails('error_hint needs the current client helper template', generate())
  writeLines(helper, helper_path)
  generate()
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  respond <- function(status) {
    function(req) httr2::response(status_code = status)
  }
  call <- function(status = NULL) {
    tryCatch(
      if (is.null(status)) {
        runtime$list_items()
      } else {
        httr2::with_mocked_responses(respond(status), runtime$list_items())
      },
      error = conditionMessage
    )
  }
  stopifnot(
    identical(call(503L), 'HTTP 503 response Run hintclient_sitrep().'),
    identical(call(404L), 'HTTP 404 response'),
    identical(call(401L), 'HTTP 401 response'),
    endsWith(call(), 'failure) Run hintclient_sitrep().')
  )
  # Session options override the configured hint; typed errors omit it.
  options(hintclient.request = list(error_hint = 'Check the status page.'))
  stopifnot(identical(call(500L), 'HTTP 500 response Check the status page.'))
  options(hintclient.request = list(preserve_errors = TRUE))
  stopifnot(
    !grepl('sitrep', call(503L), fixed = TRUE),
    !grepl('sitrep', call(), fixed = TRUE)
  )
  options(hintclient.request = list(error_hint = NA_character_))
  fails('error_hint must be one nonempty string', runtime$list_items())
  options(hintclient.request = NULL)
  invisible(TRUE)
}

test_that('request errors carry the configured error hint', {
  error_hint_contract()
  cat('error-hint: ok\n')
  succeed()
})
