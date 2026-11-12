# Saved GraphQL introspection results to IR. Sources are reviewed local JSON
# files; nothing is fetched. Schema language (SDL) files, subscriptions, named
# and inline fragments, and automatic pagination are not implemented.
graphql_schema <- function(document) {
  if (!is.list(document)) {
    return(NULL)
  }
  schema <- document[['__schema']]
  if (is.null(schema) && is.list(document[['data']])) {
    schema <- document[['data']][['__schema']]
  }
  if (is.list(schema) && is.list(schema$types)) schema
}

graphql_detect <- function(path, document) {
  if (is.null(graphql_schema(document))) 0 else 1
}

# The innermost named type of a type reference such as [String!]!.
graphql_named <- function(ref) {
  while (!is.null(ref$ofType)) {
    ref <- ref$ofType
  }
  ref
}

graphql_type_text <- function(ref) {
  switch(
    ref$kind,
    NON_NULL = paste0(graphql_type_text(ref$ofType), '!'),
    LIST = paste0('[', graphql_type_text(ref$ofType), ']'),
    ref$name
  )
}

graphql_required <- function(value) {
  identical(value$type$kind, 'NON_NULL') && is.null(value$defaultValue)
}

graphql_ir_type <- function(ref) {
  switch(
    ref$kind,
    NON_NULL = graphql_ir_type(ref$ofType),
    LIST = list(kind = 'list', items = graphql_ir_type(ref$ofType)),
    SCALAR = switch(
      ref$name,
      String = list(kind = 'scalar', name = 'string'),
      ID = list(kind = 'scalar', name = 'string', native_type = 'ID'),
      Int = list(kind = 'scalar', name = 'integer', bits = 32L),
      Float = list(kind = 'scalar', name = 'float'),
      Boolean = list(kind = 'scalar', name = 'boolean'),
      list(kind = 'ref', name = ref$name)
    ),
    list(kind = 'ref', name = ref$name)
  )
}

graphql_described <- function(node, source) {
  if (is.character(source$description) && nzchar(source$description)) {
    node$description <- source$description
  }
  if (isTRUE(source$isDeprecated)) {
    node$deprecated <- TRUE
  }
  node
}

graphql_named_type <- function(type) {
  members <- function(values) {
    unname(lapply(values, function(value) {
      graphql_described(
        list(
          name = value$name,
          required = graphql_required(value),
          type = graphql_ir_type(value$type)
        ),
        value
      )
    }))
  }
  node <- switch(
    type$kind,
    OBJECT = c(
      list(kind = 'record', fields = members(type$fields)),
      if (length(type$interfaces)) {
        list(
          implements = unname(lapply(type$interfaces, function(x) x$name))
        )
      }
    ),
    INTERFACE = list(
      kind = 'record',
      abstract = TRUE,
      fields = members(type$fields)
    ),
    INPUT_OBJECT = list(kind = 'record', fields = members(type$inputFields)),
    UNION = list(
      kind = 'union',
      mode = 'one_of',
      discriminator = list(property = '__typename'),
      variants = unname(lapply(type$possibleTypes, function(x) {
        list(kind = 'ref', name = x$name)
      }))
    ),
    ENUM = list(
      kind = 'enum',
      base = 'string',
      values = unname(lapply(type$enumValues, function(value) {
        graphql_described(list(value = value$name), value)
      }))
    ),
    # A custom scalar's wire form is defined by the service, not the schema.
    list(kind = 'any', lossy = list('custom_scalar'))
  )
  node$native_type <- type$name
  if (is.character(type$description) && nzchar(type$description)) {
    node$description <- type$description
  }
  node
}

# Field names are checked against the type they are selected on. Fields that
# take required arguments, and members of unions and interfaces other than
# __typename, need a reviewed query document.
graphql_selection <- function(fields, type, types, at) {
  fail <- function(...) {
    schema_problem('graphql_selection', 'review_required', paste0(...), at)
  }
  leaf <- type$kind %in% c('SCALAR', 'ENUM')
  if (leaf) {
    if (length(fields)) {
      fail(type$name, ' has no fields to select')
    }
    return('')
  }
  if (!length(fields)) {
    schema_problem(
      'selection_required',
      'review_required',
      paste0('Select at least one field of ', type$name),
      at
    )
  }
  # Unions have no fields of their own; only __typename can be selected.
  available <- if (length(type$fields)) {
    stats::setNames(
      type$fields,
      vapply(type$fields, `[[`, character(1), 'name')
    )
  } else {
    list()
  }
  parts <- vapply(
    seq_along(fields),
    function(i) {
      entry <- fields[[i]]
      nested <- NULL
      name <- entry
      if (is.list(entry)) {
        if (length(entry) != 1L || is.null(names(entry))) {
          fail('A nested selection is one field name with a field list')
        }
        name <- names(entry)
        nested <- entry[[1L]]
      }
      if (!is.character(name) || length(name) != 1L || is.na(name)) {
        fail('Field names must be strings')
      }
      if (identical(name, '__typename') && is.null(nested)) {
        return(name)
      }
      field <- available[[name]]
      if (is.null(field)) {
        fail(type$name, ' has no field ', name)
      }
      if (any(vapply(field$args, graphql_required, logical(1)))) {
        fail(type$name, '.', name, ' takes required arguments')
      }
      target <- types[[graphql_named(field$type)$name]]
      object <- !target$kind %in% c('SCALAR', 'ENUM')
      if (object && is.null(nested)) {
        fail(type$name, '.', name, ' needs a nested field list')
      }
      paste0(name, graphql_selection(nested, target, types, at))
    },
    character(1)
  )
  if (anyDuplicated(parts)) {
    fail('Repeated field in the selection of ', type$name)
  }
  paste0(' { ', paste(parts, collapse = ' '), ' }')
}

