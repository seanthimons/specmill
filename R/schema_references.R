schema_reference_error <- function(ref, code, message) {
  structure(
    list(
      '$ref' = ref,
      'x-specmill-reference-error' = list(code = code, message = message)
    ),
    class = 'specmill_reference_error'
  )
}

schema_reference_pointer <- function(document, fragment, ref) {
  if (!fragment %in% c('', '#') && !startsWith(fragment, '#/')) {
    return(schema_reference_error(
      ref,
      'local_reference',
      paste('Unsupported local reference fragment:', ref)
    ))
  }
  if (fragment %in% c('', '#')) {
    return(document)
  }
  parts <- strsplit(sub('^#/', '', fragment), '/', fixed = TRUE)[[1L]]
  if (any(grepl('~([^01]|$)', parts))) {
    return(schema_reference_error(
      ref,
      'invalid_reference',
      paste('Invalid reference escape:', ref)
    ))
  }
  parts <- gsub('~0', '~', gsub('~1', '/', parts, fixed = TRUE), fixed = TRUE)
  value <- document
  for (part in parts) {
    if (!is.list(value)) {
      return(schema_reference_error(
        ref,
        'unresolved_reference',
        paste('Missing reference:', ref)
      ))
    }
    index <- if (is.null(names(value)) && grepl('^(0|[1-9][0-9]*)$', part)) {
      as.integer(part) + 1L
    } else {
      part
    }
    missing <- if (is.numeric(index)) {
      is.na(index) || index > length(value) || is.null(value[[index]])
    } else {
      is.null(value[[index]])
    }
    if (missing) {
      return(schema_reference_error(
        ref,
        'unresolved_reference',
        paste('Missing reference:', ref)
      ))
    }
    value <- value[[index]]
  }
  value
}

reference_lock_path <- function(path) {
  file.path(dirname(path), 'specmill-references.yml')
}

# Reviewed URL-to-file mappings for remote references. Malformed lock data is
# a configuration error, not a per-reference diagnostic.
read_reference_lock <- function(path) {
  lock_path <- reference_lock_path(path)
  if (!file.exists(lock_path)) {
    return(NULL)
  }
  lock_path <- normalizePath(lock_path, winslash = '/', mustWork = TRUE)
  fail <- function(...) stop(lock_path, ': ', ..., call. = FALSE)
  lock <- tryCatch(
    read_schema_document(lock_path, resolve_references = FALSE),
    error = function(e) fail(conditionMessage(e))
  )
  if (
    !is.list(lock) ||
      !identical(names(lock), 'references') ||
      !is.list(lock$references) ||
      !is.null(names(lock$references))
  ) {
    fail('expected only a `references` sequence')
  }
  root <- dirname(lock_path)
  entries <- list()
  for (i in seq_along(lock$references)) {
    entry <- lock$references[[i]]
    at <- paste0('references[', i, ']')
    fields <- c('url', 'file', 'sha256')
    if (
      !is.list(entry) ||
        !all(fields %in% names(entry)) ||
        length(setdiff(names(entry), c(fields, 'retrieved')))
    ) {
      fail(at, ' needs url, file and sha256 (optional: retrieved)')
    }
    for (field in names(entry)) {
      tryCatch(
        config_string(entry[[field]], field),
        error = function(e) fail(at, ': ', conditionMessage(e))
      )
    }
    if (!grepl('^https?://[^/?#]+', entry$url) || grepl('#', entry$url)) {
      fail(at, ': url must be an absolute HTTP(S) URL without a fragment')
    }
    if (!is.null(entries[[entry$url]])) {
      fail(at, ': duplicate url ', entry$url)
    }
    if (!grepl('^[0-9a-f]{64}$', entry$sha256)) {
      fail(at, ': sha256 must be 64 lowercase hexadecimal characters')
    }
    target <- file.path(root, entry$file)
    if (file.exists(target)) {
      target <- normalizePath(target, winslash = '/')
    }
    if (
      fs::is_absolute_path(entry$file) ||
        !fs::path_has_parent(target, root) ||
        dir.exists(target)
    ) {
      fail(at, ': file must be a file inside ', root)
    }
    entries[[entry$url]] <- list(
      file = as.character(fs::path_norm(target)),
      sha256 = entry$sha256
    )
  }
  list(path = lock_path, entries = entries)
}

