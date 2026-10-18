merge_settings <- function(defaults, overrides) {
  for (name in names(overrides)) {
    value <- overrides[[name]]
    if (
      is.list(value) &&
        !name %in% c('inputs', 'default') &&
        !(length(value) == 1L &&
          names(value) %in%
            c(
              'value',
              'from',
              'object',
              'compact_object',
              'array',
              'vector',
              'callback'
            )) &&
        !is.null(names(value)) &&
        is.list(defaults[[name]]) &&
        !is.null(names(defaults[[name]]))
    ) {
      defaults[[name]] <- merge_settings(defaults[[name]], value)
    } else {
      defaults[name] <- list(value)
    }
  }
  defaults
}

validate_settings <- function(
  settings,
  label,
  callbacks = new.env(parent = emptyenv())
) {
  config_fields(
    settings,
    c(
      'name',
      'helper',
      'file',
      'implementation',
      'parameters',
      'body',
      'inputs',
      'normalize_inputs',
      'validate_inputs',
      'defer_inputs',
      'extra_parameters',
      'request',
      'post_on_skip',
      'preserve_visibility',
      'result_formatter',
      'post_state',
      'private_params',
      'post_params',
      'post_response_scope',
      'post_params_source',
      'parameter_order',
      'docs',
      'batch',
      'pagination',
      'request_controls',
      'response_policy',
      'server',
      'body_media',
      'security_correction',
      'body_media_correction',
      'response_correction',
      'duplicate_response',
      'request_body_correction',
      'path_parameters_correction',
      'text_encoding',
      'query_array_style',
      'exclude_parameters',
      'routes',
      'route_guard',
      'specialization'
    ),
    label
  )
  if ('defer_inputs' %in% names(settings)) {
    deferred <- settings$defer_inputs
    if (
      (!is.list(deferred) && !is.character(deferred)) ||
        !length(deferred) ||
        !is.null(names(deferred))
    ) {
      stop('defer_inputs must be an unnamed sequence of client input names')
    }
    for (name in deferred) {
      if (
        !is.character(name) ||
          length(name) != 1L ||
          is.na(name) ||
          !identical(make.names(name), name)
      ) {
        stop('defer_inputs must contain client input names')
      }
    }
    if (anyDuplicated(unlist(deferred))) {
      stop('defer_inputs must be unique')
    }
    if (identical(settings$implementation, 'existing')) {
      stop('defer_inputs requires a generated implementation')
    }
  }
  if (!is.null(settings$duplicate_response)) {
    config_fields(
      settings$duplicate_response,
      c('source', 'reason'),
      paste(label, 'duplicate_response')
    )
    config_string(
      settings$duplicate_response$source,
      'duplicate_response.source'
    )
    config_string(
      settings$duplicate_response$reason,
      'duplicate_response.reason'
    )
  }
  if (!is.null(settings$result_formatter)) {
    config_string(settings$result_formatter, paste(label, 'result_formatter'))
    if (
      !identical(
        make.names(settings$result_formatter),
        settings$result_formatter
      )
    ) {
      stop('result_formatter must be a client function name')
    }
    if (identical(settings$implementation, 'existing')) {
      stop('result_formatter requires a generated implementation')
    }
  }
  for (field in c('post_response_scope', 'post_params_source')) {
    if (is.null(settings[[field]])) {
      next
    }
    value <- config_string(settings[[field]], paste(label, field))
    choices <- if (field == 'post_response_scope') {
      c('request', 'combined')
    } else {
      c('current', 'original')
    }
    if (!value %in% choices) {
      stop(field, ' must be ', paste(choices, collapse = ' or '))
    }
    if (identical(settings$implementation, 'existing')) {
      stop(field, ' requires a generated implementation')
    }
  }
  if ('private_params' %in% names(settings)) {
    private <- settings$private_params
    config_fields(private, names(private), paste(label, 'private_params'))
    if (
      !length(private) ||
        !all(
          vapply(
            names(private),
            function(name) identical(make.names(name), name),
            logical(1)
          )
        )
    ) {
      stop(
        'private_params must be a nonempty named mapping of private parameters'
      )
    }
    if (identical(settings$implementation, 'existing')) {
      stop('private_params requires a generated implementation')
    }
  }
  if ('post_params' %in% names(settings)) {
    selected <- settings$post_params
    if (
      (!is.list(selected) && !is.character(selected)) ||
        !is.null(names(selected)) ||
        !all(
          vapply(
            selected,
            function(name) {
              is.character(name) &&
                length(name) == 1L &&
                !is.na(name) &&
                identical(make.names(name), name)
            },
            logical(1)
          )
        ) ||
        anyDuplicated(unlist(selected))
    ) {
      stop('post_params must be an unnamed sequence of unique parameter names')
    }
    if (identical(settings$implementation, 'existing')) {
      stop('post_params requires a generated implementation')
    }
  }
  if ('preserve_visibility' %in% names(settings)) {
    value <- settings$preserve_visibility
    if (!is.logical(value) || length(value) != 1L || is.na(value)) {
      stop('preserve_visibility must be true or false')
    }
    if (isTRUE(value) && identical(settings$implementation, 'existing')) {
      stop('preserve_visibility requires a generated implementation')
    }
  }
  if (!is.null(settings$validate_inputs)) {
    name <- config_string(
      settings$validate_inputs,
      paste(label, 'validate_inputs')
    )
    if (!identical(make.names(name), name)) {
      stop('validate_inputs must name a client function')
    }
    if (identical(settings$implementation, 'existing')) {
      stop('validate_inputs requires a generated implementation')
    }
  }
  if ('normalize_inputs' %in% names(settings)) {
    normalizers <- settings$normalize_inputs
    config_fields(
      normalizers,
      names(normalizers),
      paste(label, 'normalize_inputs')
    )
    for (name in normalizers) {
      config_string(name, 'input normalizer')
      if (!identical(make.names(name), name)) {
        stop('Input normalizers must name client functions')
      }
    }
    if (identical(settings$implementation, 'existing')) {
      stop('normalize_inputs requires a generated implementation')
    }
  }
  if (!is.null(settings$security_correction)) {
    validate_security_correction(settings$security_correction)
  }
  if (!is.null(settings$body_media_correction)) {
    validate_body_media_correction(settings$body_media_correction)
  }
  if (!is.null(settings$response_correction)) {
    validate_response_correction(settings$response_correction)
  }
  if (!is.null(settings$request_body_correction)) {
    validate_request_body_correction(settings$request_body_correction)
  }
  if (!is.null(settings$path_parameters_correction)) {
    validate_path_parameters_correction(settings$path_parameters_correction)
  }
  if (!is.null(settings[['body_media']])) {
    config_string(settings[['body_media']], paste(label, 'body_media'))
    if (
      !settings[['body_media']] %in%
        c(
          'application/json',
          'application/octet-stream',
          'text/plain',
          'application/x-www-form-urlencoded',
          'multipart/form-data'
        )
    ) {
      stop('Unsupported body_media')
    }
  }
  if (!is.null(settings$text_encoding)) {
    config_string(settings$text_encoding, paste(label, 'text_encoding'))
    if (!settings$text_encoding %in% c('scalar', 'lines')) {
      stop('text_encoding must be scalar or lines')
    }
  }
  if (!is.null(settings$query_array_style)) {
    query_array_style(
      settings$query_array_style,
      paste(label, 'query_array_style')
    )
  }
  for (name in intersect(
    c(
      'name',
      'helper',
      'file',
      'implementation',
      'post_state',
      'specialization'
    ),
    names(settings)
  )) {
    config_string(settings[[name]], paste(label, name))
  }
  if (!is.null(settings$response_policy)) {
    name <- config_string(
      settings$response_policy,
      paste(label, 'response_policy')
    )
    if (!identical(make.names(name), name)) {
      stop('response_policy must be a client function name')
    }
  }
  if ('server' %in% names(settings)) {
    config_fields(settings$server, c('resolver', 'key'), paste(label, 'server'))
    name <- config_string(
      settings$server$resolver,
      paste(label, 'server resolver')
    )
    if (!identical(make.names(name), name)) {
      stop('server.resolver must be a client function name')
    }
    if (!is.null(settings$server$key)) {
      config_string(settings$server$key, paste(label, 'server key'))
    }
  }
  if ('request_controls' %in% names(settings)) {
    controls <- settings$request_controls
    config_fields(
      controls,
      c(
        'timeout',
        'max_retries',
        'retry_writes',
        'retry_policy',
        'preserve_errors'
      ),
      paste(label, 'request_controls')
    )
    if (
      'preserve_errors' %in%
        names(controls) &&
        (!is.logical(controls$preserve_errors) ||
          length(controls$preserve_errors) != 1L ||
          is.na(controls$preserve_errors))
    ) {
      stop('request_controls.preserve_errors must be true or false')
    }
    if (!is.null(controls$retry_policy)) {
      name <- config_string(controls$retry_policy, paste(label, 'retry_policy'))
      if (!identical(make.names(name), name)) {
        stop('request_controls.retry_policy must be a client function name')
      }
    }
    for (field in intersect(names(controls), c('timeout', 'max_retries'))) {
      value <- controls[[field]]
      if (
        !is.numeric(value) ||
          length(value) != 1L ||
          is.na(value) ||
          (field == 'timeout' && value <= 0) ||
          (field == 'max_retries' &&
            (!is.finite(value) ||
              value < 0 ||
              value != trunc(value) ||
              value >= .Machine$integer.max))
      ) {
        stop(
          'Invalid request_controls.',
          field,
          ': timeout must be positive (.inf for no limit); max_retries must be a nonnegative integer below .Machine$integer.max'
        )
      }
    }
    if (
      'retry_writes' %in%
        names(controls) &&
        (!is.logical(controls$retry_writes) ||
          length(controls$retry_writes) != 1L ||
          is.na(controls$retry_writes))
    ) {
      stop('request_controls.retry_writes must be true or false')
    }
  }
  if ('batch' %in% names(settings)) {
    config_fields(
      settings$batch,
      c(
        'max_items',
        'max_bytes',
        'fan_out',
        'split',
        'on_error',
        'empty',
        'metadata',
        'warning'
      ),
      'batch'
    )
    if (
      !is.null(settings$batch$metadata) &&
        !isTRUE(settings$batch$metadata) &&
        !isFALSE(settings$batch$metadata)
    ) {
      stop('batch.metadata must be true or false')
    }
    if (!is.null(settings$batch$fan_out)) {
      config_string(settings$batch$fan_out, 'batch.fan_out')
    }
    if (!is.null(settings$batch$warning) && !isFALSE(settings$batch$warning)) {
      config_string(settings$batch$warning, 'batch.warning')
    }
    if (!is.null(settings$batch$empty)) {
      config_string(settings$batch$empty, 'batch.empty')
    }
    if (
      !is.null(settings$batch$split) &&
        !isTRUE(settings$batch$split) &&
        !isFALSE(settings$batch$split)
    ) {
      stop('batch.split must be true or false')
    }
    on_error <- settings$batch$on_error
    if (is.list(on_error)) {
      config_fields(on_error, c('single', 'multiple'), 'batch.on_error')
      if (
        length(on_error) != 2L ||
          !setequal(names(on_error), c('single', 'multiple'))
      ) {
        stop('batch.on_error requires single and multiple')
      }
    } else {
      on_error <- if (is.null(on_error)) list() else list(on_error)
    }
    for (choice in on_error) {
      if (
        !is.character(choice) ||
          length(choice) != 1L ||
          is.na(choice) ||
          !choice %in% c('stop', 'drop')
      ) {
        stop('batch.on_error must be stop or drop')
      }
    }
    limits <- settings$batch[c('max_items', 'max_bytes')]
    binding <- settings$batch$max_items
    if (is.list(binding)) {
      config_fields(binding, c('env', 'default', 'cap'), 'batch.max_items')
      env <- config_string(binding$env, 'batch.max_items env')
      if (!grepl('^[A-Za-z_][A-Za-z0-9_]*$', env)) {
        stop('Invalid batch.max_items environment variable')
      }
      if (is.null(binding$default)) {
        stop('batch.max_items binding requires a default')
      }
      limits <- c(binding[c('default', 'cap')], settings$batch['max_bytes'])
    }
    for (limit in limits) {
      if (
        !is.null(limit) &&
          (!is.numeric(limit) ||
            length(limit) != 1L ||
            is.na(limit) ||
            !is.finite(limit) ||
            limit < 1 ||
            limit != floor(limit))
      ) {
        stop('Batch limits must be positive integers or null')
      }
    }
    if (
      is.list(binding) &&
        any(unlist(binding[c('default', 'cap')]) > .Machine$integer.max)
    ) {
      stop('batch.max_items default and cap must fit an R integer')
    }
  }
  if (!is.null(settings[['pagination']])) {
    pagination <- settings[['pagination']]
    config_fields(
      pagination,
      c(
        'mode',
        'parameter',
        'start',
        'completed',
        'max_pages',
        'metadata',
        'next_cursor',
        'items',
        'error_policy',
        'warn_limits',
        'warn_errors',
        'stop_on_empty',
        'on_limit'
      ),
      'pagination'
    )
    if (
      'metadata' %in%
        names(pagination) &&
        !isTRUE(pagination$metadata) &&
        !isFALSE(pagination$metadata)
    ) {
      stop('pagination.metadata must be true or false')
    }
    if (!is.null(pagination[['mode']])) {
      config_string(pagination[['mode']], 'pagination.mode')
      if (!pagination[['mode']] %in% c('page', 'cursor')) {
        stop(
          'pagination.mode must be page or cursor; offset paging is not available for generated wrappers yet'
        )
      }
    }
    if (!is.null(pagination[['parameter']])) {
      config_string(pagination[['parameter']], 'pagination.parameter')
    }
    if (!is.null(pagination[['completed']])) {
      config_string(pagination[['completed']], 'pagination.completed')
      if (
        !identical(pagination[['completed']], 'empty') &&
          !identical(
            make.names(pagination[['completed']]),
            pagination[['completed']]
          )
      ) {
        stop('pagination.completed must be empty or a client function name')
      }
    }
    for (field in c('next_cursor', 'items', 'on_limit')) {
      if (!is.null(pagination[[field]])) {
        value <- config_string(
          pagination[[field]],
          paste0('pagination.', field)
        )
        if (!identical(make.names(value), value)) {
          stop('Pagination callbacks must name client functions')
        }
      }
    }
    for (field in intersect(
      c('warn_limits', 'warn_errors', 'stop_on_empty'),
      names(pagination)
    )) {
      if (!isTRUE(pagination[[field]]) && !isFALSE(pagination[[field]])) {
        stop('pagination.', field, ' must be true or false')
      }
    }
    if (!is.null(pagination$error_policy)) {
      policy <- config_string(
        pagination$error_policy,
        'pagination.error_policy'
      )
      if (!policy %in% c('stop', 'partial', 'empty')) {
        stop('pagination.error_policy must be stop, partial, or empty')
      }
    }
    cursor <- identical(pagination$mode, 'cursor') ||
      (is.null(pagination$mode) && is.character(pagination$start))
    if (
      cursor &&
        !is.null(pagination$start) &&
        (!is.character(pagination$start) ||
          length(pagination$start) != 1L ||
          is.na(pagination$start))
    ) {
      stop('pagination.start must be NULL or one nonmissing cursor string')
    }
    for (field in if (cursor) 'max_pages' else c('start', 'max_pages')) {
      value <- pagination[[field]]
      if (
        !is.null(value) &&
          (!is.numeric(value) ||
            length(value) != 1L ||
            is.na(value) ||
            !is.finite(value) ||
            value != floor(value) ||
            value < (if (field == 'start') 0 else 1) ||
            value > .Machine$integer.max)
      ) {
        stop(
          'pagination.',
          field,
          ' must be a ',
          if (field == 'start') 'nonnegative' else 'positive',
          ' integer'
        )
      }
    }
  }
  if (
    'implementation' %in%
      names(settings) &&
      !settings$implementation %in% c('generated', 'existing')
  ) {
    stop('implementation must be generated or existing')
  }
  if (
    identical(settings$implementation, 'existing') &&
      !'inputs' %in% names(settings)
  ) {
    stop('Existing implementations require an explicit public input contract')
  }
  if (
    'post_state' %in%
      names(settings) &&
      !settings$post_state %in% c('parameters', 'hook_state')
  ) {
    stop('post_state must be parameters or hook_state')
  }
  if (
    'post_on_skip' %in%
      names(settings) &&
      (!is.logical(settings$post_on_skip) ||
        length(settings$post_on_skip) != 1L ||
        is.na(settings$post_on_skip))
  ) {
    stop('post_on_skip must be true or false')
  }
  for (field in intersect(
    c('parameters', 'extra_parameters', 'inputs'),
    names(settings)
  )) {
    config_fields(settings[[field]], names(settings[[field]]), field)
    for (parameter in settings[[field]]) {
      config_fields(
        parameter,
        if (field == 'parameters') {
          c('name', 'default', 'required', 'exclude', 'description')
        } else {
          c(
            'default',
            'required',
            'description',
            'type',
            if (field == 'inputs') 'missing_as_null'
          )
        },
        'parameter'
      )
      for (name in intersect(
        names(parameter),
        c('name', 'description', 'type')
      )) {
        config_string(parameter[[name]], paste('parameter', name))
      }
      for (flag in intersect(
        c('required', 'exclude', 'missing_as_null'),
        names(parameter)
      )) {
        if (
          !is.logical(parameter[[flag]]) ||
            length(parameter[[flag]]) != 1L ||
            is.na(parameter[[flag]])
        ) {
          stop(flag, ' must be true or false')
        }
      }
      if (isTRUE(parameter$missing_as_null) && !isTRUE(parameter$required)) {
        stop('missing_as_null requires an explicitly required public input')
      }
    }
  }
  if ('body' %in% names(settings)) {
    config_fields(settings[['body']], c('name', 'description'), 'body')
    if (!length(settings[['body']])) {
      stop(label, ': body override needs a name or description')
    }
    for (field in names(settings[['body']])) {
      config_string(settings[['body']][[field]], paste('body', field))
    }
    name <- settings[['body']]$name
    if (
      !is.null(name) &&
        (!identical(make.names(name), name) ||
          grepl('^(\\.\\.([0-9]+|\\.)|\\.\\.\\.)$', name) ||
          name %in% c('params', 'state', 'result', 'send', 'fetch', 'chunk', 'changed'))
    ) {
      stop(
        label,
        ': body name must be a valid R argument name that generated code does not use internally'
      )
    }
  }
  if ('parameter_order' %in% names(settings)) {
    config_sequence(settings$parameter_order, 'parameter_order')
  }
  if ('exclude_parameters' %in% names(settings)) {
    config_sequence(
      settings$exclude_parameters,
      paste(label, 'exclude_parameters')
    )
  }
  if ('routes' %in% names(settings)) {
    routes <- config_sequence(settings[['routes']], paste(label, 'routes'))
    if (
      anyDuplicated(routes) ||
        !all(
          grepl(
            '^.+ (GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|TRACE) /[^[:space:]]*$',
            routes
          )
        )
    ) {
      stop(label, ': routes must be unique schema-file METHOD /path references')
    }
  }
  if ('route_guard' %in% names(settings)) {
    guard <- settings$route_guard
    if (is.logical(guard)) {
      if (length(guard) != 1L || is.na(guard)) {
        stop('route_guard must be true, false or a method/path argument map')
      }
    } else {
      config_fields(guard, c('method', 'path'), 'route_guard')
      if (!setequal(names(guard), c('method', 'path'))) {
        stop('route_guard requires method and path argument names')
      }
      for (name in guard) {
        config_string(name, 'route_guard argument')
      }
      if (identical(guard$method, guard$path)) {
        stop('route_guard method and path must name distinct arguments')
      }
    }
    if (
      !identical(guard, FALSE) && identical(settings$implementation, 'existing')
    ) {
      stop('route_guard requires a generated implementation')
    }
  }
  if ('docs' %in% names(settings)) {
    validate_documentation(settings$docs)
  }
  if ('request' %in% names(settings)) {
    config_fields(settings[['request']], c('arguments'), 'request')
    config_fields(
      settings[['request']]$arguments,
      names(settings[['request']]$arguments),
      'request arguments'
    )
    for (binding in settings[['request']]$arguments) {
      validate_binding(binding, callbacks)
    }
  }
  invisible(settings)
}

