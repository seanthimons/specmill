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
      'match',
      'record_write'
    ),
    label
  )
  config_string(x$operation, paste(label, 'operation'))
  if (!is.null(x$record_write)) {
    config_fields(x$record_write, 'reason', paste(label, 'record_write'))
    config_string(x$record_write$reason, paste(label, 'record_write reason'))
  }
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

# The YAML reader keeps every sequence a list, but R callers pass vectors: a
# sequence of same-type scalars becomes a vector. Bodies are left as written,
# because a one-item list and a scalar serialize to different JSON.
testing_vectors <- function(x) {
  if (!is.list(x)) {
    return(x)
  }
  x <- lapply(x, testing_vectors)
  scalars <- length(x) &&
    is.null(names(x)) &&
    all(vapply(x, function(v) is.atomic(v) && length(v) == 1L, logical(1))) &&
    length(unique(sub(
      '^integer$',
      'double',
      vapply(x, typeof, character(1))
    ))) ==
      1L
  if (scalars) unlist(x) else x
}

# The body argument whose YAML sequences must stay lists: JSON and form bodies
# serialize a one-item list differently from a scalar. Line bodies take a
# vector of lines, so they convert like any other input.
testing_kept_body <- function(op) {
  lines <- identical(op$text_encoding, 'lines') &&
    grepl('^text/', op$body_media %or% '')
  if (!is.null(op$body) && !lines) body_argument_name(op)
}

# Inputs or helper arguments, except the named body argument.
testing_arguments <- function(x, body) {
  names <- setdiff(names(x), body)
  x[names] <- lapply(x[names], testing_vectors)
  x
}

testing_function_name <- function(x, label) {
  name <- config_string(x, label)
  if (!identical(make.names(name), name)) {
    stop(label, ': invalid function name')
  }
  name
}

# A direct case runs one hook function, or a wrapper's configured chain through
# the client's hook callback.
testing_hook_case <- function(x, label) {
  config_fields(x, c('hook', 'chain', 'stage', 'state', 'expect'), label)
  if (sum(c('hook', 'chain') %in% names(x)) != 1L) {
    stop(label, ' needs exactly one of hook or chain')
  }
  if (!all(c('stage', 'state', 'expect') %in% names(x))) {
    stop(label, ' needs stage, state and expect')
  }
  if (!is.null(x$hook)) {
    testing_function_name(x$hook, paste(label, 'hook'))
  } else {
    testing_function_name(x$chain, paste(label, 'chain'))
  }
  if (!config_string(x$stage, paste(label, 'stage')) %in% testing_hook_stages) {
    stop(
      label,
      ' stage must be one of: ',
      paste(testing_hook_stages, collapse = ', ')
    )
  }
  config_fields(x$state, names(x$state), paste(label, 'state'))
  config_fields(x$expect, c('state', 'error', 'hook'), paste(label, 'expect'))
  if (sum(c('state', 'error') %in% names(x$expect)) != 1L) {
    stop(label, ' expect needs exactly one of state or error')
  }
  if (!is.null(x$expect$error)) {
    config_string(x$expect$error, paste(label, 'expected error class'))
  }
  if (!is.null(x$expect$hook)) {
    if (is.null(x$chain) || is.null(x$expect$error)) {
      stop(label, ' expect hook applies only to chain errors')
    }
    testing_function_name(x$expect$hook, paste(label, 'expected hook'))
  }
  config_data(x)
}

