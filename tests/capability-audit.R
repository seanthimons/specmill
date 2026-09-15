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

  # Known gap #22: readOnly required fields are enforced on request bodies.
  read_only <- specmill::read_operations(fixture('read-only-request.json'))
  stopifnot(!length(read_only$diagnostics))
  create <- operation(read_only, 'create_item')
  rejected <- tryCatch(invoke(create, list(name = 'Ada')), error = identity)
  accepted <- invoke(create, list(id = 'server-owned', name = 'Ada'))
  stopifnot(
    inherits(rejected, 'error'),
    grepl('Missing required body fields', conditionMessage(rejected)),
    identical(accepted$body$id, 'server-owned')
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
    'Capability audit: corrected parameter/media regressions and three silent-risk fixtures passed.\n'
  )
}

if (sys.nframe() == 0L) {
  capability_audit_acceptance()
}
