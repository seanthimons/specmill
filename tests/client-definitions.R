client_definitions_acceptance <- function() {
  root <- tempfile('client-definitions-')
  dir.create(file.path(root, 'R'), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines(
    '.ct_request_build <- function(x) x',
    file.path(root, 'R/helper.R')
  )
  writeLines(
    c('.ct_request_build <- function(y) y', 'other <- function() 1'),
    file.path(root, 'R/legacy.R')
  )
  found <- specmill:::client_definitions(file.path(root, 'unrelated'))
  stopifnot(length(found) == 0L)
  root <- normalizePath(root, winslash = '/')
  error <- tryCatch(specmill:::client_definitions(root), error = identity)
  message <- if (inherits(error, 'error')) conditionMessage(error) else ''
  stopifnot(
    inherits(error, 'error'),
    grepl('Duplicate client runtime definitions', message, fixed = TRUE),
    # The symbol and both files are named, so nobody has to search for them.
    grepl('.ct_request_build', message, fixed = TRUE),
    grepl('R/helper.R', message, fixed = TRUE),
    grepl('R/legacy.R', message, fixed = TRUE),
    !grepl('other', message, fixed = TRUE)
  )
  unlink(file.path(root, 'R/legacy.R'))
  stopifnot(identical(
    names(specmill:::client_definitions(root)),
    '.ct_request_build'
  ))
  cat(
    'Client definitions: duplicate runtime definitions name the symbol and both files.\n'
  )
}

if (sys.nframe() == 0L) {
  client_definitions_acceptance()
}
