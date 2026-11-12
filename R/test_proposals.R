# Proposed testing declarations and recording review (#273). Both are
# read-only: proposals are returned (or written to a new review file), never
# copied into service YAML or testing files.

# Configured operations per service, shaped like the entries inspect_client()
# passes to testing_declarations().
testing_project <- function(root, config, callbacks) {
  project <- load_project(root, config, callbacks)
  services <- lapply(project$services, function(service) {
    parsed <- read_service_operations(service)
    entries <- list()
    for (operation in parsed$operations) {
      configured <- configure_operation(operation, service)
      entries[[operation$name]] <- list(
        id = operation$id,
        key = operation$key,
        record = list(
          name = operation$name,
          contract_declared = !is.null(fixed_contract(service, operation))
        ),
        configured = configured
      )
    }
    list(
      service = service,
      entries = entries,
      inventory = parsed$inventory,
      operations = parsed$operations
    )
  })
  list(
    root = project$root,
    services = services,
    definitions = client_definitions(project$root)
  )
}

testing_success_response <- function(op) {
  codes <- grep('^2', names(op$response %or% list()), value = TRUE)
  response <- if (length(codes)) op$response[[sort(codes)[[1L]]]]
  testing_response_schema(response)
}

testing_behavior <- function(entry, service) {
  op <- entry$configured$operation
  spec <- entry$configured$spec
  response <- testing_success_response(op)
  paging <- tryCatch(
    pagination_settings(
      op,
      spec[['pagination']] %or% list(),
      service$operations[[op$key]][['pagination']] %or% list()
    ),
    error = function(e) list(invalid = conditionMessage(e))
  )
  digest::digest(list(
    source = op$source,
    response_media = response$media,
    schema = response$schema,
    body_media = op$body_media,
    pagination = paging$mode,
    batch = spec$batch,
    scope = spec$post_response_scope,
    # Unset, result_order leaves the digests of existing groups as they were.
    formatter = if (is.null(spec$result_order)) {
      spec$result_formatter
    } else {
      list(spec$result_formatter, spec$result_order)
    },
    hooks = lapply(service$hooks[[op$name]], unlist, use.names = FALSE),
    # Different required inputs make a different request, so a separate group.
    # Public requiredness: env-bound and defaulted inputs do not split groups.
    required = sort(
      unlist(lapply(op$parameters, function(p) {
        if (isTRUE(p$public_required %or% p$required)) {
          paste(p$location, p$public_name %or% p$name)
        }
      })) %or%
        character(),
      method = 'radix'
    ),
    body_required = isTRUE(op$body_required)
  ))
}

testing_scenario_id <- function(name, taken) {
  id <- tolower(gsub('[^A-Za-z0-9_]', '_', name))
  if (!grepl('^[a-z]', id)) {
    id <- paste0('s_', id)
  }
  candidate <- id
  n <- 1L
  while (candidate %in% taken) {
    n <- n + 1L
    candidate <- paste0(id, '_', n)
  }
  candidate
}

testing_empty_policy <- function(testing) {
  testing %or%
    list(
      file = NULL,
      match = c('method', 'uri'),
      gaps = list(),
      unrecorded = list(),
      scenarios = list(),
      hook_cases = list(),
      hook_integrations = list(),
      filter = list()
    )
}

