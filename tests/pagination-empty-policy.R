pagination_empty_policy_acceptance <- function() {
  fetches <- 0L
  fetch <- function(cursor = NULL) {
    fetches <<- fetches + 1L
    list(
      results = if (is.null(cursor)) list() else list(list(id = 'found')),
      next_cursor = if (is.null(cursor)) 'two' else NULL
    )
  }
  run <- function(...) {
    specmill::paginated(
      fetch,
      mode = 'cursor',
      parameter = 'cursor',
      start = NULL,
      next_cursor = function(x) x$next_cursor,
      items = function(x) x$results,
      max_pages = 2L,
      ...
    )
  }
  old <- run()
  stopifnot(
    fetches == 1L,
    old$stop_reason == 'empty_page',
    old$item_count == 0L
  )
  fetches <- 0L
  result <- run(stop_on_empty = FALSE)
  stopifnot(
    fetches == 2L,
    result$item_count == 1L,
    result$pages[[2L]][[1L]]$id == 'found'
  )
  error <- tryCatch(
    specmill::paginated(
      function(cursor = NULL) list(),
      mode = 'cursor',
      start = NULL,
      parameter = 'cursor',
      next_cursor = function(x) 'same',
      items = identity,
      stop_on_empty = FALSE,
      max_pages = 3L
    ),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('Repeated pagination cursor', conditionMessage(error))
  )
  limited <- run(stop_on_empty = FALSE, completed = function(x, state) FALSE)
  stopifnot(limited$requests == 2L, limited$stop_reason == 'max_pages')
  done <- run(stop_on_empty = FALSE, completed = function(x, state) TRUE)
  stopifnot(done$requests == 1L, done$stop_reason == 'completed')
  cat(
    'Empty-page default, explicit continuation, completion, limits and repeated cursor safety passed.\n'
  )
}
if (sys.nframe() == 0L) {
  pagination_empty_policy_acceptance()
}
