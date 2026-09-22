numeric_fixtures_acceptance <- function() {
  file <- tempfile(fileext = '.json')
  on.exit(unlink(file), add = TRUE)
  read <- function(schema, media = NULL) {
    endpoint <- list(
      operationId = 'sample',
      responses = list(
        '200' = list(description = 'OK')
      )
    )
    if (is.null(media)) {
      endpoint$parameters <- list(list(
        name = 'value',
        'in' = 'query',
        required = TRUE,
        schema = schema
      ))
    } else {
      endpoint$requestBody <- list(
        required = TRUE,
        content = setNames(list(list(schema = schema)), media)
      )
    }
    jsonlite::write_json(
      list(
        openapi = '3.0.3',
        info = list(title = 'Numbers', version = '1'),
        paths = list('/sample' = list(post = endpoint))
      ),
      file,
      auto_unbox = TRUE
    )
    parsed <- specmill::read_operations(file)
    stopifnot(!length(parsed$diagnostics), length(parsed$operations) == 1L)
    parsed$operations
  }
  bounded <- list(type = 'integer', minimum = 8, maximum = 18)
  stopifnot(specmill::operation_fixtures(read(bounded))[[1L]]$value == 8)
  stopifnot(identical(
    specmill::operation_fixtures(read(list(type = 'integer')))[[1L]]$value,
    1L
  ))
  fails <- function(expr, pattern) {
    error <- tryCatch(force(expr), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  cases <- list(
    list(list(type = 'integer', minimum = 8), 8),
    list(list(type = 'integer', maximum = -2), -2),
    list(list(type = 'integer', minimum = -5, maximum = -2), -2),
    list(list(type = 'integer', minimum = 8, maximum = 8), 8),
    list(list(type = 'integer', minimum = 8.2, maximum = 9.8), 9),
    list(list(type = 'integer', minimum = -5.8, maximum = -2.2), -3),
    list(list(type = 'integer', minimum = 3e9, maximum = 3e9), 3e9),
    list(list(type = 'number', minimum = 0, maximum = 0.5), 0.5),
    list(list(type = 'number', minimum = 1.5), 1.5),
    list(list(type = 'number', minimum = 0.5, maximum = 0.5), 0.5)
  )
  for (case in cases) {
    stopifnot(
      specmill::operation_fixtures(read(case[[1L]]))[[1L]]$value == case[[2L]]
    )
  }
  for (schema in list(
    list(type = 'integer', minimum = 8.2, maximum = 8.8),
    list(type = 'number', minimum = 9, maximum = 8)
  )) {
    fails(
      specmill::operation_fixtures(read(schema)),
      'numeric interval has no solution'
    )
  }
  hinted <- c(bounded, list(example = 9, default = 10, enum = list(9, 10, 11)))
  for (expected in c(9, 10, 9)) {
    stopifnot(
      specmill::operation_fixtures(read(hinted))[[1L]]$value == expected
    )
    hinted[[if ('example' %in% names(hinted)) 'example' else 'default']] <- NULL
  }
  ops <- read(bounded)
  overrides <- setNames(list(list(value = 12)), ops[[1L]]$name)
  stopifnot(specmill::operation_fixtures(ops, overrides)[[1L]]$value == 12)
  overrides[[1L]]$value <- 3
  fails(specmill::operation_fixtures(ops, overrides), 'No valid fixture')
  invalid_hint <- c(bounded, list(example = 1, default = 10))
  fails(specmill::operation_fixtures(read(invalid_hint)), 'No valid fixture')
  for (hint in list(list(default = 3), list(enum = list(3)))) {
    fails(
      specmill::operation_fixtures(read(c(bounded, hint))),
      'No valid fixture'
    )
  }

  invoke <- function(ops, inputs) {
    runtime <- new.env(parent = baseenv())
    runtime$request <- function(...) list(...)
    eval(
      parse(
        text = specmill::render_operation(
          ops[[1L]],
          list(helper = 'request')
        )
      ),
      runtime
    )
    do.call(runtime[[ops[[1L]]$name]], inputs)
  }
  invoke(ops, specmill::operation_fixtures(ops)[[1L]])
  array <- list(type = 'array', items = bounded)
  stopifnot(identical(
    specmill::operation_fixtures(read(array))[[1L]]$value,
    8L
  ))
  for (media in c(
    'application/json',
    'application/x-www-form-urlencoded',
    'multipart/form-data'
  )) {
    body <- list(
      type = 'object',
      required = list('value', 'items'),
      properties = list(value = bounded, items = array)
    )
    ops <- read(body, media)
    inputs <- specmill::operation_fixtures(ops)[[1L]]
    stopifnot(inputs$body$value == 8, unlist(inputs$body$items) == 8)
    invoke(ops, inputs)
    inputs$body$value <- 3
    fails(invoke(ops, inputs), 'numeric bounds')
    overrides <- setNames(list(inputs), ops[[1L]]$name)
    fails(specmill::operation_fixtures(ops, overrides), 'numeric bounds')
    body$properties$value <- invalid_hint
    # Issue #38 now rejects invalid selected body examples without fallback.
    fails(
      specmill::operation_fixtures(read(body, media)),
      'No valid body fixture'
    )
  }
  cat('Numeric fixtures passed.\n')
}
if (sys.nframe() == 0L) {
  numeric_fixtures_acceptance()
}
