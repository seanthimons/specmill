# Compare stable schema/method/path keys, never generated function names.
args <- commandArgs(TRUE)
stopifnot(length(args) == 3L)
before <- args[[1L]]
after <- args[[2L]]
output <- args[[3L]]
dir.create(output, recursive = TRUE, showWarnings = FALSE)
read <- function(root, name) {
  read.csv(file.path(root, name), stringsAsFactors = FALSE)
}
b <- read(before, 'audit/operations.csv')
a <- read(after, 'audit/operations.csv')
stopifnot(
  !anyDuplicated(b[c('file', 'key')]),
  !anyDuplicated(a[c('file', 'key')])
)
comparison <- merge(
  b,
  a,
  by = c('file', 'key'),
  all = TRUE,
  suffixes = c('_before', '_after')
)
comparison$changed <- with(
  comparison,
  is.na(stage_before) |
    is.na(stage_after) |
    stage_before != stage_after |
    reason_before != reason_after
)
write.csv(
  comparison,
  file.path(output, 'operation-comparison.csv'),
  row.names = FALSE
)
bs <- read(before, 'audit/sources.csv')
as <- read(after, 'audit/sources.csv')
hashes <- merge(
  bs[c('file', 'sha256')],
  as[c('file', 'sha256')],
  by = 'file',
  all = TRUE,
  suffixes = c('_before', '_after')
)
hashes$identical <- with(
  hashes,
  !is.na(sha256_before) & !is.na(sha256_after) & sha256_before == sha256_after
)
stopifnot(all(hashes$identical), nrow(hashes) == 42L)
write.csv(hashes, file.path(output, 'schema-hashes.csv'), row.names = FALSE)
# Preserve configuration attribution separately from code changes.
config_files <- c(
  'provingground/specmill.yml',
  paste0(
    'full-selection-apis/',
    list.files(file.path(before, 'full-selection-apis'))
  )
)
configs <- data.frame(
  file = config_files,
  identical = vapply(
    config_files,
    function(f) {
      identical(
        readBin(
          file.path(before, f),
          'raw',
          file.info(file.path(before, f))$size
        ),
        readBin(file.path(after, f), 'raw', file.info(file.path(after, f))$size)
      )
    },
    logical(1)
  )
)
stopifnot(all(configs$identical))
write.csv(
  configs,
  file.path(output, 'configuration-comparison.csv'),
  row.names = FALSE
)
smoke <- read(after, 'installed-smoke-modes.csv')
write.csv(
  smoke[c('schema', 'key', 'mode', 'stage', 'reason', 'omitted')],
  file.path(output, 'installed-outcomes.csv'),
  row.names = FALSE
)
checks <- readRDS(file.path(after, 'package-check.rds'))
baseline_checks <- readRDS(file.path(before, 'package-check.rds'))
summary <- list(
  before = as.list(colSums(read(before, 'audit/schemas.csv')[c(
    'declared',
    'rendered',
    'fixtures',
    'invoked'
  )])),
  after = as.list(colSums(read(after, 'audit/schemas.csv')[c(
    'declared',
    'rendered',
    'fixtures',
    'invoked'
  )])),
  stages = as.data.frame(table(smoke$mode, smoke$stage)),
  parser_blockers_before = sum(b$stage == 'parser'),
  parser_blockers_after = sum(a$stage == 'parser'),
  baseline_errors = baseline_checks$errors,
  baseline_warnings = baseline_checks$warnings,
  baseline_notes = baseline_checks$notes,
  errors = checks$errors,
  warnings = checks$warnings,
  notes = checks$notes
)
jsonlite::write_json(
  summary,
  file.path(output, 'comparison-summary.json'),
  auto_unbox = TRUE,
  pretty = TRUE
)
print(summary)
