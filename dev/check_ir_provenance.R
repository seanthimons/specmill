# Source from an interactive session at the repository root, then call
# check_ir_provenance(). The reference predates the #229 accessor relocation.
ir_provenance_snapshot <- function() {
  source('dev/golden_output.R', local = TRUE)
  golden_load()
  workspace <- tempfile('ir-provenance-')
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  fixtures <- golden_fixtures(workspace)
  references <- utils::getFromNamespace('provenance_references', 'specmill')
  hash <- utils::getFromNamespace('provenance_hash', 'specmill')
  rows <- list()
  for (id in names(fixtures)) {
    file <- fixtures[[id]]
    document <- golden_read_document(file, resolve_references = TRUE)
    parsed <- suppressWarnings(suppressMessages(specmill::read_operations(
      file
    )))
    for (operation in c(
      unname(parsed$operations),
      unname(parsed$unsupported_operations)
    )) {
      rows[[length(rows) + 1L]] <- data.frame(
        fixture = id,
        key = operation$key,
        hash = hash(references(operation, document)),
        stringsAsFactors = FALSE
      )
    }
  }
  snapshot <- do.call(rbind, rows)
  snapshot <- snapshot[order(snapshot$fixture, snapshot$key), ]
  rownames(snapshot) <- NULL
  snapshot
}

check_ir_provenance <- function(path = 'dev/audits/ir-golden/provenance.csv') {
  baseline <- utils::read.csv(path, stringsAsFactors = FALSE)
  current <- ir_provenance_snapshot()
  stopifnot(identical(baseline, current))
  cli::cli_alert_success(
    'All {nrow(current)} referenced-contract provenance digests match'
  )
  invisible(current)
}
