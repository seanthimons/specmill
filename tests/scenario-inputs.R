# Regression for issue 272: scenario inputs resolve from reviewed docs examples
# and schema examples; missing or invalid examples block the scenario.

scenario_inputs_acceptance <- function() {
  workspace <- tempfile('scenario-inputs-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  write_schema <- function(name, document) {
    path <- file.path(workspace, name)
    jsonlite::write_json(document, path, auto_unbox = TRUE)
    path
  }
  string <- list(type = 'string')
  param <- function(name, location, schema, required = TRUE, ...) {
    c(
      list(name = name, `in` = location, required = required, schema = schema),
      list(...)
    )
  }
  get <- function(id, parameters) {
    list(
      get = list(
        operationId = id,
        parameters = parameters,
        responses = list('200' = list(description = 'OK'))
      )
    )
  }
  post <- function(id, content) {
    list(
      post = list(
        operationId = id,
        requestBody = list(required = TRUE, content = content),
        responses = list('200' = list(description = 'OK'))
      )
    )
  }
  object <- list(
    type = 'object',
    required = list('name'),
    properties = list(name = string)
  )
  oas3 <- write_schema(
    'oas3.json',
    list(
      openapi = '3.0.3',
      info = list(title = 'Inputs', version = '1'),
      paths = list(
        '/param-example/{id}' = get(
          'param_example',
          list(
            param('id', 'path', string, example = 'p-1'),
            param('size', 'query', list(type = 'integer', default = 5L)),
            param(
              'lang',
              'query',
              list(type = 'string', enum = list('en', 'fr')),
              required = FALSE
            )
          )
        ),
        '/synthesized/{id}' = get(
          'synthesized',
          list(param('id', 'path', string))
        ),
        '/placeholder/{id}' = get(
          'placeholder',
          list(
            param('id', 'path', list(type = 'string', example = 'string'))
          )
        ),
        '/enum' = get(
          'enum_only',
          list(
            param('kind', 'query', list(type = 'string', enum = list('a', 'b')))
          )
        ),
        '/duplicate/{id}' = get(
          'duplicate',
          list(
            param('id', 'path', string),
            param('id', 'query', string)
          )
        ),
        '/media' = post(
          'media_example',
          list(
            'application/json' = list(
              schema = object,
              example = list(name = 'from-media')
            )
          )
        ),
        '/top' = post(
          'top_example',
          list(
            'application/json' = list(
              schema = c(object, list(example = list(name = 'from-schema')))
            )
          )
        ),
        '/plain' = post(
          'plain_body',
          list('application/json' = list(schema = object))
        ),
        '/lines' = post(
          'lines_body',
          list('text/plain' = list(schema = string))
        ),
        '/status' = get(
          'find_by_status',
          list(param(
            'status',
            'query',
            list(
              type = 'array',
              items = list(
                type = 'string',
                enum = list('available', 'sold'),
                default = 'available'
              )
            )
          ))
        ),
        '/props' = post(
          'property_examples',
          list(
            'application/json' = list(
              schema = list(
                type = 'object',
                required = list('name'),
                properties = list(
                  name = list(type = 'string', example = 'from-property')
                )
              )
            )
          )
        ),
        '/form' = post(
          'form_body',
          list(
            'application/x-www-form-urlencoded' = list(
              schema = list(
                type = 'object',
                required = list('code'),
                properties = list(code = list(type = 'string', maxLength = 3L))
              )
            )
          )
        ),
        '/binary' = post(
          'binary_body',
          list(
            'application/octet-stream' = list(
              schema = list(type = 'string', format = 'binary')
            )
          )
        )
      )
    )
  )
  operations <- specmill::read_operations(oas3)$operations
  resolve <- function(
    name,
    scenario = list(operation = name),
    examples = list()
  ) {
    specmill:::scenario_resolution(
      operations[[name]],
      list(docs = list(examples = examples)),
      scenario
    )
  }

  # Parameter examples win over schema values; optional inputs are not invented.
  r <- resolve('param_example')
  stopifnot(
    identical(r$source, 'schema'),
    identical(r$inputs, list(id = 'p-1', size = 5L)),
    identical(r$sources, c(id = 'parameter_example', size = 'schema_default'))
  )
  r <- resolve('enum_only')
  stopifnot(
    identical(r$inputs$kind, 'a'),
    identical(r$sources[['kind']], 'schema_enum')
  )
  # Body media and schema examples.
  r <- resolve('media_example')
  stopifnot(
    identical(r$sources[['body']], 'media_example'),
    identical(r$inputs$body$name, 'from-media')
  )
  r <- resolve('top_example')
  stopifnot(
    identical(r$sources[['body']], 'schema_example'),
    identical(r$inputs$body$name, 'from-schema')
  )
  # Missing examples and placeholders block instead of stopping.
  stopifnot(
    identical(resolve('synthesized')$blocked, 'missing example for id'),
    identical(resolve('placeholder')$blocked, 'missing example for id'),
    identical(resolve('plain_body')$blocked, 'missing example for body'),
    # A constrained input no example fills is a missing example too.
    identical(
      specmill:::scenario_resolution(
        operations$form_body,
        list(),
        list(operation = 'x')
      )$blocked,
      'missing example for body'
    ),
    identical(resolve('synthesized')$source, 'blocked')
  )
  # A reviewed docs example supplies what the schema does not.
  r <- resolve(
    'synthesized',
    list(operation = 'x', example = 1L),
    list(list(id = 'item-9'))
  )
  stopifnot(
    identical(r$source, 'docs_example'),
    identical(r$inputs, list(id = 'item-9'))
  )
  # Duplicate schema names map positionally to their public names.
  r <- resolve(
    'duplicate',
    list(operation = 'x', example = 1L),
    list(list(id = 'path-a', id.1 = 'query-b'))
  )
  stopifnot(
    identical(r$inputs, list(id = 'path-a', id.1 = 'query-b')),
    identical(unname(r$sources), c('docs_example', 'docs_example'))
  )
  # An invalid docs example blocks with its constraint message.
  r <- resolve(
    'enum_only',
    list(operation = 'x', example = 1L),
    list(list(kind = 'zzz'))
  )
  stopifnot(
    identical(r$source, 'blocked'),
    grepl('kind', r$blocked),
    !grepl('No valid fixture', r$blocked)
  )
  r <- resolve(
    'enum_only',
    list(operation = 'x', example = 1L),
    list(list(knd = 'a'))
  )
  stopifnot(identical(r$blocked, 'docs example names unknown arguments: knd'))
  # Paging controls are stripped before checks and passed through.
  r <- resolve(
    'enum_only',
    list(operation = 'x', example = 1L),
    list(list(kind = 'b', all_pages = FALSE))
  )
  stopifnot(identical(r$inputs, list(kind = 'b', all_pages = FALSE)))
  # Explicit scenario inputs are used as reviewed.
  r <- resolve(
    'synthesized',
    list(operation = 'x', inputs = list(id = 'given'))
  )
  stopifnot(
    identical(r$source, 'scenario'),
    identical(r$inputs, list(id = 'given'))
  )
  # An empty docs example adds nothing; required inputs still come from the schema.
  r <- resolve('enum_only', list(operation = 'x', example = 1L), list(list()))
  stopifnot(identical(r$source, 'schema'))
  # Values built from item or property examples, defaults or enums are not
  # missing examples.
  r <- resolve('find_by_status')
  stopifnot(
    identical(r$inputs$status, 'available'),
    identical(r$sources[['status']], 'schema_default')
  )
  r <- resolve('property_examples')
  stopifnot(
    identical(r$inputs$body, list(name = 'from-property')),
    identical(r$sources[['body']], 'schema_example')
  )
  # Docs examples for form and binary bodies are checked on their own paths.
  r <- resolve(
    'form_body',
    list(operation = 'x', example = 1L),
    list(list(body = list(code = 'toolong')))
  )
  stopifnot(
    identical(r$source, 'blocked'),
    grepl('Invalid body', r$blocked, fixed = TRUE)
  )
  r <- resolve(
    'form_body',
    list(operation = 'x', example = 1L),
    list(list(body = list(code = 'ok')))
  )
  stopifnot(identical(r$source, 'docs_example'))
  r <- resolve(
    'binary_body',
    list(operation = 'x', example = 1L),
    list(list(body = 'not raw'))
  )
  stopifnot(grepl(
    'Binary fixture must be a raw vector',
    r$blocked,
    fixed = TRUE
  ))
  stopifnot(identical(
    resolve('binary_body')$blocked,
    'missing example for body'
  ))

  # Line bodies take a vector of lines.
  lines <- specmill::read_operations(
    oas3,
    list(text_encoding = 'lines')
  )$operations$lines_body
  r <- specmill:::scenario_resolution(
    lines,
    list(docs = list(examples = list(list(body = list('a', 'b'))))),
    list(operation = 'x', example = 1L)
  )
  stopifnot(
    identical(r$source, 'docs_example'),
    identical(r$inputs$body, c('a', 'b'))
  )
  r <- specmill:::scenario_resolution(
    lines,
    list(docs = list(examples = list(list(body = list(1L, 2L))))),
    list(operation = 'x', example = 1L)
  )
  stopifnot(grepl(
    'Text body must be a character value',
    r$blocked,
    fixed = TRUE
  ))

  # Swagger 2 parameter examples, defaults and body schema examples.
  swagger <- write_schema(
    'swagger.json',
    list(
      swagger = '2.0',
      info = list(title = 'Swagger', version = '1'),
      host = 'example.org',
      basePath = '/',
      paths = list(
        '/things/{id}' = list(
          get = list(
            operationId = 'get_thing',
            parameters = list(
              list(
                name = 'id',
                `in` = 'path',
                required = TRUE,
                type = 'string',
                example = 's-1'
              ),
              list(
                name = 'limit',
                `in` = 'query',
                required = TRUE,
                type = 'integer',
                default = 10L
              )
            ),
            responses = list('200' = list(description = 'OK'))
          )
        ),
        '/things' = list(
          post = list(
            operationId = 'add_thing',
            consumes = list('application/json'),
            parameters = list(list(
              name = 'payload',
              `in` = 'body',
              required = TRUE,
              schema = c(object, list(example = list(name = 'swagger-body')))
            )),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    )
  )
  swagger_ops <- specmill::read_operations(swagger)$operations
  r <- specmill:::scenario_resolution(
    swagger_ops$get_thing,
    list(),
    list(operation = 'x')
  )
  stopifnot(
    identical(r$inputs, list(id = 's-1', limit = 10L)),
    identical(r$sources, c(id = 'parameter_example', limit = 'schema_default'))
  )
  r <- specmill:::scenario_resolution(
    swagger_ops$add_thing,
    list(),
    list(operation = 'x')
  )
  stopifnot(identical(r$sources[['body']], 'schema_example'))

  # operation_fixtures() values are unchanged and now carry their sources.
  fixtures <- specmill::operation_fixtures(operations[
    'param_example'
  ])$param_example
  stopifnot(
    identical(attr(fixtures, 'input_sources')[['lang']], 'schema_enum'),
    identical(fixtures$lang, 'en')
  )

  # Through a client: renamed body argument, reporting and generation.
  root <- file.path(workspace, 'client')
  specmill::initialize_client(
    root,
    oas3,
    package = 'inputsclient',
    title = 'Inputs Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'http://127.0.0.1:1'
  )
  description <- read.dcf(file.path(root, 'DESCRIPTION'))
  description[1L, 'Suggests'] <- paste(
    description[1L, 'Suggests'],
    'vcr, withr, yaml',
    sep = ', '
  )
  write.dcf(description, file.path(root, 'DESCRIPTION'))
  service_path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
  service$operations <- list(
    'POST /plain' = list(
      body = list(name = 'record'),
      docs = list(examples = list(list(record = list(name = 'reviewed'))))
    ),
    # An example that violates the schema blocks a scenario that uses it.
    'GET /param-example/{id}' = list(
      docs = list(examples = list(list(id = 'x', size = 'many')))
    )
  )
  service$testing <- list(file = 'tests/testthat/fixtures/testing.yml')
  yaml::write_yaml(service, service_path)
  dir.create(file.path(root, 'tests/testthat/fixtures'), recursive = TRUE)
  testing <- file.path(root, 'tests/testthat/fixtures/testing.yml')
  writeLines(
    c(
      'scenarios:',
      "  from_schema: {operation: 'GET /param-example/{id}'}",
      '  renamed_body: {operation: POST /plain, example: 1, match: [method, uri, body_json]}',
      "  needs_example: {operation: 'GET /synthesized/{id}'}"
    ),
    testing
  )
  declared <- specmill::inspect_client(root)$testing$inputsclient$scenarios
  stopifnot(
    identical(declared$from_schema$inputs, 'schema'),
    identical(declared$renamed_body$inputs, 'docs_example'),
    identical(
      declared$renamed_body$input_values,
      list(record = list(name = 'reviewed'))
    ),
    identical(declared$needs_example$inputs, 'blocked'),
    identical(declared$needs_example$blocked, 'missing example for id')
  )
  generate <- function() {
    specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = 'apply'
    )
  }
  messages <- character()
  withCallingHandlers(generate(), message = function(m) {
    messages <<- c(messages, conditionMessage(m))
    invokeRestart('muffleMessage')
  })
  tests_dir <- file.path(root, 'tests/testthat')
  stopifnot(
    file.exists(file.path(
      tests_dir,
      'test-scenario-inputsclient-from_schema.R'
    )),
    file.exists(file.path(
      tests_dir,
      'test-scenario-inputsclient-renamed_body.R'
    )),
    !file.exists(file.path(
      tests_dir,
      'test-scenario-inputsclient-needs_example.R'
    )),
    any(grepl(
      'needs_example is blocked: missing example for id',
      messages,
      fixed = TRUE
    ))
  )
  rendered <- readLines(file.path(
    tests_dir,
    'test-scenario-inputsclient-from_schema.R'
  ))
  stopifnot(any(grepl(
    'param_example(id = "p-1", size = 5L)',
    rendered,
    fixed = TRUE
  )))
  # A missing docs example index is a declaration error, not a block.
  writeLines(
    c(
      'scenarios:',
      '  renamed_body: {operation: POST /plain, example: 2, match: [method, uri, body_json]}'
    ),
    testing
  )
  stopifnot(identical(
    tryCatch(specmill::inspect_client(root), error = conditionMessage),
    'inputsclient testing scenario renamed_body: docs example 2 does not exist'
  ))
  # A scenario that becomes blocked keeps its reviewed test.
  writeLines(
    c(
      'scenarios:',
      "  from_schema: {operation: 'GET /param-example/{id}', example: 1}",
      '  renamed_body: {operation: POST /plain, example: 1, match: [method, uri, body_json]}'
    ),
    testing
  )
  kept <- file.path(tests_dir, 'test-scenario-inputsclient-from_schema.R')
  before <- tools::md5sum(kept)
  blocked <- specmill::inspect_client(
    root
  )$testing$inputsclient$scenarios$from_schema$blocked
  stopifnot(is.character(blocked), grepl('size', blocked, fixed = TRUE))
  generate()
  stopifnot(identical(tools::md5sum(kept), before))
  # Blocked reasons keep route braces when reported.
  messages <- character()
  withCallingHandlers(generate(), message = function(m) {
    messages <<- c(messages, conditionMessage(m))
    invokeRestart('muffleMessage')
  })
  stopifnot(any(grepl(
    'GET /param-example/{id} query size',
    messages,
    fixed = TRUE
  )))
}

if (sys.nframe() == 0L) {
  scenario_inputs_acceptance()
}
