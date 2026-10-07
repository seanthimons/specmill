parameter_defaults_acceptance <- function() {
  root <- tempfile('parameter-defaults-')
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(c(root, schema), recursive = TRUE), add = TRUE)
  union <- function(s) list(anyOf = list(s, list(type = 'null')))
  definitions <- list(
    good = list(type = 'integer', default = 3L),
    numeric = list(type = 'number', default = 1L),
    nullable = c(union(list(type = 'integer')), list(default = '2048')),
    enum = list(type = 'string', enum = list('yes'), default = 'no'),
    bounds = list(type = 'integer', minimum = 2L, default = 1L),
    pattern = c(
      union(list(type = 'string', pattern = '^a', minLength = 2L)),
      list(maxLength = 4L, default = 'abcdef')
    ),
    arrow = list(type = 'string', enum = list('', 'forward'), default = ''),
    required = list(type = 'integer', default = 'not-used'),
    header = list(type = 'string', default = 'line\r\nbreak'),
    empty = list(
      type = 'array',
      items = list(type = 'integer'),
      default = list()
    ),
    nested = list(
      type = 'array',
      items = list(type = 'integer'),
      default = list(list(1L))
    ),
    null_item = list(
      type = 'array',
      items = list(type = 'integer'),
      default = list(NULL)
    ),
    delimiter = list(
      type = 'array',
      items = list(type = 'string'),
      default = list('a b')
    )
  )
  paths <- setNames(
    lapply(names(definitions), function(name) {
      p <- list(
        name = 'p',
        'in' = if (name == 'header') 'header' else 'query',
        required = name == 'required',
        schema = definitions[[name]]
      )
      if (name == 'delimiter') {
        p$style <- 'spaceDelimited'
        p$explode <- FALSE
      }
      list(
        get = list(
          operationId = name,
          parameters = list(p),
          responses = list('200' = list(description = 'OK'))
        )
      )
    }),
    paste0('/', names(definitions))
  )
  document <- list(
    openapi = '3.1.0',
    info = list(title = 'Defaults', version = '1'),
    paths = paths
  )
  jsonlite::write_json(document, schema, auto_unbox = TRUE, null = 'null')
  # Defaults are annotations. The ordinary schema gate must still accept them.
  stopifnot(specmill::validate_schema(schema)$status == 'passed')
  specmill::initialize_client(
    root,
    schema,
    package = 'defaultclient',
    title = 'Defaults',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'maintainer@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://example.invalid'
  )
  callbacks <- new.env(parent = emptyenv())
  run <- function(mode) {
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = mode,
      callbacks = callbacks
    )
  }
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  before <- hashes()
  plan <- run('plan')
  stopifnot(
    identical(before, hashes()),
    length(plan$diagnostics) == 10L,
    setequal(names(plan$operations), c('good', 'numeric', 'required'))
  )
  for (d in plan$diagnostics) {
    stopifnot(
      d$classification == 'review_required',
      d$parameter == 'p',
      d$default_origin == 'schema',
      grepl('/schema/default$', d$source_location),
      grepl(d$parameter, d$reason, fixed = TRUE)
    )
  }
  codes <- setNames(
    vapply(plan$diagnostics, `[[`, character(1), 'code'),
    vapply(plan$diagnostics, `[[`, character(1), 'key')
  )
  stopifnot(
    codes[['GET /nullable']] == 'parameter_default_schema',
    codes[['GET /arrow']] == 'parameter_default_transport',
    codes[['GET /header']] == 'parameter_default_transport',
    codes[['GET /empty']] == 'parameter_default_transport',
    codes[['GET /delimiter']] == 'parameter_default_transport'
  )
  fails_unchanged <- function(mode) {
    before <- hashes()
    error <- tryCatch(run(mode), error = identity)
    stopifnot(
      inherits(error, 'error'),
      identical(before, hashes()),
      grepl('defaults', conditionMessage(error))
    )
  }
  fails_unchanged('apply')
  fails_unchanged('check')
  service_file <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_file)
  service$schemas$files <- as.list(service$schemas$files)
  fixes <- list(
    nullable = 2048L,
    enum = 'yes',
    bounds = 2L,
    pattern = 'abc',
    arrow = NULL,
    nested = list(1L),
    null_item = NULL,
    header = 'safe',
    empty = list(1L),
    delimiter = list('a', 'b')
  )
  service$operations <- setNames(
    lapply(names(fixes), function(name) {
      list(
        parameters = setNames(
          list(list(default = fixes[[name]])),
          paste(if (name == 'header') 'header' else 'query', 'p')
        )
      )
    }),
    paste('GET', paste0('/', names(fixes)))
  )
  yaml::write_yaml(service, service_file)
  stopifnot(!length(run('plan')$diagnostics))
  applied <- run('apply')
  stopifnot(length(applied$operations) == length(definitions))
  before <- hashes()
  run('check')
  run('apply')
  stopifnot(identical(before, hashes()))
  runtime <- new.env(parent = baseenv())
  for (f in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(f, runtime)
  }
  withr::local_options(list(defaultclient.dry_run = TRUE))
  for (name in setdiff(names(definitions), 'required')) {
    stopifnot(inherits(runtime[[name]](), 'httr2_request'))
  }
  stopifnot(
    inherits(runtime$required(1L), 'httr2_request'),
    grepl('p=2048', runtime$nullable()$url, fixed = TRUE),
    !grepl('p=', runtime$arrow()$url, fixed = TRUE),
    identical(formals(runtime$numeric)$p, 1)
  )
  # Configuration can introduce a bad default too, even over a valid annotation.
  service$operations[['GET /good']] <- list(
    parameters = list('query p' = list(default = 'bad'))
  )
  yaml::write_yaml(service, service_file)
  plan <- run('plan')
  stopifnot(
    length(plan$diagnostics) == 1L,
    plan$diagnostics[[1L]]$default_origin == 'configuration',
    plan$diagnostics[[1L]]$code == 'parameter_default_schema'
  )
  stopifnot(
    !any(vapply(
      plan$files,
      function(x) {
        x$file == 'R/good.R' && x$action %in% c('remove', 'delete')
      },
      logical(1)
    ))
  )
  fails_unchanged('apply')
  # Bad annotations on required parameters are not emitted as R defaults.
  # Explicit NULL and excluded parameters also do not need value validation.
  service$operations[['GET /good']]$parameters[['query p']]['default'] <- list(
    NULL
  )
  service$operations[['GET /nullable']] <- list(exclude_parameters = list('p'))
  yaml::write_yaml(service, service_file)
  stopifnot(!length(run('plan')$diagnostics))
  run('apply')
  sys.source(file.path(root, 'R', 'good.R'), runtime)
  stopifnot(!grepl('p=', runtime$good()$url, fixed = TRUE))
  callbacks$change_default <- function(op) {
    if (op$key == 'GET /good') {
      op$parameters[[1L]]$public_default <- 'bad'
    }
    op
  }
  service$prepare <- 'change_default'
  yaml::write_yaml(service, service_file)
  prepared <- run('plan')
  stopifnot(
    length(prepared$diagnostics) == 1L,
    prepared$diagnostics[[1L]]$key == 'GET /good',
    prepared$diagnostics[[1L]]$code == 'parameter_default_schema'
  )
  fails_unchanged('apply')
  # Direct rendering must not emit a wrapper with a self-invalid default.
  parsed <- specmill::read_operations(schema)
  error <- tryCatch(
    specmill::render_operation(
      parsed$operations$nullable,
      list(helper = 'api_request')
    ),
    error = identity
  )
  stopifnot(inherits(error, 'error'), error$code == 'parameter_default_schema')
  cat(
    'Parameter defaults: schema/transport diagnostics, overrides, NULL omission, required/excluded inputs, atomic generation and prepared default calls passed.\n'
  )
}

if (sys.nframe() == 0L) {
  parameter_defaults_acceptance()
}