configure_operation <- function(operation, service) {
  settings <- merge_settings(
    service$defaults %or% list(),
    service$operations[[operation$key]] %or% list()
  )
  validate_settings(
    settings,
    operation$id,
    service$callbacks %or% new.env(parent = emptyenv())
  )
  if (!is.null(settings$security_correction)) {
    correction <- settings$security_correction
    unknown <- setdiff(
      unlist(lapply(correction$requirements, names), use.names = FALSE),
      names(operation$security_schemes)
    )
    if (length(unknown)) {
      stop(
        'Undefined security scheme in security_correction: ',
        paste(unknown, collapse = ', ')
      )
    }
    operation$security <- config_data(correction$requirements)
    operation$security_correction <- config_data(correction)
  }
  if (!is.null(settings[['body']])) {
    if ('inputs' %in% names(settings)) {
      stop(
        'Body override cannot be combined with explicit inputs: ',
        operation$id
      )
    }
    if (is.null(operation$body)) {
      stop(
        'Body override requires an operation with a request body: ',
        operation$id
      )
    }
  }
  parameters <- operation$parameters
  ids <- vapply(parameters, function(p) paste(p$location, p$name), character(1))
  unknown <- setdiff(names(settings$parameters), ids)
  if (length(unknown)) {
    stop(
      'Unknown parameter override for ',
      operation$id,
      ': ',
      paste(unknown, collapse = ', ')
    )
  }
  keep <- rep(TRUE, length(parameters))
  for (i in seq_along(parameters)) {
    override <- settings$parameters[[ids[[i]]]]
    if (is.null(override)) {
      next
    }
    keep[[i]] <- !isTRUE(override$exclude)
    if ('name' %in% names(override)) {
      parameters[[i]]$public_name <- config_string(
        override$name,
        'public parameter name'
      )
    }
    if ('required' %in% names(override)) {
      parameters[[i]]$public_required <- override$required
    }
    if ('default' %in% names(override)) {
      parameters[[i]]['public_default'] <- list(config_data(override$default))
    }
    if ('description' %in% names(override)) {
      parameters[[i]]$schema$description <- config_string(
        override$description,
        'parameter description'
      )
    }
  }
  parameters <- parameters[keep]
  extra_parameters <- settings$extra_parameters
  if ('inputs' %in% names(settings)) {
    if (
      is.null(settings[['request']]) ||
        length(settings$parameters) ||
        length(extra_parameters)
    ) {
      stop(
        'Explicit inputs require a request mapping and replace parameter overrides/extras'
      )
    }
    operation$schema_parameters <- operation$parameters
    operation$schema_body <- operation$body
    operation$explicit_inputs <- TRUE
    operation['body'] <- list(NULL)
    operation$body_required <- FALSE
    parameters <- list()
    extra_parameters <- settings$inputs
  }
  for (name in names(extra_parameters)) {
    extra <- extra_parameters[[name]]
    default <- config_data(extra$default)
    if (
      is.list(default) &&
        !is.null(extra$type) &&
        extra$type %in% c('character', 'logical', 'numeric', 'integer')
    ) {
      default <- unlist(default, use.names = FALSE)
    }
    parameters[[length(parameters) + 1L]] <- list(
      name = name,
      location = 'client',
      public_name = name,
      public_type = extra$type,
      public_required = extra$required %or%
        ('inputs' %in% names(settings) && !'default' %in% names(extra)),
      public_default = default,
      missing_as_null = isTRUE(extra$missing_as_null),
      required = FALSE,
      schema = list(
        type = switch(
          extra$type %or% 'string',
          character = 'string',
          numeric = 'number',
          logical = 'boolean',
          extra$type %or% 'string'
        ),
        description = extra$description %or% name
      )
    )
  }
  public_names <- parameter_names(parameters)
  if (
    !is.null(settings[['body']]$name) &&
      settings[['body']]$name %in% public_names
  ) {
    stop(
      'Body name collides with parameter "',
      settings[['body']]$name,
      '": ',
      operation$id
    )
  }
  requested_names <- vapply(
    parameters,
    function(p) p$public_name %or% p$name,
    character(1)
  )
  explicit <- vapply(
    parameters,
    function(p) p$public_name %or% '',
    character(1)
  )
  if (
    any(nzchar(explicit) & explicit != public_names) ||
      any(
        nzchar(explicit) &
          requested_names %in% requested_names[duplicated(requested_names)]
      )
  ) {
    stop('Invalid or colliding public parameter name for ', operation$id)
  }
  if (length(settings$parameter_order)) {
    order <- unlist(settings$parameter_order, use.names = FALSE)
    ordered_operation <- operation
    ordered_operation$parameters <- parameters
    ordered_operation$body_name <- settings[['body']]$name
    inputs <- c(
      public_names,
      if (!is.null(operation$body)) body_argument_name(ordered_operation)
    )
    if (!all(order %in% inputs) || anyDuplicated(order)) {
      stop('Invalid public parameter_order for ', operation$id)
    }
    parameters <- parameters[match(
      c(intersect(order, public_names), setdiff(public_names, order)),
      public_names
    )]
  }
  operation$response_policy <- settings$response_policy
  if (!is.null(settings$server)) {
    operation$server_resolver <- c(
      list(
        name = settings$server$resolver,
        key = settings$server$key %or% operation$service
      ),
      if (!is.null(operation$server_relative)) {
        list(relative = operation$server_relative)
      }
    )
  }
  operation$request_controls <- config_data(settings$request_controls)
  operation$body_name <- settings[['body']]$name
  operation$body_description <- settings[['body']]$description
  operation$parameters <- parameters
  spec <- merge_settings(service, settings)
  list(operation = operation, spec = spec)
}

