schema_operation_keys <- function(document) {
  unlist(
    lapply(names(document$paths), function(path) {
      item <- local_ref(document$paths[[path]], document)
      methods <- intersect(
        names(item),
        c('get', 'post', 'put', 'patch', 'delete', 'head', 'options', 'trace')
      )
      if (length(methods)) paste(toupper(methods), path) else character()
    }),
    use.names = FALSE
  ) %or%
    character()
}

generation_schema_inventory <- function(files, labels) {
  stats::setNames(
    lapply(files, function(file) {
      # Reporting must not replace the schema validation diagnostics.
      keys <- tryCatch(
        schema_operation_keys(read_schema_document(file)),
        error = function(e) NULL
      )
      if (is.null(keys)) {
        return(NULL)
      }
      list(keys = as.list(keys), functions = list())
    }),
    labels
  )
}

generation_schema_changes <- function(
  files,
  labels,
  hashes,
  baseline,
  inventory,
  services
) {
  changes <- list()
  for (i in seq_along(files)) {
    label <- labels[[i]]
    previous_hash <- baseline$inputs[[label]]
    if (identical(previous_hash, hashes[[i]])) {
      next
    }
    old <- baseline$schema_inventory[[label]]
    current <- inventory[[label]]
    comparable <- !is.null(old) && !is.null(current)
    added <- if (comparable) {
      setdiff(unlist(current$keys), unlist(old$keys))
    } else {
      character()
    }
    removed <- if (comparable) {
      setdiff(unlist(old$keys), unlist(current$keys))
    } else {
      character()
    }
    members <- Filter(
      function(service) {
        files[[i]] %in% normalizePath(service$files, winslash = '/')
      },
      services
    )
    unselected <- Filter(
      function(key) {
        method <- sub(' .*', '', key)
        path <- substring(key, nchar(method) + 2L)
        !any(vapply(
          members,
          function(service) {
            !length(operation_selection_reason(
              key,
              path,
              method,
              service[['policy']] %or% list()
            ))
          },
          logical(1)
        ))
      },
      added
    )
    functions <- stats::setNames(
      lapply(removed, function(key) {
        unlist(old$functions[[key]], use.names = FALSE) %or% character()
      }),
      removed
    )
    changes[[label]] <- list(
      source = label,
      previous_hash = previous_hash,
      current_hash = hashes[[i]],
      comparable = comparable,
      added = added,
      unselected = unselected,
      removed = functions,
      affected_functions = unique(unlist(functions, use.names = FALSE)) %or%
        character()
    )
  }
  changes
}

format_schema_change <- function(change) {
  lines <- c(
    paste0('Schema changed since last apply: ', change$source),
    paste0('  Previous SHA-256: ', change$previous_hash %or% 'not recorded'),
    paste0('  Current SHA-256: ', change$current_hash)
  )
  if (change$comparable) {
    lines <- c(
      lines,
      sprintf(
        '  Added endpoints (%d; %d not selected)',
        length(change$added),
        length(change$unselected)
      ),
      if (length(change$added)) {
        paste0(
          '    ',
          change$added,
          ifelse(change$added %in% change$unselected, ' [not selected]', '')
        )
      },
      sprintf('  Removed endpoints (%d)', length(change$removed)),
      vapply(
        names(change$removed),
        function(key) {
          functions <- change$removed[[key]]
          paste0(
            '    ',
            key,
            if (length(functions)) {
              paste0(' -> ', paste(functions, collapse = ', '))
            }
          )
        },
        character(1)
      ),
      sprintf(
        '  Configured functions affected (%d)',
        length(change$affected_functions)
      )
    )
  } else {
    lines <- c(
      lines,
      '  Endpoint comparison unavailable; no recorded inventory or current schema could not be read.'
    )
  }
  paste(
    c(
      lines,
      'Check does not rebuild functions. Run mode = "plan" to review file changes before applying.'
    ),
    collapse = '\n'
  )
}
