ir_compatibility_acceptance <- function() {
  internal <- function(name) getFromNamespace(name, 'specmill')
  prepare <- internal('prepare_operation_policy')
  context <- internal('operation_review_context')
  native <- internal('openapi_read_records')
  finish <- internal('finish_operation_policy')
  summarize <- internal('operation_records_result')
  project <- internal('openapi_records_ir')
  adapt <- internal('ir_compatibility_records')
  validate <- internal('validate_ir')
  workspace <- tempfile('ir-compatibility-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  file <- file.path(workspace, 'schema.json')
  response <- list('200' = list(description = 'OK'))
  request <- function(schema) {
    list(content = list('application/json' = list(schema = schema)))
  }
  document <- list(
    openapi = '3.1.0',
    info = list(title = 'Compatibility', version = '1'),
    servers = list(list(url = 'https://api.example.test')),
    paths = list(
      '/first' = list(
        get = list(
          operationId = 'first',
          parameters = list(list(
            name = 'q',
            `in` = 'query',
            schema = list(type = 'string', default = 'all')
          )),
          responses = response
        )
      ),
      '/middle' = list(
        post = list(
          operationId = 'middle',
          responses = response,
          requestBody = request(list(
            type = 'object',
            propertyNames = list(pattern = '^x')
          ))
        )
      ),
      '/third' = list(
        post = list(
          operationId = 'third',
          responses = response,
          requestBody = request(list(
            type = 'object',
            properties = list(value = list(type = 'string'))
          ))
        )
      ),
      '/last' = list(get = list(operationId = 'last', responses = response))
    )
  )
  write <- function(doc) {
    jsonlite::write_json(
      doc,
      file,
      auto_unbox = TRUE,
      null = 'null',
      pretty = TRUE
    )
  }
  write(document)
  policy <- prepare(list(service = 'reviewed'))
  records <- native(file, context(policy))
  before <- tools::md5sum(file)
  # The public adapter must keep complete R shapes, NULL fields, interleaving,
  # schema attributes and diagnostics, not merely equivalent JSON.
  stopifnot(identical(
    specmill::read_operations(file, list(service = 'reviewed')),
    finish(records, policy)
  ))
  parsed <- summarize(records)
  parsed$operations <- records$operations
  parsed$unsupported_operations <- list()
  ir <- project(file, parsed, records$source_data)
  ir$service$id <- 'reviewed'
  stopifnot(!length(validate(ir)), length(ir$operations) == 4L)
  roundtrip <- adapt(ir, records)
  stopifnot(identical(roundtrip, records))
  ir$operations[[1L]]$name <- 'renamed_first'
  ir$operations[[1L]]$parameters[[1L]]$name <- 'search'
  ir$operations[[3L]]$body$required <- TRUE
  changed <- adapt(ir, records)
  stopifnot(
    changed$operations[[1L]]$name == 'renamed_first',
    changed$operations[[1L]]$parameters[[1L]]$name == 'search',
    changed$operations[[3L]]$body_required,
    identical(
      changed$operations[[1L]]$parameters[[1L]]$schema,
      records$operations[[1L]]$parameters[[1L]]$schema
    ),
    identical(changed$operations[[3L]]$body, records$operations[[3L]]$body),
    identical(changed$diagnostics, records$diagnostics),
    identical(changed$inventory, records$inventory),
    identical(before, tools::md5sum(file))
  )
  # A second document read would mix a new source with already parsed requests.
  updated <- document
  updated$info$title <- 'Changed after normalization'
  write(updated)
  snapshot <- project(file, parsed, records$source_data)
  stopifnot(
    snapshot$sources[[1L]]$title == 'Compatibility',
    snapshot$sources[[1L]]$hash$value == unname(before)
  )
  write(document)
  # Missing entries for excluded operations in this atomic override map throw
  # if eagerly looked up. Only the selected operation may resolve its setting.
  selected_policy <- list(
    include = 'GET /first',
    text_encoding_overrides = c('GET /first' = 'scalar')
  )
  selected <- specmill::read_operations(file, selected_policy)
  stopifnot(
    length(selected$operations) == 1L,
    !length(selected$diagnostics),
    length(selected$inventory) == 4L
  )
  # Invalid, unused metadata was not a request blocker before the IR adapter.
  # Preserve that behavior and expose projection gaps as explicit lossy types.
  simple <- document
  simple$paths <- list(
    '/first' = list(get = list(operationId = 'first', responses = response))
  )
  variants <- list(
    reference = list('$ref' = 5L),
    format = list(type = 'string', format = list('bad', 'format'))
  )
  for (bad in variants) {
    malformed <- simple
    malformed$components <- list(schemas = list(Unused = bad))
    write(malformed)
    raw <- native(file, context(prepare(list())))
    stopifnot(identical(
      specmill::read_operations(file),
      finish(raw, prepare(list()))
    ))
    imported <- internal('importer_openapi')(file)
    stopifnot(
      !length(validate(imported)),
      length(imported$sources[[1L]]$types$Unused$lossy) == 1L
    )
  }
  for (kind in c('header', 'auth', 'http', 'response')) {
    malformed <- simple
    if (kind == 'header') {
      malformed$paths[['/first']]$get$responses[['200']]$headers <- list(
        Unused = list('$ref' = '#/components/headers/Missing')
      )
    }
    if (kind == 'auth') {
      malformed$components <- list(
        securitySchemes = list(Unused = list(type = list('bad', 'type')))
      )
    }
    if (kind == 'http') {
      malformed$components <- list(
        securitySchemes = list(
          Unused = list(type = 'http', scheme = list('bearer', 'basic'))
        )
      )
    }
    if (kind == 'response') {
      malformed$paths[['/first']]$get$responses[['404']] <- list(
        '$ref' = '#/components/responses/Missing'
      )
    }
    write(malformed)
    raw <- native(file, context(prepare(list())))
    stopifnot(identical(
      specmill::read_operations(file),
      finish(raw, prepare(list()))
    ))
    imported <- internal('importer_openapi')(file)
    stopifnot(!length(validate(imported)))
    if (kind %in% c('auth', 'http')) {
      stopifnot(imported$sources[[1L]]$auth_schemes$Unused$kind == 'custom')
    }
    if (kind == 'header') {
      stopifnot(
        imported$operations[[1L]]$responses[[1L]]$headers$Unused$lossy[[1L]] ==
          'unresolved_reference'
      )
    }
    if (kind == 'response') {
      stopifnot(
        imported$operations[[1L]]$responses[[2L]]$type$lossy[[1L]] ==
          'unresolved_reference'
      )
    }
  }
  # Preserve legacy handling of an ambiguous direct-R review map: a leading
  # NULL must not turn into a later source selection merely through filtering.
  write(simple)
  alternate <- simple
  alternate$paths[['/first']]$get$responses[[
    '200'
  ]]$description <- 'Different response'
  alternate_file <- file.path(workspace, 'alternate.json')
  jsonlite::write_json(
    alternate,
    alternate_file,
    auto_unbox = TRUE,
    pretty = TRUE
  )
  ambiguous <- list(
    duplicate_response_overrides = stats::setNames(
      list(NULL, list(source = 'alternate.json', reason = 'Reviewed response')),
      rep('GET /first', 2L)
    )
  )
  conflict <- tryCatch(
    specmill::read_operations(c(file, alternate_file), ambiguous),
    error = identity
  )
  stopifnot(
    inherits(conflict, 'error'),
    grepl(
      'Conflicting duplicate operation',
      conditionMessage(conflict),
      fixed = TRUE
    )
  )
  empty <- specmill::read_operations(character())
  stopifnot(
    !length(empty$operations),
    !length(empty$inventory),
    !'source_data' %in% names(empty)
  )
  cat(
    'ir-compatibility: exact R records, neutral field projection, lazy reviews, source snapshots and unused metadata passed\n'
  )
}
if (sys.nframe() == 0L) {
  ir_compatibility_acceptance()
}
