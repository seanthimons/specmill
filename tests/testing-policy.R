# Regression for issue 257: reviewed test declarations for cassette scenarios,
# contract gaps, unrecorded routes and hook cases.

testing_policy_acceptance <- function() {
  root <- tempfile('testing-policy-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  fixture <- system.file('catalogue', package = 'specmill', mustWork = TRUE)
  stopifnot(all(file.copy(
    list.files(fixture, full.names = TRUE),
    root,
    recursive = TRUE
  )))
  # Add an operation the parser cannot support (a negated body schema).
  schema <- jsonlite::read_json(file.path(root, 'schema.json'))
  schema$paths[['/odd']] <- list(
    post = list(
      operationId = 'odd',
      requestBody = list(
        required = TRUE,
        content = list(
          'application/json' = list(
            schema = list(
              oneOf = list(list(
                type = 'string',
                not = list(enum = list('blocked'))
              ))
            )
          )
        )
      ),
      responses = list('200' = list(description = 'ok'))
    )
  )
  jsonlite::write_json(
    schema,
    file.path(root, 'schema.json'),
    auto_unbox = TRUE
  )
  # A Swagger 2 API that shares the catalogue's GET /items/{item_id} route.
  jsonlite::write_json(
    list(
      swagger = '2.0',
      info = list(title = 'Mirror', version = '1'),
      host = 'mirror.example.org',
      basePath = '/',
      paths = list(
        '/items/{item_id}' = list(
          get = list(
            operationId = 'mirror_item',
            parameters = list(list(
              name = 'item_id',
              'in' = 'path',
              required = TRUE,
              type = 'string'
            )),
            responses = list('200' = list(description = 'Item'))
          )
        )
      )
    ),
    file.path(root, 'mirror.json'),
    auto_unbox = TRUE
  )
  writeLines(
    c(
      'normalize_item_id <- function(state) {',
      '  state$params$item_id <- trimws(state$params$item_id)',
      '  state',
      '}'
    ),
    file.path(root, 'R/hooks_items.R')
  )
  dir.create(file.path(root, 'tests/testthat/fixtures'), recursive = TRUE)
  dir.create(file.path(root, 'tests/testthat/_vcr/catalogue'), recursive = TRUE)
  writeLines(
    '[]',
    file.path(root, 'tests/testthat/_vcr/catalogue/get_item_basic.yml')
  )
  writeLines('[]', file.path(root, 'tests/testthat/_vcr/catalogue/retired.yml'))
  writeLines(
    c('config_version: 1', 'services: [catalogue.yml, mirror.yml]'),
    file.path(root, 'specmill.yml')
  )
  service <- function(testing = NULL, extra = character()) {
    writeLines(
      c(
        'id: catalogue',
        'schemas: {files: [schema.json]}',
        'helper: catalogue_request',
        'operations:',
        '  GET /items:',
        '    docs: {examples: [{page: 2}]}',
        extra,
        testing
      ),
      file.path(root, 'catalogue.yml')
    )
  }
  mirror <- function(testing = NULL) {
    writeLines(
      c(
        'id: mirror',
        'schemas: {files: [mirror.json]}',
        'helper: catalogue_request',
        "names: {'GET /items/{item_id}': mirror_item}",
        testing
      ),
      file.path(root, 'mirror.yml')
    )
  }
  data <- function(lines, file = 'testing.yml') {
    writeLines(lines, file.path(root, 'tests/testthat/fixtures', file))
  }
  valid_policy <- c(
    'testing:',
    '  file: tests/testthat/fixtures/testing.yml',
    '  gaps:',
    "    POST /items: {reason: 'Write endpoint; expectations pending', issue: '#300'}",
    '    POST /odd: {reason: Unsupported body schema}',
    '  unrecorded:',
    '    POST /refresh: {reason: Side effects on the live service}'
  )
  valid_data <- c(
    'scenarios:',
    '  get_item_basic:',
    "    operation: GET /items/{item_id}",
    "    represents: ['GET /items/{item_id}']",
    '    inputs: {item_id: item-1}',
    '    checks:',
    '      class: list',
    '      values: [{path: [id], equals: item-1}]',
    '  list_items_page:',
    '    operation: list_items',
    '    example: 1',
    'hook_cases:',
    '  trims_item_id:',
    '    hook: normalize_item_id',
    '    stage: pre_request',
    "    state: {params: {item_id: ' abc '}}",
    '    expect: {state: {params: {item_id: abc}}}'
  )
  inspect <- function() specmill::inspect_client(root)
  fails <- function(expected) {
    message <- tryCatch(
      {
        inspect()
        'no error'
      },
      error = conditionMessage
    )
    if (!grepl(expected, message, fixed = TRUE)) {
      stop('Expected error containing "', expected, '", got: ', message)
    }
  }

  # Without testing declarations, inspection output is unchanged.
  service()
  mirror()
  plain <- inspect()
  stopifnot(
    !length(plain$testing),
    identical(
      names(plain$coverage$catalogue),
      c('total', 'implemented', 'contracts')
    ),
    is.null(plain$operations[['catalogue GET /items']]$scenarios)
  )

  # A valid declaration set.
  service(valid_policy)
  mirror(c('testing:', '  file: tests/testthat/fixtures/mirror.yml'))
  data(valid_data)
  data(
    c(
      'scenarios:',
      '  get_item_basic:',
      '    operation: mirror_item',
      '    inputs: {item_id: m-1}'
    ),
    'mirror.yml'
  )
  result <- inspect()
  declared <- result$testing$catalogue
  stopifnot(
    identical(
      declared$routes[c(
        'GET /items/{item_id}',
        'GET /items',
        'POST /items',
        'POST /refresh',
        'POST /odd'
      )],
      c(
        'GET /items/{item_id}' = 'scenario',
        'GET /items' = 'scenario',
        'POST /items' = 'not_covered',
        'POST /refresh' = 'unrecorded',
        'POST /odd' = 'not_covered'
      )
    ),
    identical(declared$scenarios$get_item_basic$inputs, 'scenario'),
    identical(declared$scenarios$get_item_basic$expectation, 'checks'),
    identical(declared$scenarios$get_item_basic$match, c('method', 'uri')),
    isTRUE(declared$scenarios$get_item_basic$cassette_exists),
    identical(declared$scenarios$list_items_page$inputs, 'docs_example'),
    identical(declared$scenarios$list_items_page$expectation, 'signature'),
    !isTRUE(declared$scenarios$list_items_page$cassette_exists),
    identical(declared$unreferenced_cassettes, 'retired'),
    identical(declared$hook_cases, 'trims_item_id'),
    identical(declared$gaps[['POST /items']]$issue, '#300'),
    # Gaps never count as contracts; unsupported routes stay in the total.
    result$coverage$catalogue$total == 5L,
    result$coverage$catalogue$contracts == 0L,
    result$coverage$catalogue$gaps == 2L,
    result$coverage$catalogue$scenarios == 2L,
    result$coverage$catalogue$represented == 2L,
    result$coverage$catalogue$unrecorded == 1L,
    identical(
      result$operations[['catalogue POST /items']]$gap$reason,
      'Write endpoint; expectations pending'
    ),
    identical(
      result$operations[['catalogue GET /items']]$scenarios,
      'list_items_page'
    ),
    # Overlapping routes keep separate service identities and cassettes.
    identical(
      result$testing$mirror$scenarios$get_item_basic$cassette,
      'tests/testthat/_vcr/mirror/get_item_basic.yml'
    ),
    identical(
      result$testing$mirror$routes,
      c('GET /items/{item_id}' = 'scenario')
    )
  )

  # A scenario may represent another selected route with the same behavior.
  data(c(
    'scenarios:',
    '  get_item_basic:',
    "    operation: GET /items/{item_id}",
    "    represents: ['GET /items/{item_id}', 'GET /items']",
    '    inputs: {item_id: item-1}'
  ))
  stopifnot(identical(
    inspect()$testing$catalogue$routes[['GET /items']],
    'represented'
  ))

  # Structure errors.
  service(c(
    'testing:',
    '  file: tests/testthat/fixtures/testing.yml',
    '  owner: me'
  ))
  fails('catalogue testing: unknown field owner')
  service(c('testing:', '  match: [method, header]'))
  fails('catalogue testing match must list distinct matchers')
  service(c('testing:', '  gaps: {/items: {reason: x}}'))
  fails('must be keyed by METHOD /path')
  service(c('testing:', '  gaps: {POST /items: {issue: "#1"}}'))
  fails('reason must be a nonempty string')
  service(c('testing:', '  file: fixtures/testing.yml'))
  fails('file must be a YAML or JSON file inside tests/testthat/')
  service(c('testing:', '  file: tests/testthat/fixtures/missing.yml'))
  fails('file does not exist')
  service(
    c('testing:', '  file: tests/testthat/fixtures/testing.yml'),
    'contracts_file: tests/testthat/fixtures/testing.yml'
  )
  fails('testing file must differ from contracts_file')
  service(c('testing:', '  file: tests/testthat/fixtures/testing.yml'))
  mirror(c('testing:', '  file: tests/testthat/fixtures/testing.yml'))
  data(c('scenarios: {}'))
  fails('Services must not share a testing file')
  mirror()
  for (case in list(
    list(
      c('scenarios:', '  Bad-ID: {operation: get_item}'),
      'scenario: invalid ID Bad-ID'
    ),
    list(
      c(
        'scenarios:',
        '  a: {operation: get_item}',
        '  a: {operation: get_item}'
      ),
      'Duplicate map key'
    ),
    list(
      c(
        'scenarios:',
        '  a: {operation: get_item, result: 1, checks: {rows: 1}}'
      ),
      'declare result or checks, not both'
    ),
    list(
      c('scenarios:', '  a: {operation: get_item, inputs: {}, example: 1}'),
      'declare inputs or example, not both'
    ),
    list(
      c('scenarios:', '  a: {operation: get_item, checks: {}}'),
      'must declare at least one check'
    ),
    list(
      c(
        'scenarios:',
        '  a: {operation: get_item, checks: {values: [{path: [], equals: 1}]}}'
      ),
      'value path must be a sequence'
    ),
    list(
      c('scenarios:', '  a: {operation: get_item, example: 0}'),
      'example must be a positive whole number'
    ),
    list(
      c('scenarios:', '  a: {operation: get_item, cassette: other}'),
      'unknown field cassette'
    ),
    list(
      c(
        'hook_cases:',
        '  a: {hook: normalize_item_id, stage: later, state: {}, expect: {state: {}}}'
      ),
      'stage must be one of'
    ),
    list(
      c(
        'hook_cases:',
        '  a: {hook: normalize_item_id, stage: pre_request, state: {}, expect: {}}'
      ),
      'expect needs exactly one of state or error'
    ),
    list(c('fixtures: {}'), 'unknown field fixtures')
  )) {
    data(case[[1L]])
    fails(case[[2L]])
  }

  # Reference errors: missing, renamed and stale declarations.
  for (case in list(
    list(
      c('scenarios:', '  a: {operation: fetch_item}'),
      'unknown operation fetch_item; if the wrapper was renamed, use its METHOD /path route key'
    ),
    list(
      c('scenarios:', '  a: {operation: DELETE /items}'),
      'route is not selected: DELETE /items'
    ),
    list(
      c('scenarios:', '  a: {operation: POST /odd, inputs: {}}'),
      'operation is not supported: POST /odd'
    ),
    list(
      c('scenarios:', "  a: {operation: get_item, represents: ['GET /items']}"),
      'represents must include its own route GET /items/{item_id}'
    ),
    list(
      c(
        'scenarios:',
        "  a: {operation: get_item, represents: ['GET /items/{item_id}', 'GET /gone']}"
      ),
      'represents names a route that is not selected: GET /gone'
    ),
    list(
      c(
        'scenarios:',
        "  a: {operation: get_item, represents: ['GET /items/{item_id}', 'POST /odd']}"
      ),
      'represents unsupported routes: POST /odd'
    ),
    list(
      c('scenarios:', '  a: {operation: get_item, inputs: {itemid: x}}'),
      'inputs name unknown arguments: itemid'
    ),
    list(
      c('scenarios:', '  a: {operation: get_item, example: 1}'),
      'docs example 1 does not exist'
    ),
    list(
      c(
        'scenarios:',
        '  a: {operation: create_item, inputs: {body: {title: x}}}'
      ),
      'must match body or body_json'
    ),
    list(
      c(
        'hook_cases:',
        '  a: {hook: missing_hook, stage: pre_request, state: {}, expect: {error: client_hook_error}}'
      ),
      'unknown hook function missing_hook'
    )
  )) {
    data(case[[1L]])
    fails(case[[2L]])
  }
  # A body matcher satisfies the body rule.
  data(c(
    'scenarios:',
    '  a: {operation: create_item, inputs: {body: {title: x}}, match: [method, uri, body_json]}'
  ))
  stopifnot(identical(
    inspect()$testing$catalogue$routes[['POST /items']],
    'scenario'
  ))

  data(c('scenarios: {}'))
  service(c(
    'testing:',
    '  file: tests/testthat/fixtures/testing.yml',
    '  gaps: {DELETE /items: {reason: x}}'
  ))
  fails('gaps names a route that is not selected: DELETE /items')
  service(c('testing:', '  unrecorded: {GET /gone: {reason: x}}'))
  fails('unrecorded names a route that is not selected: GET /gone')
  service(
    c('testing:', "  gaps: {'GET /items/{item_id}': {reason: x}}"),
    c(
      'contracts:',
      '  get_item: {inputs: {item_id: x}, request: {}, result: {}}'
    )
  )
  fails('gap declared for a route with a fixed contract: GET /items/{item_id}')
  data(c('scenarios:', '  a: {operation: get_item, inputs: {item_id: x}}'))
  service(c(
    'testing:',
    '  file: tests/testthat/fixtures/testing.yml',
    "  unrecorded: {'GET /items/{item_id}': {reason: x}}"
  ))
  fails('unrecorded route is covered by a scenario: GET /items/{item_id}')

  # More structure checks.
  service(c('testing:', '  file: tests/testthat/fixtures/testing.yml'))
  for (case in list(
    list(
      c('scenarios:', '  a: {operation: get_item, checks: {rows: -1}}'),
      'rows must be a nonnegative whole number'
    ),
    list(
      c('scenarios:', '  a: {operation: get_item, environment: {KEY: 1}}'),
      'environment value must be a nonempty string'
    ),
    list(
      c(
        'hook_cases:',
        "  a: {hook: 'bad name', stage: pre_request, state: {}, expect: {error: x}}"
      ),
      'invalid hook function name'
    )
  )) {
    data(case[[1L]])
    fails(case[[2L]])
  }
  # An explicit null result is an exact expectation, not a signature.
  data(c(
    'scenarios:',
    '  a: {operation: get_item, inputs: {item_id: x}, result: null}'
  ))
  stopifnot(identical(
    inspect()$testing$catalogue$scenarios$a$expectation,
    'result'
  ))

  # Paged wrappers accept their paging controls as inputs.
  writeLines(
    c(
      'id: catalogue',
      'schemas: {files: [schema.json]}',
      'helper: catalogue_request',
      'operations:',
      '  GET /items:',
      '    pagination: {mode: page, parameter: page, start: 1, max_pages: 3}',
      '  POST /items:',
      '    inputs: {payload: {type: object, required: true}}',
      '    request: {arguments: {body: {from: [params, payload]}}}',
      'testing: {file: tests/testthat/fixtures/testing.yml}'
    ),
    file.path(root, 'catalogue.yml')
  )
  data(c(
    'scenarios:',
    '  a: {operation: list_items, inputs: {page: 1, all_pages: false}}'
  ))
  stopifnot(identical(
    inspect()$testing$catalogue$routes[['GET /items']],
    'scenario'
  ))
  # Mapped operations have no parameter schemas, so inputs must be explicit.
  data(c(
    'scenarios:',
    '  a: {operation: create_item, match: [method, uri, body_json]}'
  ))
  fails('mapped or retained operations need explicit inputs')
  data(c(
    'scenarios:',
    '  a: {operation: create_item, inputs: {payload: {title: x}}}'
  ))
  stopifnot(identical(
    inspect()$testing$catalogue$scenarios$a$inputs,
    'scenario'
  ))

  # An API group declares its own testing file.
  writeLines(
    c(
      'api: shop',
      'schemas: {files: [schema.json]}',
      'helper: catalogue_request',
      'groups:',
      '  shop_items:',
      "    selection: {include: ['GET /items/{item_id}']}",
      '    testing: {file: tests/testthat/fixtures/group.yml}'
    ),
    file.path(root, 'catalogue.yml')
  )
  data(
    c('scenarios:', '  basic: {operation: get_item, inputs: {item_id: x}}'),
    'group.yml'
  )
  grouped <- inspect()$testing$shop_items
  stopifnot(
    identical(grouped$routes, c('GET /items/{item_id}' = 'scenario')),
    identical(
      grouped$scenarios$basic$cassette,
      'tests/testthat/_vcr/shop_items/basic.yml'
    )
  )

  # Recording policy: write approval and redaction filters.
  service(c(
    'testing:',
    '  file: tests/testthat/fixtures/testing.yml',
    '  filter:',
    '    response_headers: [X-Internal-Host]',
    "    patterns: {'<<EMAIL>>': '[a-z]+@corp[.]example'}"
  ))
  data(c(
    'scenarios:',
    '  a:',
    '    operation: create_item',
    '    inputs: {body: {title: x}}',
    '    match: [method, uri, body_json]',
    '    record_write: {reason: Sandbox accepts writes}'
  ))
  declared <- inspect()$testing$catalogue
  stopifnot(
    identical(declared$scenarios$a$write_approval, 'Sandbox accepts writes'),
    identical(declared$filter$response_headers, 'X-Internal-Host'),
    identical(
      declared$filter$patterns,
      c('<<EMAIL>>' = '[a-z]+@corp[.]example')
    )
  )
  data(c(
    'scenarios:',
    '  a: {operation: get_item, inputs: {item_id: x}, record_write: {reason: reviewed}}'
  ))
  fails('record_write applies only to state-changing operations')
  data(c(
    'scenarios:',
    '  a: {operation: create_item, inputs: {body: {}}, match: [method, uri, body], record_write: {}}'
  ))
  fails('record_write reason must be a nonempty string')
  data(c('scenarios: {}'))
  for (case in list(
    list("{'EMAIL': 'x'}", 'pattern placeholders look like <<NAME>>'),
    list("{'<<A>>': '('}", 'pattern does not compile'),
    list(
      "{'<<A>>': '.*'}",
      'must not match an empty string or its placeholder'
    ),
    list("{'<<A>>': '<<'}", 'must not match an empty string or its placeholder')
  )) {
    service(c(
      'testing:',
      '  file: tests/testthat/fixtures/testing.yml',
      paste0('  filter: {patterns: ', case[[1L]], '}')
    ))
    fails(case[[2L]])
  }
  service(c('testing:', '  filter: {headers: [X]}'))
  fails('unknown field headers')
}

if (sys.nframe() == 0L) {
  testing_policy_acceptance()
}
