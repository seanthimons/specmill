#' Scaffold a client-owned runtime hook executor
#'
#' Preview or create an optional YAML hook registry and base R executor in an existing client package. Specmill remains a development dependency.
#'
#' @param root Existing client package directory containing DESCRIPTION.
#' @param mode Preview by default; apply creates absent files only.
#' @return A list containing proposed text in files, changes with file/action/before/after, missing_imports, and collisions with existing executor definitions.
#' @details Creates R/hook_registry.R and inst/hooks.yml. Move yaml to the client's DESCRIPTION Imports before applying; new clients list it in Suggests for their tests, and a package belongs in only one field. This function does not modify metadata or service configuration. Set hook_config: inst/hooks.yml in each participating service or API group, and define the referenced functions in client R source. The empty registry enables no hooks.
#'
#' Existing differing files and executor definitions in other R files block application. Matching files are left alone. Ordinary generate_client regeneration preserves these client-owned files. Rerunning this setup command is not a runtime upgrade mechanism.
#'
#' The executor reads the installed hooks.yml on each stage, resolves functions only in its own environment, executes chains in order, and reports failures with class client_hook_error and parent, function_name, hook_name and stage fields. Pre-hooks return state; the last post-hook returns the wrapper result. An absent chain returns pre-state or data$result for a post-stage. YAML expression evaluation is disabled. No specmill runtime dependency or global registration API is introduced.
#' @seealso `initialize_client`, `generate_client`, `check_client_hooks`, [Configure and maintain runtime hooks](https://seanthimons.github.io/specmill/articles/hooks.html)
#' @examples
#' \dontrun{
#' proposal <- configure_hooks('path/to/client')
#' proposal$changes
#' proposal$missing_imports
#' # Move yaml from DESCRIPTION Suggests to Imports, then:
#' configure_hooks('path/to/client', mode = 'apply')
#' }
#' @export
configure_hooks <- function(root, mode = c('plan', 'apply')) {
  mode <- match.arg(mode)
  description <- project_path(root, 'DESCRIPTION')
  metadata <- read.dcf(description)[1L, ]
  package <- unname(metadata[['Package']])
  files <- list(
    'R/hook_registry.R' = gsub(
      'CLIENT_PACKAGE',
      r_literal(package),
      file_text(system.file(
        'templates/hooks.R',
        package = 'specmill',
        mustWork = TRUE
      )),
      fixed = TRUE
    ),
    'inst/hooks.yml' = paste(
      '# Public wrapper names map to ordered pre_request/post_response chains.',
      '# Batched wrappers (batch.fan_out/batch.split) may also use post_combine, which',
      '# runs once on the combined result.',
      '# Define hook functions in R/ before enabling them here.',
      '# Example:',
      '# get_item:',
      '#   pre_request: [normalize_item_id]',
      '#   post_response: [extract_item]',
      '{}',
      sep = '\n'
    )
  )
  changes <- lapply(names(files), function(file) {
    path <- project_path(root, file)
    before <- if (file.exists(path)) file_text(path) else NULL
    list(
      file = file,
      action = if (is.null(before)) {
        'create'
      } else if (identical(before, files[[file]])) {
        'unchanged'
      } else {
        'conflict'
      },
      before = before,
      after = files[[file]]
    )
  })
  imports <- if ('Imports' %in% names(metadata)) {
    trimws(sub(' *\\(.*', '', strsplit(metadata[['Imports']], ',')[[1L]]))
  } else {
    character()
  }
  missing <- setdiff('yaml', imports)
  # Existing executors may live in any R file, not just the proposed destination.
  definitions <- client_definitions(root)
  collisions <- Filter(
    function(x) {
      x$function_name %in%
        c('run_hook', 'read_hook_config') &&
        !identical(
          normalizePath(x$file_path),
          normalizePath(file.path(root, 'R/hook_registry.R'), mustWork = FALSE)
        )
    },
    definitions
  )
  if (mode == 'apply') {
    if (length(missing)) {
      stop(
        'Move yaml to DESCRIPTION Imports (out of Suggests) before applying ',
        'hook scaffolding'
      )
    }
    if (length(collisions)) {
      stop('Existing hook executor functions; retain or adapt them instead')
    }
    if (any(vapply(changes, function(x) x$action == 'conflict', logical(1)))) {
      stop(
        'Existing hook files differ; review the plan. Client-owned files are never overwritten'
      )
    }
    new <- vapply(
      Filter(function(x) x$action == 'create', changes),
      `[[`,
      character(1),
      'file'
    )
    if (length(new)) apply_files(root, files[new], mode = 'apply')
  }
  list(
    files = files,
    changes = changes,
    missing_imports = missing,
    collisions = collisions
  )
}
