ir_acceptance <- function() {
  internal <- function(name) getFromNamespace(name, 'specmill')
  validate_ir <- internal('validate_ir')
  read_operations <- internal('read_operations')
  configure_operation <- internal('configure_operation')
  read_service_operations <- internal('read_service_operations')
  root <- system.file('ir', package = 'specmill', mustWork = TRUE)

  # Hand-written descriptions from three non-OpenAPI formats validate, which
  # shows the IR does not depend on OpenAPI vocabulary.
  for (example in list.files(file.path(root, 'examples'), full.names = TRUE)) {
    problems <- validate_ir(example)
    stopifnot(
      'example must validate' = length(problems) == 0L
    )
  }

  # Constructs that must be rejected, each by the layer that owns the rule.
  base <- jsonlite::fromJSON(
    file.path(root, 'examples', 'arcgis-query.json'),
    simplifyVector = FALSE
  )
  rejects <- function(label, change, pattern) {
    problems <- validate_ir(change(base))
    stopifnot(
      'invalid IR must be rejected' = length(problems) > 0L,
      'rejection must name the defect' = any(grepl(pattern, problems))
    )
  }
  rejects(
    'unknown scalar',
    function(x) {
      x$operations[[1]]$parameters[[1]]$type$name <- 'text'
      x
    },
    'allowed values'
  )
  rejects(
    'unknown type member',
    function(x) {
      x$operations[[1]]$parameters[[1]]$type$extra <- 1
      x
    },
    'unevaluated'
  )
  rejects(
    'REST binding without path',
    function(x) {
      x$operations[[1]]$binding$path <- NULL
      x
    },
    "required property 'path'"
  )
  rejects(
    'unknown paradigm',
    function(x) {
      x$operations[[1]]$paradigm <- 'carrier-pigeon'
      x
    },
    'allowed values'
  )
  rejects(
    'api key scheme without location',
    function(x) {
      x$sources[[1]]$auth_schemes$key <- list(kind = 'api_key')
      x
    },
    "required property 'in'"
  )
  rejects(
    'empty enum',
    function(x) {
      x$sources[[1]]$types$Empty <- list(
        kind = 'enum',
        base = 'string',
        values = list()
      )
      x
    },
    'fewer than 1'
  )
  rejects(
    'operation from an unknown source',
    function(x) {
      x$operations[[1]]$source <- 'missing'
      x
    },
    'unknown source'
  )
  rejects(
    'security naming an undeclared scheme',
    function(x) {
      x$operations[[1]]$security <- list(list(missing = list()))
      x
    },
    'undefined auth scheme'
  )
  rejects(
    'dangling type reference',
    function(x) {
      x$operations[[1]]$responses[[1]]$type$name <- 'Missing'
      x
    },
    'unresolved type'
  )
  rejects(
    'paradigm contradicting the document',
    function(x) {
      x$paradigm <- 'graphql'
      x
    },
    'differs from'
  )
  rejects(
    'duplicate operation key in one source',
    function(x) {
      x$operations[[2]] <- x$operations[[1]]
      x
    },
    'duplicate key'
  )

  # Two sources: a scheme id may repeat with a different definition, and a
  # reference resolves only inside the source of its operation.
  second_source <- base$sources[[1]]
  second_source$id <- 'second'
  second_source$types <- list(
    Other = list(kind = 'scalar', name = 'string')
  )
  second_source$auth_schemes$arcgis_token <- list(
    kind = 'api_key',
    `in` = 'header',
    name = 'X-Token'
  )
  second_operation <- base$operations[[1]]
  second_operation$key <- 'GET /1/query'
  second_operation$id <- 'parcels GET /1/query'
  second_operation$name <- 'query_layer_1'
  second_operation$binding$path <- '/1/query'
  second_operation$source <- 'second'
  second_operation$responses[[1]]$type$name <- 'Other'
  two <- base
  two$sources[[2]] <- second_source
  two$operations[[2]] <- second_operation
  stopifnot(
    'two sources validate' = identical(validate_ir(two), character())
  )
  rejects_from <- function(ir, change, pattern) {
    problems <- validate_ir(change(ir))
    stopifnot(
      'invalid IR must be rejected' = length(problems) > 0L,
      'rejection must name the defect' = any(grepl(pattern, problems))
    )
  }
  rejects_from(
    two,
    function(x) {
      x$operations[[2]]$responses[[1]]$type$name <- 'FeatureSet'
      x
    },
    'unresolved type FeatureSet'
  )
  rejects_from(
    two,
    function(x) {
      x$sources[[2]]$id <- 'featureserver'
      x
    },
    'Duplicate source id'
  )
  rejects_from(
    two,
    function(x) {
      x$operations[[2]]$key <- x$operations[[1]]$key
      x$operations[[2]]$id <- 'parcels other id'
      x
    },
    'duplicate key or id'
  )
  rejects_from(
    two,
    function(x) {
      x$sources[[1]]$types$Child <- list(
        kind = 'record',
        implements = list('Nowhere'),
        fields = list()
      )
      x
    },
    'unresolved type Nowhere'
  )
  rejects_from(
    two,
    function(x) {
      x$sources[[1]]$types$Choice <- list(
        kind = 'union',
        variants = list(list(kind = 'ref', name = 'Feature')),
        discriminator = list(
          property = 'kind',
          mapping = list(feature = 'Absent')
        )
      )
      x
    },
    'unresolved type Absent'
  )
  # Data shaped like a type is not a reference.
  data_like <- base
  data_like$operations[[1]]$parameters[[1]]$type$default <- list(
    kind = 'ref',
    name = 'NotAType'
  )
  data_like$sources[[1]]$types$Holder <- list(
    kind = 'enum',
    base = 'string',
    values = list(list(value = list(kind = 'ref', name = 'AlsoNotAType')))
  )
  stopifnot(
    'defaults and enum values are data' = identical(
      validate_ir(data_like),
      character()
    )
  )

  # R lists and parsed JSON take the same path: an empty object stays an
  # object and a one-element array must be a list.
  minimal <- list(
    ir_version = '1',
    paradigm = 'rest',
    service = list(id = 'minimal'),
    sources = list(list(
      id = 's',
      format = 'openapi',
      file = 'schema.json',
      hash = list(algorithm = 'md5', value = 'abc'),
      auth_schemes = setNames(list(), character())
    )),
    operations = list()
  )
  stopifnot(identical(validate_ir(minimal), character()))

  # The ledger must account for every field the generators can receive. Walk
  # the fields of real records over the shipped fixtures and a few synthetic
  # schemas, so a new record field fails here until it is classified.
  ledger <- utils::read.csv(
    file.path(root, 'field-ledger.csv'),
    stringsAsFactors = FALSE,
    na.strings = character()
  )
  stopifnot(
    'ledger columns' = identical(
      names(ledger),
      c('stage', 'field', 'class', 'ir_path', 'note')
    ),
    'ledger stages' = all(
      ledger$stage %in%
        c('operation', 'parameter', 'policy', 'return', 'diagnostic')
    ),
    'ledger classes' = all(
      ledger$class %in%
        c(
          'neutral',
          'openapi_only',
          'policy',
          'derived',
          'diagnostic',
          'call_context'
        )
    ),
    'ledger duplicates' = !anyDuplicated(ledger[c('stage', 'field')]),
    'mapped fields name an IR path' = all(
      nzchar(ledger$ir_path[ledger$class %in% c('neutral', 'openapi_only')])
    )
  )

  # Every IR path in the ledger must exist in the schema.
  schema <- jsonlite::fromJSON(
    file.path(root, 'ir-v1.schema.json'),
    simplifyVector = FALSE
  )
  resolve <- function(node) {
    while (!is.null(node[['$ref']])) {
      node <- schema[['$defs']][[sub(
        '#/$defs/',
        '',
        node[['$ref']],
        fixed = TRUE
      )]]
    }
    node
  }
  path_exists <- function(path) {
    node <- schema
    for (segment in strsplit(gsub('\\[\\]', '', path), '.', fixed = TRUE)[[
      1
    ]]) {
      node <- resolve(node)
      if (identical(node$type, 'array')) {
        node <- resolve(node$items)
      }
      if (is.null(node$properties[[segment]])) {
        return(FALSE)
      }
      node <- node$properties[[segment]]
    }
    TRUE
  }
  mapped <- unique(ledger$ir_path[nzchar(ledger$ir_path)])
  missing_paths <- mapped[!vapply(mapped, path_exists, logical(1))]
  stopifnot('ledger path missing from schema' = !length(missing_paths))

  fixtures <- c(
    list.files(
      system.file('configuration', package = 'specmill'),
      full.names = TRUE
    ),
    list.files(
      system.file('schema-stress', package = 'specmill'),
      full.names = TRUE
    ),
    system.file('catalogue/schema.json', package = 'specmill')
  )
  synthetic <- tempfile(fileext = '.json')
  writeLines(
    jsonlite::toJSON(
      list(
        swagger = '2.0',
        info = list(title = 'Synthetic', version = '1'),
        host = 'example.test',
        basePath = '/v1',
        securityDefinitions = list(
          key = list(type = 'apiKey', `in` = 'header', name = 'X-Key')
        ),
        paths = list(
          `/things` = list(
            get = list(
              operationId = 'listThings',
              parameters = list(
                list(
                  name = 'ids',
                  `in` = 'query',
                  type = 'array',
                  items = list(type = 'string'),
                  collectionFormat = 'csv',
                  `x-example` = list('a')
                )
              ),
              responses = list(`200` = list(description = 'ok'))
            )
          )
        )
      ),
      auto_unbox = TRUE
    ),
    synthetic
  )
  fixtures <- c(fixtures, synthetic)

  allowed <- function(stage) ledger$field[ledger$stage == stage]
  walked <- 0L
  for (file in fixtures) {
    parsed <- tryCatch(
      suppressWarnings(suppressMessages(read_operations(file))),
      error = function(e) NULL
    )
    if (is.null(parsed)) {
      # Origin lists beside the schemas are not schemas.
      next
    }
    stopifnot(
      'return list field' = all(names(parsed) %in% allowed('return'))
    )
    for (diagnostic in c(parsed$diagnostics, parsed$server_diagnostics)) {
      stopifnot(
        'diagnostic field' = all(names(diagnostic) %in% allowed('diagnostic'))
      )
    }
    for (operation in c(parsed$operations, parsed$unsupported_operations)) {
      walked <- walked + 1L
      unknown <- setdiff(
        names(operation),
        c(allowed('operation'), allowed('policy'))
      )
      stopifnot(
        'operation field missing from ledger' = !length(unknown)
      )
      for (parameter in operation$parameters) {
        stopifnot(
          'parameter field missing from ledger' = all(
            names(parameter) %in% allowed('parameter')
          )
        )
      }
      configured <- configure_operation(operation, list(files = file))$operation
      stopifnot(
        'configured field missing from ledger' = all(
          names(configured) %in% c(allowed('operation'), allowed('policy'))
        )
      )
      for (parameter in configured$parameters) {
        stopifnot(
          'configured parameter field missing from ledger' = all(
            names(parameter) %in% allowed('parameter')
          )
        )
      }
    }
  }
  # Fields that exist only after policy is applied.
  fixture <- system.file('configuration/petstore.json', package = 'specmill')
  catalogue <- suppressMessages(read_operations(fixture))$operations
  keys <- vapply(catalogue, function(op) op$key, character(1))
  arguments <- list(
    status = list(
      from = structure(list('params', 'wanted'), class = 'specmill_sequence')
    )
  )
  policies <- list(
    list(
      key = 'GET /pet/findByStatus',
      settings = list(
        extra_parameters = list(
          flag = list(type = 'logical', default = FALSE),
          cap = list(type = 'numeric', default = 1, minimum = 0)
        ),
        parameters = list(
          `query status` = list(
            name = 'state',
            required = TRUE,
            default = 'sold'
          )
        )
      )
    ),
    list(
      key = 'GET /pet/findByStatus',
      settings = list(
        inputs = list(
          wanted = list(
            type = 'character',
            required = TRUE,
            missing_as_null = TRUE
          )
        ),
        request = list(arguments = arguments)
      )
    ),
    list(
      key = 'GET /pet/findByStatus',
      settings = list(
        parameters = list(`query status` = list(env = 'PET_STATUS'))
      )
    ),
    list(
      key = 'POST /pet',
      settings = list(body = list(name = 'pet', description = 'The pet.'))
    )
  )
  service_walk <- read_service_operations(list(files = fixture))
  stopifnot(
    'service return field missing from ledger' = all(
      names(service_walk) %in% allowed('return')
    )
  )
  for (record in c(service_walk$inventory, service_walk$diagnostics)) {
    stopifnot(
      'inventory field missing from ledger' = all(
        names(record) %in% allowed('diagnostic')
      )
    )
  }
  for (case in policies) {
    operation <- catalogue[[match(case$key, keys)]]
    service <- list(
      files = fixture,
      operations = setNames(list(case$settings), case$key)
    )
    configured <- configure_operation(operation, service)$operation
    stopifnot(
      'policy operation field missing from ledger' = all(
        names(configured) %in% c(allowed('operation'), allowed('policy'))
      )
    )
    for (parameter in configured$parameters) {
      stopifnot(
        'policy parameter field missing from ledger' = all(
          names(parameter) %in% allowed('parameter')
        )
      )
    }
  }

  stopifnot('no operations were walked' = walked > 20L)
  cat('ir: ok (', walked, 'operations walked)\n')
}
if (sys.nframe() == 0L) {
  ir_acceptance()
}
