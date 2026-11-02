# Regression for issue 260: reviewed hook cases and wrapper integrations run
# real client hooks, including skips, rejections, paging and batching.

hook_cases_acceptance <- function() {
  if (!requireNamespace('callr', quietly = TRUE)) {
    message('Skipping hook case test: callr is not installed')
    return(invisible())
  }
  workspace <- tempfile('hook-cases-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  schema <- file.path(workspace, 'schema.json')
  string <- list(type = 'string')
  path_param <- function(name) {
    list(name = name, `in` = 'path', required = TRUE, schema = string)
  }
  op <- function(id, parameters = list()) {
    list(
      operationId = id,
      parameters = parameters,
      responses = list('200' = list(description = 'OK'))
    )
  }
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Hooks', version = '1'),
      servers = list(list(url = 'http://127.0.0.1:1')),
      paths = list(
        '/items/{item_id}' = list(
          get = op('get_item', list(path_param('item_id')))
        ),
        '/things/{thing_id}' = list(
          get = op('get_thing', list(path_param('thing_id')))
        ),
        '/items' = list(
          get = op(
            'list_items',
            list(list(
              name = 'page',
              `in` = 'query',
              schema = list(type = 'integer')
            ))
          )
        ),
        '/batch/{id}' = list(get = op('get_batch', list(path_param('id')))),
        '/combined/{id}' = list(
          get = op('get_combined', list(path_param('id')))
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
    package = 'hookcases',
    title = 'Hook Cases',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    companions = 'pagination'
  )
  description <- read.dcf(file.path(root, 'DESCRIPTION'))
  description[1L, 'Imports'] <- paste(
    description[1L, 'Imports'],
    'yaml',
    sep = ', '
  )
  write.dcf(description, file.path(root, 'DESCRIPTION'))
  specmill::configure_hooks(root, mode = 'apply')
  writeLines(
    c(
      'normalize_item_id <- function(state) {',
      '  id <- trimws(state$params$item_id)',
      '  if (!nzchar(id)) stop("Supply an item ID")',
      '  state$params$item_id <- id',
      '  if (identical(id, "local")) {',
      '    state$skip_request <- TRUE',
      '    state$result <- list(data = list(id = "local"))',
      '  }',
      '  state',
      '}',
      'tag_request <- function(state) {',
      '  state$params$item_id <- toupper(state$params$item_id)',
      '  state',
      '}',
      'extract_item <- function(state) {',
      '  if (!is.null(state$result$data)) state$result$data else state$result',
      '}',
      'skip_thing <- function(state) {',
      '  state$skip_request <- TRUE',
      '  state$result <- list(id = "cached")',
      '  state',
      '}',
      'keep_rows <- function(state) state$result',
      'count_rows <- function(state) {',
      '  list(rows = state$result, count = length(state$result))',
      '}'
    ),
    file.path(root, 'R/hooks_cases.R')
  )
  # The executor reads this registry at runtime, so chains are declared here.
  writeLines(
    c(
      'get_item:',
      '  pre_request: [normalize_item_id, tag_request]',
      '  post_response: [extract_item]',
      'get_thing:',
      '  pre_request: [skip_thing]',
      '  post_response: [extract_item]',
      'list_items:',
      '  post_response: [keep_rows]',
      '  post_combine: [count_rows]',
      'get_batch:',
      '  post_response: [keep_rows]',
      '  post_combine: [count_rows]',
      'get_combined:',
      '  post_response: [keep_rows]',
      '  post_combine: [count_rows]'
    ),
    file.path(root, 'inst/hooks.yml')
  )
  writeLines(
    c(
      'id: hookcases',
      'schemas: {files: [schema/openapi.json]}',
      'helper: api_request',
      'hook_callback: run_hook',
      'hook_config: inst/hooks.yml',
      'operations:',
      '  GET /items/{item_id}: {post_on_skip: true}',
      '  GET /items:',
      '    pagination: {mode: page, parameter: page, start: 1, max_pages: 5, metadata: false}',
      '  GET /batch/{id}: {batch: {fan_out: id, metadata: false}}',
      '  GET /combined/{id}:',
      '    batch: {fan_out: id, metadata: false}',
      '    post_response_scope: combined',
      'testing: {file: tests/testthat/fixtures/testing.yml}'
    ),
    file.path(root, 'apis/default.yml')
  )
  fixtures <- file.path(root, 'tests/testthat/fixtures')
  dir.create(fixtures, recursive = TRUE)
  call <- function(path, path_params, query, response) {
    c(
      '    - helper: api_request',
      '      arguments:',
      '        method: GET',
      paste0('        path: ', path),
      paste0('        path_params: ', path_params),
      paste0('        query: ', query),
      '        body: null',
      '        request_controls: {timeout: 30, max_retries: 0, retry_writes: false}',
      "        server: {url: 'http://127.0.0.1:1'}",
      paste0('      response: ', response)
    )
  }
  declarations <- function(extra_case = character(), page_rows = 2L) {
    c(
      'hook_cases:',
      '  trims_item_id:',
      '    hook: normalize_item_id',
      '    stage: pre_request',
      "    state: {params: {item_id: ' abc '}}",
      '    expect: {state: {params: {item_id: abc}}}',
      '  blank_item_fails:',
      '    hook: normalize_item_id',
      '    stage: pre_request',
      "    state: {params: {item_id: '  '}}",
      '    expect: {error: simpleError}',
      '  item_chain_order:',
      '    chain: get_item',
      '    stage: pre_request',
      "    state: {params: {item_id: ' abc '}}",
      '    expect: {state: {params: {item_id: ABC}}}',
      '  item_chain_rejects_blank:',
      '    chain: get_item',
      '    stage: pre_request',
      "    state: {params: {item_id: ''}}",
      '    expect: {error: client_hook_error, hook: normalize_item_id}',
      '  rows_are_counted:',
      '    hook: count_rows',
      '    stage: post_combine',
      '    state: {result: [a, b]}',
      '    expect: {state: {rows: [a, b], count: 2}}',
      extra_case,
      'hook_integrations:',
      '  item_reaches_helper:',
      '    operation: GET /items/{item_id}',
      "    inputs: {item_id: ' abc '}",
      '    calls:',
      call('/items/{item_id}', '{item_id: ABC}', '[]', '{data: {id: ABC}}'),
      '    result: {id: ABC}',
      '    sequence: [normalize_item_id, tag_request, api_request, extract_item]',
      '  local_item_skips_with_post:',
      '    operation: get_item',
      '    inputs: {item_id: local}',
      '    calls: []',
      '    result: {id: local}',
      '    sequence: [normalize_item_id, tag_request, extract_item]',
      '  thing_skips_by_default:',
      '    operation: get_thing',
      '    inputs: {thing_id: x}',
      '    calls: []',
      '    result: {id: cached}',
      '    sequence: [skip_thing]',
      '  blank_item_rejected:',
      '    operation: get_item',
      "    inputs: {item_id: '  '}",
      '    calls: []',
      '    error: {class: client_hook_error, hook: normalize_item_id, stage: pre_request}',
      '    sequence: [normalize_item_id]',
      '  pages_run_hooks_per_page:',
      '    operation: list_items',
      '    inputs: {}',
      '    calls:',
      call('/items', '[]', '{page: 1}', '[{id: a}]'),
      call('/items', '[]', '{page: 2}', '[{id: b}]'),
      call('/items', '[]', '{page: 3}', '[]'),
      paste0('    result: {rows: [{id: a}, {id: b}], count: ', page_rows, '}'),
      '    sequence: [api_request, keep_rows, api_request, keep_rows, api_request, keep_rows, count_rows]',
      '  batch_runs_hooks_per_chunk:',
      '    operation: get_batch',
      '    inputs: {id: [p, q]}',
      '    calls:',
      call('/batch/{id}', '{id: p}', '[]', '[{id: p}]'),
      call('/batch/{id}', '{id: q}', '[]', '[{id: q}]'),
      '    result: {rows: [{id: p}, {id: q}], count: 2}',
      '    sequence: [api_request, keep_rows, api_request, keep_rows, count_rows]',
      '  combined_scope_runs_post_response_last:',
      '    operation: get_combined',
      '    inputs: {id: [p, q]}',
      '    calls:',
      call('/combined/{id}', '{id: p}', '[]', '[{id: p}]'),
      call('/combined/{id}', '{id: q}', '[]', '[{id: q}]'),
      '    result: {rows: [{id: p}, {id: q}], count: 2}',
      '    sequence: [api_request, api_request, count_rows, keep_rows]'
    )
  }
  testing_file <- file.path(fixtures, 'testing.yml')
  writeLines(declarations(), testing_file)
  generate <- function(mode = 'apply') {
    specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = mode
    )
  }
  generate()
  tests_dir <- file.path(root, 'tests/testthat')
  generated <- list.files(tests_dir, '^test-hook-')
  stopifnot(
    length(generated) == 12L,
    file.exists(file.path(root, 'tests/testthat.R'))
  )

  # Generated files pass static validation as client tooling binds it.
  context <- new.env(parent = globalenv())
  specmill::bind_tools('test_validation', context)
  specmill::bind_tools('test_helpers', context)
  context$tg_config <- list(
    generated_header = '# Generated with specmill; do not edit by hand.',
    legacy_metadata_header = '# legacy generated'
  )
  for (file in generated) {
    text <- paste(readLines(file.path(tests_dir, file)), collapse = '\n')
    stopifnot(context$tg_validate_generated_text(text)$valid)
  }

  # Missing reviewed cases are reported, not invented.
  inspection <- specmill::inspect_client(root)
  stopifnot(
    identical(
      inspection$testing$hookcases$hooks_without_cases,
      c('extract_item', 'keep_rows', 'skip_thing')
    ),
    inspection$coverage$hookcases$hook_cases_missing == 3L
  )

  library <- tempfile('hook-library-')
  dir.create(library)
  install_log <- tempfile('hook-install-')
  status <- system2(
    file.path(R.home('bin'), 'R'),
    c('CMD', 'INSTALL', paste0('--library=', shQuote(library)), shQuote(root)),
    stdout = install_log,
    stderr = install_log
  )
  if (status != 0L) {
    stop(paste(readLines(install_log), collapse = '\n'))
  }
  run_tests <- function() {
    callr::r(
      function(root) {
        result <- testthat::test_local(
          root,
          filter = 'hook',
          load_package = 'installed',
          reporter = 'silent',
          stop_on_failure = FALSE
        )
        frame <- as.data.frame(result)
        list(
          failed = frame$file[frame$failed > 0L | frame$error],
          tests = nrow(frame),
          specmill_loaded = 'specmill' %in% loadedNamespaces()
        )
      },
      list(root = root),
      libpath = c(library, .libPaths())
    )
  }
  passed <- run_tests()
  if (length(passed$failed)) {
    stop('Generated hook tests failed: ', paste(passed$failed, collapse = ', '))
  }
  stopifnot(passed$tests == 12L, !passed$specmill_loaded)

  # A wrong reviewed expectation fails, so the tests are not tautological.
  writeLines(declarations(page_rows = 3L), testing_file)
  generate()
  wrong <- run_tests()
  stopifnot(identical(
    wrong$failed,
    'test-hook-integration-hookcases-pages_run_hooks_per_page.R'
  ))
  writeLines(declarations(), testing_file)
  generate()

  # Adding a case clears it from the missing list.
  writeLines(
    declarations(c(
      '  thing_skip_sets_result:',
      '    hook: skip_thing',
      '    stage: pre_request',
      '    state: {params: {thing_id: x}}',
      '    expect: {state: {params: {thing_id: x}, skip_request: true, result: {id: cached}}}'
    )),
    testing_file
  )
  generate()
  stopifnot(identical(
    specmill::inspect_client(root)$testing$hookcases$hooks_without_cases,
    c('extract_item', 'keep_rows')
  ))

  # A second generation changes nothing.
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  generate('check')
  current <- hashes()
  generate()
  stopifnot(identical(current, hashes()))

  # Reference errors.
  fails <- function(lines, expected) {
    writeLines(lines, testing_file)
    message <- tryCatch(
      {
        generate()
        'no error'
      },
      error = conditionMessage
    )
    if (!grepl(expected, message, fixed = TRUE)) {
      stop('Expected "', expected, '", got: ', message)
    }
  }
  fails(
    c(
      'hook_cases:',
      '  a: {hook: no_such_hook, stage: pre_request, state: {}, expect: {state: {}}}'
    ),
    'unknown hook function no_such_hook'
  )
  fails(
    c(
      'hook_cases:',
      '  a: {chain: get_thing, stage: post_combine, state: {}, expect: {state: {}}}'
    ),
    'get_thing has no post_combine hooks'
  )
  fails(
    c(
      'hook_cases:',
      '  a: {chain: get_item, stage: pre_request, state: {}, expect: {error: client_hook_error, hook: skip_thing}}'
    ),
    'expected hook is not in the chain: skip_thing'
  )
  fails(
    c(
      'hook_integrations:',
      '  a: {operation: get_item, inputs: {item_id: x}, calls: [{helper: run_hook, arguments: {}, response: 1}], result: 1}'
    ),
    'calls must name request helpers, not run_hook'
  )
  fails(
    c(
      'hook_integrations:',
      '  a: {operation: list_items, inputs: {}, calls: [{helper: api_request_pages, arguments: {}, response: 1}], result: 1}'
    ),
    'calls must name request helpers, not api_request_pages'
  )
  fails(
    c(
      'hook_integrations:',
      '  a: {operation: get_item, inputs: {item_id: x}, calls: [], result: 1, sequence: [nothing]}'
    ),
    'sequence names neither a configured hook nor a helper: nothing'
  )
  fails(
    c(
      'hook_integrations:',
      '  a: {operation: get_item, inputs: {item_id: x}, calls: [], result: 1, error: {class: x}}'
    ),
    'needs exactly one of result or error'
  )

  fails(
    c(
      'hook_cases:',
      '  a: {hook: count_rows, chain: get_item, stage: pre_request, state: {}, expect: {state: {}}}'
    ),
    'needs exactly one of hook or chain'
  )
  fails(
    c(
      'hook_cases:',
      '  a: {stage: pre_request, state: {}, expect: {state: {}}}'
    ),
    'needs exactly one of hook or chain'
  )
  fails(
    c(
      'hook_cases:',
      '  a: {hook: count_rows, stage: post_combine, state: {}, expect: {error: x, hook: count_rows}}'
    ),
    'expect hook applies only to chain errors'
  )
  fails(
    c(
      'hook_integrations:',
      '  a: {operation: get_item, inputs: {item_id: x}, calls: [{helper: no_such_helper, arguments: {}, response: 1}], result: 1}'
    ),
    'unknown helper no_such_helper'
  )
  hooks_file <- file.path(root, 'inst/hooks.yml')
  registry <- readLines(hooks_file)
  thing <- which(registry == 'get_thing:')
  writeLines(registry[-(thing + 0:2)], hooks_file)
  fails(
    c(
      'hook_integrations:',
      '  a: {operation: get_thing, inputs: {thing_id: x}, calls: [], result: 1}'
    ),
    'get_thing has no configured hooks'
  )
  last <- max(which(registry == '  post_combine: [count_rows]'))
  writeLines(
    replace(registry, last, '  post_combine: [missing_hook]'),
    hooks_file
  )
  fails(
    c(
      'hook_integrations:',
      '  a: {operation: get_combined, inputs: {id: x}, calls: [], result: 1}'
    ),
    'missing_hook'
  )
  writeLines(registry, hooks_file)
  # An integration that sets environment needs withr, which is reported.
  fails(
    c(
      'hook_integrations:',
      '  a: {operation: get_thing, inputs: {thing_id: x}, calls: [], result: {id: cached}, environment: {HOOKCASES_MODE: test}}'
    ),
    'Declared tests need these packages in the client DESCRIPTION (Suggests is enough for test-only packages): withr'
  )

  # Sequences become vectors in inputs and helper arguments, never in bodies.
  converted <- specmill:::testing_arguments(
    list(
      ids = list('a', 'b'),
      body = list(tags = list('a')),
      mixed = list(1L, 'a')
    ),
    'body'
  )
  stopifnot(
    identical(converted$ids, c('a', 'b')),
    identical(converted$body, list(tags = list('a'))),
    identical(converted$mixed, list(1L, 'a')),
    identical(
      specmill:::testing_arguments(list(n = list(1L, 2.5)), 'body')$n,
      c(1, 2.5)
    )
  )

  # Removing the declarations removes the owned hook tests.
  writeLines('hook_cases: {}', testing_file)
  generate()
  stopifnot(!length(list.files(tests_dir, '^test-hook-')))
}

if (sys.nframe() == 0L) {
  hook_cases_acceptance()
}