# One level of scalar and enum fields, the default written at initialization.
graphql_default_fields <- function(type, types) {
  if (type$kind %in% c('SCALAR', 'ENUM')) {
    return(list())
  }
  unname(lapply(
    Filter(
      function(field) {
        types[[graphql_named(field$type)$name]]$kind %in%
          c('SCALAR', 'ENUM') &&
          !isTRUE(field$isDeprecated) &&
          !any(vapply(field$args, graphql_required, logical(1)))
      },
      type$fields
    ),
    `[[`,
    'name'
  ))
}

# Arguments are always sent as variables, never written into the document.
graphql_document <- function(operation_type, field, selection) {
  # A default keeps a non-null variable optional, as it is for the argument.
  declared <- vapply(
    field$args,
    function(arg) {
      paste0(
        '$',
        arg$name,
        ': ',
        graphql_type_text(arg$type),
        if (!is.null(arg$defaultValue)) paste0(' = ', arg$defaultValue)
      )
    },
    character(1)
  )
  passed <- vapply(
    field$args,
    function(arg) paste0(arg$name, ': $', arg$name),
    character(1)
  )
  paste0(
    operation_type,
    ' ',
    field$name,
    if (length(declared)) paste0('(', paste(declared, collapse = ', '), ')'),
    ' { ',
    field$name,
    if (length(passed)) paste0('(', paste(passed, collapse = ', '), ')'),
    selection,
    ' }'
  )
}

graphql_source <- function(path) {
  document <- jsonlite::read_json(path)
  schema <- graphql_schema(document)
  if (is.null(schema)) {
    cli::cli_abort(
      'GraphQL import requires a saved introspection result with __schema.types'
    )
  }
  names <- vapply(
    schema$types,
    function(type) type$name %or% '',
    character(1)
  )
  if (anyDuplicated(names) || !all(nzchar(names))) {
    cli::cli_abort('GraphQL introspection result repeats or omits a type name')
  }
  wrapped <- is.null(document[['__schema']])
  list(
    schema = schema,
    types = stats::setNames(schema$types, names),
    pointer = if (wrapped) '/data/__schema' else '/__schema'
  )
}

# Root fields in schema order, with the operation type that reaches them.
graphql_roots <- function(source) {
  roots <- list()
  for (operation_type in c('query', 'mutation')) {
    name <- source$schema[[paste0(operation_type, 'Type')]]$name
    index <- match(name %or% '', names(source$types))
    if (is.na(index)) {
      next
    }
    fields <- source$types[[index]]$fields
    for (i in seq_along(fields)) {
      roots[[length(roots) + 1L]] <- list(
        operation_type = operation_type,
        field = fields[[i]],
        key = paste(operation_type, fields[[i]]$name),
        pointer = paste0(
          source$pointer,
          '/types/',
          index - 1L,
          '/fields/',
          i - 1L
        )
      )
    }
  }
  roots
}

