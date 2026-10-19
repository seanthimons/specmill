validate_cache <- function(cache, callbacks) {
  config_fields(
    cache,
    c(
      'mode',
      'enabled',
      'environment',
      'name',
      'key',
      'input',
      'max_items',
      'entries',
      'combine',
      'project'
    ),
    'cache'
  )
  mode <- config_string(cache$mode, 'cache.mode')
  if (!mode %in% c('call', 'items')) {
    stop('cache.mode must be call or items')
  }
  for (field in c('enabled', 'environment')) {
    if (is.null(cache[[field]])) {
      stop('cache requires ', field)
    }
    validate_binding(cache[[field]], callbacks)
  }
  config_string(cache$name, 'cache.name')
  fields <- c(
    'key',
    if (mode == 'items') c('entries', 'combine'),
    if (!is.null(cache$project)) 'project'
  )
  for (field in fields) {
    name <- config_string(cache[[field]], paste0('cache.', field))
    if (!identical(make.names(name), name)) {
      stop('cache callbacks must name client functions')
    }
  }
  if (
    mode == 'call' &&
      any(
        c('input', 'max_items', 'entries', 'combine', 'project') %in%
          names(cache)
      )
  ) {
    stop('cache input/max_items/entries/combine/project require items mode')
  }
  if (mode == 'items') {
    config_string(cache$input, 'cache.input')
    size <- cache$max_items
    if (
      !is.numeric(size) ||
        length(size) != 1L ||
        !is.finite(size) ||
        size < 1 ||
        size != trunc(size) ||
        size >= .Machine$integer.max
    ) {
      stop(
        'cache.max_items must be a positive integer below .Machine$integer.max'
      )
    }
  }
}

cache_callback <- function(name) {
  paste0(
    'base::get(',
    r_literal(name),
    ', envir = base::parent.env(base::environment()), mode = "function", inherits = FALSE)'
  )
}

cache_key_check <- function() {
  c(
    '    if (!base::is.character(cache_key) || base::length(cache_key) != 1L || base::is.na(cache_key) || !base::nzchar(cache_key)) base::stop("cache.key must return one nonempty string", call. = FALSE)'
  )
}

cache_setup <- function(operation, spec, parameters) {
  cache <- spec$cache
  callback <- cache_callback(cache$key)
  binding <- function(x) {
    request_binding(
      x,
      parameters,
      FALSE,
      operation,
      spec$callbacks %or% new.env(parent = emptyenv())
    )
  }
  items <- identical(cache$mode, 'items')
  c(
    paste0(
      '  cache_state <- base::list(params = params, enabled = ',
      binding(cache$enabled),
      ', cached = base::list()',
      if (items) paste0(', pending = params[[', r_literal(cache$input), ']]'),
      ')'
    ),
    '  if (cache_state$enabled) {',
    paste0('    cache_environment <- ', binding(cache$environment)),
    '    if (!base::is.environment(cache_environment)) base::stop("cache.environment must select an environment", call. = FALSE)',
    paste0(
      '    if (!base::exists(',
      r_literal(cache$name),
      ', envir = cache_environment, inherits = FALSE)) base::assign(',
      r_literal(cache$name),
      ', base::new.env(hash = TRUE, parent = base::emptyenv()), envir = cache_environment)'
    ),
    paste0(
      '    cache_state$store <- base::get(',
      r_literal(cache$name),
      ', envir = cache_environment, inherits = FALSE)'
    ),
    '    if (!base::is.environment(cache_state$store)) base::stop("Named cache must be an environment", call. = FALSE)',
    if (!items) {
      c(
        paste0(
          '    cache_key <- ',
          callback,
          '(base::list(params = cache_state$params))'
        ),
        cache_key_check(),
        '    cache_state$key <- cache_key',
        '    if (base::exists(cache_key, envir = cache_state$store, inherits = FALSE)) base::return(base::get(cache_key, envir = cache_state$store, inherits = FALSE))'
      )
    } else {
      c(
        '    cache_missing <- base::integer()',
        '    for (cache_index in base::seq_along(cache_state$pending)) {',
        paste0(
          '    cache_key <- ',
          callback,
          '(base::list(input = cache_state$pending[[cache_index]], params = cache_state$params))'
        ),
        cache_key_check(),
        '      if (base::exists(cache_key, envir = cache_state$store, inherits = FALSE)) {',
        '        cache_state$cached[base::length(cache_state$cached) + 1L] <- base::list(base::get(cache_key, envir = cache_state$store, inherits = FALSE))',
        '      } else cache_missing <- base::c(cache_missing, cache_index)',
        '    }',
        '    cache_state$pending <- cache_state$pending[cache_missing]'
      )
    },
    '  }',
    if (items) {
      c(
        '  if (!base::length(cache_state$pending)) {',
        '    result <- NULL',
        paste0(
          '    result <- ',
          cache_callback(cache$combine),
          '(base::list(result = result, cached = cache_state$cached, params = cache_state$params))'
        ),
        if (!is.null(cache$project)) {
          paste0(
            '    result <- ',
            cache_callback(cache$project),
            '(base::list(result = result, params = cache_state$params))'
          )
        },
        '    base::return(result)',
        '  }',
        paste0(
          '  params[[',
          r_literal(cache$input),
          ']] <- cache_state$pending'
        )
      )
    }
  )
}

