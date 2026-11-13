# Report of what each verification layer covers (#261): declarations,
# generated test files, recordings and, only when supplied, test results.
# Read-only; it never re-records or treats a recording as current acceptance.

# Per generated test file: passed, failed or skipped. Missing files are not run.
testing_results <- function(results) {
  if (is.null(results)) {
    return(character())
  }
  frame <- as.data.frame(results)
  if (!all(c('file', 'failed', 'error', 'skipped') %in% names(frame))) {
    stop('results need file, failed, error and skipped columns')
  }
  files <- basename(as.character(frame$file))
  vapply(
    split(seq_along(files), files),
    function(rows) {
      if (any(frame$failed[rows] > 0L) || any(as.logical(frame$error[rows]))) {
        'failed'
      } else if (all(as.logical(frame$skipped[rows]))) {
        'skipped'
      } else {
        'passed'
      }
    },
    character(1)
  )
}

report_execution <- function(file, execution) {
  status <- unname(execution[basename(file)])
  if (length(status) && !is.na(status)) status else 'not run'
}

report_service <- function(
  root,
  x,
  definitions,
  execution,
  responses,
  documents
) {
  service <- x$service
  id <- service$id
  entries <- x$entries
  by_key <- stats::setNames(entries, vapply(entries, `[[`, character(1), 'key'))
  inventory <- x$inventory
  keys <- unique(vapply(inventory, `[[`, character(1), 'key'))
  selected <- unique(vapply(
    Filter(function(r) r$status != 'excluded', inventory),
    `[[`,
    character(1),
    'key'
  ))
  declared <- if (!is.null(service$testing)) {
    testing_declarations(root, service, entries, inventory, definitions)
  }
  present <- function(path) file.exists(project_path(root, path))

  contracts <- list()
  for (entry in entries) {
    op <- entry$configured$operation
    contract <- fixed_contract(service, op)
    if (is.null(contract)) {
      next
    }
    file <- portable_output_path(
      root,
      paste0(
        'tests/testthat/test-',
        if ('calls' %in% names(contract)) 'contract-',
        op$name,
        '.R'
      )
    )
    contracts[[entry$key]] <- list(
      wrapper = op$name,
      test = file,
      test_present = present(file),
      execution = report_execution(file, execution)
    )
  }

  scenarios <- list()
  for (scenario_id in names(declared$scenarios)) {
    d <- declared$scenarios[[scenario_id]]
    test <- declared_test_file(root, 'scenario', id, scenario_id)
    provenance_file <- file.path(
      'tests/testthat/_vcr',
      id,
      paste0(scenario_id, '.provenance')
    )
    current <- if (is.null(d$blocked)) {
      scenario_provenance(
        service,
        service$testing$scenarios[[scenario_id]],
        d,
        x$operations,
        definitions,
        documents
      )
    }
    recorded <- provenance_recorded(project_path(root, provenance_file))
    embedded <- provenance_embedded(project_path(root, test))
    changed <- if (length(current) && length(recorded)) {
      names(current)[
        is.na(recorded[names(current)]) | recorded[names(current)] != current
      ]
    }
    recorded_status <- if (!d$cassette_exists) {
      'not recorded'
    } else if (!length(recorded) || !length(current)) {
      'unknown'
    } else if (length(changed)) {
      'changed'
    } else {
      'current'
    }
    response <- responses[[id]][[scenario_id]]
    scenarios[[scenario_id]] <- list(
      route = d$route,
      represents = d$represents,
      inputs = d$inputs,
      blocked = d$blocked,
      test = test,
      test_present = present(test),
      # The test embeds the digests it records; stale ones need regeneration.
      test_current = if (length(current)) {
        identical(embedded[names(current)], current)
      },
      cassette_present = d$cassette_exists,
      signature_present = present(file.path(
        'tests/testthat/_signatures',
        id,
        paste0(scenario_id, '.yml')
      )),
      provenance = recorded_status,
      changed = changed,
      response = response$status,
      execution = report_execution(test, execution),
      review = if (!is.null(d$blocked)) {
        'resolve inputs'
      } else if (!d$cassette_exists) {
        'record'
      } else if (length(changed) || identical(recorded_status, 'unknown')) {
        'review changes'
      } else if (identical(response$status, 'disagrees')) {
        'review response'
      } else {
        'none'
      }
    )
  }

  hook_tests <- list()
  for (kind in c('hook-case', 'hook-integration')) {
    ids <- names(service$testing[[
      if (kind == 'hook-case') 'hook_cases' else 'hook_integrations'
    ]])
    for (case_id in ids) {
      test <- declared_test_file(root, kind, id, case_id)
      hook_tests[[paste(kind, case_id)]] <- list(
        kind = sub('-', ' ', kind),
        id = case_id,
        test = test,
        test_present = present(test),
        execution = report_execution(test, execution)
      )
    }
  }

  own <- function(key) {
    names(Filter(function(s) identical(s$route, key), scenarios))
  }
  routes <- do.call(
    rbind,
    lapply(keys, function(key) {
      entry <- by_key[[key]]
      # Excluded routes have no replay status.
      replay <- if (is.null(declared)) {
        NA_character_
      } else {
        unname(declared$routes[key])
      }
      mine <- own(key)
      represented_by <- names(Filter(
        function(s) key %in% s$represents && !identical(s$route, key),
        scenarios
      ))
      recorded <- any(vapply(
        scenarios[mine],
        `[[`,
        logical(1),
        'cassette_present'
      ))
      no_cassette <- if (is.null(declared) || !key %in% selected) {
        NA_character_
      } else if (length(mine) && recorded) {
        NA_character_
      } else if (length(mine)) {
        reasons <- Filter(
          Negate(is.null),
          lapply(scenarios[mine], `[[`, 'blocked')
        )
        if (length(reasons)) {
          paste('blocked:', reasons[[1L]])
        } else {
          'not recorded yet'
        }
      } else if (length(represented_by)) {
        paste('represented by', paste(represented_by, collapse = ', '))
      } else if (!is.null(declared$unrecorded[[key]])) {
        paste('unrecorded:', declared$unrecorded[[key]]$reason)
      } else {
        'no scenario'
      }
      data.frame(
        service = id,
        route = key,
        selection = if (key %in% selected) 'selected' else 'excluded',
        support = if (!key %in% selected) {
          NA_character_
        } else if (is.null(entry)) {
          'unsupported'
        } else {
          'supported'
        },
        wrapper = entry$record$name %or% NA_character_,
        contract = if (key %in% names(contracts)) 'declared' else 'none',
        contract_test = if (key %in% names(contracts)) {
          if (contracts[[key]]$test_present) 'present' else 'missing'
        } else {
          NA_character_
        },
        gap = declared$gaps[[key]]$reason %or% NA_character_,
        replay = replay,
        scenarios = if (length(mine)) {
          paste(mine, collapse = ', ')
        } else {
          NA_character_
        },
        recorded = length(mine) > 0L && recorded,
        no_cassette = no_cassette,
        stringsAsFactors = FALSE
      )
    })
  )

  executions <- c(
    vapply(contracts, `[[`, character(1), 'execution'),
    vapply(scenarios, `[[`, character(1), 'execution'),
    vapply(hook_tests, `[[`, character(1), 'execution')
  )
  replayed <- unique(unlist(lapply(
    Filter(function(s) identical(s$execution, 'passed'), scenarios),
    `[[`,
    'route'
  )))
  summary <- list(
    schema_operations = length(keys),
    selected = length(selected),
    selected_unsupported = sum(!selected %in% names(by_key)),
    contracts_declared = length(contracts),
    contract_tests_present = sum(vapply(
      contracts,
      `[[`,
      logical(1),
      'test_present'
    )),
    scenarios_declared = length(scenarios),
    scenarios_blocked = sum(vapply(
      scenarios,
      function(s) !is.null(s$blocked),
      logical(1)
    )),
    scenario_tests_present = sum(vapply(
      scenarios,
      `[[`,
      logical(1),
      'test_present'
    )),
    recordings_present = sum(vapply(
      scenarios,
      `[[`,
      logical(1),
      'cassette_present'
    )),
    routes_recorded = sum(routes$recorded),
    routes_replayed = length(replayed),
    routes_represented = sum(routes$replay %in% 'represented'),
    unrecorded = sum(routes$replay %in% 'unrecorded'),
    gaps = length(declared$gaps),
    not_covered = sum(routes$replay %in% 'not_covered'),
    hook_cases_declared = length(service$testing$hook_cases),
    hook_integrations_declared = length(service$testing$hook_integrations),
    hook_tests_present = sum(vapply(
      hook_tests,
      `[[`,
      logical(1),
      'test_present'
    )),
    hooks_without_cases = length(declared$hooks_without_cases),
    tests_passed = sum(executions == 'passed'),
    tests_failed = sum(executions == 'failed'),
    tests_skipped = sum(executions == 'skipped'),
    tests_not_run = sum(executions == 'not run'),
    needs_review = sum(vapply(
      scenarios,
      function(s) s$review != 'none',
      logical(1)
    ))
  )
  list(
    summary = summary,
    routes = routes,
    contracts = contracts,
    scenarios = scenarios,
    hook_tests = hook_tests,
    hooks_without_cases = declared$hooks_without_cases
  )
}