validate_binding <- function(binding, callbacks) {
  config_fields(
    binding,
    c(
      'value',
      'from',
      'object',
      'compact_object',
      'array',
      'vector',
      'callback'
    ),
    'request binding'
  )
  if (length(binding) != 1L) {
    stop(
      'Request binding must contain exactly one of value, from, object, compact_object, array, vector or callback'
    )
  }
  if ('from' %in% names(binding)) {
    path <- config_sequence(binding$from, 'request reference')
    if (!length(path) || !path[[1L]] %in% c('params', 'hook_state')) {
      stop('Request reference must start with params or hook_state')
    }
  }
  if ('array' %in% names(binding)) {
    if (!is.list(binding$array) || !is.null(names(binding$array))) {
      stop('Request array must be a sequence of bindings')
    }
    for (child in binding$array) {
      validate_binding(child, callbacks)
    }
  }
  for (field in intersect(
    names(binding),
    c('object', 'compact_object', 'vector')
  )) {
    config_fields(
      binding[[field]],
      names(binding[[field]]),
      paste('request', field)
    )
    for (child in binding[[field]]) {
      validate_binding(child, callbacks)
    }
  }
  if ('callback' %in% names(binding)) {
    name <- config_string(binding$callback, 'request callback')
    if (!exists(name, envir = callbacks, mode = 'function', inherits = FALSE)) {
      stop('Unresolved callback: ', name)
    }
  }
  invisible(binding)
}

