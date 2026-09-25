# Run from the repository root: Rscript dev/check_testing_report.R
source('dev/audit_testing_specs.R')
local({
  root <- tempfile('corpus-report-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE))
  schema <- file.path(root, 'example.json')
  jsonlite::write_json(list(
    swagger = '2.0',
    info = list(title = 'Reporting checks', version = '1'),
    paths = list(
      '/ready' = list(get = list(operationId = 'ready', responses = list('200' = list(description = 'OK')))),
      '/invalid' = list(get = list(parameters = list(list(name = 'q', 'in' = 'query', type = 'dict')))),
      '/unspecified' = list(post = list(parameters = list(list(name = 'body', 'in' = 'body', schema = list(type = 'string')))))
    )
  ), schema, auto_unbox = TRUE)
  writeLines('{', file.path(root, 'broken.json'))
  write.csv(data.frame(
    file = c('example.json', 'broken.json'), tier = 'example',
    stresses = 'diagnostics', url = '', sha256 = '', version = '2.0'
  ), file.path(root, 'manifest.csv'), row.names = FALSE)
  output <- file.path(root, 'report')
  result <- audit_testing_specs(native_root = root, output = output)
  report <- paste(readLines(file.path(output, 'DIAGNOSTICS.md')), collapse = '\n')
  csv <- read.csv(file.path(output, 'operations.csv'))
  stopifnot(
    sum(result$operations$stage == 'passed') == 1L,
    sum(result$operations$stage == 'parser') == 2L,
    all(c('source_location', 'guidance') %in% names(csv)),
    grepl('GET /invalid', report, fixed = TRUE),
    grepl('[schema_defect]', report, fixed = TRUE),
    grepl('#/paths/~1invalid', report, fixed = TRUE),
    grepl('POST /unspecified', report, fixed = TRUE),
    grepl('request media unspecified', report, fixed = TRUE),
    grepl('do not infer JSON', report, fixed = TRUE),
    grepl('Document broken.json [parser_error]', report, fixed = TRUE),
    !grepl('GET /ready', report, fixed = TRUE)
  )
  # A corpus consisting entirely of unreadable documents still gets a report.
  report_testing_diagnostics(result$schemas[2, ], data.frame(), output)
  stopifnot(any(grepl('Operation failures or blockers: 0', readLines(file.path(output, 'DIAGNOSTICS.md')), fixed = TRUE)))
  cat('Corpus report: invalid schema, unspecified media, document failure and successful operation checks passed.\n')
})
