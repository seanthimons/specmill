# Generated cassette scenario tests (#258): one replay test per declared
# scenario, a shared replay helper, and the standard test runner when absent.

replay_helper_file <- 'tests/testthat/helper-scenario-replay.R'
replay_runner_file <- 'tests/testthat.R'
replay_test_marker <- '# Cassette scenario test; replays a reviewed recording.'
replay_dependencies <- c('testthat', 'vcr', 'withr', 'yaml', 'jsonlite')

declared_test_file <- function(root, prefix, service, id) {
  portable_output_path(
    root,
    paste0('tests/testthat/test-', prefix, '-', service, '-', id, '.R')
  )
}

declared_test_owner <- function(kind, service, id) {
  paste0('specmill ', kind, ' ', service, '/', id)
}

replay_character_literal <- function(x) {
  if (!length(x)) {
    return('character()')
  }
  values <- encodeString(unname(x), quote = "'")
  if (!is.null(names(x))) {
    values <- paste0(encodeString(names(x), quote = "'"), ' = ', values)
  }
  paste0('c(', paste(values, collapse = ', '), ')')
}

replay_record_env <- function(package) {
  paste0(toupper(gsub('[^A-Za-z0-9]', '_', package)), '_RECORD')
}

# Per-service recording filters, keyed by service ID.
replay_filters_literal <- function(filters) {
  if (!length(filters)) {
    return('list()')
  }
  entries <- vapply(
    sort(names(filters)),
    function(id) {
      paste0(
        encodeString(id, quote = "'"),
        ' = list(response_headers = ',
        replay_character_literal(
          filters[[id]]$response_headers %or% character()
        ),
        ', patterns = ',
        replay_character_literal(filters[[id]]$patterns %or% character()),
        ')'
      )
    },
    character(1)
  )
  paste0('list(', paste(entries, collapse = ', '), ')')
}

replay_helper_text <- function(
  package,
  credentials,
  query_credentials,
  filters = list()
) {
  record_env <- replay_record_env(package)
  text <- file_text(system.file(
    'templates/replay.R',
    package = 'specmill',
    mustWork = TRUE
  ))
  for (field in list(
    c('REPLAY_RECORD_ENV', encodeString(record_env, quote = "'")),
    c(
      'REPLAY_CREDENTIALS',
      replay_character_literal(sort(unique(credentials)))
    ),
    c(
      'REPLAY_QUERY_CREDENTIALS',
      replay_character_literal(
        query_credentials[order(names(query_credentials) %or% character())]
      )
    ),
    c('REPLAY_FILTERS', replay_filters_literal(filters))
  )) {
    text <- sub(
      paste0('<- ', field[[1L]], '\n'),
      paste0('<- ', field[[2L]], '\n'),
      text,
      fixed = TRUE
    )
  }
  text
}

replay_runner_text <- function(package) {
  paste(
    c(
      '# Generated with specmill; do not edit by hand.',
      'library(testthat)',
      paste0('library(', package, ')'),
      '',
      paste0("test_check('", package, "')")
    ),
    collapse = '\n'
  )
}