# RFC 3986 section 5.2 reference resolution against an absolute base URI.
reference_uri <- function(base, ref) {
  if (grepl('^[A-Za-z][A-Za-z0-9+.-]*:', ref)) {
    return(ref)
  }
  if (startsWith(ref, '#') || startsWith(ref, '?')) {
    return(paste0(
      sub(if (startsWith(ref, '#')) '#.*$' else '[?#].*$', '', base),
      ref
    ))
  }
  if (startsWith(ref, '//')) {
    return(paste0(sub(':.*$', ':', base), ref))
  }
  authority <- sub('^([^:]+://[^/?#]*).*$', '\\1', base)
  path <- if (startsWith(ref, '/')) {
    ref
  } else {
    base_path <- substring(sub('[?#].*$', '', base), nchar(authority) + 1L)
    paste0(sub('[^/]*$', '', if (nzchar(base_path)) base_path else '/'), ref)
  }
  query <- regmatches(path, regexpr('[?].*$', path))
  path <- sub('[?].*$', '', path)
  segments <- character()
  for (segment in strsplit(path, '/', fixed = TRUE)[[1L]][-1L]) {
    if (segment == '..') {
      segments <- utils::head(segments, -1L)
    } else if (segment != '.') {
      segments <- c(segments, segment)
    }
  }
  trailing <- if (length(segments) && grepl('/(\\.\\.?)?$', path)) '/' else ''
  paste0(
    authority,
    '/',
    paste(segments, collapse = '/'),
    trailing,
    paste(query, collapse = '')
  )
}

