schema_report_files <- function(
  directory,
  pattern,
  stage_priority,
  exclude_pattern
) {
  files <- list.files(directory, pattern, full.names = FALSE)
  if (!is.null(exclude_pattern)) {
    files <- files[!grepl(exclude_pattern, files, ignore.case = TRUE)]
  }
  if (!is.null(stage_priority)) {
    stage <- sub(
      '^.*-([^-]+)[.](json|ya?ml)$',
      '\\1',
      files,
      ignore.case = TRUE
    )
    group <- sub('-[^-]+[.](json|ya?ml)$', '', files, ignore.case = TRUE)
    ranked <- order(match(stage, stage_priority), files)
    valid <- stage[ranked] %in% stage_priority | stage[ranked] == files[ranked]
    files <- files[ranked][valid & !duplicated(group[ranked])]
  }
  files
}

#' Compare schema snapshots and format a change report
#'
#' Compare explicitly selected schema files and method/path operations, including reachable local references.
#'
#' @details Use the same file naming and selection policy for both schema snapshots. Changed canonical contracts require review and are conservatively counted in the breaking-change lane. Malformed input stops comparison. Policy changes should be reviewed separately from schema changes; these reports do not prove upstream runtime compatibility.
#' @param old_dir Existing directory containing the previous schema snapshot.
#' @param new_dir Existing directory containing the candidate schema snapshot, using matching basenames.
#' @param pattern Regular expression selecting filenames; defaults to JSON, YAML, and YML files.
#' @param stage_priority Optional ordered suffix priority for files such as `service-prod.json` and `service-dev.json`. The first matching stage per service is selected. NULL disables stage selection.
#' @param exclude_pattern Optional case-insensitive filename exclusion regex, applied after selection by pattern.
#' @param policies Operation selection policies keyed by schema basename.
#' @return schema_diff() returns changed schema records containing schema_file plus added, removed, and modified tables. format_diff_markdown() returns report text. count_diff_changes() returns change counts, including the conservative breaking-change count.
#' @seealso [Step-by-step guide](https://seanthimons.github.io/specmill/articles/maintenance.html).
#' @export
schema_diff <- function(
  old_dir,
  new_dir,
  pattern = '\\.(json|ya?ml)$',
  stage_priority = NULL,
  exclude_pattern = NULL,
  policies = list()
) {
  if (!dir.exists(old_dir) || !dir.exists(new_dir)) {
    stop('Schema comparison directories must exist')
  }
  files <- sort(union(
    schema_report_files(old_dir, pattern, stage_priority, exclude_pattern),
    schema_report_files(new_dir, pattern, stage_priority, exclude_pattern)
  ))
  rows <- function(records) {
    if (!length(records)) {
      return(tibble::tibble(
        route = character(),
        method = character(),
        summary = character()
      ))
    }
    dplyr::bind_rows(lapply(records, function(x) {
      x[c('route', 'method', 'summary')]
    }))
  }
  results <- lapply(files, function(file) {
    policy <- policies[[file]] %or% list()
    old <- schema_report_operations(file.path(old_dir, file), policy)
    new <- schema_report_operations(file.path(new_dir, file), policy)
    common <- intersect(names(old), names(new))
    changed <- common[
      !vapply(
        common,
        function(key) identical(old[[key]]$contract, new[[key]]$contract),
        logical(1)
      )
    ]
    modified <- rows(new[changed])[, c('route', 'method')]
    modified$change_type <- rep('review', length(changed))
    modified$detail <- rep(
      'Schema contract changed; compatibility requires review',
      length(changed)
    )
    modified$breaking <- rep(TRUE, length(changed))
    list(
      schema_file = file,
      added = rows(new[setdiff(names(new), names(old))]),
      removed = rows(old[setdiff(names(old), names(new))]),
      modified = modified
    )
  })
  names(results) <- files
  Filter(
    function(x) nrow(x$added) + nrow(x$removed) + nrow(x$modified) > 0L,
    results
  )
}
