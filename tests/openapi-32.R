openapi_32_acceptance <- function() {
  workspace <- tempfile('openapi-32-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  ok <- list('200' = list(description = 'OK'))
  item <- list(
    type = 'object',
    required = list('name'),
    properties = list(
      name = list(type = 'string'),
      note = list(type = list('string', 'null')),
      kind = list(type = 'string', const = 'item'),
      owner = list('$ref' = '#/components/schemas/Owner', description = 'Who.')
    )
  )
  document <- function(version) {
    list(
      openapi = version,
      info = list(title = 'Items', version = '1'),
      servers = list(list(url = 'https://items.example.test')),
      tags = list(list(name = 'items')),
      paths = list(
        '/items' = list(
          get = list(
            operationId = 'list_items',
            tags = list('items'),
            parameters = list(list(
              name = 'limit',
              `in` = 'query',
              schema = list(type = list('integer', 'null'))
            )),
            responses = ok
          ),
          post = list(
            operationId = 'create_item',
            tags = list('items'),
            requestBody = list(
              required = TRUE,
              content = list(
                'application/json' = list(
                  schema = list('$ref' = '#/components/schemas/Item')
                )
              )
            ),
            responses = ok
          )
        )
      ),
      components = list(
        schemas = list(
          Item = item,
          Owner = list(
            type = 'object',
            properties = list(id = list(type = 'string'))
          )
        )
      )
    )
  }
  write_document <- function(value, name) {
    path <- file.path(workspace, name)
    jsonlite::write_json(value, path, auto_unbox = TRUE, null = 'null')
    path
  }
  read <- function(path) {
    suppressWarnings(suppressMessages(specmill::read_operations(path)))
  }
  codes <- function(parsed) {
    vapply(parsed$diagnostics, `[[`, character(1), 'code')
  }
  # An OpenAPI 3.2 document is read exactly like the same document declared as
  # 3.1: both follow JSON Schema 2020-12.
  current <- write_document(document('3.2.0'), 'current.json')
  previous <- write_document(document('3.1.0'), 'previous.json')
  neutral <- function(parsed) {
    lapply(parsed$operations, function(op) {
      op[setdiff(names(op), c('source', 'source_hash', 'schema_version'))]
    })
  }
  parsed <- read(current)
  limit <- parsed$operations$list_items$parameters[[1L]]
  stopifnot(
    specmill::validate_schema(current)$status == 'passed',
    specmill::validate_schema(current)$schema_version == '3.2.0',
    length(parsed$operations) == 2L,
    !length(parsed$diagnostics),
    parsed$operations[[1L]]$schema_version == '3.2.0',
    identical(neutral(parsed), neutral(read(previous))),
    # The wire type drops null; validation keeps the declared type array.
    identical(limit$schema$type, 'integer'),
    identical(limit$validation_schema$type, c('integer', 'null'))
  )
  # A later minor version is still refused.
  later <- write_document(document('3.3.0'), 'later.json')
  stopifnot(
    specmill::validate_schema(later)$status == 'unsupported',
    inherits(tryCatch(read(later), error = identity), 'error')
  )
  # Constructs that only OpenAPI 3.2 defines.
  extended <- document('3.2.0')
  extended$tags <- list(
    list(name = 'catalogue', kind = 'nav'),
    list(name = 'items', parent = 'catalogue', summary = 'Items')
  )
  extended$components$mediaTypes <- list(
    ItemBody = list(schema = list('$ref' = '#/components/schemas/Item'))
  )
  extended$paths[['/items']]$post$requestBody$content <- list(
    'application/json' = list('$ref' = '#/components/mediaTypes/ItemBody')
  )
  # The same media type behind a shared response and a shared request body.
  extended$components$responses <- list(
    Listed = list(
      description = 'Items',
      content = list(
        'application/json' = list('$ref' = '#/components/mediaTypes/ItemBody')
      )
    )
  )
  extended$components$requestBodies <- list(
    ItemRequest = list(
      required = TRUE,
      content = list(
        'application/json' = list('$ref' = '#/components/mediaTypes/ItemBody')
      )
    )
  )
  extended$paths[['/items']]$get$responses <- list(
    '200' = list('$ref' = '#/components/responses/Listed')
  )
  extended$paths[['/items']]$put <- list(
    operationId = 'replace_item',
    tags = list('items'),
    requestBody = list('$ref' = '#/components/requestBodies/ItemRequest'),
    responses = ok
  )
  extended$paths[['/items']]$query <- list(
    operationId = 'query_items',
    requestBody = list(
      content = list(
        'application/json' = list(schema = list(type = 'object'))
      )
    ),
    responses = ok
  )
  extended$paths[['/items']]$additionalOperations <- list(
    COPY = list(operationId = 'copy_items', responses = ok)
  )
  extended$paths[['/search']] <- list(
    get = list(
      operationId = 'search_items',
      parameters = list(list(
        name = 'q',
        `in` = 'querystring',
        content = list(
          'application/x-www-form-urlencoded' = list(
            schema = list(type = 'object')
          )
        )
      )),
      responses = ok
    )
  )
  extended$paths[['/events']] <- list(
    post = list(
      operationId = 'send_events',
      requestBody = list(
        content = list(
          'application/json' = list(itemSchema = list(type = 'object'))
        )
      ),
      responses = ok
    )
  )
  full <- write_document(extended, 'extended.json')
  as_previous <- extended
  as_previous$openapi <- '3.1.0'
  report <- specmill::validate_schema(full)
  parsed <- read(full)
  standard <- c('list_items', 'create_item', 'replace_item')
  internal <- function(name) utils::getFromNamespace(name, 'specmill')
  imported <- Filter(
    function(op) op$key == 'GET /items',
    internal('importer_openapi')(full)$operations
  )
  listed <- imported[[1L]]$responses[[1L]]
  response_schema <- internal('testing_response_schema')
  shared <- extended$components$responses$Listed
  inventory <- stats::setNames(
    parsed$inventory,
    vapply(parsed$inventory, `[[`, character(1), 'key')
  )
  stopifnot(
    report$status == 'passed',
    # The same document is not valid OpenAPI 3.1.
    specmill::validate_schema(write_document(
      as_previous,
      'not-31.json'
    ))$status ==
      'invalid',
    setequal(
      vapply(report$operations, `[[`, character(1), 'key'),
      c(
        'GET /items',
        'POST /items',
        'PUT /items',
        'QUERY /items',
        'COPY /items',
        'GET /search',
        'POST /events'
      )
    ),
    # A referenced Media Type Object supplies the request body.
    setequal(names(parsed$operations), standard),
    identical(
      parsed$operations$create_item$body$properties$name$type,
      'string'
    ),
    # So does one behind a referenced request body.
    identical(
      parsed$operations$replace_item$body$properties$name$type,
      'string'
    ),
    # A shared response keeps its type in the IR.
    identical(listed$media, 'application/json'),
    identical(listed$type$kind, 'ref'),
    identical(listed$type$name, 'Item'),
    # Recorded-response review follows the reference for 3.2 documents only.
    identical(
      response_schema(shared, jsonlite::read_json(full))$schema,
      list('$ref' = '#/components/schemas/Item')
    ),
    is.null(response_schema(shared, as_previous)$schema),
    # QUERY and additionalOperations are listed, never generated or blocking.
    inventory[['QUERY /items']]$status == 'excluded',
    inventory[['QUERY /items']]$code == 'query_method',
    inventory[['COPY /items']]$status == 'excluded',
    inventory[['COPY /items']]$code == 'additional_operation',
    setequal(codes(parsed), c('querystring_parameter', 'sequential_media')),
    identical(
      inventory[['GET /search']]$code,
      'querystring_parameter'
    ),
    identical(inventory[['POST /events']]$code, 'sequential_media')
  )
  # A defect inside a QUERY operation does not block the standard operations
  # of the same path.
  broken <- extended
  broken$paths[['/items']]$query$undeclared <- TRUE
  findings <- specmill::validate_schema(
    write_document(broken, 'broken.json')
  )$findings
  stopifnot(
    length(findings) > 0L,
    all(vapply(
      findings,
      function(x) identical(unlist(x$keys), 'QUERY /items'),
      logical(1)
    ))
  )
  # A client is generated once the two unsupported operations are excluded;
  # the QUERY and additionalOperations entries need no policy.
  root <- file.path(workspace, 'client')
  invisible(specmill::initialize_client(
    root,
    full,
    package = 'itemsclient',
    title = 'Items client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT'
  ))
  blocked <- tryCatch(
    specmill::generate_client(root, config = 'specmill.yml', mode = 'apply'),
    error = identity
  )
  project_path <- file.path(root, 'specmill.yml')
  project <- yaml::read_yaml(
    project_path,
    handlers = list(seq = function(x) x)
  )
  project$selection$exclude <- list('^/search$', '^/events$')
  yaml::write_yaml(project, project_path)
  generated <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  env <- new.env(parent = baseenv())
  for (file in list.files(
    file.path(root, 'R'),
    pattern = '\\.R$',
    full.names = TRUE
  )) {
    sys.source(file, env)
  }
  stopifnot(
    inherits(blocked, 'error'),
    grepl('Unsupported selected operations', conditionMessage(blocked)),
    setequal(names(generated$operations), standard),
    !length(generated$diagnostics),
    all(vapply(
      generated$validation,
      function(x) x$status == 'passed',
      logical(1)
    )),
    is.function(env$list_items),
    is.function(env$create_item),
    is.function(env$replace_item),
    !exists('query_items', envir = env),
    !exists('copy_items', envir = env)
  )
  # A defect inside the QUERY entry leaves generation and its record alone.
  stopifnot(file.copy(
    file.path(workspace, 'broken.json'),
    file.path(root, 'schema/openapi.json'),
    overwrite = TRUE
  ))
  replanned <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  queries <- Filter(
    function(x) x$key == 'QUERY /items',
    replanned$inventory
  )
  stopifnot(
    setequal(names(replanned$operations), standard),
    !length(replanned$diagnostics),
    length(queries) > 0L,
    all(vapply(queries, function(x) x$code == 'query_method', logical(1))),
    all(vapply(queries, function(x) x$status == 'excluded', logical(1)))
  )
  cat(
    'OpenAPI 3.2: 3.1 parity, validation, referenced media types, QUERY and additionalOperations listing, querystring and sequential-body diagnostics, and generation passed.\n'
  )
}
if (sys.nframe() == 0L) {
  openapi_32_acceptance()
}
