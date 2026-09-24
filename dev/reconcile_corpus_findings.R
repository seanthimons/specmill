# Reconcile frozen operation outcomes without changing schemas or supplying overrides.
# Run after audit_testing_specs(); see dev/audits/corpus-reconciliation/README.md.
reconcile_corpus_findings <- function(
  before,
  after,
  schema_root,
  output,
  historical = before,
  policies = list()
) {
  read <- function(root, file) {
    read.csv(file.path(root, file), stringsAsFactors = FALSE)
  }
  old <- read(historical, 'operations.csv')
  start <- read(before, 'operations.csv')
  current <- read(after, 'operations.csv')
  sources <- read(after, 'sources.csv')
  key <- function(x) paste(x$file, x$key, sep = '\n')
  stopifnot(
    !anyDuplicated(key(old)),
    !anyDuplicated(key(start)),
    !anyDuplicated(key(current))
  )
  for (root in c(historical, before)) {
    hashes <- read(root, 'sources.csv')
    stopifnot(all(
      hashes$sha256 == sources$sha256[match(hashes$file, sources$file)]
    ))
  }
  failed <- function(x) x$stage %in% c('fixture', 'invoke', 'render')
  keys <- union(
    key(old)[failed(old)],
    union(key(start)[failed(start)], key(current)[failed(current)])
  )
  stopifnot(all(keys %in% key(current)), all(keys %in% key(start)))
  rows <- current[match(keys, key(current)), ]
  rows$historical_stage <- old$stage[match(keys, key(old))]
  rows$historical_reason <- old$reason[match(keys, key(old))]
  rows$before_stage <- start$stage[match(keys, key(start))]
  rows$before_reason <- start$reason[match(keys, key(start))]
  rows$sha256 <- sources$sha256[match(rows$file, sources$file)]
  rows$disposition <- rows$evidence <- ''
  rows$minimal_stage <- rows$minimal_reason <- ''
  compact <- function(x) {
    substr(
      as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = 'null')),
      1L,
      250L
    )
  }
  error <- function(expr) {
    tryCatch(
      {
        force(expr)
        ''
      },
      error = conditionMessage
    )
  }
  evidence <- function(schema, at) {
    if (!nzchar(error(specmill:::body_fixture(schema)))) {
      return(character())
    }
    selected <- intersect(c('example', 'default'), names(schema))
    if (length(selected)) {
      field <- selected[[1L]]
      return(paste(
        'invalid_selected_value',
        paste0(at, '/', field),
        compact(schema[[field]]),
        error(specmill:::body_value(schema[[field]], schema)),
        sep = ' | '
      ))
    }
    children <- c(
      unlist(lapply(names(schema$properties), function(name) {
        evidence(schema$properties[[name]], paste0(at, '/properties/', name))
      })),
      if (is.list(schema$items)) evidence(schema$items, paste0(at, '/items')),
      unlist(lapply(
        intersect(names(schema), c('allOf', 'anyOf', 'oneOf')),
        function(field) {
          unlist(lapply(seq_along(schema[[field]]), function(i) {
            evidence(schema[[field]][[i]], paste0(at, '/', field, '/', i - 1L))
          }))
        }
      ))
    )
    if (length(children)) {
      return(children)
    }
    constraints <- schema[intersect(
      names(schema),
      c('type', 'pattern', 'minLength', 'maxLength', 'required', 'enum')
    )]
    paste(
      'synthesis_limit',
      at,
      compact(constraints),
      error(specmill:::body_fixture(schema)),
      sep = ' | '
    )
  }
  for (file in unique(rows$file)) {
    path <- file.path(schema_root, file)
    stopifnot(
      digest::digest(file = path, algo = 'sha256') ==
        sources$sha256[match(file, sources$file)]
    )
    policy <- policies[[file]]
    if (is.null(policy)) {
      policy <- list()
    }
    parsed <- specmill::read_operations(path, policy)
    for (i in which(rows$file == file)) {
      op <- Filter(function(x) x$key == rows$key[[i]], parsed$operations)[[1L]]
      context <- new.env(parent = baseenv())
      context$request <- function(...) list(...)
      eval(
        parse(text = specmill::render_operation(op, list(helper = 'request'))),
        context
      )
      for (mode in c('default', 'minimal')) {
        stage <- 'fixture'
        reason <- error({
          values <- specmill::operation_fixtures(list(op), mode = mode)[[1L]]
          stage <- 'invoke'
          do.call(context[[op$name]], values)
          stage <- 'passed'
        })
        if (mode == 'default') {
          stopifnot(stage == rows$stage[[i]], reason == rows$reason[[i]])
        } else {
          rows$minimal_stage[[i]] <- stage
          rows$minimal_reason[[i]] <- reason
        }
      }
      if (rows$stage[[i]] == 'passed') {
        rows$disposition[[i]] <- if (rows$before_stage[[i]] == 'passed') {
          'fixed_before_review'
        } else {
          'fixed_specmill'
        }
        rows$evidence[[i]] <- if (rows$before_stage[[i]] == 'passed') {
          'Current checkout already passes the unchanged schema; historical failure is stale.'
        } else {
          'Exact singular example selection fixes partial matching against the examples collection.'
        }
        next
      }
      contradictions <- specmill:::fixture_diagnostics(op)
      if (length(contradictions)) {
        rows$disposition[[i]] <- 'schema_defect'
        rows$evidence[[i]] <- paste(
          vapply(
            contradictions,
            function(d) {
              paste(d$source_location, d$reason)
            },
            character(1)
          ),
          collapse = '; '
        )
        next
      }
      findings <- character()
      for (p in op$parameters) {
        if ('example' %in% names(p$example)) {
          reason <- error(specmill:::fixture_value(p$schema, p$example$example))
          if (nzchar(reason)) {
            findings <- c(
              findings,
              paste(
                'invalid_selected_value',
                p$source_location,
                'parameter example',
                compact(p$example$example),
                reason,
                sep = ' | '
              )
            )
          }
        } else {
          findings <- c(findings, evidence(p$schema, p$source_location))
        }
      }
      if ('example' %in% names(op$body_example)) {
        reason <- error(specmill:::body_value(op$body_example$example, op$body))
        if (nzchar(reason)) {
          findings <- c(
            findings,
            paste(
              'invalid_selected_value',
              'body media example',
              compact(op$body_example$example),
              reason,
              sep = ' | '
            )
          )
        }
      } else if (!is.null(op$body)) {
        findings <- c(findings, evidence(op$body, 'resolved body'))
      }
      if (
        grepl(
          'Form field needs a declared schema:',
          rows$reason[[i]],
          fixed = TRUE
        )
      ) {
        findings <- c(
          'unsupported_form_contract | Required form field has no declared type; do not invent its encoding.',
          findings
        )
      }
      if (!length(findings)) {
        stop('Unclassified finding: ', file, ' ', op$key)
      }
      rows$disposition[[i]] <- if (
        any(startsWith(findings, 'invalid_selected_value'))
      ) {
        'invalid_example_or_default'
      } else if (any(startsWith(findings, 'unsupported_form_contract'))) {
        'unsupported_form_contract'
      } else {
        'synthesis_limit'
      }
      rows$evidence[[i]] <- paste(unique(findings), collapse = '; ')
    }
  }
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  rows <- rows[order(rows$file, rows$key), ]
  write.csv(rows, file.path(output, 'findings.csv'), row.names = FALSE)
  invisible(rows)
}
