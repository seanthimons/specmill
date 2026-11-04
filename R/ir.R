# Format-neutral API intermediate representation (IR), version 1.
# Contract: dev/ir/ir-v1.md. Schema: inst/ir/ir-v1.schema.json. Field ledger:
# inst/ir/field-ledger.csv. importer_openapi() emits this contract; generation
# still uses compatibility records during #229. The registry follows in #230.

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
