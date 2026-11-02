# Generated cassette scenario tests (#258): one replay test per declared
# scenario, a shared replay helper, and the standard test runner when absent.

replay_helper_file <- 'tests/testthat/helper-scenario-replay.R'
replay_runner_file <- 'tests/testthat.R'
replay_test_marker <- '# Cassette scenario test; replays a reviewed recording.'
replay_dependencies <- c('testthat', 'vcr', 'withr', 'yaml')

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

replay_helper_text <- function(package, credentials, query_credentials) {
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
    )
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

# Inputs come from the scenario, from a reviewed docs example, or are empty when
# the wrapper has no required inputs. Schema examples are resolved by #272.
scenario_inputs <- function(op, spec, scenario, where) {
  if ('inputs' %in% names(scenario)) {
    return(scenario$inputs %or% list())
  }
  if (!is.null(scenario$example)) {
    return(spec$docs$examples[[scenario$example]])
  }
  required <- any(vapply(
    op$parameters,
    function(p) isTRUE(p$required),
    logical(1)
  )) ||
    (!is.null(op$body) && isTRUE(op$body_required))
  if (required) {
    stop(
      where,
      ' needs inputs: declare inputs or a docs example ',
      '(schema examples are not used yet)'
    )
  }
  list()
}

render_scenario_test <- function(
  op,
  spec,
  service,
  id,
  scenario,
  match,
  credentials
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
  inputs <- scenario_inputs(op, spec, scenario, where)
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
        ')'
      ),
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
replay_check_dependencies <- function(root) {
  metadata <- read.dcf(project_path(root, 'DESCRIPTION'))[1L, ]
  declared <- unlist(lapply(
    intersect(c('Depends', 'Imports', 'Suggests'), names(metadata)),
    function(field) {
      trimws(sub('\\(.*$', '', strsplit(metadata[[field]], ',')[[1L]]))
    }
  ))
  missing <- setdiff(c(replay_dependencies, 'httr2'), declared)
  if (length(missing)) {
    stop(
      'Cassette scenarios need these packages in the client DESCRIPTION ',
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
    held <- vapply(
      service$testing$scenarios,
      function(x) x$operation %in% c(deferred, deferred_names),
      logical(1)
    )
    # A held scenario keeps its existing test, like the deferred wrapper.
    for (id in names(service$testing$scenarios)[held]) {
      file <- portable_output_path(
        root,
        paste0('tests/testthat/test-scenario-', service$id, '-', id, '.R')
      )
      if (file.exists(project_path(root, file))) {
        files[[file]] <- file_text(project_path(root, file))
        owners[[file]] <- paste0('specmill scenario ', service$id, '/', id)
      }
    }
    service$testing$scenarios <- service$testing$scenarios[!held]
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
    for (id in names(declared$scenarios)) {
      entry <- service_entries[[declared$scenarios[[id]]$operation]]
      op <- entry$configured$operation
      file <- portable_output_path(
        root,
        paste0('tests/testthat/test-scenario-', service$id, '-', id, '.R')
      )
      if (file %in% names(files)) {
        stop('Portable test filenames collide: ', file)
      }
      files[[file]] <- render_scenario_test(
        op,
        entry$configured$spec,
        service$id,
        id,
        service$testing$scenarios[[id]],
        declared$scenarios[[id]]$match,
        unlist(authentication, use.names = FALSE)
      )
      owners[[file]] <- paste0('specmill scenario ', service$id, '/', id)
      if (length(authentication)) {
        for (requirement in operation_authentication(op, authentication)) {
          for (scheme in requirement) {
            if (identical(scheme$location, 'query')) {
              query[[scheme$name]] <- scheme$envvar
            }
          }
        }
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
  if (
    any(startsWith(
      names(files) %or% character(),
      'tests/testthat/test-scenario-'
    ))
  ) {
    replay_check_dependencies(root)
    files[[replay_helper_file]] <- replay_helper_text(
      package,
      unlist(authentication, use.names = FALSE),
      query
    )
    owners[[replay_helper_file]] <- 'specmill replay'
  }
  list(files = files, owners = owners)
}
