# Reviewed test declarations (#257): cassette scenarios, contract gaps, routes
# deliberately left unrecorded, and hook cases. Loading checks structure only;
# testing_declarations() checks references against the inspected operations.

testing_match_terms <- c(
  'method',
  'uri',
  'host',
  'path',
  'query',
  'body',
  'body_json'
)
testing_hook_stages <- c('pre_request', 'post_response', 'post_combine')
testing_route_pattern <- '^[A-Z]+ /'
testing_id_pattern <- '^[a-z][a-z0-9_]*$'

testing_match <- function(x, label) {
  terms <- config_sequence(x, label)
  # vcr compares all request headers or none, so header matching is not offered.
  if (
    !length(terms) ||
      anyDuplicated(terms) ||
      !all(terms %in% testing_match_terms)
  ) {
    stop(
      label,
      ' must list distinct matchers from: ',
      paste(testing_match_terms, collapse = ', ')
    )
  }
  terms
}

testing_routes <- function(x, label) {
  routes <- config_sequence(x, label)
  if (!all(grepl(testing_route_pattern, routes)) || anyDuplicated(routes)) {
    stop(label, ' must list distinct METHOD /path route keys')
  }
  routes
}

testing_reasons <- function(x, label) {
  config_fields(x, names(x), label)
  for (route in names(x)) {
    if (!grepl(testing_route_pattern, route)) {
      stop(label, ' must be keyed by METHOD /path: ', route)
    }
    entry <- x[[route]]
    config_fields(entry, c('reason', 'issue'), paste(label, route))
    config_string(entry$reason, paste(label, route, 'reason'))
    if (!is.null(entry$issue)) {
      config_string(entry$issue, paste(label, route, 'issue'))
    }
  }
  config_data(x)
}

testing_checks <- function(x, label) {
  config_fields(x, c('class', 'rows', 'names', 'values'), label)
  if (!length(x)) {
    stop(label, ' must declare at least one check')
  }
  if (!is.null(x$class)) {
    config_string(x$class, paste(label, 'class'))
  }
  if (
    !is.null(x$rows) &&
      (!is.numeric(x$rows) ||
        length(x$rows) != 1L ||
        is.na(x$rows) ||
        x$rows < 0 ||
        x$rows != round(x$rows))
  ) {
    stop(label, ' rows must be a nonnegative whole number')
  }
  if (!is.null(x$names)) {
    config_sequence(x$names, paste(label, 'names'))
  }
  if (!is.null(x$values)) {
    if (!inherits(x$values, 'specmill_sequence') || !length(x$values)) {
      stop(label, ' values must be a nonempty sequence')
    }
    for (value in x$values) {
      config_fields(value, c('path', 'equals'), paste(label, 'value'))
      if (!all(c('path', 'equals') %in% names(value))) {
        stop(label, ' values need path and equals')
      }
      path <- value$path
      valid <- inherits(path, 'specmill_sequence') &&
        length(path) &&
        all(vapply(
          path,
          function(step) {
            (is.character(step) && length(step) == 1L && nzchar(step)) ||
              (is.numeric(step) &&
                length(step) == 1L &&
                step >= 1 &&
                step == round(step))
          },
          logical(1)
        ))
      if (!isTRUE(valid)) {
        stop(label, ' value path must be a sequence of names or positions')
      }
    }
  }
  config_data(x)
}

testing_scenario <- function(x, label) {
  config_fields(
    x,
    c(
      'operation',
      'represents',
      'inputs',
      'example',
      'result',
      'checks',
      'environment',
      'match'
    ),
    label
  )
  config_string(x$operation, paste(label, 'operation'))
  if (all(c('result', 'checks') %in% names(x))) {
    stop(label, ': declare result or checks, not both')
  }
  if (all(c('inputs', 'example') %in% names(x))) {
    stop(label, ': declare inputs or example, not both')
  }
  if ('inputs' %in% names(x)) {
    config_fields(x$inputs, names(x$inputs), paste(label, 'inputs'))
  }
  if (
    !is.null(x$example) &&
      (!is.numeric(x$example) ||
        length(x$example) != 1L ||
        is.na(x$example) ||
        x$example < 1 ||
        x$example != round(x$example))
  ) {
    stop(label, ' example must be a positive whole number')
  }
  if (!is.null(x$environment)) {
    config_fields(
      x$environment,
      names(x$environment),
      paste(label, 'environment')
    )
    for (value in x$environment) {
      config_string(value, paste(label, 'environment value'))
    }
  }
  scenario <- config_data(x)
  if (!is.null(x$represents)) {
    scenario$represents <- testing_routes(
      x$represents,
      paste(label, 'represents')
    )
  }
  if (!is.null(x$match)) {
    scenario$match <- testing_match(x$match, paste(label, 'match'))
  }
  if (!is.null(x$checks)) {
    scenario$checks <- testing_checks(x$checks, paste(label, 'checks'))
  }
  scenario
}

