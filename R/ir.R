# Format-neutral API intermediate representation (IR), version 1.
# Contract: dev/ir/ir-v1.md. Schema: inst/ir/ir-v1.schema.json. Field ledger:
# inst/ir/field-ledger.csv. importer_openapi() emits this contract; the reviewed
# view projects neutral fields into compatibility records during #229. Registry:
# #230. Remaining JSON Schema consumers: #279.

ir_state <- new.env(parent = emptyenv())

ir_schema_path <- function() {
  system.file('ir/ir-v1.schema.json', package = 'specmill', mustWork = TRUE)
}

ir_validator <- function() {
  if (is.null(ir_state$validator)) {
    ir_state$validator <- jsonvalidate::json_validator(
      ir_schema_path(),
      engine = 'ajv'
    )
  }
  ir_state$validator
}

# The IR is JSON-shaped data held in R lists: a named list is an object, an
# unnamed list is an array, an empty object is `setNames(list(), character())`,
# and a length-one array must be `list(x)` because a length-one vector is a
# scalar.
ir_to_json <- function(ir) {
  jsonlite::toJSON(
    ir,
    auto_unbox = TRUE,
    null = 'null',
    na = 'null',
    digits = NA,
    pretty = FALSE
  )
}

# Names referenced by a type tree. Only structural slots are walked, so values
# held by `default`, `example`, `const`, enum values or `native` are never read
# as types, and user-chosen map keys are never read as slot names.
ir_type_refs <- function(type) {
  if (!is.list(type)) {
    return(character())
  }
  nested <- c(
    list(type[['items']], type[['key']], type[['value']]),
    if (is.list(type[['additional']])) list(type[['additional']]),
    lapply(type[['fields']], function(field) field[['type']]),
    unname(type[['pattern_properties']]),
    type[['variants']],
    type[['members']]
  )
  # Names that point at other types without being type nodes themselves.
  named <- c(
    unlist(type[['implements']], use.names = FALSE),
    unlist(type[['discriminator']][['mapping']], use.names = FALSE)
  )
  found <- if (identical(type[['kind']], 'ref')) type[['name']] else character()
  c(found, named, unlist(lapply(nested, ir_type_refs), use.names = FALSE))
}

ir_operation_refs <- function(operation) {
  types <- c(
    lapply(operation[['parameters']], function(p) p[['type']]),
    lapply(operation[['parameters']], function(p) p[['validation_type']]),
    list(operation[['body']][['type']]),
    lapply(operation[['responses']], function(r) r[['type']]),
    unlist(
      lapply(operation[['responses']], function(r) unname(r[['headers']])),
      recursive = FALSE
    ),
    lapply(operation[['errors']], function(e) e[['type']])
  )
  unlist(lapply(types, ir_type_refs), use.names = FALSE)
}

ir_semantic_problems <- function(ir) {
  problems <- character()
  source_ids <- vapply(ir$sources, function(s) s$id, character(1))
  if (anyDuplicated(source_ids)) {
    problems <- c(problems, 'Duplicate source id')
  }
  seen_keys <- character()
  seen_ids <- character()
  for (op in ir$operations) {
    label <- paste0('operation ', op$id)
    if (op$key %in% seen_keys || op$id %in% seen_ids) {
      problems <- c(problems, paste0(label, ': duplicate key or id'))
    }
    seen_keys <- c(seen_keys, op$key)
    seen_ids <- c(seen_ids, op$id)
    if (
      !identical(ir$paradigm, 'mixed') && !identical(op$paradigm, ir$paradigm)
    ) {
      problems <- c(
        problems,
        paste0(label, ': paradigm ', op$paradigm, ' differs from ', ir$paradigm)
      )
    }
    index <- match(op$source, source_ids)
    if (is.na(index)) {
      problems <- c(problems, paste0(label, ': unknown source ', op$source))
      next
    }
    source <- ir$sources[[index]]
    for (requirement in op$security) {
      unknown <- setdiff(names(requirement), names(source$auth_schemes))
      if (length(unknown)) {
        problems <- c(
          problems,
          paste0(
            label,
            ': undefined auth scheme ',
            paste(unknown, collapse = ', ')
          )
        )
      }
    }
    unresolved <- setdiff(ir_operation_refs(op), names(source$types))
    if (length(unresolved)) {
      problems <- c(
        problems,
        paste0(
          label,
          ': unresolved type ',
          paste(unique(unresolved), collapse = ', ')
        )
      )
    }
  }
  for (source in ir$sources) {
    unresolved <- setdiff(
      unlist(lapply(source$types, ir_type_refs), use.names = FALSE),
      names(source$types)
    )
    if (length(unresolved)) {
      problems <- c(
        problems,
        paste0(
          'source ',
          source$id,
          ': unresolved type ',
          paste(unique(unresolved), collapse = ', ')
        )
      )
    }
  }
  problems
}

