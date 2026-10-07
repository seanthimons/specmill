# Use the same value for generation checks and the emitted R argument default.
parameter_default <- function(p) {
  value <- if ('public_default' %in% names(p)) {
    p$public_default
  } else {
    p$schema$default
  }
  if (identical(p$schema$type, 'array') && is.list(value)) {
    value <- if (length(value)) {
      unlist(value, use.names = FALSE)
    } else {
      switch(
        p$schema$items$type,
        string = character(),
        integer = integer(),
        number = numeric(),
        boolean = logical()
      )
    }
  }
  number_value(value, p$schema)
}

# Reuse the encoder from our own shipped template. Never execute a client
# helper or prepare an HTTP request while checking a generation default.
parameter_default_encoder <- function() {
  request <- parse(text = request_helper_template())[[1L]][[3L]]
  statements <- as.list(body(eval(request, baseenv())))
  encoder <- Filter(
    function(x) {
      is.call(x) &&
        identical(x[[1L]], as.name('<-')) &&
        identical(x[[2L]], as.name('encode_parameter'))
    },
    statements
  )
  if (length(encoder) != 1L) {
    stop('Missing parameter encoder in request template')
  }
  eval(encoder[[1L]][[3L]], baseenv())
}

parameter_default_diagnostics <- function(operation, native_transport = TRUE) {
  diagnostics <- list()
  encode <- NULL
  for (p in operation$parameters) {
    if (
      !p$location %in% c('path', 'query', 'header', 'cookie') ||
        isTRUE(p$public_required %or% p$required)
    ) {
      next
    }
    origin <- if ('public_default' %in% names(p)) 'configuration' else 'schema'
    value <- if ('public_default' %in% names(p)) {
      p$public_default
    } else {
      p$schema$default
    }
    # NULL is omission for optional parameter transports, regardless of schema
    # nullability. An absent default also emits NULL.
    if (is.null(value)) {
      next
    }
    phase <- 'schema'
    error <- tryCatch(
      {
        parameter_values(
          setNames(list(value), p$name),
          setNames(list(p$schema), p$name),
          body_value,
          setNames(list(p$location), p$name)
        )
        # Validate the original container before converting a JSON/YAML array
        # into its R vector representation. Never flatten an invalid default.
        value <- parameter_default(p)
        phase <- 'transport'
        if (
          p$location == 'query' &&
            !isTRUE(p$allow_empty_value) &&
            is.character(value) &&
            any(!nzchar(value))
        ) {
          stop('Empty query parameter: ', p$name, call. = FALSE)
        }
        if (native_transport) {
          if (is.null(encode)) {
            encode <- parameter_default_encoder()
          }
          wire <- p
          if (!is.null(p$wire_type)) {
            wire$schema$type <- p$wire_type
          }
          wire$style <- p$style %or%
            if (p$location %in% c('path', 'header')) 'simple' else 'form'
          wire$explode <- p$explode %or% (wire$style == 'form')
          encode(value, wire)
        }
        NULL
      },
      error = identity
    )
    if (is.null(error)) {
      next
    }
    diagnostics[[length(diagnostics) + 1L]] <- list(
      id = operation$id,
      service = operation$service,
      key = operation$key,
      source = operation$source,
      status = 'unsupported',
      parameter = p$name,
      location = p$location,
      default_origin = origin,
      default = value,
      classification = 'review_required',
      code = paste0('parameter_default_', phase),
      source_location = if (origin == 'schema') {
        schema_location(p$source_location %or% '#', 'default')
      } else {
        p$source_location %or% '#'
      },
      configuration_setting = if (origin == 'configuration') {
        paste0('parameters["', p$location, ' ', p$name, '"].default')
      } else {
        NULL
      },
      reason = paste0(
        'Invalid ',
        origin,
        ' default for ',
        p$location,
        ' parameter ',
        p$name,
        ' (',
        substr(r_literal(value), 1L, 160L),
        '): ',
        conditionMessage(error)
      ),
      guidance = paste0(
        'Set an explicit valid default or NULL omission with parameters["',
        p$location,
        ' ',
        p$name,
        '"]; default annotations are not schema assertions.'
      )
    )
  }
  diagnostics
}