testing_hook_case <- function(x, label) {
  config_fields(x, c('hook', 'stage', 'state', 'expect'), label)
  if (!all(c('hook', 'stage', 'state', 'expect') %in% names(x))) {
    stop(label, ' needs hook, stage, state and expect')
  }
  hook <- config_string(x$hook, paste(label, 'hook'))
  if (!identical(make.names(hook), hook)) {
    stop(label, ': invalid hook function name')
  }
  if (!config_string(x$stage, paste(label, 'stage')) %in% testing_hook_stages) {
    stop(
      label,
      ' stage must be one of: ',
      paste(testing_hook_stages, collapse = ', ')
    )
  }
  config_fields(x$state, names(x$state), paste(label, 'state'))
  config_fields(x$expect, c('state', 'error'), paste(label, 'expect'))
  if (length(x$expect) != 1L) {
    stop(label, ' expect needs exactly one of state or error')
  }
  if (!is.null(x$expect$error)) {
    config_string(x$expect$error, paste(label, 'expected error class'))
  }
  config_data(x)
}

testing_entries <- function(x, label, read) {
  if (is.null(x)) {
    return(list())
  }
  config_fields(x, names(x), label)
  bad <- names(x)[!grepl(testing_id_pattern, names(x))]
  if (length(bad)) {
    stop(label, ': invalid ID ', paste(bad, collapse = ', '))
  }
  stats::setNames(
    lapply(names(x), function(id) read(x[[id]], paste(label, id))),
    names(x)
  )
}

# Structure of a service `testing` field and the data file it names.
read_testing_policy <- function(root, testing, id) {
  label <- paste(id, 'testing')
  config_fields(testing, c('file', 'match', 'gaps', 'unrecorded'), label)
  policy <- list(
    file = NULL,
    match = if (is.null(testing$match)) {
      c('method', 'uri')
    } else {
      testing_match(testing$match, paste(label, 'match'))
    },
    gaps = if (is.null(testing$gaps)) {
      list()
    } else {
      testing_reasons(testing$gaps, paste(label, 'gaps'))
    },
    unrecorded = if (is.null(testing$unrecorded)) {
      list()
    } else {
      testing_reasons(testing$unrecorded, paste(label, 'unrecorded'))
    },
    scenarios = list(),
    hook_cases = list()
  )
  if (is.null(testing$file)) {
    return(policy)
  }
  policy$file <- config_string(testing$file, paste(label, 'file'))
  if (!grepl('^tests/testthat/.+\\.(ya?ml|json)$', policy$file)) {
    stop(label, ' file must be a YAML or JSON file inside tests/testthat/')
  }
  path <- project_path(root, policy$file)
  if (!file.exists(path)) {
    stop(label, ' file does not exist: ', policy$file)
  }
  data <- read_config_yaml(path) %or% list()
  config_fields(data, c('scenarios', 'hook_cases'), policy$file)
  policy$scenarios <- testing_entries(
    data$scenarios,
    'scenario',
    testing_scenario
  )
  policy$hook_cases <- testing_entries(
    data$hook_cases,
    'hook case',
    testing_hook_case
  )
  policy
}

# Cassette identity is the service ID plus the scenario ID, so services whose
# routes overlap cannot collide.
testing_cassette <- function(service, scenario) {
  file.path('tests/testthat/_vcr', service, paste0(scenario, '.yml'))
}