# Returns a character vector of problems; `character(0)` means valid. Accepts
# an IR list or the path to an IR JSON file.
validate_ir <- function(ir) {
  json <- if (is.character(ir) && length(ir) == 1L) {
    if (!file.exists(ir)) {
      cli::cli_abort('IR file not found: {ir}')
    }
    paste(readLines(ir, warn = FALSE, encoding = 'UTF-8'), collapse = '\n')
  } else {
    as.character(ir_to_json(ir))
  }
  verdict <- ir_validator()(json, verbose = TRUE, greedy = TRUE)
  if (!isTRUE(verdict)) {
    errors <- attr(verdict, 'errors')
    return(paste0(
      ifelse(nzchar(errors$instancePath), errors$instancePath, '/'),
      ': ',
      errors$message
    ))
  }
  ir_semantic_problems(jsonlite::fromJSON(json, simplifyVector = FALSE))
}

# Adapt neutral operation fields to the established R record shape. The opaque
# compatibility sidecar retains JSON Schema fragments, derived parser columns,
# policy provenance and character diagnostics until the #279 consumers migrate.
# This adapter never reads native format bags or JSON Schema keywords.
ir_compatibility_records <- function(ir, compatibility) {
  keys <- vapply(ir$operations, `[[`, character(1), 'key')
  source_ids <- vapply(ir$sources, `[[`, character(1), 'id')
  compatibility$operations <- lapply(
    compatibility$operations,
    function(record) {
      index <- match(record$key, keys)
      if (is.na(index)) {
        cli::cli_abort(
          'Missing IR operation for compatibility record: {record$key}'
        )
      }
      operation <- ir$operations[[index]]
      source <- ir$sources[[match(operation$source, source_ids)]]
      for (field in intersect(
        c('key', 'id', 'name', 'summary', 'description', 'deprecated'),
        names(operation)
      )) {
        record[field] <- operation[field]
      }
      record$service <- ir$service$id
      record$method <- operation$binding$method
      record$path <- operation$binding$path
      record$source <- source$file
      record$source_hash <- source$hash$value
      record$schema_version <- source$format_version
      record$server <- operation$server[setdiff(
        names(operation$server),
        'relative'
      )]
      record['server_relative'] <- list(operation$server$relative)
      record['security'] <- list(operation$security)
      if (length(record$parameters) != length(operation$parameters)) {
        cli::cli_abort(
          'IR parameter count differs from compatibility record: {record$key}'
        )
      }
      record$parameters <- lapply(seq_along(record$parameters), function(i) {
        parameter <- record$parameters[[i]]
        neutral <- operation$parameters[[i]]
        fields <- c(
          'name',
          'location',
          'required',
          'allow_empty_value',
          'style',
          'explode',
          'collection_format'
        )
        for (field in intersect(
          fields,
          union(names(parameter), names(neutral))
        )) {
          parameter[field] <- list(neutral[[field]])
        }
        parameter
      })
      if (!is.null(operation$body)) {
        record$body_required <- operation$body$required
        record$body_media <- operation$body$media
        # Empty R list and empty named object serialize differently in wrappers;
        # retain that legacy representation when the IR encoding object is empty.
        if (
          length(operation$body$form_encoding) || length(record$body_encoding)
        ) {
          record$body_encoding <- operation$body$form_encoding
        }
      }
      record
    }
  )
  compatibility
}
