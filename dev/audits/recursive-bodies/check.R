# Run from the repository root after R CMD INSTALL .
# Optional first argument: extracted historical standardizer.json.
args <- commandArgs(trailingOnly = TRUE)
local({
  root <- tempfile('recursive-audit-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE))
  schema <- if (length(args)) {
    args[[1L]]
  } else {
    zip <- 'dev/proving-ground-schemas/specmill-testing-base-schemas.zip'
    member <- utils::unzip(zip, list = TRUE)$Name
    member <- member[grepl('/standardizer.json$', member)]
    stopifnot(length(member) == 1L)
    utils::unzip(zip, files = member, exdir = root)
    file.path(root, member)
  }
  parsed <- specmill::read_operations(schema)
  keys <- c(
    'POST /api/stdizer/protocol/export',
    'POST /api/stdizer/protocols',
    'PUT /api/stdizer/protocols/{id}',
    'POST /api/stdizer/protocols/{id}/export'
  )
  operations <- Filter(function(op) op$key %in% keys, parsed$operations)
  stopifnot(length(operations) == 4L)
  source('tests/native-transport.R')
  native_transport_acceptance(function(runtime, root) {
    for (op in operations) {
      eval(
        parse(
          text = specmill::render_operation(
            op,
            list(helper = 'api_request')
          )
        ),
        runtime
      )
      inputs <- specmill::operation_fixtures(list(op))[[1L]]
      exported <- grepl('/export$', op$path)
      protocol <- if (exported) inputs$body$protocol else inputs$body
      stopifnot(!'parent' %in% names(protocol$records[[1L]]))
      leaf <- protocol$records[[1L]]
      protocol$records[[1L]]$parent <- list(id = 'parent', parent = leaf)
      if (exported) {
        inputs$body$protocol <- protocol
      } else {
        inputs$body <- protocol
      }
      expected <- as.character(jsonlite::toJSON(
        inputs$body,
        auto_unbox = TRUE,
        null = 'null',
        digits = NA
      ))
      response <- do.call(runtime[[op$name]], inputs)
      stopifnot(
        identical(rawToChar(as.raw(unlist(response$bytes))), expected),
        identical(response$method, op$method),
        identical(response$path, sub('{id}', 'example', op$path, fixed = TRUE))
      )
      if (exported) {
        inputs$body$protocol$records[[1L]]$parent$status <- 'INVALID'
      } else {
        inputs$body$records[[1L]]$parent$status <- 'INVALID'
      }
      stopifnot(inherits(
        try(do.call(runtime[[op$name]], inputs), silent = TRUE),
        'try-error'
      ))
      cat(
        op$key,
        ': parse, render, fixture, recursive validation, exact localhost JSON passed\n'
      )
    }
  })
})