propose_service <- function(root, x, definitions) {
  service <- x$service
  entries <- x$entries
  testing <- testing_empty_policy(service$testing)
  service$testing <- testing
  declared <- testing_declarations(
    root,
    service,
    entries,
    x$inventory,
    definitions
  )
  covered <- names(declared$routes)[
    declared$routes %in% c('scenario', 'represented', 'unrecorded')
  ]
  cassettes <- sub(
    '\\.yml$',
    '',
    list.files(file.path(root, 'tests/testthat/_vcr', service$id), '\\.yml$')
  )
  taken <- c(names(testing$scenarios), cassettes)
  entries <- entries[order(vapply(entries, `[[`, character(1), 'key'))]
  writes <- character()
  blocked <- list()
  groups <- list()
  for (entry in entries) {
    op <- entry$configured$operation
    spec <- entry$configured$spec
    if (entry$key %in% covered) {
      next
    }
    if (!op$method %in% c('GET', 'HEAD')) {
      writes <- c(writes, entry$key)
      next
    }
    if (
      !is.null(spec[['request']]) || identical(spec$implementation, 'existing')
    ) {
      blocked[[
        entry$key
      ]] <- 'mapped or retained operations need reviewed inputs'
      next
    }
    behavior <- testing_behavior(entry, service)
    groups[[behavior]] <- c(groups[[behavior]], entry$record$name)
  }
  scenarios <- list()
  examples <- list()
  for (members in groups) {
    choice <- NULL
    for (name in members) {
      entry <- entries[[name]]
      op <- entry$configured$operation
      spec <- entry$configured$spec
      # Prefer an existing reviewed example, then schema-provided inputs.
      for (k in c(seq_along(spec$docs$examples), 0L)) {
        scenario <- if (k) list(example = k) else list()
        if (is.null(scenario_resolution(op, spec, scenario)$blocked)) {
          choice <- list(name = name, example = if (k) k)
          break
        }
      }
      if (!is.null(choice)) {
        break
      }
    }
    stub <- NULL
    if (is.null(choice)) {
      entry <- entries[[members[[1L]]]]
      reason <- scenario_resolution(
        entry$configured$operation,
        entry$configured$spec,
        list()
      )$blocked
      if (!startsWith(reason, 'missing example for ')) {
        for (member in members) {
          blocked[[entries[[member]]$key]] <- reason
        }
        next
      }
      missing <- strsplit(sub('^missing example for ', '', reason), ', ')[[1L]]
      # The operation's effective examples (including inherited defaults.docs)
      # plus one entry to fill in.
      stub <- c(
        entry$configured$spec$docs$examples %or% list(),
        list(stats::setNames(rep(list(NULL), length(missing)), missing))
      )
      choice <- list(name = members[[1L]], example = length(stub))
    }
    entry <- entries[[choice$name]]
    op <- entry$configured$operation
    id <- testing_scenario_id(choice$name, c(taken, names(scenarios)))
    proposal <- list(
      operation = entry$key,
      represents = unname(vapply(
        entries[members],
        `[[`,
        character(1),
        'key'
      )),
      example = choice$example,
      match = if (!is.null(op$body)) c('method', 'uri', 'body_json')
    )
    proposal <- Filter(Negate(is.null), proposal)
    # Proposals must pass the same checks as reviewed declarations.
    trial <- service
    trial$testing$scenarios <- c(
      testing$scenarios,
      stats::setNames(list(proposal), id)
    )
    trial_entries <- entries
    if (!is.null(stub)) {
      trial_entries[[choice$name]]$configured$spec$docs$examples <- stub
    }
    problem <- tryCatch(
      {
        testing_declarations(
          root,
          trial,
          trial_entries,
          x$inventory,
          definitions
        )
        NULL
      },
      error = conditionMessage
    )
    if (!is.null(problem)) {
      for (member in members) {
        blocked[[entries[[member]]$key]] <- problem
      }
      next
    }
    scenarios[[id]] <- proposal
    if (!is.null(stub)) {
      examples[[entry$key]] <- list(docs = list(examples = stub))
    }
  }
  list(
    testing_file = testing$file,
    scenarios = scenarios,
    operations = examples,
    writes = writes,
    blocked = blocked
  )
}

propose_testing <- function(
  root,
  config = 'specmill.yml',
  callbacks = new.env(parent = emptyenv()),
  file = NULL
) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  if (!is.null(file)) {
    target <- project_path(root, config_string(file, 'proposal file'))
    protected <- '^(tests|apis|r|man|inst)(/|$)|^specmill[.]yml$'
    if (
      grepl(protected, tolower(gsub('\\\\', '/', file))) ||
        file.exists(target)
    ) {
      stop(
        'Proposal file must be a new path outside tests/, apis/, R/, man/ ',
        'and inst/: ',
        file
      )
    }
  }
  loaded <- testing_project(root, config, callbacks)
  services <- stats::setNames(
    lapply(loaded$services, function(x) {
      propose_service(loaded$root, x, loaded$definitions)
    }),
    vapply(loaded$services, function(x) x$service$id, character(1))
  )
  header <- c(
    '# Proposed by specmill; unreviewed. Nothing here is a declaration yet.',
    '# Copy reviewed scenarios into each service testing file (or add',
    '# testing: {file: tests/testthat/fixtures/testing.yml} to its apis file),',
    '# and reviewed docs.examples into the operation. Fill every null first.',
    '# Writes are listed, never proposed: recording them needs record_write.'
  )
  body <- lapply(services, function(x) {
    # Sequences stay sequences even with one item, as testing files need.
    x$scenarios <- lapply(x$scenarios, function(scenario) {
      scenario$represents <- as.list(scenario$represents)
      if (!is.null(scenario$match)) {
        scenario$match <- as.list(scenario$match)
      }
      scenario
    })
    x$writes <- as.list(x$writes)
    Filter(length, x[c('scenarios', 'operations', 'writes', 'blocked')])
  })
  text <- paste(c(header, sub('\n$', '', yaml::as.yaml(body))), collapse = '\n')
  if (!is.null(file)) {
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    writeLines(text, target)
  }
  invisible(list(services = services, yaml = text))
}

# Validation context for recorded responses, shared with schema validation.
response_validator <- function() {
  v8 <- schema_validator()
  if (!identical(v8$eval('typeof validate_response'), 'function')) {
    v8$source(system.file(
      'validation',
      'response.js',
      package = 'specmill',
      mustWork = TRUE
    ))
  }
  v8
}

