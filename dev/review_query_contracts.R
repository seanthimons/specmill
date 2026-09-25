# Run from the repository root after R CMD INSTALL . No service calls or schema edits.
local({
  root <- tempfile('query-contracts-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE))
  zip <- 'dev/proving-ground-schemas/specmill-testing-base-schemas.zip'
  apis <- c('alerts', 'hazard', 'resolver', 'services', 'standardizer', 'toxprints')
  files <- paste0('specmill-testing/schema/', apis, '.json')
  utils::unzip(zip, files = files, exdir = root)
  historical <- read.csv('dev/audits/proving-ground/schemas.csv')
  rows <- list()
  for (i in seq_along(files)) {
    file <- file.path(root, files[[i]])
    hash <- digest::digest(file = file, algo = 'sha256')
    stopifnot(hash %in% historical$sha256)
    document <- jsonlite::read_json(file)
    parsed <- specmill::read_operations(file)
    for (path in names(document$paths)) {
      item <- document$paths[[path]]
      for (method in intersect(names(item), c('get', 'post', 'put', 'patch', 'delete', 'head', 'options', 'trace'))) {
        operation <- item[[method]]
        # These snapshots keep the affected parameters on operations.
        stopifnot(is.null(item$parameters))
        for (j in seq_along(operation$parameters)) {
          parameter <- operation$parameters[[j]]
          if (!identical(parameter[['in']], 'query')) next
          pointer <- paste0('#/paths/', gsub('/', '~1', gsub('~', '~0', path, fixed = TRUE), fixed = TRUE), '/', method, '/parameters/', j - 1L)
          schema <- specmill:::input_schema(parameter$schema, document, source_location = paste0(pointer, '/schema'))
          problem <- tryCatch(
            specmill:::parameter_shape(parameter, schema, document$openapi, pointer),
            error = identity
          )
          if (!inherits(problem, 'error') || !problem$code %in% c('binary_parameter', 'nested_parameter')) next
          key <- paste(toupper(method), path)
          diagnostics <- Filter(function(x) identical(x$key, key), parsed$diagnostics)
          stopifnot(length(diagnostics) == 1L, !key %in% vapply(parsed$operations, `[[`, '', 'key'))
          rows[[length(rows) + 1L]] <- data.frame(
            api = apis[[i]], key = key,
            issue = if (problem$code == 'binary_parameter') 28L else 31L,
            parameter = parameter$name, required = isTRUE(parameter$required),
            pointer = pointer, schema_ref = if (is.null(parameter$schema[['$ref']])) '' else parameter$schema[['$ref']],
            style = if (is.null(parameter$style)) 'form (default)' else parameter$style,
            explode = if (is.null(parameter$explode)) 'true (default for form)' else as.character(parameter$explode),
            body_media = paste(names(operation$requestBody$content), collapse = ';'),
            code = problem$code, parser_reason = diagnostics[[1L]]$reason,
            schema_sha256 = hash, disposition = 'unresolved', evidence = 'QUERY-CONTRACTS.md'
          )
        }
      }
    }
  }
  ledger <- do.call(rbind, rows)
  binary <- unique(ledger$key[ledger$issue == 28L])
  nested <- unique(ledger$key[ledger$issue == 31L])
  stopifnot(
    length(binary) == 18L, length(nested) == 13L,
    length(intersect(binary, nested)) == 11L,
    length(union(binary, nested)) == 20L,
    setequal(setdiff(nested, binary), c('GET /api/stdizer/protocols/{id}', 'POST /api/stdizer/protocols/{id}'))
  )
  output <- 'dev/audits/source-contracts/query-contracts.csv'
  write.csv(ledger, output, row.names = FALSE)
  cat('20 blocked operations: 18 binary-query, 13 nested-query, 11 overlaps. All unresolved.\n')
})