importer_graphql <- function(path, policy = list()) {
  source <- graphql_source(path)
  file <- normalizePath(path, winslash = '/', mustWork = TRUE)
  endpoint <- policy$graphql_path %or% '/graphql'
  roots <- graphql_roots(source)
  builtin <- c('String', 'ID', 'Int', 'Float', 'Boolean')
  named <- Filter(
    function(type) !startsWith(type$name, '__') && !type$name %in% builtin,
    source$types
  )
  title <- tools::file_path_sans_ext(basename(path))
  service <- list(
    id = policy$service %or% configuration_words(title),
    title = title
  )
  source_id <- 'graphql'
  diagnostics <- list()
  if (!is.null(source$schema$subscriptionType$name)) {
    diagnostics <- list(list(
      code = 'subscriptions_unsupported',
      reason = 'Subscription fields are not imported.',
      source_location = list(
        file = file,
        pointer = paste0(source$pointer, '/subscriptionType')
      )
    ))
  }
  queries <- vapply(
    Filter(function(root) root$operation_type == 'query', roots),
    function(root) root$field$name,
    character(1)
  )
  operations <- lapply(roots, function(root) {
    field <- root$field
    # A mutation that shares its name with a query gets a distinct wrapper name.
    name <- if (root$operation_type == 'mutation' && field$name %in% queries) {
      paste0('mutate_', field$name)
    } else {
      field$name
    }
    summary <- strsplit(field$description %or% '', '\n', fixed = TRUE)[[1L]]
    summary <- sub('^([^.]*[.]).*$', '\\1', c(summary, '')[[1L]])
    op <- list(
      key = root$key,
      id = paste(service$id, root$key),
      name = name,
      native_name = field$name,
      summary = if (nzchar(summary)) summary else root$key,
      tags = list(root$operation_type),
      paradigm = 'graphql',
      source = source_id,
      binding = list(
        operation_type = root$operation_type,
        field = field$name,
        method = 'POST',
        path = endpoint
      ),
      parameters = unname(lapply(field$args, function(arg) {
        type <- graphql_ir_type(arg$type)
        type$native_type <- graphql_type_text(arg$type)
        if (is.character(arg$description) && nzchar(arg$description)) {
          type$description <- arg$description
        }
        if (!is.null(arg$defaultValue)) {
          type$native <- list(default_value = arg$defaultValue)
        }
        list(
          name = arg$name,
          location = 'argument',
          required = graphql_required(arg),
          type = type
        )
      })),
      responses = list(list(
        status = 'data',
        media = 'application/json',
        type = graphql_ir_type(field$type)
      )),
      errors = list(list(
        when = list(body_path = list('errors'), present = TRUE),
        message_path = list('errors'),
        description = 'GraphQL reports failures in an errors array, also with HTTP 200.'
      )),
      source_location = list(file = file, pointer = root$pointer)
    )
    graphql_described(op, field)
  })
  ir <- list(
    ir_version = '1',
    paradigm = 'graphql',
    service = service,
    sources = list(list(
      id = source_id,
      format = 'graphql',
      format_version = '',
      importer_version = '1',
      file = file,
      hash = list(
        algorithm = 'sha256',
        value = digest::digest(file = path, algo = 'sha256')
      ),
      servers = list(),
      auth_schemes = stats::setNames(list(), character()),
      types = if (length(named)) {
        lapply(named, graphql_named_type)
      } else {
        stats::setNames(list(), character())
      }
    )),
    operations = operations,
    diagnostics = diagnostics
  )
  problems <- validate_ir(ir)
  if (length(problems)) {
    cli::cli_abort('Invalid GraphQL IR: {paste(problems, collapse = "; ")}')
  }
  list(ir = ir, diagnostics = diagnostics)
}

# Compatibility records carry the rendered query document. The reviewed field
# list, or a reviewed document, comes from service policy; an operation whose
# selection does not fit the schema is reported and not generated.
graphql_records <- function(files, view) {
  if (length(files) != 1L) {
    cli::cli_abort(
      'Use one GraphQL introspection result per service configuration'
    )
  }
  source <- graphql_source(files)
  ir <- importer_graphql(files, list(graphql_path = view$graphql_path))$ir
  result <- ir_request_records(ir, view)
  roots <- graphql_roots(source)
  roots <- stats::setNames(roots, vapply(roots, `[[`, character(1), 'key'))
  kept <- list()
  for (record in result$operations) {
    root <- roots[[record$key]]
    review <- view$operation(record$key, record$path, record$method)
    returned <- source$types[[graphql_named(root$field$type)$name]]
    # Without a reviewed list, the default selection applies; an explicitly
    # empty list is a review that selected nothing.
    fields <- review$setting('fields') %or%
      graphql_default_fields(returned, source$types)
    document <- tryCatch(
      review$setting('query_document') %or%
        graphql_document(
          root$operation_type,
          root$field,
          graphql_selection(fields, returned, source$types, root$pointer)
        ),
      specmill_schema_problem = identity
    )
    if (inherits(document, 'specmill_schema_problem')) {
      result$diagnostics[[length(result$diagnostics) + 1L]] <- c(
        record[c('id', 'service', 'key', 'source')],
        list(status = 'unsupported', reason = conditionMessage(document)),
        diagnostic_fields(document, root$pointer)
      )
      next
    }
    record$graphql <- list(document = document)
    kept[[length(kept) + 1L]] <- record
  }
  result$operations <- kept
  result
}

graphql_configuration_source <- function(path) {
  source <- graphql_source(path)
  roots <- graphql_roots(source)
  roots <- stats::setNames(roots, vapply(roots, `[[`, character(1), 'key'))
  ir_configuration_source(
    importer_graphql(path)$ir,
    path,
    format = 'graphql',
    artifact = 'schema/graphql.json',
    tags = function(op) op$tags,
    authentication = function(package) list(),
    pagination = function(op) NULL,
    security_declared = FALSE,
    response_policy = 'api_request_graphql_response',
    diagnostic_key = function(diagnostic) 'SERVICE',
    # Every operation shares one endpoint, so path-based names use the field.
    route = function(op) paste0('/', op$binding$field),
    settings = function(op) {
      field <- roots[[op$key]]$field
      list(
        fields = graphql_default_fields(
          source$types[[graphql_named(field$type)$name]],
          source$types
        )
      )
    },
    defaults = list(graphql_path = '/graphql')
  )
}

graphql_validation_report <- function(path) {
  ir_validation_report(
    path,
    importer_graphql,
    'specmill GraphQL introspection/IR validation 1',
    'graphql_introspection'
  )
}