# Annotations are not validation: examples, defaults and x- extensions can hold
# strings ajv would read as duplicate draft-04 ids, so they are dropped. Keys
# of property maps are names, not keywords, and are kept.
response_schema_clean <- function(node) {
  if (!is.list(node)) {
    return(node)
  }
  if (is.null(names(node))) {
    return(lapply(node, response_schema_clean))
  }
  node <- node[
    !names(node) %in% c('example', 'examples', 'default') &
      !startsWith(names(node), 'x-')
  ]
  for (name in names(node)) {
    node[[name]] <- if (
      name %in%
        c('properties', 'patternProperties', 'definitions', '$defs', 'schemas')
    ) {
      lapply(node[[name]], response_schema_clean)
    } else {
      response_schema_clean(node[[name]])
    }
  }
  node
}

testing_path_matches <- function(uri, template) {
  path <- sub('[?#].*$', '', sub('^[a-zA-Z][a-zA-Z0-9+.-]*://[^/]+', '', uri))
  pattern <- gsub('([][{}()+*^$|\\\\.?])', '\\\\\\1', template, perl = TRUE)
  pattern <- gsub('\\\\\\{[^}]*\\\\\\}', '[^/]+', pattern)
  grepl(paste0(pattern, '$'), path)
}

# A recorded body as text: vcr keeps unreadable bodies as base64.
recorded_body <- function(body) {
  if (is.character(body$string) && length(body$string) == 1L) {
    return(body$string)
  }
  encoded <- body$raw_gzip %or% body$base64_string
  if (!is.character(encoded)) {
    return(NULL)
  }
  tryCatch(
    {
      bytes <- jsonlite::base64_dec(gsub('\\s', '', encoded))
      if (!is.null(body$raw_gzip)) {
        bytes <- memDecompress(bytes, type = 'gzip')
      }
      rawToChar(bytes)
    },
    error = function(e) NULL
  )
}

# Follows a local `$ref` such as Swagger 2 `#/responses/Name`.
json_pointer <- function(document, ref) {
  target <- document
  for (part in strsplit(sub('^#/', '', ref), '/', fixed = TRUE)[[1L]]) {
    part <- gsub('~0', '~', gsub('~1', '/', part, fixed = TRUE), fixed = TRUE)
    target <- if (is.list(target)) target[[part]] else NULL
  }
  target
}

review_recordings <- function(
  root,
  config = 'specmill.yml',
  callbacks = new.env(parent = emptyenv())
) {
  loaded <- testing_project(root, config, callbacks)
  documents <- openapi_response_documents()
  report <- list()
  for (x in loaded$services) {
    service <- x$service
    if (is.null(service$testing)) {
      next
    }
    declared <- testing_declarations(
      loaded$root,
      service,
      x$entries,
      x$inventory,
      loaded$definitions
    )
    for (id in names(declared$scenarios)) {
      scenario <- declared$scenarios[[id]]
      op <- x$entries[[scenario$operation]]$configured$operation
      path <- file.path(loaded$root, scenario$cassette)
      result <- if (!file.exists(path)) {
        list(status = 'unchecked', reason = 'no recording')
      } else {
        interactions <- config_data(read_config_yaml(path))$http_interactions
        checks <- Filter(
          Negate(is.null),
          lapply(
            interactions,
            review_interaction,
            op = op,
            documents = documents
          )
        )
        statuses <- vapply(checks, `[[`, character(1), 'status')
        if (any(statuses == 'disagrees')) {
          list(
            status = 'disagrees',
            errors = unlist(lapply(checks, `[[`, 'errors'), use.names = FALSE)
          )
        } else if (any(statuses == 'agrees')) {
          list(status = 'agrees')
        } else if (length(checks)) {
          list(status = 'unchecked', reason = checks[[1L]]$reason)
        } else {
          list(status = 'unchecked', reason = 'no interaction for this route')
        }
      }
      # Filtered values read as placeholders and can explain a disagreement.
      placeholders <- if (file.exists(path)) {
        # Raw or URL-encoded; recorded bodies can hold a bare '%'.
        text <- paste(readLines(path, warn = FALSE), collapse = '\n')
        found <- regmatches(
          text,
          gregexpr(
            '(<<|%3C%3C)[A-Z0-9_]+(>>|%3E%3E)',
            text,
            ignore.case = TRUE
          )
        )[[1L]]
        unique(gsub(
          '%3E',
          '>',
          gsub('%3C', '<', found, ignore.case = TRUE),
          ignore.case = TRUE
        ))
      }
      report[[service$id]][[id]] <- c(
        list(route = scenario$route, cassette = scenario$cassette),
        result,
        if (length(placeholders)) list(placeholders = placeholders)
      )
    }
  }
  report
}