request_binding <- function(
  binding,
  parameters,
  has_hook,
  operation = NULL,
  callbacks = new.env(parent = emptyenv())
) {
  if ('value' %in% names(binding)) {
    return(r_literal(config_data(binding$value)))
  }
  if ('callback' %in% names(binding)) {
    callback <- get(
      binding$callback,
      envir = callbacks,
      mode = 'function',
      inherits = FALSE
    )
    return(r_literal(callback(operation)))
  }
  if ('array' %in% names(binding)) {
    return(paste0(
      'base::list(',
      paste(
        vapply(
          binding$array,
          function(child) {
            request_binding(child, parameters, has_hook, operation, callbacks)
          },
          character(1)
        ),
        collapse = ', '
      ),
      ')'
    ))
  }
  for (field in intersect(
    names(binding),
    c('object', 'compact_object', 'vector')
  )) {
    values <- binding[[field]]
    return(paste0(
      if (field == 'vector') {
        'base::c('
      } else if (field == 'compact_object') {
        'base::local({ .body <- base::Filter(base::Negate(base::is.null), base::list('
      } else {
        'base::list('
      },
      paste(
        vapply(
          names(values),
          function(name) {
            paste0(
              r_literal(name),
              ' = ',
              request_binding(
                values[[name]],
                parameters,
                has_hook,
                operation,
                callbacks
              )
            )
          },
          character(1)
        ),
        collapse = ', '
      ),
      if (field == 'compact_object') {
        ')); if (base::length(.body)) .body else base::list() })'
      } else {
        ')'
      }
    ))
  }
  path <- unlist(binding$from, use.names = FALSE)
  if (
    path[[1L]] == 'params' && length(path) > 1L && !path[[2L]] %in% parameters
  ) {
    stop('Request references missing public parameter: ', path[[2L]])
  }
  if (path[[1L]] == 'hook_state' && !has_hook) {
    stop('Request references hook_state without a pre-request hook')
  }
  text_reference <- operation$text_body_reference
  if (
    path[[1L]] == 'params' &&
      length(path) > 1L &&
      path[[2L]] %in% names(text_reference)
  ) {
    expression <- unname(text_reference[[path[[2L]]]])
    path <- path[-1L]
  } else {
    expression <- if (path[[1L]] == 'params') 'params' else 'state'
  }
  for (name in path[-1L]) {
    expression <- paste0(expression, '[[', r_literal(name), ']]')
  }
  expression
}
