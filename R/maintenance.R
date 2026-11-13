#' Check credential presence without exposing its value
#'
#' Detect missing or placeholder credential strings without logging the value or
#' sending a request.
#'
#' @param value Credential string to inspect, usually read from an environment variable. Its value is never logged.
#' @param name Display label used in status messages.
#' @param abort Whether preflight should raise an error for invalid input. FALSE emits a warning instead.
#' @param guidance Character vector of client-owned credential setup instructions.
#' @return credential_status() returns valid and reason. credential_preflight() returns TRUE/FALSE invisibly and emits a success message, warning, or error according to status and abort.
#' @details These checks do not establish service authorization or key validity.
#'   guidance contains client-owned setup instructions. With abort = FALSE,
#'   preflight warns and returns FALSE instead of raising an error.
#' @seealso [Step-by-step guide](https://seanthimons.github.io/specmill/articles/maintenance.html).
#' @examples
#' credential_status('', 'service key')
#' credential_status('your_key', 'service key')
#' @export
credential_status <- function(value, name = 'credential') {
  value <- trimws(value %or% '')
  if (length(value) != 1L || is.na(value) || !nzchar(value)) {
    return(list(valid = FALSE, reason = paste(name, 'is not set')))
  }
  placeholders <- '^$|dummy|placeholder|your_?key|token here|api[_ -]?key|redacted|masked|^x+$|^\\*+$|^<+.*>+$|<<<.*>>>|test_api_key|logic_test_key'
  if (grepl(placeholders, tolower(value), perl = TRUE)) {
    return(list(
      valid = FALSE,
      reason = paste(name, 'looks like a placeholder or redacted value')
    ))
  }
  list(valid = TRUE, reason = 'ok')
}

#' @rdname credential_status
#' @export
credential_preflight <- function(
  value,
  name = 'credential',
  abort = TRUE,
  guidance = character()
) {
  status <- credential_status(value, name)
  if (status$valid) {
    cli::cli_alert_success('{name} preflight passed')
    return(invisible(TRUE))
  }
  if (abort) {
    cli::cli_abort(c('x' = status$reason, guidance))
  }
  cli::cli_alert_warning(paste(
    c(status$reason, unname(guidance)),
    collapse = '\n'
  ))
  invisible(FALSE)
}

#' @rdname generation_command
#' @param script Maintenance script basename, located from source frames or the Rscript command line.
#' @export
script_root <- function(script) {
  candidates <- c(
    sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)),
    unlist(
      lapply(sys.frames(), function(frame) {
        Filter(is.character, list(frame$ofile, frame$file))
      }),
      use.names = FALSE
    )
  )
  candidates <- candidates[
    basename(candidates) == script & file.exists(candidates)
  ]
  if (!length(candidates)) {
    stop('Cannot locate maintenance script: ', script)
  }
  root <- dirname(normalizePath(
    tail(candidates, 1L),
    winslash = '/',
    mustWork = TRUE
  ))
  while (!file.exists(file.path(root, 'DESCRIPTION'))) {
    parent <- dirname(root)
    if (identical(parent, root)) {
      stop('Maintenance script is outside an R package')
    }
    root <- parent
  }
  root
}

