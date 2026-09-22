public_input_validation_acceptance <- function() {
  native <- if (file.exists('tests/native-transport.R')) {
    'tests/native-transport.R'
  } else {
    'native-transport.R'
  }
  source(native, local = TRUE)
  native_transport_acceptance(function(runtime, root) {
    shapes <- list(
      enum = list(
        type = 'integer',
        enum = list(1L, 2L),
        minimum = 1L,
        maximum = 2L
      ),
      bounds = list(type = 'integer', minimum = 0L, maximum = 2L),
      string = list(
        type = 'string',
        minLength = 1L,
        maxLength = 3L,
        pattern = '^[a-z]+$'
      ),
      boolean = list(type = 'boolean'),
      array = list(
        type = 'array',
        items = list(type = 'integer', enum = list(1L, 2L)),
        minItems = 1L,
        maxItems = 2L
      )
    )
    good <- list(
      enum = 1L,
      bounds = 0L,
      string = 'abc',
      boolean = FALSE,
      array = list(1L, 2L)
    )
    bad <- list(
      enum = list(0L, 3L, '1', 1.5, NA),
      bounds = list(-1L, 3L, '0'),
      string = list('', 'abcd', 'A', 1L),
      boolean = list(0L, 'false'),
      array = list(list(), list(1L, 2L, 1L), list(3L), list('1'))
    )
    locations <- c('query', 'path', 'header', 'cookie', 'json', 'form')
    paths <- list()
    for (location in locations) {
      for (kind in names(shapes)) {
        name <- paste(location, kind, sep = '_')
        operation <- list(
          operationId = name,
          responses = list('200' = list(description = 'OK'))
        )
        path <- paste0('/', name, if (location == 'path') '/{value}')
        if (location %in% c('json', 'form')) {
          shape <- if (location == 'form') {
            list(
              type = 'object',
              required = list('value'),
              properties = list(value = shapes[[kind]])
            )
          } else {
            shapes[[kind]]
          }
          media <- if (location == 'form') {
            'application/x-www-form-urlencoded'
          } else {
            'application/json'
          }
          operation$requestBody <- list(
            required = TRUE,
            content = setNames(list(list(schema = shape)), media)
          )
        } else {
          operation$parameters <- list(list(
            name = if (location == 'header') 'x-test' else 'value',
            'in' = location,
            required = TRUE,
            schema = shapes[[kind]]
          ))
        }
        paths[[path]] <- setNames(
          list(operation),
          if (location %in% c('json', 'form')) 'post' else 'get'
        )
      }
    }
    schema <- tempfile(fileext = '.json')
    on.exit(unlink(schema), add = TRUE)
    jsonlite::write_json(
      list(
        openapi = '3.0.3',
        info = list(title = 'Public validation', version = '1'),
        paths = paths
      ),
      schema,
      auto_unbox = TRUE
    )
    parsed <- specmill::read_operations(schema)
    stopifnot(
      length(parsed$operations) == length(locations) * length(shapes),
      !length(parsed$diagnostics)
    )
    for (op in parsed$operations) {
      eval(
        parse(
          text = specmill::render_operation(op, list(helper = 'api_request'))
        ),
        runtime
      )
    }
    count <- function() {
      runtime$api_request('GET', '/count', list(), list(), NULL)$request_number
    }
    wire <- function(result) rawToChar(as.raw(unlist(result$bytes)))
    for (location in locations) {
      for (kind in names(shapes)) {
        fn <- runtime[[paste(location, kind, sep = '_')]]
        value <- good[[kind]]
        input <- if (location == 'form') list(value = value) else value
        result <- fn(input)
        expected <- switch(
          kind,
          enum = '1',
          bounds = '0',
          string = 'abc',
          boolean = if (location %in% c('query', 'path', 'header')) {
            'FALSE'
          } else {
            'false'
          },
          array = '1,2'
        )
        if (location == 'query') {
          stopifnot(
            result$query ==
              if (kind == 'array') {
                '?value=1&value=2'
              } else {
                paste0('?value=', expected)
              }
          )
        }
        if (location == 'path') {
          stopifnot(result$path == paste0('/path_', kind, '/', expected))
        }
        if (location == 'header') {
          stopifnot(result$parameter_header == expected)
        }
        if (location == 'cookie') {
          stopifnot(
            result$cookie ==
              if (kind == 'array') {
                'value=1; value=2'
              } else {
                paste0('value=', expected)
              }
          )
        }
        if (location == 'json') {
          stopifnot(
            wire(result) ==
              switch(kind, string = '"abc"', array = '[1,2]', expected)
          )
        }
        if (location == 'form') {
          stopifnot(
            wire(result) ==
              if (kind == 'array') {
                'value=1&value=2'
              } else {
                paste0('value=', expected)
              }
          )
        }
        before <- count()
        for (value in c(bad[[kind]], list(NULL))) {
          input <- if (location == 'form') list(value = value) else value
          stopifnot(inherits(tryCatch(fn(input), error = identity), 'error'))
        }
        stopifnot(
          inherits(tryCatch(fn(), error = identity), 'error'),
          count() == before + 1L
        )
      }
    }
    # Schema-derived aliases and explicit request bindings retain the public gate.
    op <- parsed$operations$query_enum
    op$parameters[[1L]]$public_name <- 'renamed'
    mapping <- list(
      helper = 'record',
      request = list(
        arguments = list(value = list(from = c('params', 'renamed')))
      )
    )
    runtime$record <- function(value) value
    eval(parse(text = specmill::render_operation(op, mapping)), runtime)
    stopifnot(
      runtime$query_enum(renamed = 2L) == 2L,
      inherits(
        tryCatch(runtime$query_enum(renamed = 3L), error = identity),
        'error'
      )
    )
    op$parameters[[1L]]$required <- FALSE
    eval(parse(text = specmill::render_operation(op, mapping)), runtime)
    stopifnot(is.null(runtime$query_enum()), is.null(runtime$query_enum(NULL)))
    cat(
      'Public inputs: six locations, types/enums/bounds/strings/arrays, omission, renamed mappings, exact localhost bytes and zero requests for rejected inputs passed.\n'
    )
  })
}
if (sys.nframe() == 0L) {
  public_input_validation_acceptance()
}