# A wrapper integration runs the real wrapper and hooks around mocked helper
# calls. Unlike fixed contracts it may expect no helper call at all.
testing_hook_integration <- function(x, label) {
  config_fields(
    x,
    c(
      'operation',
      'inputs',
      'calls',
      'result',
      'error',
      'sequence',
      'environment'
    ),
    label
  )
  config_string(x$operation, paste(label, 'operation'))
  if (!all(c('inputs', 'calls') %in% names(x))) {
    stop(label, ' needs inputs and calls')
  }
  if (sum(c('result', 'error') %in% names(x)) != 1L) {
    stop(label, ' needs exactly one of result or error')
  }
  config_fields(x$inputs, names(x$inputs), paste(label, 'inputs'))
  if (!inherits(x$calls, 'specmill_sequence') && length(x$calls)) {
    stop(label, ' calls must be a sequence')
  }
  for (call in x$calls) {
    config_fields(
      call,
      c('helper', 'arguments', 'response'),
      paste(label, 'call')
    )
    if (!all(c('helper', 'arguments', 'response') %in% names(call))) {
      stop(label, ' calls need helper, arguments and response')
    }
    testing_function_name(call$helper, paste(label, 'call helper'))
    config_fields(
      call$arguments,
      names(call$arguments),
      paste(label, 'call arguments')
    )
  }
  if (!is.null(x$error)) {
    config_fields(x$error, c('class', 'hook', 'stage'), paste(label, 'error'))
    config_string(x$error$class, paste(label, 'error class'))
    if (!is.null(x$error$hook)) {
      testing_function_name(x$error$hook, paste(label, 'error hook'))
    }
    if (
      !is.null(x$error$stage) &&
        !config_string(x$error$stage, paste(label, 'error stage')) %in%
          testing_hook_stages
    ) {
      stop(label, ' error stage must be a hook stage')
    }
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
  case <- config_data(x)
  case$calls <- config_data(unclass(x$calls)) %or% list()
  if (!is.null(x$sequence)) {
    case$sequence <- vapply(
      config_sequence(x$sequence, paste(label, 'sequence')),
      testing_function_name,
      character(1),
      label = paste(label, 'sequence'),
      USE.NAMES = FALSE
    )
  }
  case
}

# Recording-time redaction beyond credentials: response headers to drop and
# regex patterns replaced by a placeholder (vcr applies them with gsub()).
testing_filter <- function(x, label) {
  config_fields(x, c('response_headers', 'patterns'), label)
  filter <- list()
  if (!is.null(x$response_headers)) {
    filter$response_headers <- config_sequence(
      x$response_headers,
      paste(label, 'response_headers')
    )
  }
  if (!is.null(x$patterns)) {
    config_fields(x$patterns, names(x$patterns), paste(label, 'patterns'))
    for (placeholder in names(x$patterns)) {
      pattern <- config_string(
        x$patterns[[placeholder]],
        paste(label, 'pattern', placeholder)
      )
      if (!grepl('^<<[A-Z0-9_]+>>$', placeholder)) {
        stop(label, ' pattern placeholders look like <<NAME>>: ', placeholder)
      }
      fail <- function(e) {
        stop(label, ' pattern does not compile: ', placeholder, call. = FALSE)
      }
      matches <- tryCatch(
        grepl(pattern, c('', placeholder)),
        warning = fail,
        error = fail
      )
      if (any(matches)) {
        stop(
          label,
          ' pattern must not match an empty string or its placeholder: ',
          placeholder
        )
      }
    }
    filter$patterns <- unlist(config_data(x$patterns))
  }
  filter
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
  config_fields(
    testing,
    c('file', 'match', 'gaps', 'unrecorded', 'filter'),
    label
  )
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
    hook_cases = list(),
    hook_integrations = list(),
    filter = if (is.null(testing$filter)) {
      list()
    } else {
      testing_filter(testing$filter, paste(label, 'filter'))
    }
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
  config_fields(
    data,
    c('scenarios', 'hook_cases', 'hook_integrations'),
    policy$file
  )
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
  policy$hook_integrations <- testing_entries(
    data$hook_integrations,
    'hook integration',
    testing_hook_integration
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

  # Scenarios and hook integrations name an operation by route key or wrapper.
  resolve <- function(target, where) {
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
    entry
  }
  # Mapped and retained operations own their facade, so only the others are
  # checked against public argument names.
  check_inputs <- function(entry, case, where) {
    op <- entry$configured$operation
    spec <- entry$configured$spec
    mapped <- !is.null(spec[['request']]) ||
      identical(spec$implementation, 'existing')
    if (mapped && !'inputs' %in% names(case)) {
      stop(where, ': mapped or retained operations need explicit inputs')
    }
    public <- c(
      parameter_names(op$parameters),
      if (!is.null(op$body)) body_argument_name(op),
      # Generation has already resolved paging; inspection resolves it the
      # same way generation does.
      if (
        !is.null(op$paginate) ||
          !is.null(pagination_settings(
            op,
            spec[['pagination']] %or% list(),
            service$operations[[entry$key]][['pagination']] %or% list()
          ))
      ) {
        c('all_pages', 'max_pages')
      }
    )
    unknown <- setdiff(names(case$inputs), public)
    if (!mapped && length(unknown)) {
      stop(
        where,
        ': inputs name unknown arguments: ',
        paste(unknown, collapse = ', ')
      )
    }
  }

  scenarios <- list()
  for (scenario_id in names(policy$scenarios)) {
    scenario <- policy$scenarios[[scenario_id]]
    where <- paste(label, 'scenario', scenario_id)
    entry <- resolve(scenario$operation, where)
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
    check_inputs(entry, scenario, where)
    # vcr cannot store multipart parts, so such a recording would fail.
    if (startsWith(op$body_media %or% '', 'multipart/')) {
      stop(
        where,
        ': multipart request bodies cannot be recorded; declare the route ',
        'under unrecorded and cover it with a contract'
      )
    }
    if (!is.null(scenario$example)) {
      examples <- spec$docs$examples %or% list()
      if (scenario$example > length(examples)) {
        stop(where, ': docs example ', scenario$example, ' does not exist')
      }
    }
    resolution <- scenario_resolution(op, spec, scenario)
    match <- scenario$match %or% policy$match
    if (!is.null(op$body) && !any(c('body', 'body_json') %in% match)) {
      stop(
        where,
        ': an operation with a request body must match body or body_json'
      )
    }
    if (!is.null(scenario$record_write) && op$method %in% c('GET', 'HEAD')) {
      stop(where, ': record_write applies only to state-changing operations')
    }
    cassette <- testing_cassette(id, scenario_id)
    scenarios[[scenario_id]] <- list(
      operation = entry$record$name,
      route = key,
      represents = represents,
      inputs = resolution$source,
      input_sources = resolution$sources,
      input_values = resolution$inputs,
      blocked = resolution$blocked,
      expectation = if ('result' %in% names(scenario)) {
        'result'
      } else if ('checks' %in% names(scenario)) {
        'checks'
      } else {
        'signature'
      },
      match = match,
      write_approval = scenario$record_write$reason,
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
  chain_of <- function(wrapper, stage) {
    unlist(service$hooks[[wrapper]][[stage]], use.names = FALSE)
  }
  covered <- character()
  for (case_id in names(policy$hook_cases)) {
    case <- policy$hook_cases[[case_id]]
    where <- paste(label, 'hook case', case_id)
    if (!is.null(case$hook)) {
      if (is.null(definitions[[case$hook]])) {
        stop(where, ': unknown hook function ', case$hook)
      }
      covered <- c(covered, case$hook)
      next
    }
    if (is.null(operations[[case$chain]])) {
      stop(where, ': unknown wrapper ', case$chain)
    }
    chain <- chain_of(case$chain, case$stage)
    if (!length(chain)) {
      stop(where, ': ', case$chain, ' has no ', case$stage, ' hooks')
    }
    if (!is.null(case$expect$hook) && !case$expect$hook %in% chain) {
      stop(where, ': expected hook is not in the chain: ', case$expect$hook)
    }
    covered <- c(covered, chain)
  }
  callback <- service$hook_callback %or% 'run_hook'
  integrations <- list()
  for (case_id in names(policy$hook_integrations)) {
    case <- policy$hook_integrations[[case_id]]
    where <- paste(label, 'hook integration', case_id)
    entry <- resolve(case$operation, where)
    check_inputs(entry, case, where)
    wrapper <- entry$record$name
    helper <- entry$configured$spec$helper %or% service$helper
    hooks <- unique(unlist(service$hooks[[wrapper]], use.names = FALSE))
    if (!length(hooks)) {
      stop(where, ': ', wrapper, ' has no configured hooks')
    }
    helpers <- vapply(case$calls, `[[`, character(1), 'helper')
    # Companions and the callback run the hooks under test, so never mock them.
    reserved <- helpers[
      helpers == callback | startsWith(helpers, paste0(helper, '_'))
    ]
    if (length(reserved)) {
      stop(
        where,
        ': calls must name request helpers, not ',
        paste(unique(reserved), collapse = ', ')
      )
    }
    unknown <- setdiff(helpers, names(definitions))
    if (length(unknown)) {
      stop(where, ': unknown helper ', paste(unknown, collapse = ', '))
    }
    unknown <- setdiff(hooks, names(definitions))
    if (length(unknown)) {
      stop(where, ': unknown hook function ', paste(unknown, collapse = ', '))
    }
    unknown <- setdiff(case$sequence, c(hooks, helpers, helper))
    if (length(unknown)) {
      stop(
        where,
        ': sequence names neither a configured hook nor a helper: ',
        paste(unknown, collapse = ', ')
      )
    }
    if (!is.null(case$error$hook) && !case$error$hook %in% hooks) {
      stop(where, ': error hook is not configured for ', wrapper)
    }
    integrations[[case_id]] <- list(
      operation = wrapper,
      route = entry$key,
      hooks = hooks,
      helpers = unique(c(helper, helpers))
    )
  }
  # Missing cases are reported, never invented from generated code.
  configured <- unique(unlist(
    service$hooks[intersect(names(service$hooks), names(operations))],
    use.names = FALSE
  ))
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
    filter = policy$filter,
    scenarios = scenarios,
    gaps = policy$gaps,
    unrecorded = policy$unrecorded,
    hook_cases = names(policy$hook_cases),
    hook_integrations = integrations,
    hooks_without_cases = sort(setdiff(configured, covered)),
    routes = routes,
    unreferenced_cassettes = setdiff(cassettes, names(scenarios))
  )
}
