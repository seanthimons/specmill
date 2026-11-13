legacy_runtime_controls_acceptance <- function() {
  withr::local_options(list(
    ComptoxR.run_verbose = NULL,
    comptoxr_native.run_verbose = NULL,
    comptoxr_native.dry_run = NULL
  ))
  withr::local_envvar(c(COMPTOXR_NATIVE_DRY_RUN = 'true'))
  scaffold <- getFromNamespace('request_helper_scaffold', 'specmill')(
    'api_request',
    'https://example.invalid',
    NULL,
    'COMPTOXR_NATIVE_DRY_RUN'
  )
  runtime <- new.env(parent = baseenv())
  eval(parse(text = scaffold$code), runtime)
  runtime$.ComptoxREnv <- new.env(parent = emptyenv())
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(schema), add = TRUE)
  writeLines(
    '{"openapi":"3.0.3","servers":[{"url":"https://example.invalid"}],"info":{"title":"Services","version":"1"},"paths":{"/api/services/version":{"get":{"operationId":"chemi_services_version","responses":{"200":{"description":"Version"}}}}}}',
    schema
  )
  operation <- specmill::read_operations(schema)$operations[[1L]]
  eval(
    parse(
      text = specmill::render_operation(operation, list(helper = 'api_request'))
    ),
    runtime
  )
  calls <- 0L
  messages <- character()
  request <- function() {
    withCallingHandlers(
      httr2::with_mocked_responses(
        function(req) {
          calls <<- calls + 1L
          httr2::response(
            status_code = 200L,
            headers = list('content-type' = 'application/json'),
            body = charToRaw('{}')
          )
        },
        runtime$chemi_services_version()
      ),
      message = function(m) {
        messages <<- c(messages, trimws(conditionMessage(m)))
        invokeRestart('muffleMessage')
      }
    )
  }
  # Reproduce the legacy mismatch without letting the request reach the network.
  options(comptoxr_native.dry_run = FALSE, ComptoxR.run_verbose = TRUE)
  runtime$.ComptoxREnv$run_debug <- TRUE
  stopifnot(
    !inherits(request(), 'httr2_request'),
    calls == 1L,
    !length(messages)
  )

  # Exercise the documented integration recipe itself, keeping it executable.
  # Source checkouts read the vignette; built packages read the installed copy.
  guide_path <- if (is.null(source_root())) {
    system.file('doc', 'existing-clients.Rmd', package = 'specmill')
  } else {
    file.path(source_root(), 'vignettes', 'existing-clients.Rmd')
  }
  if (!nzchar(guide_path) || !file.exists(guide_path)) {
    skip('existing-clients guide is not available')
  }
  guide <- readLines(guide_path)
  start <- match('```{r legacy-runtime-setters, eval=FALSE}', guide)
  stopifnot(!is.na(start))
  end <- start + match('```', guide[(start + 1L):length(guide)])
  eval(parse(text = guide[(start + 1L):(end - 1L)]), runtime)
  runtime$run_debug(TRUE)
  runtime$run_verbose(TRUE)
  stopifnot(
    inherits(request(), 'httr2_request'),
    calls == 1L,
    identical(messages, 'GET request (dry run)'),
    isTRUE(runtime$.ComptoxREnv$run_debug),
    isTRUE(getOption('ComptoxR.run_verbose'))
  )
  for (invalid in list(NULL, NA, 'true', c(TRUE, FALSE))) {
    for (setter in c('run_debug', 'run_verbose')) {
      stopifnot(inherits(
        tryCatch(runtime[[setter]](invalid), error = identity),
        'error'
      ))
    }
  }
  runtime$run_debug(FALSE)
  runtime$run_verbose(FALSE)
  messages <- character()
  stopifnot(
    !inherits(request(), 'httr2_request'),
    calls == 2L,
    !length(messages),
    identical(runtime$.ComptoxREnv$run_debug, FALSE),
    identical(getOption('ComptoxR.run_verbose'), FALSE)
  )
  options(comptoxr_native.dry_run = NULL)
  stopifnot(inherits(request(), 'httr2_request'), calls == 2L)
  cat(
    'Legacy runtime controls: documented setters preserve state, prevent transport and override environment flags.\n'
  )
}
test_that('legacy runtime controls and documented setters keep working', {
  legacy_runtime_controls_acceptance()
  succeed()
})