#' Check client public-release boundaries
#'
#' Check client-defined host, artifact, export, and schema restrictions without
#' loading the client.
#'
#' @param policy Public-boundary policy list or explicit YAML filename; see details for accepted fields.
#' @param schema_names Selected public operation names; NULL skips membership checks for built artifacts.
#' @param root Explicit existing client root directory.
#' @return Invisibly TRUE after printing a scan summary; raises an error when a policy restriction fails.
#' @details Policy accepts forbidden_hosts, forbidden_files, forbidden_exports,
#'   forbidden_schemas, and api_exports regex strings plus a manual_exports
#'   sequence. With schema_names supplied, selected API exports must have an
#'   approved schema or manual mapping. Source scans include untracked nonignored
#'   files in Git projects. String policy filenames resolve against the R working
#'   directory.
#' @seealso [Step-by-step guide](https://seanthimons.github.io/specmill/articles/maintenance.html).
#' @export
check_public_boundary <- function(root, policy, schema_names = NULL) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  if (is.character(policy)) {
    policy <- config_data(read_config_yaml(policy))
  }
  config_fields(
    policy,
    c(
      'forbidden_hosts',
      'forbidden_files',
      'forbidden_exports',
      'forbidden_schemas',
      'api_exports',
      'manual_exports'
    ),
    'public boundary policy'
  )
  for (field in setdiff(names(policy), 'manual_exports')) {
    config_string(policy[[field]], field)
    tryCatch(grepl(policy[[field]], '', perl = TRUE), error = function(error) {
      stop('Invalid public boundary pattern: ', field)
    })
  }
  manual <- vapply(
    policy$manual_exports,
    config_string,
    character(1),
    label = 'manual export'
  )
  files <- if (file.exists(file.path(root, '.git'))) {
    paths <- system2(
      'git',
      c(
        '-C',
        shQuote(root),
        'ls-files',
        '--cached',
        '--others',
        '--exclude-standard'
      ),
      stdout = TRUE
    )
    if (!is.null(attr(paths, 'status'))) {
      stop('Cannot inventory public files')
    }
    file.path(root, unique(paths))
  } else {
    list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE)
  }
  files <- files[file.exists(files) & !dir.exists(files)]
  text_files <- files[grepl(
    '[.](R|Rd|md|Rmd|json|ya?ml|html|xml|txt|csv|js)$',
    files
  )]
  hits <- if (is.null(policy$forbidden_hosts)) {
    character()
  } else {
    text_files[vapply(
      text_files,
      function(file) {
        any(grepl(
          policy$forbidden_hosts,
          readLines(file, warn = FALSE, encoding = 'UTF-8'),
          ignore.case = TRUE,
          useBytes = TRUE,
          perl = TRUE
        ))
      },
      logical(1)
    )]
  }
  if (length(hits)) {
    stop('Non-production address found: ', paste(hits, collapse = ', '))
  }
  owned <- files[grepl('/(R|man|reference)/', files)]
  if (
    !is.null(policy$forbidden_files) &&
      any(grepl(policy$forbidden_files, basename(owned), perl = TRUE))
  ) {
    stop('Non-production output filename found')
  }
  exports <- tg_parse_namespace_exports(root)
  if (
    !is.null(policy$forbidden_exports) &&
      any(grepl(policy$forbidden_exports, exports, perl = TRUE))
  ) {
    stop('Non-production export found')
  }
  if (!is.null(schema_names)) {
    api <- if (is.null(policy$api_exports)) {
      exports
    } else {
      grep(policy$api_exports, exports, value = TRUE, perl = TRUE)
    }
    missing <- setdiff(api, c(schema_names, manual))
    if (length(missing)) {
      stop(
        'Export has no approved production mapping: ',
        paste(missing, collapse = ', ')
      )
    }
  }
  if (
    !is.null(policy$forbidden_schemas) &&
      length(list.files(file.path(root, 'schema'), policy$forbidden_schemas))
  ) {
    stop('Non-production schema filename found')
  }
  cat(sprintf(
    'Public boundary passed: %d text files scanned.\n',
    length(text_files)
  ))
  invisible(TRUE)
}

#' @rdname validate_hooks
#' @param root Explicit existing client root directory.
#' @export
check_client_hooks <- function(root, config, hooks, callback = 'run_hook') {
  definitions <- client_definitions(root)
  wrappers <- lapply(definitions, function(definition) {
    eval(definition$expr, envir = hooks)
  })
  result <- validate_hooks(config, wrappers, hooks, callback)
  if (!result$valid) {
    stop(paste(result$errors, collapse = '\n'), call. = FALSE)
  }
  message(sprintf(
    'Hook config validation passed: %d function(s), %d hook(s), %d extra param(s)',
    result$functions,
    result$hooks,
    result$parameters
  ))
  invisible(result)
}

