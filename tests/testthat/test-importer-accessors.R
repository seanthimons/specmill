importer_accessors_acceptance <- function() {
  internal <- function(name) utils::getFromNamespace(name, 'specmill')
  workspace <- tempfile('importer-accessors-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  file <- file.path(workspace, 'api.json')
  document <- jsonlite::read_json(system.file(
    'catalogue/schema.json',
    package = 'specmill'
  ))
  save <- function(value) jsonlite::write_json(value, file, auto_unbox = TRUE)
  save(document)
  source <- internal('openapi_configuration_source')(file)
  events <- list()
  source$operations(
    function(metadata) {
      events[[length(events) + 1L]] <<- metadata
    },
    function(...) stop('Unexpected diagnostic')
  )
  stopifnot(
    length(events) == 4L,
    all(vapply(
      events,
      function(x) {
        identical(names(x), c('key', 'path', 'method', 'tags', 'name'))
      },
      logical(1)
    ))
  )
  # A cached source must describe one snapshot even if its file changes later.
  changed <- document
  changed$paths <- list()
  save(changed)
  cached <- list()
  source$operations(
    function(metadata) {
      cached[[length(cached) + 1L]] <<- metadata
    },
    function(...) stop('Unexpected diagnostic')
  )
  stopifnot(identical(events, cached))
  # Configuration policy failure on an earlier operation must precede malformed
  # tags on a later operation. Eagerly collecting all metadata changes this order.
  changed <- document
  keys <- sort(names(changed$paths), method = 'radix')
  changed$paths[[tail(keys, 1L)]][[1L]]$tags <- list(123L)
  save(changed)
  source <- internal('openapi_configuration_source')(file)
  failure <- tryCatch(
    source$operations(
      function(metadata) {
        stop('Earlier policy failure')
      },
      function(...) NULL
    ),
    error = conditionMessage
  )
  stopifnot(identical(failure, 'Earlier policy failure'))
  # Server inspection is deferred so a reviewed base URL can replace an invalid
  # native declaration without changing initialization validation order.
  changed <- document
  changed$servers <- list(list(url = 1L))
  save(changed)
  source <- internal('openapi_initialization_source')(file)
  stopifnot(is.function(source$server))
  # The legacy diff adapter loads both sources before invoking the client parser,
  # and invokes that parser in its own explicit policy environment.
  save(document)
  parses <- 0L
  parser <- function(document) {
    parses <<- parses + 1L
    document$info$title
  }
  failure <- tryCatch(
    internal('openapi_spec_tables')(
      c(file, file.path(workspace, 'missing.json')),
      parser
    ),
    error = identity
  )
  stopifnot(inherits(failure, 'error'), parses == 0L)
  tables <- internal('openapi_spec_tables')(c(file, file), parser)
  stopifnot(parses == 2L, identical(tables, rep(list(document$info$title), 2L)))
  cat(
    'Importer accessors: source snapshots, lazy policy ordering, server overrides and client parser context passed.\n'
  )
}
test_that('importer accessors keep snapshots and policy ordering', {
  importer_accessors_acceptance()
  succeed()
})
