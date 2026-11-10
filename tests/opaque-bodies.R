opaque_bodies_acceptance <- function() {
  workspace <- tempfile('opaque-bodies-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  empty <- structure(list(), names = character())
  url <- 'https://schemas.example.org/filter.json'
  dynamic_url <- 'https://schemas.example.org/dynamic.json'
  write <- function(x, file) {
    jsonlite::write_json(x, file, auto_unbox = TRUE, pretty = TRUE)
  }
  ref <- function(x) list('$ref' = x)
  write(
    list(
      type = 'object',
      properties = list(value = list(type = 'string'), child = ref('#'))
    ),
    file.path(workspace, 'filter.json')
  )
  write(
    list(
      '$dynamicAnchor' = 'filter',
      type = 'object',
      properties = list(child = list('$dynamicRef' = '#filter'))
    ),
    file.path(workspace, 'dynamic.json')
  )
  entries <- lapply(c(url, dynamic_url), function(url) {
    list(
      url = url,
      file = basename(url),
      sha256 = digest::digest(
        file = file.path(workspace, basename(url)),
        algo = 'sha256'
      )
    )
  })
  lock <- file.path(workspace, 'specmill-references.yml')
  yaml::write_yaml(list(references = entries), lock)
  operation <- function(id, url) {
    list(
      post = list(
        operationId = id,
        requestBody = list(
          required = TRUE,
          content = list('application/json' = list(schema = ref(url)))
        ),
        responses = list('200' = list(description = 'OK'))
      )
    )
  }
  document <- list(
    openapi = '3.1.0',
    info = list(title = 'Opaque', version = '1'),
    paths = list(
      '/filter' = operation('filter_items', url),
      '/dynamic' = operation('dynamic_items', dynamic_url)
    )
  )
  schema <- file.path(workspace, 'openapi.json')
  write(document, schema)
  before <- specmill::read_operations(schema)
  stopifnot(
    !length(before$operations),
    any(vapply(
      before$diagnostics,
      function(d) d$code == 'recursive_reference',
      logical(1)
    ))
  )
  reviews <- list(
    'POST /filter' = list(
      reference = url,
      reason = 'Server validates filter shapes.'
    ),
    'POST /dynamic' = list(
      reference = dynamic_url,
      reason = 'Server validates dynamic filters.'
    )
  )
  parsed <- specmill::read_operations(
    schema,
    policy = list(opaque_bodies = reviews)
  )
  stopifnot(
    length(parsed$operations) == 2L,
    !length(parsed$diagnostics),
    length(parsed$body_diagnostics) == 2L,
    all(vapply(
      parsed$inventory,
      function(op) op$status != 'unsupported',
      logical(1)
    ))
  )
  # Reviews cannot swallow hash errors or change the reviewed target.
  yaml::write_yaml(
    list(
      references = list(
        modifyList(entries[[1L]], list(sha256 = strrep('0', 64))),
        entries[[2L]]
      )
    ),
    lock
  )
  tampered <- specmill::read_operations(
    schema,
    policy = list(opaque_bodies = reviews)
  )
  stopifnot(any(vapply(
    tampered$diagnostics,
    function(d) d$code == 'reference_hash_mismatch',
    logical(1)
  )))
  yaml::write_yaml(list(references = entries), lock)
  wrong <- reviews
  wrong[['POST /filter']]$reference <- 'https://schemas.example.org/other.json'
  rejected <- specmill::read_operations(
    schema,
    policy = list(opaque_bodies = wrong)
  )
  stopifnot(any(vapply(
    rejected$diagnostics,
    function(d) d$code == 'opaque_body_review',
    logical(1)
  )))
  # Boolean remote schemas keep their normal per-operation diagnostic.
  filter_file <- file.path(workspace, 'filter.json')
  filter_bytes <- readBin(filter_file, 'raw', n = file.info(filter_file)$size)
  write(FALSE, filter_file)
  boolean_entries <- entries
  boolean_entries[[1L]]$sha256 <- digest::digest(
    file = filter_file,
    algo = 'sha256'
  )
  yaml::write_yaml(list(references = boolean_entries), lock)
  boolean <- specmill::read_operations(schema)
  stopifnot(any(vapply(
    boolean$diagnostics,
    function(d) d$key == 'POST /filter' && d$code == 'boolean_schema',
    logical(1)
  )))
  writeBin(filter_bytes, filter_file)
  yaml::write_yaml(list(references = entries), lock)
  # The same reviewed URL in parameters remains unsupported.
  parameter_document <- document
  parameter_document$paths[['/parameter']] <- list(
    get = list(
      operationId = 'parameter',
      parameters = list(list(
        name = 'filter',
        `in` = 'query',
        schema = ref(url)
      )),
      responses = list('200' = list(description = 'OK'))
    )
  )
  write(parameter_document, file.path(workspace, 'parameter.json'))
  parameter <- specmill::read_operations(
    file.path(workspace, 'parameter.json'),
    policy = list(opaque_bodies = reviews)
  )
  stopifnot(any(vapply(
    parameter$diagnostics,
    function(d) d$key == 'GET /parameter' && d$code == 'recursive_reference',
    logical(1)
  )))
  # A recursive response remains a validation blocker after body review.
  response_document <- document
  response_document$paths[['/filter']]$post$responses[['200']]$content <-
    list('application/json' = list(schema = ref(url)))
  response_file <- file.path(workspace, 'response.json')
  write(response_document, response_file)
  reviewed_body <- getFromNamespace('opaque_body_document', 'specmill')
  validation_report <- getFromNamespace('schema_validation_report', 'specmill')
  response_view <- reviewed_body(response_file, reviews)
  stopifnot(
    validation_report(response_file, response_view)$status == 'unsupported'
  )
  for (review in list(
    list(reference = url),
    list(reference = url, reason = ''),
    list(reference = url, reason = 'Reviewed', extra = TRUE)
  )) {
    error <- tryCatch(
      specmill::read_operations(
        schema,
        policy = list(opaque_bodies = list('POST /filter' = review))
      ),
      error = identity
    )
    stopifnot(inherits(error, 'error'))
  }
  ready <- tempfile()
  on.exit(unlink(ready), add = TRUE)
  server <- callr::r_bg(
    function(ready) {
      port <- httpuv::randomPort()
      httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(
              list(
                media = req$CONTENT_TYPE,
                body = rawToChar(req$rook.input$read())
              ),
              auto_unbox = TRUE
            )
          )
        })
      )
      writeLines(as.character(port), ready)
      repeat {
        httpuv::service(10)
      }
    },
    list(ready),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  for (i in seq_len(400L)) {
    if (file.exists(ready)) {
      break
    }
    if (!server$is_alive()) {
      server$get_result()
    }
    Sys.sleep(0.025)
  }
  stopifnot(file.exists(ready))
  root <- file.path(workspace, 'client')
  specmill::initialize_client(
    root,
    schema,
    package = 'opaqueclient',
    title = 'Opaque Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT',
    base_url = paste0('http://127.0.0.1:', readLines(ready))
  )
  bundled <- specmill::read_operations(
    file.path(root, 'schema/openapi.json'),
    policy = list(opaque_bodies = reviews)
  )
  stopifnot(length(bundled$operations) == 2L, !length(bundled$diagnostics))
  # Also exercise the default validation gate against the original frozen inputs.
  stopifnot(all(file.copy(
    file.path(
      workspace,
      c(
        'openapi.json',
        'filter.json',
        'dynamic.json',
        'specmill-references.yml'
      )
    ),
    file.path(root, 'schema'),
    overwrite = TRUE
  )))
  policy_file <- file.path(root, 'apis/default.yml')
  policy <- yaml::read_yaml(policy_file, handlers = list(seq = identity))
  for (key in names(reviews)) {
    policy$operations[[key]] <- list(opaque_body = reviews[[key]])
  }
  yaml::write_yaml(policy, policy_file)
  plan <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  stopifnot(
    length(plan$operations) == 2L,
    !length(plan$diagnostics),
    length(plan$body_diagnostics) == 2L,
    plan$validation[[1L]]$status %in% c('unsupported', 'invalid'),
    plan$validation[[1L]]$reviewed[[1L]]$status == 'passed'
  )
  manifest <- jsonlite::read_json(file.path(root, '.specmill/manifest.json'))
  stopifnot(
    length(manifest$files[['R/filter_items.R']]$opaque_bodies) == 1L,
    grepl(
      url,
      paste(readLines(file.path(root, 'man/filter_items.Rd')), collapse = '\n'),
      fixed = TRUE
    )
  )
  specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
  policy$operations[['POST /dynamic']]$opaque_body <- NULL
  yaml::write_yaml(policy, policy_file)
  blocked <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(any(vapply(
    blocked$diagnostics,
    function(d) d$key == 'POST /dynamic',
    logical(1)
  )))
  policy$operations[['POST /dynamic']]$opaque_body <- reviews[['POST /dynamic']]
  policy$defaults$opaque_body <- reviews[['POST /filter']]
  yaml::write_yaml(policy, policy_file)
  error <- tryCatch(
    specmill::generate_client(root, config = 'specmill.yml', mode = 'plan'),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('belongs under operations', conditionMessage(error))
  )
  policy$defaults$opaque_body <- NULL
  yaml::write_yaml(policy, policy_file)
  # Source into a fresh process: the client must not load the toolkit at runtime.
  callr::r(
    function(root) {
      stopifnot(!'specmill' %in% loadedNamespaces())
      runtime <- new.env(parent = baseenv())
      for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
        sys.source(file, runtime)
      }
      body <- list(
        op = '=',
        args = list(list(property = 'parameter_code'), '00060')
      )
      for (name in c('filter_items', 'dynamic_items')) {
        result <- runtime[[name]](body)
        stopifnot(
          startsWith(result$media, 'application/json'),
          identical(
            jsonlite::fromJSON(result$body, simplifyVector = FALSE),
            body
          )
        )
      }
      stopifnot(!'specmill' %in% loadedNamespaces())
    },
    list(root)
  )
  cat(
    'Opaque bodies: reviewed cycles and dynamic references, hashes, selection, provenance and offline client transport passed.\n'
  )
}
if (sys.nframe() == 0L) {
  opaque_bodies_acceptance()
}