#' Inspect implementation and fixed-contract coverage
#'
#' Compare selected YAML operations with client source definitions, exports, and
#' fixed test files.
#'
#' @param root Explicit existing client root directory.
#' @param config Project YAML path relative to root, or client hook configuration for hook validation.
#' @param callbacks Explicit environment containing named development callbacks.
#' @return A list with operations, inventory, diagnostics, manual_exports, coverage, helpers, protected_sources, and testing. Coverage is keyed by service ID and contains total selected operations, implemented exported definitions, and declared contracts with test files. For a service that declares `testing`, coverage also counts gaps, scenarios, represented routes and unrecorded routes; `testing` holds that service's checked declarations and each selected route's status; and its operations carry `gap` and `scenarios`. These are declarations, not test results.
#' @details This is a read-only structural inspection. Unsupported selections
#'   remain in coverage totals. Manual exports are listed separately. A present
#'   test file is not evidence that tests ran or passed.
#' @section Client-owned helpers:
#'   Newly initialized helpers retain their substituted baseline and template
#'   hash under \file{.specmill/helpers/}. The `helpers` result includes baseline,
#'   local and proposed current source for read-only review, local/upstream change
#'   flags, and missing explicit helper arguments. Legacy helpers have unknown
#'   baselines. Argument compatibility does not establish behavior. Manually merge
#'   selected improvements and run request/transport checks; inspection never
#'   adopts or overwrites a helper. `protected_sources` lists discovered
#'   lifecycle-protected R files. Each operation includes specialization evidence,
#'   configured helper/mapping/hooks and ownership separately.
#' @seealso [Step-by-step guide](https://seanthimons.github.io/specmill/articles/testing.html).
#' @export
inspect_client <- function(
  root,
  config = 'specmill.yml',
  callbacks = new.env(parent = emptyenv())
) {
  project <- load_project(root, config, callbacks)
  root <- project$root
  definitions <- client_definitions(root)
  exports <- tg_parse_namespace_exports(root)
  operations <- list()
  inventory <- list()
  diagnostics <- list()
  testing <- list()
  for (service in project$services) {
    parsed <- read_service_operations(service)
    inventory <- c(inventory, parsed$inventory)
    diagnostics <- c(diagnostics, parsed$diagnostics)
    entries <- list()
    for (operation in parsed$operations) {
      configured <- configure_operation(operation, service)
      name <- operation$name
      definition <- definitions[[name]]
      contract <- fixed_contract(service, operation)
      # Generation writes portable names; look for the same file.
      test_file <- portable_output_path(
        root,
        paste0(
          'tests/testthat/test-',
          if ('calls' %in% names(contract)) 'contract-',
          name,
          '.R'
        )
      )
      operations[[operation$id]] <- list(
        id = operation$id,
        service = service$id,
        method = operation$method,
        path = operation$path,
        name = name,
        implemented = !is.null(definition) && name %in% exports,
        implementation = configured$spec$implementation %or% 'generated',
        specialization = list(
          reason = configured$spec$specialization,
          helper = configured$spec$helper %or% service$helper,
          request = configured$spec[['request']],
          hooks = service$hooks[[name]],
          status = if (
            !is.null(configured$spec[['request']]) ||
              length(service$hooks[[name]])
          ) {
            'configured; behavior unverified'
          } else if (!is.null(configured$spec$specialization)) {
            'requires client handling'
          } else {
            'none recorded'
          }
        ),
        file = if (is.null(definition)) {
          NULL
        } else {
          substring(definition$file_path, nchar(root) + 2L)
        },
        contract_declared = !is.null(contract),
        contract_file = if (
          !is.null(contract) && file.exists(file.path(root, test_file))
        ) {
          test_file
        } else {
          NULL
        }
      )
      entries[[name]] <- list(
        id = operation$id,
        key = operation$key,
        record = operations[[operation$id]],
        configured = configured
      )
    }
    if (!is.null(service$testing)) {
      declared <- testing_declarations(
        root,
        service,
        entries,
        parsed$inventory,
        definitions
      )
      testing[[service$id]] <- declared
      for (entry in entries) {
        operations[[entry$id]]$gap <- declared$gaps[[entry$key]]
        operations[[entry$id]]$scenarios <- names(Filter(
          function(x) entry$key %in% x$represents,
          declared$scenarios
        ))
      }
    }
  }
  selected_names <- vapply(operations, `[[`, character(1), 'name')
  if (anyDuplicated(tolower(selected_names))) {
    stop('Operation names collide across services (including case)')
  }
  manual <- setdiff(intersect(exports, names(definitions)), selected_names)
  list(
    operations = operations,
    helpers = inspect_request_helpers(
      root,
      unique(c(
        vapply(project$services, `[[`, character(1), 'helper'),
        vapply(operations, function(x) x$specialization$helper, character(1))
      )),
      definitions
    ),
    protected_sources = list.files(
      file.path(root, 'R'),
      pattern = '[.]R$',
      full.names = TRUE,
      recursive = TRUE
    )[vapply(
      list.files(
        file.path(root, 'R'),
        pattern = '[.]R$',
        full.names = TRUE,
        recursive = TRUE
      ),
      has_protected_lifecycle,
      logical(1)
    )],
    inventory = inventory,
    diagnostics = diagnostics,
    manual_exports = stats::setNames(
      lapply(manual, function(name) {
        list(
          name = name,
          calls = definitions[[name]]$call_names,
          file = substring(definitions[[name]]$file_path, nchar(root) + 2L)
        )
      }),
      manual
    ),
    coverage = lapply(project$services, function(service) {
      records <- Filter(function(x) x$service == service$id, operations)
      selected <- Filter(
        function(x) x$service == service$id && x$status != 'excluded',
        inventory
      )
      counts <- list(
        total = length(selected),
        implemented = sum(vapply(records, `[[`, logical(1), 'implemented')),
        contracts = sum(vapply(
          records,
          function(x) x$contract_declared && !is.null(x$contract_file),
          logical(1)
        ))
      )
      declared <- testing[[service$id]]
      if (!is.null(declared)) {
        # Declarations only: gaps never count as contracts, and represented
        # routes are not executed. Execution results are reported separately.
        counts$gaps <- length(declared$gaps)
        counts$scenarios <- length(declared$scenarios)
        counts$represented <- sum(
          declared$routes %in% c('scenario', 'represented')
        )
        counts$unrecorded <- sum(declared$routes == 'unrecorded')
        counts$hook_cases_missing <- length(declared$hooks_without_cases)
      }
      counts
    }),
    testing = testing
  )
}

