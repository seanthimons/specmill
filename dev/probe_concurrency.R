# Finds how much batch concurrency a live service tolerates, for a maintainer
# choosing a `batch.concurrency` ceiling. It calls the real API: use a small,
# read-only input and the service's own rate limits as the guide.
#
# `call` runs one fan-out or split wrapper with its on_error set to drop, for
# example function() myclient::get_items(ids). `option` is the client's
# batching option name, for example 'myclient.api_request.batching'. Levels
# above the generated ceiling run at the ceiling.
#
# source('dev/probe_concurrency.R')
# probe_concurrency(function() myclient::get_items(ids), 'myclient.api_request.batching')
probe_concurrency <- function(
  call,
  option,
  levels = c(1L, 2L, 4L),
  pause = 10
) {
  # A hard cap on what the probe will ever try, whatever the ceiling allows.
  stopifnot(is.function(call), all(levels >= 1L), all(levels <= 8L))
  results <- list()
  for (level in sort(levels)) {
    policy <- getOption(option, list())
    policy$concurrency <- level
    started <- Sys.time()
    outcome <- withr::with_options(
      stats::setNames(list(policy), option),
      tryCatch(suppressWarnings(call()), error = identity)
    )
    failed <- if (inherits(outcome, 'error')) {
      conditionMessage(outcome)
    } else if (length(attr(outcome, 'failed'))) {
      paste(length(attr(outcome, 'failed')), 'items failed')
    }
    results[[length(results) + 1L]] <- data.frame(
      concurrency = level,
      seconds = round(as.numeric(Sys.time() - started, units = 'secs'), 2),
      failure = if (is.null(failed)) NA_character_ else failed
    )
    # Stop at the first refusal (429, 5xx or any other failure); do not push on.
    if (!is.null(failed)) {
      break
    }
    Sys.sleep(pause)
  }
  do.call(rbind, results)
}
