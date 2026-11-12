# Run from an interactive session at the repository root:
#   source('dev/check_golden_output.R')
#   check_golden_output()
check_golden_output <- function() {
  source('dev/golden_output.R', local = TRUE)
  baseline <- utils::read.csv(golden_baseline_path, stringsAsFactors = FALSE)
  first <- golden_snapshot()
  second <- golden_snapshot()
  stopifnot(
    !any(first$item == 'error'),
    !nrow(golden_changes(baseline, first)),
    !nrow(golden_changes(first, second))
  )
  # A changed wrapper, a removed artifact, and a new artifact must each fail
  # comparison, rather than being hidden by an inner join or missing hashes.
  wrapper <- which(first$kind == 'client' & first$item == 'R/get_item.R')[[1L]]
  changed <- first
  changed$sha256[[wrapper]] <- golden_sha('changed wrapper\n')
  added <- first[wrapper, ]
  added$item <- 'R/new_wrapper.R'
  stopifnot(
    nrow(golden_changes(first, changed)) == 1L,
    nrow(golden_changes(first, first[-wrapper, ])) == 1L,
    nrow(golden_changes(first, rbind(first, added))) == 1L,
    golden_sha('wrapper\n') != golden_sha('wrapper'),
    identical(
      golden_normalize('default: 0.2.0', golden_replacements()),
      'default: 0.2.0'
    )
  )
  duplicate <- tryCatch(
    golden_changes(first, rbind(first, first[wrapper, ])),
    error = identity
  )
  stopifnot(inherits(duplicate, 'error'))
  cli::cli_alert_success(
    '{nrow(first)} baseline artifacts match twice; change, removal, addition and duplicate checks pass'
  )
  invisible(first)
}