resolve_schema_references <- function(document, path) {
  root <- normalizePath(path, winslash = '/', mustWork = TRUE)
  dependencies <- stats::setNames(tools::md5sum(root), root)
  lock <- read_reference_lock(root)
  documents <- list()
  resolved <- list()
  is_uri <- function(x) grepl('^https?://', x)
  # Mapped documents are keyed by URI: their base for nested references is the
  # reviewed URL, never the local storage path.
  load_remote <- function(uri, ref) {
    if (is.null(documents[[uri]])) {
      entry <- lock$entries[[uri]]
      dependencies[[lock$path]] <<- tools::md5sum(lock$path)
      documents[[uri]] <<- if (!file.exists(entry$file)) {
        schema_reference_error(
          ref,
          'unresolved_reference',
          paste0('Missing reviewed reference file for ', uri, ': ', entry$file)
        )
      } else {
        sha256 <- digest::digest(file = entry$file, algo = 'sha256')
        dependencies[[entry$file]] <<- tools::md5sum(entry$file)
        if (!identical(sha256, entry$sha256)) {
          schema_reference_error(
            ref,
            'reference_hash_mismatch',
            paste0(
              'Reviewed reference file ',
              entry$file,
              ' has SHA-256 ',
              sha256,
              ' but ',
              basename(lock$path),
              ' records ',
              entry$sha256,
              ' for ',
              uri
            )
          )
        } else {
          tryCatch(
            read_schema_document(entry$file, resolve_references = FALSE),
            error = function(e) {
              schema_reference_error(
                ref,
                'invalid_reference',
                paste('Cannot read reference:', ref)
              )
            }
          )
        }
      }
    }
    documents[[uri]]
  }
  load_document <- function(file) {
    file <- normalizePath(file, winslash = '/', mustWork = TRUE)
    if (!file %in% names(dependencies)) {
      dependencies[[file]] <<- tools::md5sum(file)
    }
    if (is.null(documents[[file]])) {
      documents[[file]] <<- read_schema_document(
        file,
        resolve_references = FALSE
      )
    }
    documents[[file]]
  }
  resolve <- function(
    node,
    current,
    file,
    inline_local = FALSE,
    stack = character(),
    allow_ref = TRUE
  ) {
    if (!is.list(node)) {
      return(node)
    }
    id <- node[['$id']]
    if (
      is_uri(file) &&
        is.character(id) &&
        length(id) == 1L &&
        !startsWith(id, '#') &&
        !identical(sub('#.*$', '', reference_uri(file, id)), file)
    ) {
      # ponytail: $id rebasing is rejected rather than modelled; add a base
      # stack when a reviewed dependency needs it.
      return(schema_reference_error(
        id,
        'reference_base',
        paste('Remote schema $id changes the reference base:', id)
      ))
    }
    ref <- node[['$ref']]
    if (!allow_ref || is.null(ref) || !is.character(ref) || length(ref) != 1L) {
      if (is.null(names(node))) {
        return(lapply(
          node,
          resolve,
          current = current,
          file = file,
          inline_local = inline_local,
          stack = stack
        ))
      }
      result <- lapply(names(node), function(name) {
        value <- node[[name]]
        if (name %in% c('example', 'examples', 'default', 'enum', 'const')) {
          return(value)
        }
        resolve(value, current, file, inline_local, stack)
      })
      names(result) <- names(node)
      return(result)
    }
    if (is.na(ref)) {
      return(schema_reference_error(
        '',
        'invalid_reference',
        'Reference must be a string'
      ))
    }
    split <- regexpr('#', ref, fixed = TRUE)[[1L]]
    target_file <- if (split < 0L) ref else substr(ref, 1L, split - 1L)
    fragment <- if (split < 0L) '' else substr(ref, split, nchar(ref))
    external <- nzchar(target_file)
    remote <- external &&
      (is_uri(file) ||
        grepl('^(?:[A-Za-z][A-Za-z0-9+.-]*:|//)', target_file))
    if (!external && !inline_local) {
      return(node)
    }
    if (remote) {
      target_path <- if (is_uri(file)) {
        reference_uri(file, target_file)
      } else {
        target_file
      }
      if (is.null(lock$entries[[target_path]])) {
        return(schema_reference_error(
          ref,
          'external_reference',
          paste0('Remote reference is not fetched: ', target_path, fragment)
        ))
      }
      target_document <- load_remote(target_path, ref)
      if (inherits(target_document, 'specmill_reference_error')) {
        return(target_document)
      }
    } else if (external) {
      target_path <- normalizePath(
        file.path(dirname(file), utils::URLdecode(target_file)),
        winslash = '/',
        mustWork = FALSE
      )
      if (!file.exists(target_path)) {
        return(schema_reference_error(
          ref,
          'unresolved_reference',
          paste('Missing reference file:', ref)
        ))
      }
      target_document <- tryCatch(
        load_document(target_path),
        error = function(e) {
          schema_reference_error(
            ref,
            'invalid_reference',
            paste('Cannot read reference:', ref)
          )
        }
      )
      if (inherits(target_document, 'specmill_reference_error')) {
        return(target_document)
      }
    } else {
      target_path <- file
      target_document <- current
    }
    target <- schema_reference_pointer(target_document, fragment, ref)
    if (inherits(target, 'specmill_reference_error')) {
      return(target)
    }
    identity <- paste0(target_path, fragment %or% '#')
    if (length(stack) >= 100L) {
      return(schema_reference_error(
        ref,
        'reference_depth',
        'Reference nesting exceeds 100 levels'
      ))
    }
    if (identity %in% stack) {
      return(schema_reference_error(
        ref,
        'recursive_reference',
        paste(
          'Recursive reference:',
          if (is_uri(target_path)) identity else ref
        )
      ))
    }
    if (!is.null(resolved[[identity]])) {
      target <- resolved[[identity]]
    } else {
      target <- resolve(
        target,
        target_document,
        target_path,
        TRUE,
        c(stack, identity)
      )
      resolved[[identity]] <<- target
    }
    if (inherits(target, 'specmill_reference_error')) {
      return(target)
    }
    siblings <- node[setdiff(names(node), '$ref')]
    if (length(setdiff(names(siblings), c('summary', 'description')))) {
      return(schema_reference_error(
        ref,
        'reference_siblings',
        paste(
          'Bundled reference assertion siblings require an explicit allOf:',
          ref
        )
      ))
    }
    siblings <- lapply(
      siblings,
      resolve,
      current = current,
      file = file,
      inline_local = inline_local,
      stack = stack
    )
    if (length(siblings)) {
      target <- utils::modifyList(target, siblings)
    }
    target
  }
  resolved <- resolve(document, document, root)
  if (length(dependencies) > 1L) {
    attr(resolved, 'specmill_reference_dependencies') <- dependencies
  }
  resolved
}

