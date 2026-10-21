# Opt-in removal of owned output: named operations, or everything owned.

prune_request <- function(prune) {
  if (is.null(prune)) {
    return(character())
  }
  if (
    !is.character(prune) ||
      !length(prune) ||
      anyNA(prune) ||
      !all(nzchar(prune)) ||
      ('all' %in% prune && length(prune) > 1L)
  ) {
    stop("prune must be 'all' or operation IDs like '<service> <METHOD> <path>'")
  }
  unique(prune)
}

# Match IDs against manifest ownership; an enrolled deferral ID also matches
# the retired owner of the same METHOD /path.
prune_removals <- function(prune, previous, stored_deferrals, generated_ids) {
  owned_ids <- unique(unlist(lapply(previous, function(x) x$operations)))
  matched <- character()
  for (id in prune) {
    key <- if (is.list(stored_deferrals[[id]])) stored_deferrals[[id]]$key
    found <- if (id %in% owned_ids) {
      id
    } else if (is.character(key) && length(key) == 1L) {
      owned_ids[endsWith(owned_ids, paste0(' ', key))]
    }
    if (!(id %in% owned_ids) && length(found) > 1L) {
      stop(
        'Ambiguous prune ID; name one of: ',
        paste(found, collapse = ', ')
      )
    }
    if (!length(found)) {
      stop('Cannot prune an operation that owns no output: ', id)
    }
    matched <- c(matched, found)
  }
  still <- intersect(matched, generated_ids)
  if (length(still)) {
    stop(
      'Cannot prune an operation that is still generated; defer or exclude it first: ',
      paste(still, collapse = ', ')
    )
  }
  # NAMESPACE is regenerated from the remaining sources, never removed by ID.
  candidates <- setdiff(names(previous), 'NAMESPACE')
  owned <- Filter(
    function(path) {
      ids <- unlist(previous[[path]]$operations)
      length(ids) && any(ids %in% matched)
    },
    candidates
  )
  shared <- Filter(
    function(path) !all(unlist(previous[[path]]$operations) %in% matched),
    owned
  )
  if (length(shared)) {
    stop(
      'Cannot prune a file that also owns other operations: ',
      paste(shared, collapse = ', ')
    )
  }
  owned
}

prune_confirm <- function(confirm) {
  if (!is.null(confirm) && !(isTRUE(confirm) || isFALSE(confirm))) {
    stop('confirm must be TRUE, FALSE or NULL')
  }
}

# Plan-first removal of every manifest-owned, unmodified output.
purge_client <- function(root, mode, confirm) {
  manifest_path <- project_path(root, '.specmill/manifest.json')
  manifest <- if (file.exists(manifest_path)) {
    jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  } else {
    list(files = list())
  }
  owned <- names(manifest$files)
  run <- function(mode) {
    apply_files(root, list(), remove = owned, mode = mode)
  }
  planned <- run('plan')
  pending <- Filter(function(x) identical(x$action, 'remove'), planned)
  if (mode == 'check' && length(pending)) {
    stop('Owned output remains; inspect plan: prune = \'all\'')
  }
  if (mode != 'apply') {
    return(structure(list(files = planned), class = c('specmill_generation', 'list')))
  }
  if (!length(pending)) {
    # Only stale ownership records remain; dropping them deletes nothing.
    return(structure(list(files = run('apply')), class = c('specmill_generation', 'list')))
  }
  if (is.null(confirm)) {
    if (!interactive()) {
      cli::cli_abort(
        'Purging all owned output needs {.code confirm = TRUE} in a non-interactive session.'
      )
    }
    cli::cli_alert_warning('{length(pending)} owned file{?s} will be deleted.')
    answer <- readline('Are you sure? [y/N] ')
    confirm <- tolower(trimws(answer)) %in% c('y', 'yes')
  }
  if (!isTRUE(confirm)) {
    cli::cli_abort('Purge cancelled; no files were changed.')
  }
  structure(list(files = run('apply')), class = c('specmill_generation', 'list'))
}