# Cross-reference one service's declarations against inspected operations.
# `operations` holds, per wrapper name, the operation key, its inspect_client()
# record and its configured operation; `inventory` is the service's inventory.
testing_declarations <- function(
  root,
  service,
  operations,
  inventory,
  definitions
) {
  policy <- service$testing
  id <- service$id
  label <- paste(id, 'testing')
  selected <- unique(vapply(
    Filter(function(x) x$status != 'excluded', inventory),
    `[[`,
    character(1),
    'key'
  ))
  by_key <- stats::setNames(
    operations,
    vapply(operations, `[[`, character(1), 'key')
  )
  stale <- function(kind, routes) {
    routes <- setdiff(routes, selected)
    if (length(routes)) {
      stop(
        label,
        ' ',
        kind,
        ' names a route that is not selected: ',
        paste(routes, collapse = ', ')
      )
    }
  }
  stale('gaps', names(policy$gaps))
  stale('unrecorded', names(policy$unrecorded))
  contracted <- names(Filter(
    function(x) isTRUE(x$record$contract_declared),
    by_key
  ))
  both <- intersect(names(policy$gaps), contracted)
  if (length(both)) {
    stop(
      label,
      ': gap declared for a route with a fixed contract: ',
      paste(both, collapse = ', ')
    )
  }

  scenarios <- list()
  for (scenario_id in names(policy$scenarios)) {
    scenario <- policy$scenarios[[scenario_id]]
    where <- paste(label, 'scenario', scenario_id)
    target <- scenario$operation
    entry <- if (grepl(testing_route_pattern, target)) {
      by_key[[target]]
    } else {
      operations[[target]]
    }
    if (is.null(entry)) {
      if (target %in% selected) {
        stop(where, ': operation is not supported: ', target)
      }
      if (grepl(testing_route_pattern, target)) {
        stop(where, ': route is not selected: ', target)
      }
      stop(
        where,
        ': unknown operation ',
        target,
        '; if the wrapper was renamed, use its METHOD /path route key'
      )
    }
    key <- entry$key
    represents <- scenario$represents %or% key
    if (!key %in% represents) {
      stop(where, ': represents must include its own route ', key)
    }
    stale(paste('scenario', scenario_id, 'represents'), represents)
    unsupported <- setdiff(represents, names(by_key))
    if (length(unsupported)) {
      stop(
        where,
        ': represents unsupported routes: ',
        paste(unsupported, collapse = ', ')
      )
    }
    op <- entry$configured$operation
    spec <- entry$configured$spec
    mapped <- !is.null(spec[['request']]) ||
      identical(spec$implementation, 'existing')
    if (mapped && !'inputs' %in% names(scenario)) {
      stop(where, ': mapped or retained operations need explicit inputs')
    }
    public <- c(
      parameter_names(op$parameters),
      if (!is.null(op$body)) body_argument_name(op),
      # Paging is resolved during generation, so resolve it the same way here.
      if (
        !is.null(pagination_settings(
          op,
          spec[['pagination']] %or% list(),
          service$operations[[key]][['pagination']] %or% list()
        ))
      ) {
        c('all_pages', 'max_pages')
      }
    )
    if (!mapped && length(setdiff(names(scenario$inputs), public))) {
      stop(
        where,
        ': inputs name unknown arguments: ',
        paste(setdiff(names(scenario$inputs), public), collapse = ', ')
      )
    }
    if (!is.null(scenario$example)) {
      examples <- spec$docs$examples %or% list()
      if (scenario$example > length(examples)) {
        stop(where, ': docs example ', scenario$example, ' does not exist')
      }
    }
    match <- scenario$match %or% policy$match
    if (!is.null(op$body) && !any(c('body', 'body_json') %in% match)) {
      stop(
        where,
        ': an operation with a request body must match body or body_json'
      )
    }
    cassette <- testing_cassette(id, scenario_id)
    scenarios[[scenario_id]] <- list(
      operation = entry$record$name,
      route = key,
      represents = represents,
      inputs = if ('inputs' %in% names(scenario)) {
        'scenario'
      } else if (!is.null(scenario$example)) {
        'docs_example'
      } else {
        'unresolved'
      },
      expectation = if ('result' %in% names(scenario)) {
        'result'
      } else if ('checks' %in% names(scenario)) {
        'checks'
      } else {
        'signature'
      },
      match = match,
      cassette = cassette,
      cassette_exists = file.exists(file.path(root, cassette))
    )
  }

  scenario_routes <- unique(unlist(
    lapply(scenarios, `[[`, 'route'),
    use.names = FALSE
  ))
  represented <- setdiff(
    unique(unlist(lapply(scenarios, `[[`, 'represents'), use.names = FALSE)),
    scenario_routes
  )
  overlap <- intersect(
    names(policy$unrecorded),
    c(scenario_routes, represented)
  )
  if (length(overlap)) {
    stop(
      label,
      ': unrecorded route is covered by a scenario: ',
      paste(overlap, collapse = ', ')
    )
  }
  for (case_id in names(policy$hook_cases)) {
    hook <- policy$hook_cases[[case_id]]$hook
    if (is.null(definitions[[hook]])) {
      stop(label, ' hook case ', case_id, ': unknown hook function ', hook)
    }
  }
  directory <- file.path(root, 'tests/testthat/_vcr', id)
  cassettes <- sub(
    '\\.yml$',
    '',
    list.files(directory, '\\.yml$')
  )
  routes <- stats::setNames(
    vapply(
      selected,
      function(route) {
        if (route %in% scenario_routes) {
          'scenario'
        } else if (route %in% represented) {
          'represented'
        } else if (route %in% names(policy$unrecorded)) {
          'unrecorded'
        } else {
          'not_covered'
        }
      },
      character(1)
    ),
    selected
  )
  list(
    file = policy$file,
    match = policy$match,
    scenarios = scenarios,
    gaps = policy$gaps,
    unrecorded = policy$unrecorded,
    hook_cases = names(policy$hook_cases),
    routes = routes,
    unreferenced_cassettes = setdiff(cassettes, names(scenarios))
  )
}
