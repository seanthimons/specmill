nested_body_acceptance <- function() {
  fixture <- getFromNamespace('body_fixture', 'specmill')
  normalize <- getFromNamespace('supported_body', 'specmill')
  schema <- list(
    type = 'object',
    required = list('records'),
    properties = list(
      records = list(
        type = 'array',
        minItems = 1L,
        items = list(
          type = 'object',
          required = list('id'),
          properties = list(
            id = list(type = 'integer', minimum = 1L),
            labels = list(type = 'array', items = list(type = 'string'))
          )
        )
      )
    )
  )
  schema <- normalize(schema, list())
  expected <- list(records = list(list(id = 1L, labels = list('example'))))
  stopifnot(
    identical(fixture(schema), expected),
    identical(fixture(schema, expected), expected)
  )
  fails <- function(expr) {
    stopifnot(inherits(tryCatch(force(expr), error = identity), 'error'))
  }
  fails(fixture(
    schema,
    list(records = list(list(labels = list('missing id'))))
  ))
  fails(fixture(schema, list(records = list(list(id = 0L)))))
  fails(fixture(
    schema,
    list(records = list(list(id = 1L, labels = 'wrong array shape')))
  ))
  with_example <- schema
  with_example$example <- list(records = list(list(id = 42L)))
  stopifnot(identical(fixture(with_example), with_example$example))
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'Nested bodies', version = '1'),
    paths = list(
      '/records' = list(
        post = list(
          operationId = 'submit_records',
          requestBody = list(
            required = TRUE,
            content = list('application/json' = list(schema = schema))
          ),
          responses = list('200' = list(description = 'ok'))
        )
      )
    )
  )
  file <- tempfile(fileext = '.json')
  read <- function() {
    jsonlite::write_json(document, file, auto_unbox = TRUE, null = 'null')
    specmill::read_operations(file)
  }
  parsed <- read()
  stopifnot(!length(parsed$diagnostics))
  runtime <- new.env(parent = baseenv())
  calls <- 0L
  runtime$request <- function(...) {
    calls <<- calls + 1L
    list(...)$body
  }
  eval(
    parse(
      text = specmill::render_operation(
        parsed$operations[[1L]],
        list(helper = 'request')
      )
    ),
    runtime
  )
  stopifnot(identical(runtime$submit_records(expected), expected), calls == 1L)
  fails(runtime$submit_records(list(
    records = list(list(labels = list('missing id')))
  )))
  stopifnot(calls == 1L)
  for (value in list('one\ntwo', FALSE, 0)) {
    type <- if (is.character(value)) {
      'string'
    } else if (is.logical(value)) {
      'boolean'
    } else {
      'number'
    }
    document$paths[['/records']]$post$requestBody$content[[
      'application/json'
    ]]$schema <- list(type = type)
    parsed <- read()
    stopifnot(!length(parsed$diagnostics))
    eval(
      parse(
        text = specmill::render_operation(
          parsed$operations[[1L]],
          list(helper = 'request')
        )
      ),
      runtime
    )
    stopifnot(identical(runtime$submit_records(value), value))
  }
  recursive <- list(
    type = 'object',
    required = list('id'),
    additionalProperties = FALSE,
    properties = list(
      id = list(type = 'integer', minimum = 1L),
      child = list('$ref' = '#/components/schemas/Node')
    )
  )
  document$components <- list(schemas = list(Node = recursive))
  document$paths[['/records']]$post$requestBody$content[[
    'application/json'
  ]]$schema <- list('$ref' = '#/components/schemas/Node')
  parsed <- read()
  stopifnot(
    length(parsed$operations) == 1L,
    !length(parsed$diagnostics)
  )
  eval(
    parse(
      text = specmill::render_operation(
        parsed$operations[[1L]],
        list(helper = 'request')
      )
    ),
    runtime
  )
  leaf <- list(id = 1L)
  chain <- list(id = 2L, child = list(id = 3L, child = leaf))
  stopifnot(
    identical(runtime$submit_records(chain), chain),
    identical(fixture(parsed$operations[[1L]]$body), leaf)
  )
  before <- calls
  fails(runtime$submit_records(list(id = 1L, child = list(id = 0L))))
  fails(runtime$submit_records(list(id = 1L, child = list())))
  fails(runtime$submit_records(list(
    id = 1L,
    child = list(id = 1L, extra = TRUE)
  )))
  cyclic <- new.env(parent = emptyenv())
  cyclic$child <- cyclic
  fails(runtime$submit_records(list(id = 1L, child = cyclic)))
  deep <- leaf
  for (i in seq_len(33L)) {
    deep <- list(id = 1L, child = deep)
  }
  error <- tryCatch(runtime$submit_records(deep), error = identity)
  stopifnot(grepl('depth limit', conditionMessage(error)))
  wide <- list(id = 1L, unknown = rep(list(1L), 20000L))
  error <- tryCatch(runtime$submit_records(wide), error = identity)
  stopifnot(grepl('node limit', conditionMessage(error)), calls == before)
  # Recursive targets retain request direction and OpenAPI 3.1 siblings stay guarded.
  document$components$schemas$Node$readOnly <- TRUE
  directional <- read()
  eval(
    parse(
      text = specmill::render_operation(
        directional$operations[[1L]],
        list(helper = 'request')
      )
    ),
    runtime
  )
  fails(runtime$submit_records(chain))
  document$components$schemas$Node$readOnly <- NULL
  document$openapi <- '3.1.0'
  document$paths[['/records']]$post$requestBody$content[[
    'application/json'
  ]]$schema$maxProperties <- 1L
  guarded <- read()
  stopifnot(
    !length(guarded$operations),
    guarded$diagnostics[[1L]]$code == 'recursive_reference'
  )
  document$paths[['/records']]$post$requestBody$content[[
    'application/json'
  ]]$schema$maxProperties <- NULL
  document$openapi <- '3.0.3'
  document$components$schemas$Node$required <- list('id', 'child')
  parsed <- read()
  stopifnot(
    !length(parsed$operations),
    parsed$diagnostics[[1L]]$code == 'recursive_reference'
  )
  for (ref in c(
    '#/components/schemas/Missing',
    'https://example.invalid/node.json'
  )) {
    document$components$schemas$Node$properties$child <- list('$ref' = ref)
    parsed <- read()
    stopifnot(!length(parsed$operations), length(parsed$diagnostics) == 1L)
  }
  cat(
    'Nested JSON bodies: recursive fixtures, scalar payloads, nested required fields and bounded finite recursion passed.\n'
  )
}
if (sys.nframe() == 0L) {
  nested_body_acceptance()
}