cache_iteration <- function(lines, per_request, spec) {
  cache <- spec$cache
  c(
    head(lines, per_request),
    '  send <- function(params) {',
    paste0('  ', tail(lines, -per_request)),
    '  }',
    '  if (base::length(cache_state$pending) > 1L) {',
    paste0(
      '    cache_chunks <- base::split(cache_state$pending, base::ceiling(base::seq_along(cache_state$pending) / ',
      r_literal(as.integer(cache$max_items)),
      '))'
    ),
    '    result <- base::tryCatch(purrr::map(cache_chunks, function(chunk) {',
    paste0('      params[[', r_literal(cache$input), ']] <- chunk'),
    '      send(params)',
    '    }), error = function(e) { if (base::inherits(e, "purrr_error_indexed") && base::inherits(e$parent, "specmill_call_error")) base::stop(e$parent); base::stop(e) })',
    '  } else result <- send(params)',
    '  if (base::inherits(result, "httr2_request") || (base::is.list(result) && base::length(result) && base::all(base::vapply(result, base::inherits, base::logical(1), "httr2_request")))) base::return(result)',
    '  params <- cache_state$params'
  )
}

cache_finish <- function(spec) {
  cache <- spec$cache
  items <- identical(cache$mode, 'items')
  c(
    '  if (base::inherits(result, "httr2_request")) base::return(result)',
    '  if (cache_state$enabled) {',
    if (!items) {
      '    base::assign(cache_state$key, result, envir = cache_state$store)'
    } else {
      c(
        paste0(
          '    cache_entries <- ',
          cache_callback(cache$entries),
          '(base::list(result = result, params = cache_state$params))'
        ),
        '    if (!base::is.list(cache_entries) || (base::length(cache_entries) && (base::is.null(base::names(cache_entries)) || base::anyNA(base::names(cache_entries)) || base::any(!base::nzchar(base::names(cache_entries)))))) base::stop("cache.entries must return a list with nonempty keys", call. = FALSE)',
        '    for (cache_index in base::seq_along(cache_entries)) base::assign(base::names(cache_entries)[[cache_index]], cache_entries[[cache_index]], envir = cache_state$store)'
      )
    },
    '  }',
    if (items) {
      c(
        paste0(
          '  result <- ',
          cache_callback(cache$combine),
          '(base::list(result = result, cached = cache_state$cached, params = cache_state$params))'
        ),
        if (!is.null(cache$project)) {
          paste0(
            '  result <- ',
            cache_callback(cache$project),
            '(base::list(result = result, params = cache_state$params))'
          )
        }
      )
    },
    '  result'
  )
}
