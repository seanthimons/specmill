# Regression for issue 273: proposed scenarios and docs example stubs, and a
# review of recorded responses against the OpenAPI response schema.

testing_proposals_acceptance <- function() {
  workspace <- tempfile('proposals-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  string <- list(type = 'string')
  ref <- function(name) list(`$ref` = paste0('#/components/schemas/', name))
  json <- function(schema) {
    list(
      '200' = list(
        description = 'OK',
        content = list('application/json' = list(schema = schema))
      )
    )
  }
  get <- function(id, parameters = list(), responses = json(ref('Item'))) {
    list(
      get = list(
        operationId = id,
        parameters = parameters,
        responses = responses
      )
    )
  }
  path_id <- function(name = 'id', ...) {
    c(
      list(name = name, `in` = 'path', required = TRUE, schema = string),
      list(...)
    )
  }
  schema <- file.path(workspace, 'schema.json')
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Proposals', version = '1'),
      paths = list(
        '/items/{id}' = get('get_item', list(path_id(example = 'i-1'))),
        '/things/{id}' = get('get_thing', list(path_id())),
        '/other' = get('get_other', responses = json(ref('Other'))),
        '/hooked/{id}' = get('get_hooked', list(path_id(example = 'h-1'))),
        '/paged' = get(
          'get_paged',
          list(list(
            name = 'page',
            `in` = 'query',
            schema = list(type = 'integer')
          )),
          json(list(type = 'array', items = ref('Item')))
        ),
        '/covered/{id}' = get(
          'get_covered',
          list(path_id()),
          json(ref('Other'))
        ),
        '/codes/{code}' = get(
          'get_code',
          list(list(
            name = 'code',
            `in` = 'path',
            required = TRUE,
            schema = list(type = 'string', maxLength = 3L)
          )),
          json(list(type = 'object', properties = list(code = string)))
        ),
        '/text' = get(
          'get_text',
          responses = list(
            '200' = list(
              description = 'OK',
              content = list('text/plain' = list(schema = string))
            )
          )
        ),
        '/items' = list(
          post = list(
            operationId = 'create_item',
            requestBody = list(
              required = TRUE,
              content = list('application/json' = list(schema = ref('Item')))
            ),
            responses = json(ref('Item'))
          )
        )
      ),
      components = list(
        schemas = list(
          Item = list(
            type = 'object',
            required = list('id'),
            example = list(id = 'same'),
            properties = list(
              id = string,
              count = list(type = 'integer', nullable = TRUE)
            )
          ),
          # Examples repeat id strings ajv would otherwise read as schema ids.
          Other = list(
            type = 'object',
            example = list(id = 'same'),
            `x-note` = list(id = 'same'),
            properties = list(total = list(type = 'integer'))
          )
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  root <- file.path(workspace, 'client')
  specmill::initialize_client(
    root,
    schema,
    package = 'proposalsclient',
    title = 'Proposals Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'http://127.0.0.1:1',
    companions = 'pagination'
  )
  service_path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
  service$hooks <- list(get_hooked = list(post_response = list('keep')))
  # Inherited examples apply to every operation; only get_code can use them,
  # and this one breaks its maxLength.
  service$defaults <- list(docs = list(examples = list(list(code = 'TOOLONG'))))
  service$operations <- list(
    'GET /paged' = list(
      pagination = list(mode = 'page', parameter = 'page', start = 1L)
    )
  )
  service$testing <- list(file = 'tests/testthat/fixtures/testing.yml')
  yaml::write_yaml(service, service_path)
  dir.create(file.path(root, 'tests/testthat/fixtures'), recursive = TRUE)
  testing <- file.path(root, 'tests/testthat/fixtures/testing.yml')
  writeLines(
    c(
      'scenarios:',
      "  covered: {operation: 'GET /covered/{id}', inputs: {id: c-1}}"
    ),
    testing
  )
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  before <- hashes()
  proposal <- specmill::propose_testing(root)
  stopifnot(identical(before, hashes()))
  proposed <- proposal$services$proposalsclient
  routes <- lapply(proposed$scenarios, `[[`, 'represents')
  stopifnot(
    # Shared response schema and no hooks: one scenario represents both routes.
    identical(
      proposed$scenarios$get_item$represents,
      c('GET /items/{id}', 'GET /things/{id}')
    ),
    is.null(proposed$scenarios$get_item$example),
    # Hooks, paging and a different schema each form their own group.
    identical(proposed$scenarios$get_hooked$represents, 'GET /hooked/{id}'),
    identical(proposed$scenarios$get_paged$represents, 'GET /paged'),
    identical(proposed$scenarios$get_other$represents, 'GET /other'),
    identical(proposed$scenarios$get_text$represents, 'GET /text'),
    # Covered routes are skipped; writes are listed, never proposed.
    !'GET /covered/{id}' %in% unlist(routes),
    identical(proposed$writes, 'POST /items'),
    # The stub follows the inherited examples and the scenario points at it.
    identical(proposed$scenarios$get_code$example, 2L),
    identical(
      proposed$operations[['GET /codes/{code}']]$docs$examples,
      list(list(code = 'TOOLONG'), list(code = NULL))
    )
  )
  parsed <- yaml::yaml.load(proposal$yaml)
  stopifnot(
    startsWith(proposal$yaml, '# Proposed by specmill; unreviewed.'),
    identical(
      parsed$proposalsclient$scenarios$get_paged$operation,
      'GET /paged'
    )
  )

  # A stub pasted before it is filled keeps the scenario blocked.
  pasted <- service
  pasted$operations[['GET /codes/{code}']] <- proposed$operations[[
    'GET /codes/{code}'
  ]]
  yaml::write_yaml(pasted, service_path)
  writeLines(
    c('scenarios:', "  get_code: {operation: 'GET /codes/{code}', example: 2}"),
    testing
  )
  blocked <- specmill::inspect_client(
    root
  )$testing$proposalsclient$scenarios$get_code
  stopifnot(identical(
    blocked$blocked,
    'docs example leaves required inputs empty: code'
  ))

  # The proposal YAML loads as reviewed declarations once copied in.
  proposed_yaml <- yaml::yaml.load(
    proposal$yaml,
    handlers = list(seq = function(x) as.list(x))
  )$proposalsclient
  stopifnot(grepl(
    'represents:\n      - GET /paged',
    proposal$yaml,
    fixed = TRUE
  ))
  yaml::write_yaml(
    list(
      scenarios = proposed_yaml$scenarios[c(
        'get_item',
        'get_paged',
        'get_other'
      )]
    ),
    testing
  )
  yaml::write_yaml(service, service_path)
  loaded <- specmill::inspect_client(root)$testing$proposalsclient$scenarios
  stopifnot(
    identical(loaded$get_paged$represents, 'GET /paged'),
    identical(loaded$get_item$inputs, 'schema')
  )

  # The review file is optional, new and outside project sources.
  for (bad in c(
    'tests/proposal.yml',
    'apis/proposal.yml',
    'specmill.yml',
    'TESTS\\proposal.yml'
  )) {
    stopifnot(inherits(
      tryCatch(specmill::propose_testing(root, file = bad), error = identity),
      'error'
    ))
  }
  specmill::propose_testing(root, file = 'review/proposal.yml')
  stopifnot(file.exists(file.path(root, 'review/proposal.yml')))
  stopifnot(inherits(
    tryCatch(
      specmill::propose_testing(root, file = 'review/proposal.yml'),
      error = identity
    ),
    'error'
  ))

  # Review real vcr recordings from a localhost API.
  yaml::write_yaml(service, service_path)
  writeLines(
    c(
      'scenarios:',
      "  item: {operation: 'GET /items/{id}', inputs: {id: i-1}}",
      '  other: {operation: GET /other, inputs: {}}',
      '  text: {operation: GET /text, inputs: {}}',
      "  covered: {operation: 'GET /covered/{id}', inputs: {id: c-1}}"
    ),
    testing
  )
  port_file <- tempfile('port-')
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(request) {
          body <- switch(
            request$PATH_INFO,
            '/items/i-1' = '{"id":"i-1","count":null}',
            '/other' = '{"total":"many"}',
            '/text' = 'plain words',
            '{}'
          )
          type <- if (identical(request$PATH_INFO, '/text')) {
            'text/plain'
          } else {
            'application/json'
          }
          list(
            status = 200L,
            headers = list('Content-Type' = type),
            body = body
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
    Sys.sleep(0.05)
  }
  base <- paste0('http://127.0.0.1:', readLines(port_file))
  dir <- file.path(root, 'tests/testthat/_vcr/proposalsclient')
  dir.create(dir, recursive = TRUE)
  record <- function(name, path) {
    local({
      vcr::local_vcr_configure(dir = dir)
      vcr::local_cassette(name, record = 'once', warn_on_empty = FALSE)
      httr2::req_perform(httr2::request(paste0(base, path)))
    })
    invisible()
  }
  record('item', '/items/i-1')
  record('other', '/other')
  record('text', '/text')
  # Placeholders from testing filters are reported with the review.
  covered <- file.path(dir, 'covered.yml')
  file.copy(file.path(dir, 'other.yml'), covered)
  writeLines(
    sub(
      'many',
      '<<SECRET_VALUE>> at 50% done',
      readLines(covered),
      fixed = TRUE
    ),
    covered
  )
  before <- hashes()
  review <- specmill::review_recordings(root)$proposalsclient
  stopifnot(
    identical(before, hashes()),
    # An OAS 3.0 nullable field and a component reference validate.
    identical(review$item$status, 'agrees'),
    identical(review$other$status, 'disagrees'),
    any(grepl('/total', review$other$errors, fixed = TRUE)),
    !any(grepl('many', review$other$errors, fixed = TRUE)),
    identical(review$text$status, 'unchecked'),
    identical(review$text$reason, 'no JSON response schema'),
    identical(review$covered$placeholders, '<<SECRET_VALUE>>')
  )

  # Swagger 2 definitions and OpenAPI 3.1 validate through their own dialects.
  interaction <- function(path, body) {
    list(
      request = list(
        method = 'get',
        uri = paste0('http://example.org/api', path)
      ),
      response = list(status = 200L, body = list(string = body))
    )
  }
  documents <- function(source) {
    specmill:::read_schema_document(source, resolve_references = FALSE)
  }
  swagger <- file.path(workspace, 'swagger.json')
  jsonlite::write_json(
    list(
      swagger = '2.0',
      info = list(title = 'S', version = '1'),
      paths = list(
        '/pets' = list(
          get = list(
            operationId = 'list_pets',
            produces = list('application/json'),
            responses = list(
              '200' = list(
                description = 'OK',
                schema = list(
                  type = 'array',
                  items = list(`$ref` = '#/definitions/Pet')
                )
              )
            )
          )
        )
      ),
      definitions = list(
        Pet = list(
          type = 'object',
          required = list('name'),
          properties = list(name = string)
        )
      )
    ),
    swagger,
    auto_unbox = TRUE
  )
  pets <- specmill::read_operations(swagger)$operations$list_pets
  check <- function(op, body, path = '/pets') {
    specmill:::review_interaction(interaction(path, body), op, documents)$status
  }
  stopifnot(
    identical(check(pets, '[{"name":"a"}]'), 'agrees'),
    identical(check(pets, '[{"other":1}]'), 'disagrees'),
    # Interactions for other routes are not judged by this schema.
    is.null(specmill:::review_interaction(
      interaction('/token', '{}'),
      pets,
      documents
    ))
  )
  oas31 <- file.path(workspace, 'oas31.json')
  jsonlite::write_json(
    list(
      openapi = '3.1.0',
      info = list(title = 'T', version = '1'),
      paths = list(
        '/pets' = list(
          get = list(
            operationId = 'list_pets',
            responses = json(list(type = list('array', 'null'), items = string))
          )
        )
      )
    ),
    oas31,
    auto_unbox = TRUE
  )
  pets31 <- specmill::read_operations(oas31)$operations$list_pets
  stopifnot(
    identical(check(pets31, 'null'), 'agrees'),
    identical(check(pets31, '[1]'), 'disagrees')
  )
}

if (sys.nframe() == 0L) {
  testing_proposals_acceptance()
}
