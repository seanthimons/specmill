# Contract-change deferral: one explicitly enrolled contract revision of an
# operation is withheld from replacement generation until its contract changes.

deferral_fingerprint_version <- 1L

deferral_reason <- function(x) {
  if (
    !is.character(x) ||
      length(x) != 1L ||
      is.na(x) ||
      !nzchar(trimws(x)) ||
      nchar(x) > 500L ||
      grepl('[\r\n]', x)
  ) {
    stop(
      'A deferral reason must be one nonblank line of at most 500 characters'
    )
  }
  trimws(x)
}

deferral_arguments <- function(deferrals) {
  if (is.null(deferrals)) {
    deferrals <- list()
  }
  config_fields(deferrals, c('enroll', 'clear'), 'deferrals')
  enroll <- unlist(deferrals$enroll)
  if (length(enroll)) {
    if (is.null(names(enroll)) || !all(nzchar(names(enroll)))) {
      stop('deferrals$enroll must map operation IDs to reasons')
    }
    if (anyDuplicated(names(enroll))) {
      stop('deferrals$enroll names an operation more than once')
    }
    enroll <- stats::setNames(
      vapply(enroll, deferral_reason, character(1)),
      names(enroll)
    )
  } else {
    enroll <- character()
  }
  clear <- as.character(unlist(deferrals$clear))
  if (anyNA(clear) || length(intersect(clear, names(enroll)))) {
    stop('deferrals$clear must be operation IDs not also enrolled')
  }
  list(enroll = enroll, clear = unique(clear))
}

# Stored records are untrusted: anything not exactly current is uncertain.
deferral_record <- function(x) {
  fields <- c('key', 'source', 'reason', 'fingerprint')
  is.list(x) &&
    all(vapply(
      x[fields],
      function(f) is.character(f) && length(f) == 1L && !is.na(f),
      logical(1)
    )) &&
    identical(as.integer(unlist(x$version)), deferral_fingerprint_version) &&
    startsWith(x$fingerprint, paste0('v', deferral_fingerprint_version, ':'))
}

# One of: cleared, deferred, retry, or uncertain (with a reason).
deferral_state <- function(record, fingerprint, cleared) {
  if (cleared) {
    return(list(state = 'cleared'))
  }
  if (!deferral_record(record)) {
    return(list(
      state = 'uncertain',
      detail = 'enrollment metadata is missing or from an incompatible version'
    ))
  }
  if (is.null(fingerprint)) {
    return(list(
      state = 'uncertain',
      detail = 'the operation or its contract cannot be read from the enrolled source'
    ))
  }
  list(
    state = if (identical(fingerprint, record$fingerprint)) {
      'deferred'
    } else {
      'retry'
    }
  )
}

# Source text of one named function with its roxygen block, or NULL.
deferral_member_text <- function(path, name) {
  if (!file.exists(path)) {
    return(NULL)
  }
  definitions <- tg_find_function_defs_in_file(path, documentation = TRUE)
  if (is.null(definitions[[name]])) {
    return(NULL)
  }
  expressions <- parse(file = path, keep.source = TRUE)
  index <- Find(
    function(i) {
      e <- expressions[[i]]
      is.call(e) &&
        as.character(e[[1L]]) %in% c('<-', '=') &&
        identical(as.character(e[[2L]]), name)
    },
    seq_along(expressions)
  )
  if (is.null(index)) {
    return(NULL)
  }
  paste(
    c(
      definitions[[name]]$documentation,
      as.character(attr(expressions, 'srcref')[[index]])
    ),
    collapse = '\n'
  )
}

format_deferrals <- function(deferrals) {
  if (!length(deferrals)) {
    return(character())
  }
  label <- c(
    deferred = 'deferred (awaiting contract change)',
    enrolled = 'enrolled (committed on apply)',
    retry_recovered = 'retried: recovery candidate',
    retry_blocked = 'retried: still blocked',
    auto_enrolled = 'retried: re-enrolled by automatic policy (committed on apply)',
    cleared = 'cleared (retried)',
    uncertain = 'uncertain (enrollment kept)'
  )
  vapply(
    names(deferrals),
    function(id) {
      x <- deferrals[[id]]
      paste0(
        '  ',
        id,
        ': ',
        label[[x$state]],
        if (length(x$detail)) paste0(' - ', x$detail)
      )
    },
    character(1)
  )
}
