importer_openapi_acceptance <- function() {
  importer <- getFromNamespace('importer_openapi', 'specmill')
  validate <- getFromNamespace('validate_ir', 'specmill')
  convert <- getFromNamespace('openapi_ir_type', 'specmill')
  context_for <- getFromNamespace('openapi_ir_context', 'specmill')
  empty <- stats::setNames(list(), character())
  workspace <- tempfile('openapi-importer-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  write_schema <- function(document, name = 'schema.json') {
    path <- file.path(workspace, name)
    jsonlite::write_json(
      document,
      path,
      auto_unbox = TRUE,
      null = 'null',
      pretty = TRUE
    )
    path
  }
  document <- list(
    openapi = '3.1.0',
    info = list(title = 'Importer', version = '1'),
    servers = list(list(url = 'https://api.example.test')),
    security = list(list(key = list())),
    components = list(
      securitySchemes = list(
        key = list(type = 'apiKey', name = 'X-Key', `in` = 'header')
      ),
      schemas = list(
        Node = list(
          type = 'object',
          required = list('id'),
          properties = list(
            id = list(type = 'integer', format = 'int64'),
            next_node = list('$ref' = '#/components/schemas/Node')
          )
        ),
        'a/b~c' = list(type = 'string')
      )
    ),
    paths = list(
      '/nodes/{id}' = list(
        get = list(
          operationId = 'get_node',
          parameters = list(list(
            name = 'id',
            `in` = 'path',
            required = TRUE,
            schema = list(type = 'integer')
          )),
          responses = list(
            '200' = list(
              description = 'A node',
              content = list(
                'application/json' = list(
                  schema = list('$ref' = '#/components/schemas/Node')
                )
              )
            )
          )
        )
      )
    )
  )
  file <- write_schema(document)
  context <- context_for(document, file)
  type <- function(schema) convert(schema, context)
  node <- type(document$components$schemas$Node)
  stopifnot(
    node$kind == 'record',
    node$fields[[1L]]$required,
    node$fields[[1L]]$type$bits == 64L,
    identical(node$fields[[1L]]$type$lossy, list('int64_precision')),
    node$fields[[2L]]$type$kind == 'ref',
    node$fields[[2L]]$type$name == 'Node',
    type(list('$ref' = '#/components/schemas/a~1b~0c'))$name == 'a/b~c'
  )
  nullable <- type(list(type = list('string', 'null'), default = NULL))
  stopifnot(
    nullable$nullable,
    'default' %in% names(nullable),
    is.null(nullable$default)
  )
  ignored_nullable <- type(list(type = 'string', nullable = TRUE))
  stopifnot(is.null(ignored_nullable$nullable))
  sibling <- type(list(
    '$ref' = '#/components/schemas/Node',
    maxProperties = 2L
  ))
  stopifnot(
    sibling$kind == 'intersection',
    sibling$members[[1L]]$name == 'Node'
  )
  literal <- list('$ref' = '#/not/a/type', properties = list(kind = 'ref'))
  data <- type(list(
    type = 'string',
    default = literal,
    example = literal,
    const = NULL
  ))
  stopifnot(
    identical(data$default, literal),
    identical(data$example, literal),
    'const' %in% names(data)
  )
  stopifnot(
    type(list(type = 'string', format = 'binary'))$encoding == 'raw',
    type(list(type = 'string', format = 'byte'))$encoding == 'base64',
    type(list(type = 'string', format = 'date-time'))$name == 'datetime',
    type(list(
      type = 'number',
      minimum = 1,
      exclusiveMinimum = 2
    ))$exclusive_minimum ==
      2,
    type(list(
      type = 'object',
      additionalProperties = list(type = 'integer')
    ))$kind ==
      'map',
    identical(
      type(list(
        type = 'object',
        properties = empty,
        additionalProperties = FALSE
      ))$additional,
      FALSE
    ),
    type(list(type = 'array', items = list(type = 'boolean')))$items$name ==
      'boolean',
    type(list(type = 'string', enum = list('a', 'b')))$values[[2L]]$value ==
      'b',
    type(list(
      oneOf = list(list(type = 'string'), list(type = 'integer'))
    ))$mode ==
      'one_of',
    identical(
      type(list(not = list(type = 'string')))$lossy,
      list('unsupported_keyword')
    ),
    identical(type(FALSE)$lossy, list('unsupported_schema')),
    identical(
      type(list('$ref' = '#/missing'))$lossy,
      list('unresolved_reference')
    )
  )
  # Constraints that the v1 enum/untyped shapes cannot express stay visible.
  stopifnot(
    identical(
      type(list(enum = list('a', 'ab'), minLength = 2L))$lossy,
      list('unsupported_keyword')
    ),
    identical(type(list(maxProperties = 2L))$lossy, list('unsupported_keyword'))
  )
  old_context <- context
  old_context$version <- '3.0.3'
  old_type <- convert(
    list(
      type = 'integer',
      minimum = 1L,
      exclusiveMinimum = TRUE,
      nullable = TRUE
    ),
    old_context
  )
  stopifnot(
    old_type$nullable,
    old_type$exclusive_minimum == 1L,
    is.null(old_type$minimum)
  )
  discriminated <- type(list(
    oneOf = list(list('$ref' = '#/components/schemas/Node')),
    discriminator = list(
      propertyName = 'kind',
      mapping = list(node = '#/components/schemas/Node')
    )
  ))
  stopifnot(
    discriminated$discriminator$property == 'kind',
    discriminated$discriminator$mapping$node == 'Node'
  )
  ir <- importer(file)
  stopifnot(
    !length(validate(ir)),
    length(ir$operations) == 1L,
    ir$sources[[1L]]$auth_schemes$key$kind == 'api_key',
    identical(ir$operations[[1L]]$security[[1L]]$key, list()),
    ir$sources[[1L]]$types$Node$fields[[2L]]$type$name == 'Node',
    ir$operations[[1L]]$responses[[1L]]$type$kind == 'ref',
    ir$operations[[1L]]$responses[[1L]]$type$name == 'Node'
  )
  # Equal duplicates merge as before, while their type/auth scopes stay separate.
  copy <- write_schema(document, 'copy.json')
  combined <- importer(c(file, copy))
  stopifnot(
    !length(validate(combined)),
    length(combined$sources) == 2L,
    length(combined$operations) == 1L
  )
  other <- document
  other$paths <- list('/other/{id}' = other$paths[['/nodes/{id}']])
  other$paths[['/other/{id}']]$get$operationId <- 'get_other'
  other$components$securitySchemes$key[['in']] <- 'query'
  other$components$schemas$Node$properties$id <- list(type = 'string')
  scopes <- importer(c(file, write_schema(other, 'other.json')))
  stopifnot(
    !length(validate(scopes)),
    length(scopes$operations) == 2L,
    scopes$sources[[1L]]$types$Node$fields[[1L]]$type$name == 'integer',
    scopes$sources[[2L]]$types$Node$fields[[1L]]$type$name == 'string',
    scopes$sources[[1L]]$auth_schemes$key[['in']] == 'header',
    scopes$sources[[2L]]$auth_schemes$key[['in']] == 'query',
    scopes$operations[[2L]]$source == scopes$sources[[2L]]$id
  )
  no_content <- document
  no_content$paths[['/nodes/{id}']]$get$responses[['204']] <- list(
    description = 'No content'
  )
  no_content$paths[['/nodes/{id}']]$get$responses[['200']]$headers <- list(
    'X-Count' = list(schema = list(type = 'integer'))
  )
  responses <- importer(write_schema(no_content, 'responses.json'))$operations[[
    1L
  ]]$responses
  stopifnot(
    length(responses) == 2L,
    responses[[2L]]$status == '204',
    is.null(responses[[2L]]$media),
    responses[[1L]]$headers[['X-Count']]$name == 'integer',
    endsWith(
      responses[[1L]]$type$source_location$pointer,
      '/content/application~1json/schema'
    )
  )
  # Swagger body, form and response declarations share the neutral type model.
  swagger <- list(
    swagger = '2.0',
    info = document$info,
    host = 'api.example.test',
    schemes = list('https'),
    consumes = list('application/json'),
    produces = list('application/json'),
    definitions = list(
      Item = list(
        type = 'object',
        properties = list(name = list(type = 'string'))
      )
    ),
    paths = list(
      '/items' = list(
        post = list(
          operationId = 'create_item',
          parameters = list(list(
            name = 'body',
            `in` = 'body',
            required = TRUE,
            schema = list('$ref' = '#/definitions/Item')
          )),
          responses = list(
            '201' = list(
              description = 'Created',
              schema = list('$ref' = '#/definitions/Item')
            )
          )
        )
      )
    )
  )
  swagger_file <- write_schema(swagger, 'swagger.json')
  imported <- importer(swagger_file)
  stopifnot(
    !length(validate(imported)),
    imported$sources[[1L]]$format == 'swagger',
    imported$operations[[1L]]$body$required
  )
  yaml_file <- file.path(workspace, 'swagger.yaml')
  yaml12::write_yaml(swagger, yaml_file)
  yaml_ir <- importer(yaml_file)
  stopifnot(
    !length(validate(yaml_ir)),
    yaml_ir$operations[[1L]]$body$type$kind ==
      imported$operations[[1L]]$body$type$kind
  )
  contradiction <- document
  contradiction$paths[['/nodes/{id}']]$get$parameters <- c(
    contradiction$paths[['/nodes/{id}']]$get$parameters,
    list(list(
      name = 'count',
      `in` = 'query',
      schema = list(type = 'integer', enum = list('none'))
    ))
  )
  contradictory <- importer(write_schema(contradiction, 'contradiction.json'))
  stopifnot(
    !length(validate(contradictory)),
    any(vapply(
      contradictory$diagnostics,
      function(x) identical(x$code, 'type_enum_contradiction'),
      logical(1)
    )),
    identical(
      contradictory$operations[[1L]]$parameters[[2L]]$type$lossy,
      list('type_enum_contradiction')
    )
  )
  empty_document <- document
  empty_document$paths <- empty
  empty_ir <- importer(write_schema(empty_document, 'empty.json'))
  stopifnot(!length(validate(empty_ir)), identical(empty_ir$operations, list()))
  no_responses <- document
  no_responses$paths[['/nodes/{id}']]$get$responses <- empty
  no_responses_ir <- importer(write_schema(no_responses, 'no-responses.json'))
  stopifnot(
    !length(validate(no_responses_ir)),
    identical(no_responses_ir$operations[[1L]]$responses, list())
  )
  # Route identity survives colliding default wrapper names. Namespace review
  # remains a client-policy concern, not an importer rejection.
  simple <- list(responses = list('200' = list(description = 'OK')))
  collisions <- list(
    openapi = '3.0.3',
    info = document$info,
    paths = list(
      '/a-b' = list(get = simple),
      '/a_b' = list(get = simple)
    )
  )
  collision_file <- write_schema(collisions, 'collisions.json')
  collision_ir <- importer(collision_file)
  stopifnot(
    !length(validate(collision_ir)),
    length(collision_ir$operations) == 2L,
    anyDuplicated(vapply(collision_ir$operations, `[[`, character(1), 'name')) >
      0L,
    !anyDuplicated(vapply(collision_ir$operations, `[[`, character(1), 'key'))
  )
  client_collision <- tryCatch(
    specmill::read_operations(collision_file),
    error = identity
  )
  stopifnot(
    inherits(client_collision, 'error'),
    grepl(
      'Operation name collision',
      conditionMessage(client_collision),
      fixed = TRUE
    )
  )
  renamed <- specmill::read_operations(
    collision_file,
    list(names = list('GET /a_b' = 'get_other'))
  )
  stopifnot(
    length(renamed$operations) == 2L,
    'get_other' %in% names(renamed$operations)
  )
  # Excluded invalid inputs and invalid wrapper overrides must remain unparsed.
  selection <- list(
    openapi = '3.0.3',
    info = document$info,
    paths = list(
      '/skip/{id}' = list(
        get = list(
          parameters = list(list(
            name = 'id',
            `in` = 'path',
            required = FALSE,
            schema = list(type = 'integer')
          )),
          responses = simple$responses
        )
      ),
      '/keep' = list(get = simple)
    )
  )
  selected_file <- write_schema(selection, 'selected.json')
  selected <- specmill::read_operations(
    selected_file,
    list(
      service = 'reviewed',
      include = 'GET /keep',
      names = list('GET /skip/{id}' = 'invalid name', 'GET /keep' = 'keep_item')
    )
  )
  stopifnot(
    length(selected$operations) == 1L,
    !length(selected$diagnostics),
    selected$operations[[1L]]$id == 'reviewed GET /keep',
    selected$operations[[1L]]$name == 'keep_item',
    selected$inventory[[1L]]$status == 'excluded',
    selected$inventory[[1L]]$reason == 'Not in service include'
  )
  # No input policy can enter this API, and malformed file lists fail early.
  rejects <- function(expr) {
    stopifnot(inherits(tryCatch(force(expr), error = identity), 'error'))
  }
  rejects(importer(character()))
  rejects(importer(c(file, file)))
  rejects(importer(NA_character_))
  rejects(importer(
    file,
    policy = list(names = list('GET /nodes/{id}' = 'renamed'))
  ))
  unsupported <- document
  unsupported$openapi <- '4.0.0'
  rejects(importer(write_schema(unsupported, 'unsupported.json')))
  for (fixture in c(
    'catalogue/schema.json',
    'configuration/petstore.json',
    'schema-stress/classifier-dev.json',
    'schema-stress/natural-products.json'
  )) {
    path <- system.file(fixture, package = 'specmill', mustWork = TRUE)
    imported <- importer(path)
    problems <- validate(imported)
    if (length(problems)) {
      stop(paste(problems, collapse = '\n'))
    }
    legacy <- specmill::read_operations(path)
    stopifnot(
      setequal(
        vapply(imported$operations, `[[`, character(1), 'key'),
        vapply(
          c(legacy$operations, legacy$unsupported_operations),
          `[[`,
          character(1),
          'key'
        )
      ),
      length(imported$diagnostics) ==
        length(legacy$diagnostics) +
          length(legacy$fixture_diagnostics) +
          length(legacy$server_diagnostics)
    )
  }
  cat('importer-openapi: ok\n')
}
if (sys.nframe() == 0L) {
  importer_openapi_acceptance()
}
