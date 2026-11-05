# Source from the repository root, then call check_registry_output().
# #230 deliberately adds importer provenance to ownership manifests. Every other
# golden byte still has to match the #229 reference; never rebaseline a mismatch.
check_registry_output <- function() {
  source('dev/golden_output.R', local = TRUE)
  baseline <- utils::read.csv(golden_baseline_path, stringsAsFactors = FALSE)
  keep <- tempfile('registry-golden-')
  on.exit(unlink(keep, recursive = TRUE), add = TRUE)
  current <- golden_snapshot(keep)
  expected_changes <- with(
    baseline,
    kind == 'client' & item == '.specmill/manifest.json'
  )
  changes <- golden_changes(baseline, current)
  keys <- with(
    baseline[expected_changes, ],
    paste(kind, fixture, item, sep = '\t')
  )
  stopifnot(setequal(changes$key, keys))
  for (i in which(expected_changes)) {
    fixture <- baseline$fixture[[i]]
    path <- file.path(keep, 'clients', fixture, '.specmill/manifest.json')
    text <- rawToChar(readBin(path, 'raw', file.info(path)$size))
    manifest <- jsonlite::fromJSON(text, simplifyVector = FALSE)
    stopifnot(length(manifest$importers) > 0L)
    expected_format <- if (startsWith(fixture, 'swagger2')) {
      'swagger'
    } else {
      'openapi'
    }
    for (entry in manifest$importers) {
      stopifnot(
        identical(names(entry), c('source_format', 'importer_version')),
        identical(entry$source_format, expected_format),
        identical(entry$importer_version, '1')
      )
    }
    # Remove exactly the additive provenance object from the original serialized
    # bytes. Parsing/re-serializing the rest could conceal whitespace changes.
    start <- regexpr('(?m)^  "importers": \\{\n', text, perl = TRUE)
    stopifnot(start[[1L]] > 0L)
    rest <- substring(text, start[[1L]])
    end <- regexpr('(?m)^  \\},?\n', rest, perl = TRUE)
    stopifnot(end[[1L]] > 0L)
    block_length <- end[[1L]] + attr(end, 'match.length') - 1L
    stripped <- paste0(
      substring(text, 1L, start[[1L]] - 1L),
      substring(rest, block_length + 1L)
    )
    # If the object is last, its preceding separator belongs to the additive
    # block as well. Preserve the original final newline.
    stripped <- sub(',\n\\}(\n?)$', '\n}\\1', stripped)
    stopifnot(identical(golden_sha(stripped), baseline$sha256[[i]]))
  }
  second <- golden_snapshot()
  stopifnot(!any(current$item == 'error'), identical(current, second))
  cli::cli_alert_success(
    'All {nrow(baseline)} reference artifacts match apart from the verified additive importer provenance in seven manifests'
  )
  invisible(current)
}
