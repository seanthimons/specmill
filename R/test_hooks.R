# Generated hook tests (#260): direct cases for client-owned hook rules, and
# wrapper integrations that run real hooks around mocked request helpers.

hook_case_marker <- '# Hook case test; checks a reviewed hook rule.'
hook_integration_marker <- paste(
  '# Hook integration test; runs real hooks around a mocked helper.'
)

hook_quote <- function(x) encodeString(x, quote = "'")

# Tests run in an environment whose parent is the client namespace, so internal
# hooks and the hook callback are called unqualified.
render_hook_case <- function(service, id, case, callback) {
  call <- if (!is.null(case$hook)) {
    paste0(case$hook, '(state)')
  } else {
    paste0(
      callback,
      '(',
      hook_quote(case$chain),
      ', ',
      hook_quote(case$stage),
      ', state)'
    )
  }
  expect <- case$expect
  checks <- if (!is.null(expect$error)) {
    c(
      paste0(
        '  error <- testthat::expect_error(',
        call,
        ', class = ',
        hook_quote(expect$error),
        ')'
      ),
      if (
        !is.null(case$chain) && identical(expect$error, 'client_hook_error')
      ) {
        c(
          paste0(
            '  testthat::expect_identical(error$function_name, ',
            hook_quote(case$chain),
            ')'
          ),
          paste0(
            '  testthat::expect_identical(error$stage, ',
            hook_quote(case$stage),
            ')'
          )
        )
      },
      if (!is.null(expect$hook)) {
        paste0(
          '  testthat::expect_identical(error$hook_name, ',
          hook_quote(expect$hook),
          ')'
        )
      }
    )
  } else {
    c(
      paste0('  result <- ', call),
      paste0('  testthat::expect_equal(result, ', r_literal(expect$state), ')')
    )
  }
  paste(
    c(
      '# Generated with specmill; do not edit by hand.',
      hook_case_marker,
      paste0(
        'testthat::test_that(',
        hook_quote(paste(
          id,
          'checks',
          case$hook %or% paste(case$chain, 'chain'),
          'at',
          case$stage
        )),
        ', {'
      ),
      paste0('  state <- ', r_literal(case$state)),
      checks,
      '})'
    ),
    collapse = '\n'
  )
}

# One event log holds helper calls and hook runs, so order and frequency are
# checked together. Hooks are traced, not the callback: the executor finds
# hooks through its own environment.
render_hook_integration <- function(op, spec, service, id, case, declared) {
  package <- spec$package
  inputs <- testing_arguments(
    case$inputs %or% list(),
    testing_kept_body(op)
  )
  calls <- lapply(case$calls, function(call) {
    call$arguments <- testing_arguments(call$arguments, 'body')
    call
  })
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
  mocks <- c(
    vapply(
      declared$helpers,
      function(name) paste0(name, ' = record(', hook_quote(name), ')'),
      character(1)
    ),
    vapply(
      declared$hooks,
      function(name) paste0(name, ' = watch(', hook_quote(name), ')'),
      character(1)
    )
  )
  call <- paste0(package, '::', op$name, '(', args, ')')
  error <- case$error
  outcome <- if (!is.null(error)) {
    c(
      paste0(
        '  error <- testthat::expect_error(',
        call,
        ', class = ',
        hook_quote(error$class),
        ')'
      ),
      if (!is.null(error$hook) || !is.null(error$stage)) {
        paste0(
          '  testthat::expect_identical(error$function_name, ',
          hook_quote(op$name),
          ')'
        )
      },
      if (!is.null(error$hook)) {
        paste0(
          '  testthat::expect_identical(error$hook_name, ',
          hook_quote(error$hook),
          ')'
        )
      },
      if (!is.null(error$stage)) {
        paste0(
          '  testthat::expect_identical(error$stage, ',
          hook_quote(error$stage),
          ')'
        )
      }
    )
  } else {
    c(
      paste0('  result <- ', call),
      paste0('  testthat::expect_equal(result, ', r_literal(case$result), ')')
    )
  }
  paste(
    c(
      '# Generated with specmill; do not edit by hand.',
      hook_integration_marker,
      paste0(
        'testthat::test_that(',
        hook_quote(paste(id, 'runs', op$name, 'hooks around its helper')),
        ', {'
      ),
      paste0('  expected <- ', r_literal(calls)),
      '  calls <- list()',
      '  events <- character()',
      '  record <- function(name) {',
      '    force(name)',
      '    function(...) {',
      '      events <<- c(events, name)',
      '      calls[[length(calls) + 1L]] <<- list(helper = name, arguments = list(...))',
      '      if (length(calls) > length(expected)) stop("Unexpected extra helper call")',
      '      expected[[length(calls)]]$response',
      '    }',
      '  }',
      '  watch <- function(name) {',
      '    force(name)',
      paste0(
        '    original <- get(name, envir = asNamespace(',
        hook_quote(package),
        '))'
      ),
      '    function(...) {',
      '      events <<- c(events, name)',
      '      original(...)',
      '    }',
      '  }',
      paste0(
        '  testthat::local_mocked_bindings(',
        paste(mocks, collapse = ', '),
        ', .package = ',
        hook_quote(package),
        ')'
      ),
      test_cache_off(op, package),
      if (length(case$environment)) {
        paste0(
          '  withr::local_envvar(',
          replay_character_literal(unlist(case$environment)),
          ')'
        )
      },
      outcome,
      paste0(
        "  testthat::expect_equal(calls, lapply(expected, function(x) x[c('helper', 'arguments')]))"
      ),
      if (!is.null(case$sequence)) {
        paste0(
          '  testthat::expect_identical(events, ',
          replay_character_literal(case$sequence),
          ')'
        )
      },
      '})'
    ),
    collapse = '\n'
  )
}
