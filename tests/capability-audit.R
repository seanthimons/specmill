capability_audit_acceptance <- function() {
  fixture_root <- if (dir.exists('tests/fixtures/capability-audit')) {
    'tests/fixtures/capability-audit'
  } else {
    'fixtures/capability-audit'
  }
  fixture <- function(name) file.path(fixture_root, name)
  operation <- function(parsed, name) {
    Filter(function(x) identical(x$name, name), parsed$operations)[[1L]]
  }
  invoke <- function(op, ...) {
    runtime <- new.env(parent = baseenv())
    runtime$request_helper <- function(...) list(...)
    eval(
      parse(text = specmill::render_operation(
        op,
        list(helper = 'request_helper')
      )),
      runtime
    )
    do.call(runtime[[op$name]], list(...))
  }

  # GH #20: invalid contracts are diagnosed before wrapper generation.
  parameters <- specmill::read_operations(fixture('parameter-contracts.json'))
  diagnostics <- setNames(
    parameters$diagnostics,
    vapply(parameters$diagnostics, `[[`, character(1), 'key')
  )
  rejected_empty <- lapply(
    c('empty_value_parameter', 'explicit_empty_value_parameter'),
    function(name) {
      tryCatch(invoke(operation(parameters, name), ''), error = identity)
    }
  )
  reserved <- invoke(operation(parameters, 'reserved_header_parameter'))
  allowed_empty <- invoke(
    operation(parameters, 'allowed_empty_value_parameter'),
    ''
  )
  override <- operation(parameters, 'override_path_parameter')
  stopifnot(
    length(parameters$operations) == 5L,
    length(parameters$diagnostics) == 3L,
    diagnostics[['GET /missing/{id}']]$code == 'missing_path_parameter',
    diagnostics[['GET /missing/{id}']]$source_location ==
      '#/paths/~1missing~1{id}',
    diagnostics[['GET /mismatched/{id}']]$code ==
      'unmatched_path_parameter',
    diagnostics[['GET /mismatched/{id}']]$source_location ==
      '#/paths/~1mismatched~1{id}/get/parameters/0',
    diagnostics[['GET /duplicate']]$code == 'duplicate_parameter',
    diagnostics[['GET /duplicate']]$source_location ==
      '#/paths/~1duplicate/get/parameters/1',
    all(vapply(rejected_empty, inherits, logical(1), 'error')),
    all(vapply(
      rejected_empty,
      function(e) grepl('Empty query parameter', conditionMessage(e)),
      logical(1)
    )),
    is.null(reserved$headers),
    identical(allowed_empty$query, list(value = '')),
    length(override$parameters) == 1L,
    identical(override$parameters[[1L]]$schema$type, 'integer'),
    sum(vapply(
      parameters$inventory,
      function(x) x$status == 'unsupported',
      logical(1)
    )) == 3L
  )

  # GH #22: request validation and fixtures apply property direction recursively.
  read_only <- specmill::read_operations(fixture('read-only-request.json'))
  read_only_31_file <- tempfile(fileext = '.json')
  on.exit(unlink(read_only_31_file), add = TRUE)
  read_only_31_document <- jsonlite::fromJSON(
    fixture('read-only-request.json'),
    simplifyVector = FALSE
  )
  read_only_31_document$openapi <- '3.1.1'
  jsonlite::write_json(
    read_only_31_document,
    read_only_31_file,
    auto_unbox = TRUE
  )
  read_only_31 <- specmill::read_operations(read_only_31_file)
  stopifnot(
    length(read_only$operations) == 3L,
    length(read_only$diagnostics) == 1L,
    read_only$diagnostics[[1L]]$key == 'POST /invalid',
    read_only$diagnostics[[1L]]$code == 'invalid_property_direction'
  )
  create <- operation(read_only, 'create_item')
  create_31 <- operation(read_only_31, 'create_item')
  accepted <- invoke(create, list(name = 'Ada'))
  accepted_31 <- invoke(create_31, list(name = 'Ada'))
  missing_name <- tryCatch(invoke(create, list()), error = identity)
  read_only_input <- tryCatch(
    invoke(create, list(id = 'server-owned', name = 'Ada')),
    error = identity
  )
  nested <- operation(read_only, 'create_nested_item')
  nested_body <- list(audit = list(label = 'reviewed'), name = 'Ada')
  accepted_nested <- invoke(nested, nested_body)
  nested_read_only <- tryCatch(
    invoke(
      nested,
      list(
        audit = list(createdAt = 'server-owned', label = 'reviewed'),
        name = 'Ada'
      )
    ),
    error = identity
  )
  composed <- operation(read_only, 'create_composed_item')
  composed_body <- c(list(secret = 'request-owned'), nested_body)
  accepted_composed <- invoke(composed, composed_body)
  missing_write_only <- tryCatch(
    invoke(composed, nested_body),
    error = identity
  )
  fixtures <- specmill::operation_fixtures(read_only$operations)
  stopifnot(
    identical(accepted$body, list(name = 'Ada')),
    identical(accepted_31$body, accepted$body),
    length(read_only_31$operations) == 3L,
    read_only_31$diagnostics[[1L]]$code == 'invalid_property_direction',
    inherits(missing_name, 'error'),
    grepl('Missing required body fields', conditionMessage(missing_name)),
    inherits(read_only_input, 'error'),
    grepl('Read-only body fields', conditionMessage(read_only_input)),
    identical(accepted_nested$body, nested_body),
    inherits(nested_read_only, 'error'),
    grepl('Read-only body fields', conditionMessage(nested_read_only)),
    identical(accepted_composed$body, composed_body),
    inherits(missing_write_only, 'error'),
    grepl(
      'Body allOf requires every branch',
      conditionMessage(missing_write_only)
    ),
    !'id' %in% names(fixtures$create_item$body),
    !'createdAt' %in% names(fixtures$create_nested_item$body$audit),
    !'id' %in% names(fixtures$create_composed_item$body),
    'secret' %in% names(fixtures$create_composed_item$body)
  )

  # GH #21: Swagger body media honors operation then document consumes.
  consumes <- specmill::read_operations(fixture('swagger-consumes.json'))
  stopifnot(!length(consumes$diagnostics))
  upload <- operation(consumes, 'upload_binary')
  upload_bytes <- as.raw(c(0, 1, 127, 255))
  sent <- invoke(upload, upload_bytes)
  create <- operation(consumes, 'create_item')
  created <- invoke(create, list(name = 'Ada'))
  stopifnot(
    identical(upload$source_operation$consumes, list('application/octet-stream')),
    identical(upload$body_media, 'application/octet-stream'),
    identical(sent$body_media, 'application/octet-stream'),
    identical(sent$body, upload_bytes),
    identical(create$body_media, 'application/json'),
    is.null(created$body_media),
    identical(created$body, list(name = 'Ada'))
  )

  # Known gap #11: operation servers do not reach wrappers or the fixed helper.
  servers <- specmill::read_operations(fixture('operation-server.json'))
  stopifnot(!length(servers$diagnostics))
  get_items <- operation(servers, 'get_items')
  sent <- invoke(get_items)
  client <- tempfile('capability-server-')
  on.exit(unlink(client, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    client,
    fixture('operation-server.json'),
    package = 'serverfixture',
    title = 'Server Fixture',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  helper <- paste(readLines(file.path(client, 'R/api_request.R')), collapse = '\n')
  stopifnot(
    identical(
      get_items$source_operation$servers[[1L]]$url,
      'https://operation.example.invalid/v2'
    ),
    is.null(get_items$servers),
    is.null(sent$server),
    is.null(sent$base_url),
    grepl(
      'https://{region}.root.example.invalid/v1',
      helper,
      fixed = TRUE
    )
  )

  # Known gap #24: OAS 3.0 request bodies are emitted for GET operations.
  get_body <- specmill::read_operations(fixture('oas30-get-body.json'))
  stopifnot(!length(get_body$diagnostics))
  sent <- invoke(operation(get_body, 'search_with_body'), list(term = 'audit'))
  stopifnot(
    identical(sent$method, 'GET'),
    identical(sent$body, list(term = 'audit'))
  )

  cat(
    'Capability audit: corrected parameter/request/media regressions and two silent-risk fixtures passed.\n'
  )
}

if (sys.nframe() == 0L) {
  capability_audit_acceptance()
}
