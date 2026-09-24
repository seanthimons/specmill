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
      stop('Add yaml to DESCRIPTION Imports before applying hook scaffolding')
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
