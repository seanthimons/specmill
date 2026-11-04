# Public compatibility entry point. Selection and naming remain reviewed policy;
# OpenAPI-specific document and request reading lives in the native importer.
read_operations <- function(files, policy = list()) {
  policy <- prepare_operation_policy(policy)
  finish_operation_policy(openapi_read_records(files, policy), policy)
}

compare_operations <- function(old, new) {
  identity <- function(op) {
    paste(op$service %or% basename(op$source %or% ''), op$key)
  }
  old <- setNames(
    old$operations,
    vapply(old$operations, identity, character(1))
  )
  new <- setNames(
    new$operations,
    vapply(new$operations, identity, character(1))
  )
  out <- list()
  add <- function(key, status, reason) {
    out[[length(out) + 1L]] <<- list(
      key = key,
      status = status,
      reason = reason
    )
  }
  for (key in setdiff(names(old), names(new))) {
    add(key, 'breaking', 'Operation removed')
  }
  for (key in setdiff(names(new), names(old))) {
    add(key, 'added', 'Operation added')
  }
  for (key in intersect(names(old), names(new))) {
    a <- old[[key]]
    b <- new[[key]]
    ids <- function(ps) {
      setNames(
        ps,
        vapply(ps, function(p) paste(p$location, p$name), character(1))
      )
    }
    ap <- ids(a$parameters)
    bp <- ids(b$parameters)
    for (id in setdiff(names(bp), names(ap))) {
      add(
        key,
        if (isTRUE(bp[[id]]$required)) 'breaking' else 'added',
        paste('Parameter added:', id)
      )
    }
    if (length(setdiff(names(ap), names(bp)))) {
      add(key, 'breaking', 'Parameter removed')
    }
    for (id in intersect(names(ap), names(bp))) {
      if (!identical(ap[[id]], bp[[id]])) {
        add(key, 'review', paste('Parameter contract changed:', id))
      }
    }
    if (
      !identical(a$body, b$body) ||
        !identical(a$body_required, b$body_required) ||
        !identical(a$body_media, b$body_media) ||
        !identical(a$body_encoding, b$body_encoding) ||
        !identical(a$text_encoding, b$text_encoding)
    ) {
      add(key, 'review', 'Body changed')
    }
    if (!identical(a$server, b$server)) {
      add(key, 'review', 'Effective server changed')
    }
    if (!identical(a$response, b$response)) {
      add(key, 'unknown', 'Response compatibility is not classified')
    }
    if (
      !identical(a$security, b$security) ||
        !identical(a$security_schemes, b$security_schemes)
    ) {
      add(key, 'review', 'Authentication requirements changed')
    }
  }
  out
}
