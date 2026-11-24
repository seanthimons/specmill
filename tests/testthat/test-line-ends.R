test_that('generated wrappers carry no end-of-line whitespace', {
  root <- tempfile('trim-client-')
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(c(root, schema), recursive = TRUE), add = TRUE)
  field <- function(n) {
    stats::setNames(
      rep(list(list(type = 'string', description = 'A field')), n),
      paste0('long_field_name_', seq_len(n))
    )
  }
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Trim', version = '1'),
      servers = list(list(url = 'http://127.0.0.1:1')),
      paths = list(
        '/things' = list(
          post = list(
            operationId = 'thing',
            summary = 'Create a thing',
            description = 'First paragraph.\n\nSecond paragraph.',
            requestBody = list(
              required = TRUE,
              content = list(
                'application/json' = list(
                  schema = list(
                    type = 'object',
                    properties = c(
                      field(12L),
                      list(
                        nested = list(type = 'object', properties = field(12L))
                      )
                    )
                  )
                )
              )
            ),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'trimclient',
    title = 'Trim Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT'
  )
  generate <- function(mode) {
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = mode,
      validation = FALSE
    )
  }
  generate('apply')
  lines <- unlist(lapply(
    list.files(file.path(root, 'R'), full.names = TRUE),
    readLines
  ))
  expect_true(any(lines == "#'"))
  expect_identical(grep('[ \t]+$', lines, value = TRUE), character())
  # Check mode agrees with the bytes apply wrote.
  expect_no_error(generate('check'))
  # A line that ends inside a string literal keeps its whitespace.
  expect_identical(
    specmill:::trim_line_ends('f <- function() { \n  "a \n b" \n}'),
    'f <- function() {\n  "a \n b"\n}'
  )
})