# Read-only: plan the full generation in memory, then classify every owned,
# desired and on-disk output so a purge-and-rebuild can be reviewed first.
#' Review what a clean regeneration would add, change or remove
#'
#' Plan generation in memory and compare it with the checked-in tree, the
#' ownership manifest and unowned files, without writing anything.
#'
#' @param root Explicit existing client root directory.
#' @param config Project YAML path relative to root.
#' @param callbacks Explicit environment containing named development callbacks.
#' @param validation Passed to `generate_client()`; `NULL` keeps its default.
#' @return A `specmill_regeneration_report` whose `files` data frame has columns `file`, `category`, `reason`, `prune_eligible` and `owner`. Categories: `added`, `changed`, `unchanged`, `edited_conflict` and `unowned_collision` (a hand-written file at a generated path), `kept` (lifecycle badge, existing implementation, deferral or \file{NAMESPACE}), `would_remove` (owned but no longer generated; `prune_eligible` is `FALSE` when `prune` would refuse an edited file), `unowned_generated` and `hand_written`.
#' @details Nothing is written to the working tree or manifest. The comparison is
#'   the in-memory plan against the current disk, not a purge followed by a
#'   rebuild: deferrals, existing implementations, adopted hashes and lifecycle
#'   badges keep their current placement, and the plan reads current sources. Plan
#'   mode still stops on an unresolved recovery journal, a blocked rename, or a
#'   hand-edited file that mixes other code into a generated file; the error names
#'   the file.
#' @seealso [`generate_client`], [`inspect_client`].
#' @export
regeneration_report <- function(
  root,
  config = 'specmill.yml',
  callbacks = new.env(parent = emptyenv()),
  validation = NULL
) {
  plan <- generate_client(
    root,
    config = config,
    mode = 'plan',
    callbacks = callbacks,
    validation = validation
  )
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  manifest_path <- project_path(root, '.specmill/manifest.json')
  owned <- if (file.exists(manifest_path)) {
    jsonlite::read_json(manifest_path, simplifyVector = FALSE)$files
  } else {
    list()
  }
  hash <- function(file) output_hash(project_path(root, file))
  configured <- unique(vapply(plan$operations, function(x) x$service, ''))
  held <- names(Filter(
    function(x) x$state %in% c('enrolled', 'auto_enrolled', 'uncertain', 'retry_blocked'),
    plan$deferrals
  ))
  rows <- list()
  add <- function(file, category, reason = '', prune_eligible = NA, owner = '') {
    rows[[length(rows) + 1L]] <<- data.frame(
      file = file,
      category = category,
      reason = reason,
      prune_eligible = prune_eligible,
      owner = owner,
      stringsAsFactors = FALSE
    )
  }
  planned <- character()
  for (entry in plan$files) {
    file <- entry$file
    if (identical(file, '.specmill/manifest.json')) next
    planned <- c(planned, file)
    previous <- owned[[file]]
    present <- file.exists(entry$path)
    if (entry$action == 'write') {
      if (!present) {
        add(file, 'added', 'new file')
      } else if (!is.null(previous) && identical(hash(file), previous$hash)) {
        add(file, 'changed', 'generator, schema or policy changed')
      } else {
        add(file, 'changed', 'present but not owned yet')
      }
    } else if (entry$action == 'protected') {
      if (is.null(previous)) {
        add(file, 'unowned_collision', 'hand-written file at a generated path')
      } else {
        add(file, 'edited_conflict', 'edited since generation')
      }
    } else if (entry$action == 'retained') {
      add(file, 'kept', 'lifecycle badge or edit; left alone')
    } else if (entry$action == 'remove') {
      add(file, 'would_remove', 'removed on next apply', TRUE)
    } else if (!present && !is.null(previous)) {
      # A stale record whose file is already gone: unchanged on disk, still owned.
      add(file, 'would_remove', 'ownership record without a file', TRUE)
    } else {
      add(file, 'unchanged')
    }
  }
  for (file in setdiff(names(owned), c(planned, '.specmill/manifest.json'))) {
    ids <- unlist(owned[[file]]$operations)
    owner <- unique(sub(' .*$', '', ids))
    if (identical(file, 'NAMESPACE')) {
      add(file, 'kept', 'regenerated from remaining sources, never pruned')
    } else if (file %in% plan$retained_sources) {
      add(file, 'kept', 'existing implementation', owner = toString(owner))
    } else if (length(intersect(ids, held))) {
      add(file, 'kept', 'held by a deferral', owner = toString(owner))
    } else {
      add(
        file,
        'would_remove',
        if (length(owner) && !all(owner %in% configured)) {
          'owning service is no longer configured'
        } else {
          'no longer generated'
        },
        !file.exists(project_path(root, file)) ||
          identical(hash(file), owned[[file]]$hash),
        toString(owner)
      )
    }
  }
  unowned <- c(
    list.files(file.path(root, 'R'), '\\.R$', full.names = TRUE),
    list.files(file.path(root, 'man'), '\\.Rd$', full.names = TRUE),
    list.files(file.path(root, 'tests'), '\\.R$', full.names = TRUE, recursive = TRUE)
  )
  unowned <- setdiff(
    as.character(fs::path_rel(unowned, root)),
    c(planned, names(owned))
  )
  for (file in unowned) {
    first <- readLines(project_path(root, file), n = 1L, warn = FALSE)
    generated <- length(first) == 1L &&
      grepl('^(# Generated with specmill|% Generated by roxygen2)', first)
    add(
      file,
      if (generated) 'unowned_generated' else 'hand_written',
      if (generated) 'generated-looking, no ownership record' else 'left alone'
    )
  }
  files <- if (length(rows)) do.call(rbind, rows) else data.frame()
  structure(
    list(files = files[order(files$category, files$file), , drop = FALSE]),
    class = 'specmill_regeneration_report'
  )
}

#' @export
#' @noRd
print.specmill_regeneration_report <- function(x, ...) {
  files <- x$files
  counts <- table(files$category)
  cat(
    'Regeneration report (nothing written): ',
    paste0(names(counts), ' ', counts, collapse = ', '),
    '\n',
    sep = ''
  )
  for (i in which(files$category != 'unchanged')) {
    cat(
      '  ', files$category[[i]], ': ', files$file[[i]],
      if (nzchar(files$reason[[i]])) paste0(' - ', files$reason[[i]]),
      if (isFALSE(files$prune_eligible[[i]])) ' [prune refuses: edited]',
      '\n',
      sep = ''
    )
  }
  invisible(x)
}