# Scenario inputs, in order: the scenario's own inputs, then the docs example it
# names, then schema-provided values for required inputs. A synthesized or
# placeholder value, an unknown name or a failed constraint blocks the scenario
# with a reason instead of stopping generation.
scenario_resolution <- function(op, spec, scenario) {
  body <- if (!is.null(op$body)) body_argument_name(op)
  kept <- testing_kept_body(op)
  if ('inputs' %in% names(scenario)) {
    return(list(
      inputs = testing_arguments(scenario$inputs %or% list(), kept),
      source = 'scenario',
      sources = NULL,
      blocked = NULL
    ))
  }
  blocked <- function(reason) {
    list(inputs = NULL, source = 'blocked', sources = NULL, blocked = reason)
  }
  example <- if (!is.null(scenario$example)) {
    spec$docs$examples[[scenario$example]] %or% list()
  } else {
    list()
  }
  paging <- example[intersect(names(example), c('all_pages', 'max_pages'))]
  example <- testing_arguments(
    example[setdiff(names(example), names(paging))],
    kept
  )
  unknown <- setdiff(names(example), c(parameter_names(op$parameters), body))
  if (length(unknown)) {
    return(blocked(paste(
      'docs example names unknown arguments:',
      paste(unknown, collapse = ', ')
    )))
  }
  # An unfilled proposal stub leaves required inputs empty; never send NULL.
  required <- c(
    parameter_names(op$parameters)[vapply(
      op$parameters,
      function(p) isTRUE(p$public_required %or% p$required),
      logical(1)
    )],
    if (isTRUE(op$body_required)) body
  )
  empty <- intersect(
    names(example)[vapply(example, is.null, logical(1))],
    required
  )
  if (length(empty)) {
    return(blocked(paste(
      'docs example leaves required inputs empty:',
      paste(empty, collapse = ', ')
    )))
  }
  resolved <- tryCatch(
    operation_fixture_inputs(
      op,
      mode = 'minimal',
      public = example,
      public_required = TRUE,
      defer_synthesis = TRUE
    ),
    error = identity
  )
  if (inherits(resolved, 'error')) {
    return(blocked(conditionMessage(resolved)))
  }
  sources <- attr(resolved, 'input_sources')
  missing <- names(sources)[sources %in% c('synthesized', 'schema_placeholder')]
  if (length(missing)) {
    return(blocked(paste(
      'missing example for',
      paste(missing, collapse = ', ')
    )))
  }
  inputs <- c(
    stats::setNames(
      lapply(names(resolved), function(name) resolved[[name]]),
      names(resolved)
    ),
    paging
  )
  list(
    inputs = inputs,
    source = if (length(example)) {
      'docs_example'
    } else if (length(resolved)) {
      'schema'
    } else {
      'none'
    },
    sources = sources,
    blocked = NULL
  )
}

render_scenario_test <- function(
  op,
  spec,
  service,
  id,
  scenario,
  match,
  credentials,
  inputs,
  provenance = NULL
) {
  where <- paste(service, 'scenario', id)
  environment <- scenario$environment %or% list()
  if (
    length(intersect(
      names(environment),
      c(credentials, replay_record_env(spec$package))
    ))
  ) {
    stop(where, ': environment must not set credential or record variables')
  }

  args <- paste(
    vapply(
      names(inputs),
      function(name) {
        paste0(make.names(name), ' = ', r_literal(inputs[[name]]))
      },
      character(1)
    ),
    collapse = ', '
  )
  checks <- scenario$checks
  value_lines <- vapply(
    checks$values %or% list(),
    function(check) {
      path <- paste0(
        '[[',
        vapply(check$path, r_literal, character(1)),
        ']]',
        collapse = ''
      )
      paste0(
        '  testthat::expect_equal(result',
        path,
        ', ',
        r_literal(check$equals),
        ')'
      )
    },
    character(1)
  )
  quote_r <- function(x) encodeString(x, quote = "'")
  paste(
    c(
      '# Generated with specmill; do not edit by hand.',
      replay_test_marker,
      paste0(
        'testthat::test_that(',
        quote_r(paste(id, 'replays', op$key, 'through', op$name)),
        ', {'
      ),
      paste0(
        '  replay_cassette(',
        quote_r(service),
        ', ',
        quote_r(id),
        ', ',
        replay_character_literal(match),
        if (!op$method %in% c('GET', 'HEAD')) ', writes = TRUE',
        if (length(provenance)) {
          paste0(', provenance = ', replay_character_literal(provenance))
        },
        if (!is.null(scenario$record_write)) ', write_approved = TRUE',
        ')'
      ),
      test_cache_off(op, spec$package),
      if (length(environment)) {
        paste0(
          '  withr::local_envvar(',
          replay_character_literal(unlist(environment)),
          ')'
        )
      },
      paste0('  result <- ', spec$package, '::', op$name, '(', args, ')'),
      paste0(
        '  replay_expect_signature(result, ',
        quote_r(service),
        ', ',
        quote_r(id),
        ')'
      ),
      if ('result' %in% names(scenario)) {
        paste0(
          '  testthat::expect_equal(result, ',
          r_literal(scenario$result),
          ')'
        )
      },
      if (!is.null(checks$class)) {
        paste0(
          '  testthat::expect_true(inherits(result, ',
          quote_r(checks$class),
          '))'
        )
      },
      if (!is.null(checks$rows)) {
        paste0(
          '  testthat::expect_equal(NROW(result), ',
          as.integer(checks$rows),
          'L)'
        )
      },
      if (!is.null(checks$names)) {
        paste0(
          '  testthat::expect_true(all(',
          replay_character_literal(unlist(checks$names)),
          ' %in% names(result)))'
        )
      },
      value_lines,
      '})'
    ),
    collapse = '\n'
  )
}