freeze_references <- function(schema, urls, refresh = FALSE) {
  config_string(schema, 'schema')
  schema <- normalizePath(schema, winslash = '/', mustWork = TRUE)
  if (!is.character(urls) || !length(urls) || anyNA(urls)) {
    stop('urls must be a nonempty character vector', call. = FALSE)
  }
  if (!isTRUE(refresh) && !isFALSE(refresh)) {
    stop('refresh must be TRUE or FALSE', call. = FALSE)
  }
  urls <- unique(urls)
  lock_path <- reference_lock_path(schema)
  root <- dirname(lock_path)
  lock <- read_reference_lock(schema)
  entries <- if (is.null(lock)) {
    list()
  } else {
    read_schema_document(lock_path, resolve_references = FALSE)$references
  }
  known <- vapply(entries, `[[`, character(1), 'url')
  claimed <- vapply(entries, `[[`, character(1), 'file')
  sha256 <- function(path) digest::digest(file = path, algo = 'sha256')
  inside <- function(path) {
    existing <- path
    while (!file.exists(existing)) {
      existing <- dirname(existing)
    }
    existing <- normalizePath(existing, winslash = '/')
    identical(existing, root) || fs::path_has_parent(existing, root)
  }
  # Phase 1 downloads and checks everything; nothing is written on failure.
  plan <- lapply(urls, function(url) {
    path <- sub('^https?://[^/?#]+', '', url)
    if (
      !grepl('^https?://[^/?#]+/', url) ||
        grepl('[?#]', url) ||
        grepl('/$', path) ||
        any(strsplit(path, '/', fixed = TRUE)[[1L]] %in% c('.', '..'))
    ) {
      stop(
        'Cannot freeze ',
        url,
        ': use an HTTP(S) document URL without query, ',
        'fragment, dot segments or trailing slash; map other URLs by hand ',
        'in ',
        basename(lock_path),
        call. = FALSE
      )
    }
    index <- match(url, known)
    file <- if (is.na(index)) {
      gsub(
        '[^A-Za-z0-9._/-]',
        '_',
        paste0('references/', sub('^https?://', '', url))
      )
    } else {
      entries[[index]]$file
    }
    target <- file.path(root, file)
    # Case-folded, and no file may be another's directory, so one batch
    # cannot write the same path twice on case-insensitive filesystems.
    clash <- function(a, b) {
      a <- tolower(a)
      b <- tolower(b)
      a == b | startsWith(a, paste0(b, '/')) | startsWith(b, paste0(a, '/'))
    }
    if (is.na(index) && (any(clash(file, claimed)) || file.exists(target))) {
      stop(
        'Cannot freeze ',
        url,
        ': ',
        file,
        ' is already in use',
        call. = FALSE
      )
    }
    if (!inside(target)) {
      stop('Cannot freeze ', url, ': ', file, ' escapes ', root, call. = FALSE)
    }
    claimed <<- c(claimed, file)
    ext <- tools::file_ext(file)
    download <- tempfile(fileext = if (nzchar(ext)) paste0('.', ext) else '')
    withCallingHandlers(
      utils::download.file(
        url,
        download,
        mode = 'wb',
        quiet = TRUE,
        method = 'libcurl'
      ),
      warning = function(w) {
        stop('Cannot download ', url, ': ', conditionMessage(w), call. = FALSE)
      }
    )
    tryCatch(
      read_schema_document(download, resolve_references = FALSE),
      error = function(e) {
        stop('Cannot parse ', url, ': ', conditionMessage(e), call. = FALSE)
      }
    )
    hash <- sha256(download)
    status <- if (is.na(index)) {
      'added'
    } else if (!identical(hash, entries[[index]]$sha256)) {
      if (!refresh) {
        stop(
          url,
          ' changed: ',
          basename(lock_path),
          ' records ',
          entries[[index]]$sha256,
          ', upstream is ',
          hash,
          '. Review it, then call again with refresh = TRUE.',
          call. = FALSE
        )
      }
      'refreshed'
    } else if (!file.exists(target) || !identical(sha256(target), hash)) {
      'restored'
    } else {
      'unchanged'
    }
    list(
      url = url,
      file = file,
      download = download,
      sha256 = hash,
      status = status,
      index = index
    )
  })
  on.exit(unlink(vapply(plan, `[[`, character(1), 'download')), add = TRUE)
  retrieved <- format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC')
  for (item in plan) {
    if (item$status %in% c('added', 'refreshed')) {
      entry <- list(
        url = item$url,
        file = item$file,
        sha256 = item$sha256,
        retrieved = retrieved
      )
      if (is.na(item$index)) {
        entries[[length(entries) + 1L]] <- entry
      } else {
        entries[[item$index]] <- entry
      }
    }
  }
  changed <- Filter(function(x) x$status != 'unchanged', plan)
  # ponytail: files land before the lock rename; a crash in between leaves a
  # hash mismatch diagnostic, never a silently wrong reference. A failed write
  # puts back overwritten copies and removes new ones.
  staged <- tempfile('specmill-references-', tmpdir = root, fileext = '.yml')
  on.exit(unlink(staged), add = TRUE)
  yaml::write_yaml(list(references = entries), staged)
  written <- character()
  backups <- character()
  on.exit(unlink(backups), add = TRUE)
  undo <- function(path) {
    unlink(written)
    kept <- backups[!file.rename(backups, names(backups))]
    backups <<- character()
    stop(
      'Cannot write ',
      path,
      if (length(kept)) {
        paste0('; previous copies kept at ', paste(kept, collapse = ', '))
      },
      call. = FALSE
    )
  }
  for (item in changed) {
    target <- file.path(root, item$file)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (file.exists(target)) {
      backup <- tempfile('specmill-backup-', tmpdir = dirname(target))
      if (!file.copy(target, backup)) {
        unlink(backup)
        undo(target)
      }
      backups[target] <- backup
    } else {
      written <- c(written, target)
    }
    if (!isTRUE(file.copy(item$download, target, overwrite = TRUE))) {
      undo(target)
    }
  }
  if (
    any(
      vapply(changed, `[[`, character(1), 'status') %in% c('added', 'refreshed')
    ) &&
      !file.rename(staged, lock_path)
  ) {
    undo(lock_path)
  }
  read_reference_lock(schema)
  invisible(data.frame(
    url = vapply(plan, `[[`, character(1), 'url'),
    file = vapply(plan, `[[`, character(1), 'file'),
    sha256 = vapply(plan, `[[`, character(1), 'sha256'),
    status = vapply(plan, `[[`, character(1), 'status')
  ))
}
