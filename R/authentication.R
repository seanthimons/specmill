authentication_envvars <- function(document, package) {
  schemes <- document$components$securitySchemes %or%
    document$securityDefinitions %or%
    list()
  ids <- sort(names(schemes), method = 'radix')
  supported <- vapply(
    ids,
    function(id) {
      scheme <- local_ref(schemes[[id]], document)
      identical(scheme$type, 'apiKey') ||
        (identical(scheme$type, 'http') &&
          identical(tolower(scheme$scheme), 'bearer'))
    },
    logical(1)
  )
  ids <- ids[supported]
  if (!length(ids)) {
    return(setNames(list(), character()))
  }
  values <- toupper(paste(
    configuration_words(package),
    vapply(ids, configuration_words, character(1)),
    sep = '_'
  ))
  if (anyDuplicated(values)) {
    stop('Security scheme names produce colliding environment variables')
  }
  as.list(setNames(values, ids))
}

validate_security_correction <- function(correction) {
  config_fields(correction, c('requirements', 'reason'), 'security_correction')
  config_string(correction$reason, 'security_correction reason')
  requirements <- correction$requirements
  if (!is.list(requirements) || !is.null(names(requirements))) {
    stop('security_correction requirements must be a sequence')
  }
  for (requirement in requirements) {
    config_fields(
      requirement,
      names(requirement),
      'security_correction requirement'
    )
    for (scopes in requirement) {
      config_sequence(scopes, 'security_correction scopes')
    }
  }
}

operation_authentication <- function(operation, envvars) {
  requirements <- operation$security %or% list()
  if (!is.list(requirements) || !is.null(names(requirements))) {
    stop('Security must be an array')
  }
  lapply(requirements, function(requirement) {
    if (
      !is.list(requirement) ||
        (length(requirement) && is.null(names(requirement)))
    ) {
      stop('Security requirement must be an object')
    }
    lapply(names(requirement), function(id) {
      scheme <- operation$security_schemes[[id]]
      if (is.null(scheme)) {
        stop('Undefined security scheme: ', id)
      }
      type <- scheme$type
      supported <- identical(type, 'apiKey') ||
        (identical(type, 'http') && identical(tolower(scheme$scheme), 'bearer'))
      if (!supported) {
        return(list(scheme = id, type = type %or% 'unsupported'))
      }
      envvar <- config_string(
        envvars[[id]],
        paste('authentication environment variable for', id)
      )
      if (!grepl('^[A-Za-z_][A-Za-z0-9_]*$', envvar)) {
        stop('Invalid credential environment variable')
      }
      # Role lists (valid in OpenAPI 3.1, common in 3.0) never reach the wire.
      if (type == 'apiKey') {
        location <- config_string(scheme[['in']], 'API key location')
        if (!location %in% c('header', 'query', 'cookie')) {
          stop('Unsupported API key location')
        }
        name <- config_string(scheme$name, 'API key name')
        if (grepl('[\r\n]', name)) stop('Invalid API key name')
      } else {
        location <- 'header'
        name <- 'Authorization'
      }
      list(
        scheme = id,
        type = if (type == 'http') 'bearer' else type,
        location = location,
        name = name,
        envvar = envvar
      )
    })
  })
}

# Warns when one schema file protects some operations and leaves others without
# `security`: OpenAPI reads the gap as public, but it is often a schema omission.
warn_unsecured_operations <- function(operations) {
  for (source in unique(vapply(
    operations,
    function(op) op$source,
    character(1)
  ))) {
    own <- Filter(function(op) identical(op$source, source), operations)
    protected <- vapply(
      own,
      function(op) length(op$security) > 0L,
      logical(1)
    )
    missing <- vapply(
      own,
      function(op) is.null(op$security) && length(op$security_schemes) > 0L,
      logical(1)
    )
    if (any(protected) && any(missing)) {
      warning(
        basename(source),
        ': operations without security while others declare it (treated as public): ',
        paste(
          vapply(own[missing], function(op) op$id, character(1)),
          collapse = ', '
        ),
        '. Check the schema.',
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}
