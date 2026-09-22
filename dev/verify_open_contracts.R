# Offline source-contract ledger for #26, #27, #28 and #31. Run from repo root.
# Reads archived bytes only; no policy overrides or service calls.
local({
  args <- commandArgs(trailingOnly = TRUE)
  source <- if (length(args)) args[[1L]] else
    'artifacts/proving-ground-20260921T213801Z/inputs/specmill-testing/schema'
  if (length(args) && !dir.exists(source)) stop('Schema directory does not exist: ', source)
  if (!dir.exists(source)) {
    temporary <- tempfile('open-contracts-')
    dir.create(temporary)
    on.exit(unlink(temporary, recursive = TRUE))
    utils::unzip('dev/proving-ground-schemas/specmill-testing-base-schemas.zip', exdir = temporary)
    source <- file.path(temporary, 'specmill-testing/schema')
  }
  output <- 'dev/audits/open-issues-20260922'
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  historical <- read.csv('dev/audits/proving-ground/schemas.csv')
  rows <- list()
  append_row <- function(api, key, issue, kind, pointer, parameter, required,
                         declared, code, reason, hash, dependency) {
    rows[[length(rows) + 1L]] <<- data.frame(schema = paste0(api, '.json'),
      key = key, issue = issue, kind = kind, pointer = pointer,
      parameter = parameter, required = required, declared = declared,
      code = code, parser_reason = reason, schema_sha256 = hash,
      disposition = 'unresolved; keep blocked', dependency = dependency,
      evidence = if (api == 'amos') '../source-contracts/AMOS.md' else '../source-contracts/QUERY-CONTRACTS.md')
  }
  for (api in c('amos', 'alerts', 'hazard', 'resolver', 'services', 'standardizer', 'toxprints')) {
    file <- file.path(source, paste0(api, '.json'))
    hash <- digest::digest(file = file, algo = 'sha256')
    stopifnot(hash %in% historical$sha256)
    document <- jsonlite::read_json(file)
    parsed <- specmill::read_operations(file)
    keys <- vapply(parsed$operations, `[[`, '', 'key')
    if (api == 'amos') {
      for (diagnostic in parsed$diagnostics) {
        media <- identical(diagnostic$code, 'body_media_type')
        issue <- if (media) 26L else 27L
        key <- diagnostic$key
        stopifnot(!key %in% keys)
        method <- tolower(sub(' .*', '', key))
        path <- sub('^[A-Z]+ ', '', key)
        operation <- document$paths[[path]][[method]]
        if (media) stopifnot(is.null(document$consumes), is.null(operation$consumes))
        append_row(api, key, issue, if (media) 'absent_media' else 'visible_source_defect',
          diagnostic$source_location, '', NA, if (media) 'no consumes declaration' else diagnostic$reason,
          diagnostic$code, diagnostic$reason, hash,
          if (media) 'Service-owned per-operation consumes/media and body representation' else
            'Service-owned corrected parameter types, locations, names and serialization')
        if (media) {
          for (parameter in operation$parameters) {
            if (!identical(parameter[['in']], 'body')) next
            latent <- tryCatch(specmill:::input_schema(parameter$schema, document), error = identity)
            if (!inherits(latent, 'error')) next
            stopifnot(identical(latent$code, 'invalid_type'))
            append_row(api, key, 27L, 'masked_nested_file', latent$source_location,
              parameter$name, isTRUE(parameter$required),
              paste0(parameter$schema[['$ref']], ': nested type file'), latent$code,
              diagnostic$reason, hash,
              'Service-owned upload media, field names, file representation; #26 media decision alone is insufficient')
          }
        }
      }
      next
    }
    for (path in names(document$paths)) {
      item <- document$paths[[path]]
      stopifnot(is.null(item$parameters))
      for (method in intersect(names(item), c('get', 'post', 'put', 'patch', 'delete', 'head', 'options', 'trace'))) {
        operation <- item[[method]]
        key <- paste(toupper(method), path)
        for (j in seq_along(operation$parameters)) {
          parameter <- operation$parameters[[j]]
          if (!identical(parameter[['in']], 'query')) next
          pointer <- paste0('#/paths/', gsub('/', '~1', gsub('~', '~0', path, fixed = TRUE), fixed = TRUE), '/', method, '/parameters/', j - 1L)
          schema <- specmill:::input_schema(parameter$schema, document, source_location = paste0(pointer, '/schema'))
          problem <- tryCatch(specmill:::parameter_shape(parameter, schema, document$openapi, pointer), error = identity)
          if (!inherits(problem, 'error') || !problem$code %in% c('binary_parameter', 'nested_parameter')) next
          diagnostic <- Filter(function(x) identical(x$key, key), parsed$diagnostics)
          stopifnot(length(diagnostic) == 1L, !key %in% keys)
          binary <- identical(problem$code, 'binary_parameter')
          append_row(api, key, if (binary) 28L else 31L, problem$code,
            pointer, parameter$name, isTRUE(parameter$required),
            as.character(jsonlite::toJSON(parameter, auto_unbox = TRUE)), problem$code,
            diagnostic[[1L]]$reason, hash,
            if (binary) 'Service-owned binary representation, parameter location, media and metadata relationship' else
              'Service-owned nested query bytes, field names, absent/empty/multiple values and delimiter escaping')
        }
      }
    }
  }
  ledger <- do.call(rbind, rows)
  keys_for <- function(issue) with(ledger[ledger$issue == issue, ], paste(schema, key))
  binary <- keys_for(28L)
  nested <- keys_for(31L)
  stopifnot(sum(ledger$issue == 26L) == 26L,
    sum(ledger$kind == 'visible_source_defect') == 6L,
    sum(ledger$kind == 'masked_nested_file') == 5L,
    length(binary) == 18L, length(nested) == 13L,
    length(intersect(binary, nested)) == 11L, length(union(binary, nested)) == 20L,
    length(unique(paste(ledger$schema, ledger$key))) == 52L,
    setequal(setdiff(nested, binary), paste('standardizer.json',
      c('GET /api/stdizer/protocols/{id}', 'POST /api/stdizer/protocols/{id}'))))
  ledger$overlap_issues <- vapply(seq_len(nrow(ledger)), function(i) {
    paste(sort(unique(ledger$issue[ledger$schema == ledger$schema[[i]] &
      ledger$key == ledger$key[[i]]])), collapse = ';')
  }, '')
  ledger <- ledger[order(ledger$issue, ledger$schema, ledger$key), ]
  write.csv(ledger, file.path(output, 'contract-dispositions.csv'), row.names = FALSE)
  cat('52 distinct operations remain blocked: 26 media; 6 visible + 5 masked AMOS defects; 18 binary + 13 nested query, with 11 overlaps.\n')
})
