path_naming_acceptance <- function() {
  root <- tempfile('path-naming-')
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(c(root, schema), recursive = TRUE), add = TRUE)
  ok <- list(responses = list('200' = list(description = 'OK')))
  id <- list(list(
    name = 'id',
    `in` = 'path',
    required = TRUE,
    schema = list(type = 'string')
  ))
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'Chemistry', version = '1'),
    paths = list(
      '/api/rdkit' = list(get = ok, post = ok),
      '/api/rdkit/metadata' = list(get = ok),
      '/api/hazard/reports' = list(get = ok, post = ok),
      '/api/hazard/reports/{id}' = list(get = c(ok, list(parameters = id))),
      '/api/resolver/lookupCASRN' = list(post = ok),
      '/api/x-y' = list(get = ok),
      '/api/x_y' = list(get = ok)
    )
  )
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  plan <- function(...) {
    specmill::configure_client(
      root,
      schema,
      package = 'pathnames',
      naming = 'path',
      ...
    )
  }
  names_of <- function(proposal) {
    setNames(
      vapply(proposal$operations, `[[`, character(1), 'name'),
      vapply(proposal$operations, `[[`, character(1), 'key')
    )
  }
  codes <- function(proposal, code) {
    vapply(
      Filter(function(x) x$code == code, proposal$diagnostics),
      `[[`,
      character(1),
      'key'
    )
  }

  # Route words only: `api` and {param} segments dropped, case kept for asis.
  proposal <- plan(
    naming_options = list(
      prefix = 'chemi',
      collision_suffix = list(POST = 'bulk')
    )
  )
  got <- names_of(proposal)
  stopifnot(
    identical(unname(got[['GET /api/rdkit']]), 'chemi_rdkit'),
    identical(unname(got[['POST /api/rdkit']]), 'chemi_rdkit_bulk'),
    identical(unname(got[['GET /api/rdkit/metadata']]), 'chemi_rdkit_metadata'),
    identical(unname(got[['GET /api/hazard/reports']]), 'chemi_hazard_reports'),
    # Same method, so only the path parameter can separate these two.
    identical(
      unname(got[['GET /api/hazard/reports/{id}']]),
      'chemi_hazard_reports_by_id'
    ),
    identical(
      unname(got[['POST /api/hazard/reports']]),
      'chemi_hazard_reports_bulk'
    ),
    identical(
      unname(got[['POST /api/resolver/lookupCASRN']]),
      'chemi_resolver_lookupCASRN'
    )
  )
  # Every rename is reported; names the rule cannot separate are still flagged.
  stopifnot(
    setequal(
      codes(proposal, 'name_collision_resolved'),
      c(
        'POST /api/rdkit',
        'POST /api/hazard/reports',
        'GET /api/hazard/reports/{id}'
      )
    ),
    setequal(
      codes(proposal, 'name_collision'),
      c('GET /api/x-y', 'GET /api/x_y')
    )
  )
  resolved <- Filter(
    function(x) {
      x$code == 'name_collision_resolved' && x$key == 'POST /api/rdkit'
    },
    proposal$diagnostics
  )[[1L]]
  stopifnot(grepl(
    'chemi_rdkit_post|chemi_rdkit to chemi_rdkit_bulk',
    resolved$message
  ))

  # An unmapped method falls back to its lower-case name; by_param can be off.
  plain <- plan(naming_options = list(by_param = FALSE))
  got <- names_of(plain)
  stopifnot(
    identical(unname(got[['POST /api/rdkit']]), 'rdkit_post'),
    identical(unname(got[['GET /api/hazard/reports/{id}']]), 'hazard_reports'),
    'GET /api/hazard/reports/{id}' %in% codes(plain, 'name_collision')
  )

  # A route that already ends in its path parameter is not qualified twice; the
  # method suffix separates the GET/POST pair instead (#212).
  aeid_schema <- tempfile(fileext = '.json')
  on.exit(unlink(aeid_schema), add = TRUE)
  aeid <- list(list(
    name = 'aeid',
    `in` = 'path',
    required = TRUE,
    schema = list(type = 'integer')
  ))
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Bioactivity', version = '1'),
      paths = list(
        '/search/by-aeid/{aeid}' = list(get = c(ok, list(parameters = aeid))),
        '/search/by-aeid' = list(post = ok)
      )
    ),
    aeid_schema,
    auto_unbox = TRUE
  )
  aeid_names <- names_of(specmill::configure_client(
    tempfile('path-naming-aeid-'),
    aeid_schema,
    package = 'pathnames',
    naming = 'path',
    naming_options = list(collision_suffix = list(POST = 'bulk'))
  ))
  stopifnot(
    identical(
      unname(aeid_names[['GET /search/by-aeid/{aeid}']]),
      'search_by_aeid'
    ),
    identical(
      unname(aeid_names[['POST /search/by-aeid']]),
      'search_by_aeid_bulk'
    )
  )

  # name_case still applies on top of the route words.
  snake <- names_of(plan(
    name_case = 'snake_case',
    naming_options = list(prefix = 'chemi')
  ))
  stopifnot(identical(
    unname(snake[['POST /api/resolver/lookupCASRN']]),
    'chemi_resolver_lookup_casrn'
  ))

  # Written to the service YAML as reviewable names, not re-derived later.
  yaml_text <- paste(
    unlist(lapply(
      proposal$files[grepl('^apis/', names(proposal$files))],
      identity
    )),
    collapse = '\n'
  )
  stopifnot(grepl('POST /api/rdkit: chemi_rdkit_bulk', yaml_text, fixed = TRUE))

  # Option validation fails loudly rather than being ignored.
  fails <- function(expr) {
    inherits(tryCatch(force(expr), error = identity), 'error')
  }
  stopifnot(
    fails(specmill::configure_client(
      root,
      schema,
      package = 'pathnames',
      naming = 'operation_id',
      naming_options = list(prefix = 'chemi')
    )),
    fails(plan(naming_options = list(prefx = 'chemi'))),
    fails(plan(naming_options = list(collision_suffix = list(post = 'bulk')))),
    fails(plan(
      naming_options = list(collision_suffix = list(POST = 'not valid'))
    )),
    fails(plan(naming_options = list(by_param = 'yes'))),
    fails(plan(naming_options = list(prefix = list('a', 'b'))))
  )

  # Prefix lookup: exact API id, then family token, then default, then the id.
  head <- specmill:::path_naming_head
  prefix <- list(ctx_chem = 'exact', ctx = 'ct', default = 'fallback')
  stopifnot(
    identical(head(prefix, 'ctx_chem'), 'exact'),
    identical(head(prefix, 'ctx_other'), 'ct_other'),
    identical(head(prefix, 'chemi_amos'), 'fallback'),
    identical(head(list(ctx = 'ct'), 'chemi_amos'), 'chemi_amos'),
    identical(head(list(default = 'x'), NULL), 'x')
  )

  # A catalogue: the API id is the stem, and the head is not added twice.
  catalogue_root <- tempfile('path-naming-catalogue-')
  dir.create(catalogue_root)
  on.exit(unlink(catalogue_root, recursive = TRUE), add = TRUE)
  catalogue_schema <- function(path) {
    list(
      openapi = '3.0.3',
      info = list(title = 'API', version = '1'),
      paths = stats::setNames(list(list(get = ok)), path)
    )
  }
  jsonlite::write_json(
    catalogue_schema('/api/chem/search'),
    file.path(catalogue_root, 'ctx_chem.json'),
    auto_unbox = TRUE
  )
  jsonlite::write_json(
    catalogue_schema('/api/amos/search'),
    file.path(catalogue_root, 'chemi_amos.json'),
    auto_unbox = TRUE
  )
  apis <- data.frame(
    schema = c('ctx_chem.json', 'chemi_amos.json'),
    api = c('ctx_chem', 'chemi_amos'),
    base_url = 'https://example.invalid',
    include = TRUE
  )
  catalogue <- specmill::configure_client(
    catalogue_root,
    apis,
    package = 'multinames',
    naming = 'path',
    naming_options = list(prefix = list(ctx = 'ct'))
  )
  got <- vapply(catalogue$operations, `[[`, character(1), 'name')
  stopifnot(setequal(got, c('ct_chem_search', 'chemi_amos_search')))
  cat(
    'Path naming: route words, prefixes, collision suffixes, parameter qualifiers and reporting passed.\n'
  )
}
if (sys.nframe() == 0L) {
  path_naming_acceptance()
}