# Client DESCRIPTION is client-owned: report missing test dependencies instead
# of editing it.
replay_check_dependencies <- function(root, needs = replay_dependencies) {
  metadata <- read.dcf(project_path(root, 'DESCRIPTION'))[1L, ]
  declared <- unlist(lapply(
    intersect(c('Depends', 'Imports', 'Suggests'), names(metadata)),
    function(field) {
      trimws(sub('\\(.*$', '', strsplit(metadata[[field]], ',')[[1L]]))
    }
  ))
  missing <- setdiff(
    c(needs, if ('vcr' %in% needs) 'httr2'),
    declared
  )
  if (length(missing)) {
    stop(
      'Declared tests need these packages in the client DESCRIPTION ',
      '(Suggests is enough for test-only packages): ',
      paste(missing, collapse = ', ')
    )
  }
  invisible(TRUE)
}

# Validate each service's declarations against the operations generation just
# configured, then render scenario tests plus the shared helper and runner.
replay_outputs <- function(
  root,
  services,
  parsed,
  entries,
  definitions,
  authentication,
  deferred_names,
  withheld,
  previous
) {
  files <- list()
  owners <- list()
  if (
    !any(vapply(services, function(x) !is.null(x$testing), logical(1))) &&
      is.null(previous[[replay_runner_file]])
  ) {
    return(list(files = files, owners = owners))
  }
  query <- character()
  filters <- list()
  documents <- provenance_documents()
  needs <- 'testthat'
  # Values recordings must never hold: declared credentials, plus arguments
  # bound to an environment variable (parameters.<name>.env), across services.
  bound <- list()
  for (service_entries in entries) {
    for (entry in service_entries) {
      for (p in entry$configured$operation$parameters) {
        if (!is.null(p$public_env)) {
          bound[[length(bound) + 1L]] <- p
        }
      }
    }
  }
  for (p in bound) {
    # Replay sends a dummy in place of the value; it must pass the schema.
    accepted <- tryCatch(
      {
        parameter_values(
          stats::setNames(list('replay-dummy'), p$name),
          stats::setNames(list(p$schema), p$name),
          body_value,
          stats::setNames(list(p$location), p$name)
        )
        TRUE
      },
      error = function(e) FALSE
    )
    if (!accepted) {
      stop(
        'The replay dummy does not satisfy the schema of ',
        p$location,
        ' ',
        p$name,
        ' bound to ',
        p$public_env,
        '; a parameter with such constraints cannot use env'
      )
    }
  }
  sensitive <- sort(
    unique(c(
      unlist(Filter(is.character, authentication), use.names = FALSE),
      vapply(bound, `[[`, character(1), 'public_env')
    )),
    method = 'radix'
  )
  for (i in seq_along(services)) {
    service <- services[[i]]
    if (is.null(service$testing)) {
      next
    }
    # Deferred operations are withheld from this run, so are their scenarios.
    inventory <- parsed[[i]]$inventory
    deferred <- vapply(
      Filter(function(x) x$id %in% withheld, inventory),
      `[[`,
      character(1),
      'key'
    )
    # A held declaration keeps its existing test, like the deferred wrapper.
    hold <- function(cases, target, kind, prefix) {
      held <- vapply(
        cases,
        function(x) (x[[target]] %or% '') %in% c(deferred, deferred_names),
        logical(1)
      )
      for (id in names(cases)[held]) {
        file <- declared_test_file(root, prefix, service$id, id)
        if (file.exists(project_path(root, file))) {
          files[[file]] <<- file_text(project_path(root, file))
          owners[[file]] <<- declared_test_owner(kind, service$id, id)
        }
      }
      cases[!held]
    }
    service$testing$scenarios <- hold(
      service$testing$scenarios,
      'operation',
      'scenario',
      'scenario'
    )
    service$testing$hook_cases <- hold(
      service$testing$hook_cases,
      'chain',
      'hook case',
      'hook-case'
    )
    service$testing$hook_integrations <- hold(
      service$testing$hook_integrations,
      'operation',
      'hook integration',
      'hook-integration'
    )
    service$testing$scenarios <- lapply(
      service$testing$scenarios,
      function(x) {
        if (!is.null(x$represents)) {
          x$represents <- setdiff(x$represents, deferred)
        }
        x
      }
    )
    service_entries <- entries[[service$id]] %or% list()
    declared <- testing_declarations(
      root,
      service,
      service_entries,
      inventory,
      definitions
    )
    clash <- intersect(
      names(declared$filter$patterns),
      paste0('<<', sensitive, '>>')
    )
    if (length(clash)) {
      stop(
        service$id,
        ' testing filter placeholders must differ from credential names: ',
        paste(clash, collapse = ', ')
      )
    }
    if (length(declared$filter)) {
      filters[[service$id]] <- declared$filter
    }
    for (id in names(declared$scenarios)) {
      entry <- service_entries[[declared$scenarios[[id]]$operation]]
      op <- entry$configured$operation
      file <- declared_test_file(root, 'scenario', service$id, id)
      if (file %in% names(files)) {
        stop('Portable test filenames collide: ', file)
      }
      if (!is.null(declared$scenarios[[id]]$blocked)) {
        # A blocked scenario keeps any reviewed test until its inputs resolve.
        # Values are substituted, never parsed: routes contain braces.
        scenario <- paste0(service$id, '/', id)
        reason <- declared$scenarios[[id]]$blocked
        cli::cli_alert_warning('Scenario {scenario} is blocked: {reason}')
        if (file.exists(project_path(root, file))) {
          files[[file]] <- file_text(project_path(root, file))
          owners[[file]] <- declared_test_owner('scenario', service$id, id)
        }
        next
      }
      files[[file]] <- render_scenario_test(
        op,
        entry$configured$spec,
        service$id,
        id,
        service$testing$scenarios[[id]],
        declared$scenarios[[id]]$match,
        sensitive,
        declared$scenarios[[id]]$input_values,
        scenario_provenance(
          service,
          service$testing$scenarios[[id]],
          declared$scenarios[[id]],
          parsed[[i]]$operations,
          definitions,
          documents
        )
      )
      owners[[file]] <- declared_test_owner('scenario', service$id, id)
      if (length(authentication)) {
        for (requirement in client_operation_authentication(
          op,
          authentication
        )) {
          for (scheme in requirement) {
            if (identical(scheme$location, 'query')) {
              query[[scheme$name]] <- scheme$envvar
            }
          }
        }
      }
    }
    callback <- service$hook_callback %or% 'run_hook'
    for (id in names(service$testing$hook_cases)) {
      file <- declared_test_file(root, 'hook-case', service$id, id)
      if (file %in% names(files)) {
        stop('Portable test filenames collide: ', file)
      }
      files[[file]] <- render_hook_case(
        service$id,
        id,
        service$testing$hook_cases[[id]],
        callback
      )
      owners[[file]] <- declared_test_owner('hook case', service$id, id)
    }
    for (id in names(declared$hook_integrations)) {
      entry <- service_entries[[declared$hook_integrations[[id]]$operation]]
      file <- declared_test_file(root, 'hook-integration', service$id, id)
      if (file %in% names(files)) {
        stop('Portable test filenames collide: ', file)
      }
      files[[file]] <- render_hook_integration(
        entry$configured$operation,
        entry$configured$spec,
        service$id,
        id,
        service$testing$hook_integrations[[id]],
        declared$hook_integrations[[id]]
      )
      owners[[file]] <- declared_test_owner('hook integration', service$id, id)
      if (length(service$testing$hook_integrations[[id]]$environment)) {
        needs <- union(needs, 'withr')
      }
    }
  }
  package <- services[[1L]]$package
  runner <- project_path(root, replay_runner_file)
  if (
    (length(files) || !is.null(previous[[replay_runner_file]])) &&
      (!file.exists(runner) ||
        owned_output(runner, previous[[replay_runner_file]]))
  ) {
    files[[replay_runner_file]] <- replay_runner_text(package)
    owners[[replay_runner_file]] <- 'specmill test runner'
  }
  tests <- names(files) %or% character()
  if (any(startsWith(tests, 'tests/testthat/test-scenario-'))) {
    needs <- union(needs, replay_dependencies)
  }
  if (any(startsWith(tests, 'tests/testthat/test-'))) {
    replay_check_dependencies(root, needs)
  }
  if (any(startsWith(tests, 'tests/testthat/test-scenario-'))) {
    files[[replay_helper_file]] <- replay_helper_text(
      package,
      sensitive,
      query,
      filters
    )
    owners[[replay_helper_file]] <- 'specmill replay'
  }
  list(files = files, owners = owners)
}
