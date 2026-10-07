parameter_composition_acceptance <- function() {
  root <- tempfile('composition-client-')
  port_file <- tempfile('composition-port-')
  on.exit(unlink(c(root, port_file), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(
              list(path = req$PATH_INFO, query = req$QUERY_STRING),
              auto_unbox = TRUE
            )
          )
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file = port_file),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  for (i in seq_len(200L)) {
    if (file.exists(port_file)) {
      break
    }
    if (!server$is_alive()) {
      server$get_result()
    }
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  origin <- paste0('http://127.0.0.1:', readLines(port_file))
  operation <- function(name, parameters) {
    list(
      operationId = name,
      parameters = parameters,
      responses = list('200' = list(description = 'OK'))
    )
  }
  query <- function(name, schema, ...) {
    list(name = name, `in` = 'query', schema = schema, ...)
  }
  string <- list(type = 'string')
  null <- list(type = 'null')
  document <- function(paths) {
    list(
      openapi = '3.1.0',
      info = list(title = 'Composition', version = '1'),
      servers = list(list(url = origin)),
      paths = paths,
      components = list(
        schemas = list(
          Code = list(type = 'string', pattern = '^[A-Z]+$', example = 'AB')
        )
      )
    )
  }
  closed <- function(name, type) {
    list(
      type = 'object',
      additionalProperties = FALSE,
      required = list(name),
      properties = stats::setNames(list(list(type = type)), name)
    )
  }
  supported <- list(
    '/nullable' = list(
      get = operation(
        'nullable',
        list(
          query(
            'r',
            list(anyOf = list(list(type = 'integer'), null)),
            required = TRUE
          ),
          query(
            'q',
            list(anyOf = list(list(type = 'string', minLength = 2L), null))
          ),
          query('n', list(type = list('integer', 'null'))),
          query(
            'limit',
            list(anyOf = list(list(type = 'integer'), null), default = 10L)
          ),
          query('page', list(type = 'integer', default = 1L))
        )
      )
    ),
    '/strict' = list(
      get = operation(
        'strict',
        # A default its own schema rejects needs a reviewed override.
        list(query(
          's',
          list(anyOf = list(list(type = 'integer'), null), default = '10')
        ))
      )
    ),
    '/union/{id}' = list(
      get = operation(
        'union',
        list(list(
          name = 'id',
          `in` = 'path',
          required = TRUE,
          style = 'label',
          schema = list(
            oneOf = list(
              list(type = 'string', pattern = '^[a-z]+$'),
              list(type = 'integer')
            )
          )
        ))
      )
    ),
    '/many' = list(
      get = operation(
        'many',
        list(query(
          'tags',
          list(anyOf = list(string, list(type = 'array', items = string))),
          required = TRUE
        ))
      )
    ),
    '/all' = list(
      get = operation(
        'all',
        list(query(
          'code',
          list(
            allOf = list(
              list(`$ref` = '#/components/schemas/Code'),
              list(maxLength = 3L)
            )
          ),
          required = TRUE
        ))
      )
    ),
    '/filter' = list(
      get = operation(
        'filter',
        list(query(
          'f',
          list(anyOf = list(closed('a', 'string'), closed('b', 'integer'))),
          required = TRUE,
          style = 'deepObject',
          explode = TRUE
        ))
      )
    )
  )
  unsupported <- list(
    '/mixed' = list(
      get = operation(
        'mixed',
        list(query('m', list(anyOf = list(string, list(type = 'object')))))
      )
    ),
    '/conflict' = list(
      get = operation(
        'conflict',
        list(query('c', list(allOf = list(string, list(type = 'integer')))))
      )
    ),
    '/only-null' = list(
      get = operation('only_null', list(query('z', list(anyOf = list(null)))))
    )
  )
  write_schema <- function(paths) {
    path <- tempfile(fileext = '.json')
    jsonlite::write_json(document(paths), path, auto_unbox = TRUE)
    path
  }
  # Branches without one unambiguous encoding stay visible as diagnostics.
  rejected <- specmill::read_operations(write_schema(unsupported))
  reasons <- vapply(rejected$inventory, `[[`, character(1), 'reason')
  names(reasons) <- vapply(rejected$inventory, `[[`, character(1), 'key')
  codes <- vapply(rejected$diagnostics, `[[`, character(1), 'code')
  stopifnot(
    !length(rejected$operations),
    all(codes == 'parameter_composition'),
    identical(
      reasons[c('GET /mixed', 'GET /conflict', 'GET /only-null')],
      c(
        'GET /mixed' = 'Parameter composition mixes object and non-object branches',
        'GET /conflict' = 'allOf parameter branches share no type',
        'GET /only-null' = 'Parameter schema only admits null'
      )
    )
  )
  schema <- write_schema(supported)
  parsed <- specmill::read_operations(schema)
  stopifnot(length(parsed$operations) == 6L, !length(parsed$diagnostics))
  params <- unlist(
    lapply(unname(parsed$operations), function(op) {
      stats::setNames(op$parameters, vapply(op$parameters, `[[`, '', 'name'))
    }),
    recursive = FALSE
  )
  wire <- lapply(params, function(p) p$schema$type)
  stopifnot(
    identical(wire$q, 'string'),
    identical(wire$n, 'integer'),
    identical(wire$r, 'integer'),
    identical(wire$id, c('string', 'integer')),
    identical(wire$tags, 'array'),
    identical(params$tags$schema$items$type, 'string'),
    identical(wire$code, 'string'),
    identical(params$code$schema$maxLength, 3L),
    identical(wire$f, 'object'),
    setequal(names(params$f$schema$properties), c('a', 'b')),
    all(vapply(
      params[names(params) != 'page'],
      function(p) !is.null(p$validation_schema),
      logical(1)
    )),
    is.null(params$page$validation_schema)
  )
  # Fixtures satisfy the original composed schemas.
  fixtures <- specmill::operation_fixtures(
    parsed$operations,
    list(strict = list(s = 5L))
  )
  stopifnot(
    identical(fixtures$all$code, 'AB'),
    identical(fixtures$union$id, 'example'),
    identical(fixtures$many$tags, 'example'),
    identical(names(fixtures$filter$f), 'a')
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'compositionclient',
    title = 'Composition Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  plan <- specmill::generate_client(
    validation = FALSE,
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(
    identical(
      vapply(plan$diagnostics, `[[`, character(1), 'code'),
      'parameter_default_schema'
    ),
    identical(plan$diagnostics[[1L]]$parameter, 's')
  )
  service_path <- list.files(file.path(root, 'apis'), full.names = TRUE)
  service <- yaml::read_yaml(service_path)
  service$schemas$files <- as.list(service$schemas$files)
  service$operations <- list(
    'GET /strict' = list(parameters = list('query s' = list(default = NULL)))
  )
  yaml::write_yaml(service, service_path)
  specmill::generate_client(
    validation = FALSE,
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  sent <- function(expr) {
    result <- force(expr)
    paste0(result$path, utils::URLdecode(result$query))
  }
  fails <- function(expr, pattern) {
    error <- tryCatch(force(expr), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  # Nullable scalars: NULL omits an optional parameter; JSON null has no
  # query encoding, so a required one must be present.
  stopifnot(
    identical(formals(runtime$nullable)$limit, 10L),
    identical(formals(runtime$nullable)$page, 1L),
    identical(sent(runtime$nullable(r = 1L)), '/nullable?r=1&limit=10&page=1'),
    identical(
      sent(runtime$nullable(r = 1L, q = 'ab', n = 2L, limit = 5L)),
      '/nullable?r=1&q=ab&n=2&limit=5&page=1'
    ),
    identical(
      sent(runtime$nullable(r = 1L, q = NULL, limit = NULL)),
      '/nullable?r=1&page=1'
    ),
    is.null(formals(runtime$strict)$s),
    identical(sent(runtime$strict()), '/strict'),
    identical(sent(runtime$strict(5L)), '/strict?s=5')
  )
  fails(runtime$nullable(r = 1L, q = 'a'), 'Invalid query parameter q')
  fails(runtime$nullable(r = 1L, n = 'x'), 'Invalid query parameter n')
  fails(runtime$nullable(r = NULL), 'Required input: r')
  fails(runtime$nullable(), 'r')
  # A scalar union keeps each branch's constraints.
  stopifnot(
    identical(sent(runtime$union('abc')), '/union/.abc'),
    identical(sent(runtime$union(5L)), '/union/.5')
  )
  fails(runtime$union('ABC'), 'Invalid path parameter id')
  fails(runtime$union(TRUE), 'Invalid path parameter id')
  # A scalar encodes like a one-element array.
  stopifnot(
    identical(sent(runtime$many('x')), '/many?tags=x'),
    identical(sent(runtime$many(c('x', 'y'))), '/many?tags=x&tags=y')
  )
  fails(runtime$many(1), 'Invalid query parameter tags')
  # allOf applies the referenced schema and the sibling constraint.
  stopifnot(identical(sent(runtime$all('AB')), '/all?code=AB'))
  fails(runtime$all('ABCD'), 'Invalid query parameter code')
  fails(runtime$all('ab'), 'Invalid query parameter code')
  # Object unions encode the matching branch's fields.
  stopifnot(
    identical(sent(runtime$filter(list(a = 'x'))), '/filter?f[a]=x'),
    identical(sent(runtime$filter(list(b = 2L))), '/filter?f[b]=2')
  )
  fails(runtime$filter(list(b = 'x')), 'Invalid query parameter f')
  fails(runtime$filter(list(a = 'x', b = 2L)), 'Invalid query parameter f')
  cat(
    'Parameter composition: nullable, scalar, scalar-or-array, allOf and object unions encode and validate; ambiguous compositions stay diagnosed.\n'
  )
}

if (sys.nframe() == 0L) {
  parameter_composition_acceptance()
}
