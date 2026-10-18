validate_request_pagination <- function(paging, callbacks) {
  config_fields(
    paging,
    c(
      'when',
      'mode',
      'parameter',
      'size_parameter',
      'page_size',
      'start',
      'max_pages',
      'items',
      'completed',
      'advance',
      'metadata',
      'error_policy',
      'warn_limits',
      'warn_errors',
      'stop_on_empty'
    ),
    'request.pagination'
  )
  if (!identical(paging$mode, 'offset')) {
    stop('request.pagination.mode must be offset')
  }
  for (field in c('when', 'page_size', 'start')) {
    if (is.null(paging[[field]])) {
      stop('request.pagination requires ', field)
    }
    validate_binding(paging[[field]], callbacks)
  }
  for (field in c('parameter', 'size_parameter')) {
    value <- paging[[field]]
    if (
      !is.null(names(value)) ||
        (is.list(value) &&
          !all(
            vapply(
              value,
              function(x) is.character(x) && length(x) == 1L,
              logical(1)
            )
          ))
    ) {
      stop('request.pagination.', field, ' must be an unnamed path')
    }
    path <- unlist(value, use.names = FALSE)
    if (
      !is.character(path) ||
        length(path) < 2L ||
        anyNA(path) ||
        !all(nzchar(path)) ||
        path[[1L]] != 'body'
    ) {
      stop('request.pagination.', field, ' must be a nested body argument path')
    }
  }
  for (field in c('items', 'completed', 'advance')) {
    name <- config_string(paging[[field]], paste0('request.pagination.', field))
    if (!identical(make.names(name), name)) {
      stop('request.pagination callbacks must name client functions')
    }
  }
  max_pages <- paging$max_pages %or% 100L
  if (
    !is.numeric(max_pages) ||
      length(max_pages) != 1L ||
      !is.finite(max_pages) ||
      max_pages < 1 ||
      max_pages != trunc(max_pages) ||
      max_pages >= .Machine$integer.max
  ) {
    stop(
      'request.pagination.max_pages must be a positive integer below .Machine$integer.max'
    )
  }
  for (field in intersect(
    c('metadata', 'warn_limits', 'warn_errors', 'stop_on_empty'),
    names(paging)
  )) {
    if (!isTRUE(paging[[field]]) && !isFALSE(paging[[field]])) {
      stop('request.pagination.', field, ' must be true or false')
    }
  }
  if (
    !is.null(paging$error_policy) &&
      !config_string(
        paging$error_policy,
        'request.pagination.error_policy'
      ) %in%
        c('stop', 'partial', 'empty')
  ) {
    stop('request.pagination.error_policy must be stop, partial or empty')
  }
}

render_request_pagination <- function(
  request,
  operation,
  spec,
  parameters,
  has_hook
) {
  paging <- spec$request$pagination
  if (
    isTRUE(spec$preserve_visibility) ||
      !is.null(operation$iterate) ||
      !is.null(operation$paginate) ||
      (!is.null(spec$route_guard) && !identical(spec$route_guard, FALSE))
  ) {
    stop(
      'request.pagination cannot combine with batch iteration, operation pagination or route_guard'
    )
  }
  required <- c('method', 'path', 'path_params', 'query', 'body')
  if (!all(required %in% names(spec$request$arguments))) {
    stop(
      'request.pagination requires complete native method/path/path_params/query/body bindings'
    )
  }
  helper <- spec$helper
  callback <- function(name) {
    paste0(
      'base::get(',
      r_literal(name),
      ', envir = base::environment(',
      helper,
      '_pages), mode = "function", inherits = FALSE)'
    )
  }
  binding <- function(field) {
    request_binding(
      paging[[field]],
      parameters,
      has_hook,
      operation,
      spec$callbacks %or% new.env(parent = emptyenv())
    )
  }
  call <- parse(text = request)[[1L]][[3L]]
  call[[1L]] <- quote(base::list)
  arguments <- tail(
    make.unique(c(
      parameters,
      'params',
      'state',
      'result',
      '.paging_arguments'
    )),
    1L
  )
  native <- callback(helper)
  c(
    paste0('  ', arguments, ' <- ', paste(deparse(call), collapse = '\n')),
    paste0('  if (', binding('when'), ' && TRUE) {'),
    paste0(
      '    result <- ',
      helper,
      '_pages(function(page) base::do.call(',
      native,
      ', utils::modifyList(',
      arguments,
      ', page, keep.null = TRUE), quote = TRUE),'
    ),
    paste0(
      '      parameter = ',
      r_literal(unlist(paging$parameter, use.names = FALSE)),
      ', start = ',
      binding('start'),
      ', max_pages = ',
      r_literal(as.integer(paging$max_pages %or% 100L)),
      ','
    ),
    paste0(
      '      mode = "offset", size_parameter = ',
      r_literal(unlist(paging$size_parameter, use.names = FALSE)),
      ', page_size = ',
      binding('page_size'),
      ','
    ),
    paste0(
      '      items = ',
      callback(paging$items),
      ', completed = ',
      callback(paging$completed),
      ', advance = ',
      callback(paging$advance),
      ','
    ),
    paste0(
      '      error_policy = ',
      r_literal(paging$error_policy %or% 'stop'),
      ', warn_limits = ',
      r_literal(!isFALSE(paging$warn_limits)),
      ', warn_errors = ',
      r_literal(!isFALSE(paging$warn_errors)),
      ', stop_on_empty = ',
      r_literal(!isFALSE(paging$stop_on_empty)),
      ')'
    ),
    if (isFALSE(paging$metadata)) {
      '    if (!base::inherits(result, "httr2_request") && !base::is.null(result)) base::attr(result, "pagination") <- NULL'
    },
    '  } else {',
    paste0(
      '    result <- base::do.call(',
      native,
      ', ',
      arguments,
      ', quote = TRUE)'
    ),
    '  }'
  )
}