#' Report verification layers and scenarios needing review
#'
#' Report helper contracts, cassette scenarios, represented routes, hook tests, gaps and exclusions separately for each service, with optional test results and the scenarios affected by changes since they were recorded. No file is changed.
#'
#' @details Declarations, generated test files and execution are distinct: a test is passed, failed or skipped only when `results` name its file. A route counts as replayed only when its own scenario test passed. A recording's provenance file holds digests of its operation schema and referenced components (own and represented routes), operation policy, request helper with companions and hook callback, hook chains and functions, and scenario declaration with resolved inputs; a digest that differs from the current one is listed in `changed` and asks for review. A recording without a provenance file, such as one made before provenance existed, is `unknown` and also asks for review; delete the cassette and record again to clear it. `test_current` is `FALSE` when the generated test is older than its inputs; regenerate before recording. While a represented route is deferred, its scenario can show as changed until the deferral ends. The report never re-records and never treats a recording as current service acceptance. Digests use deparsed function sources, so an R upgrade can change them. An invalid testing declaration stops the report.
#' @param root Explicit existing client root directory.
#' @param config Project YAML path relative to root.
#' @param callbacks Explicit environment containing named development callbacks.
#' @param results Optional testthat results, or a data frame with `file`, `failed`, `error` and `skipped` columns. Without it every generated test is reported as \code{not run}.
#' @param check_responses When `TRUE`, also check recorded responses with \code{\link{review_recordings}}.
#' @return A list with `services`, keyed by service ID. Each holds `summary` (counts per layer, with schema and selected denominators kept apart), `routes` (one row per route: selection, support, wrapper, contract, gap, replay status, own scenarios, whether the route has its own recording and, if not, why), `contracts`, `scenarios` (inputs, test, recording, signature, provenance status, changed components, response check, execution and review need), `hook_tests` and `hooks_without_cases`.
#' @seealso \code{\link{inspect_client}}, \code{\link{review_recordings}}, [Step-by-step guide](https://seanthimons.github.io/specmill/articles/testing.html).
#' @export
testing_report <- function(
  root,
  config = 'specmill.yml',
  callbacks = new.env(parent = emptyenv()),
  results = NULL,
  check_responses = FALSE
) {
  loaded <- testing_project(root, config, callbacks)
  execution <- testing_results(results)
  responses <- if (isTRUE(check_responses)) {
    review_recordings(loaded$root, config, callbacks)
  } else {
    list()
  }
  documents <- provenance_documents()
  services <- lapply(loaded$services, function(x) {
    report_service(
      loaded$root,
      x,
      loaded$definitions,
      execution,
      responses,
      documents
    )
  })
  names(services) <- vapply(
    loaded$services,
    function(x) x$service$id,
    character(1)
  )
  list(services = services)
}
