validation_source_acceptance <- function() {
  source <- getFromNamespace('validation_runtime', 'specmill')()
  lines <- strsplit(source, '\n', fixed = TRUE)[[1L]]
  stopifnot(!any(grepl('[[:blank:]]+$', lines)))
  runtime <- new.env(parent = baseenv())
  eval(parse(text = source), runtime)
  stopifnot(
    is.environment(runtime$.api_validation),
    is.function(runtime$.api_validation$batch_limit)
  )
  cat('Generated shared validators parse without trailing whitespace.\n')
}

test_that('generated shared validators parse without trailing whitespace', {
  validation_source_acceptance()
  succeed()
})
