# Response cache. This code is owned by the generated client.
api_request_cache_state <- base::new.env(parent = base::emptyenv())

# Disk entries are unencrypted response data in the user's cache directory.
api_request_cache_dir <- function() {
  base::file.path(tools::R_user_dir(base::tolower(base::sub('_DRY_RUN$', '', DRY_RUN_ENV)), 'cache'), 'api_request')
}

# One store per reviewed setting, so entries with different lifetimes do not prune each other.
api_request_cache_store <- function(settings) {
  id <- rlang::hash(settings)
  if (base::is.null(api_request_cache_state[[id]])) {
    age <- if (base::is.null(settings$max_age)) Inf else settings$max_age
    api_request_cache_state[[id]] <- if (base::identical(settings$store, 'disk')) {
      cachem::cache_disk(dir = base::file.path(api_request_cache_dir(), id), max_age = age)
    } else cachem::cache_mem(max_age = age)
  }
  api_request_cache_state[[id]]
}

# Answers a repeated request from the store. Errors, dry-run requests and results
# that hold a raw request or response (its URL and headers can carry a credential)
# are never stored.
api_request_cached <- function(.operation, .settings, ...) {
  arguments <- base::list(...)
  option_prefix <- base::tolower(base::sub('_DRY_RUN$', '', DRY_RUN_ENV))
  dry <- base::getOption(base::paste0(option_prefix, '.dry_run'), base::tolower(base::Sys.getenv(DRY_RUN_ENV)) %in% base::c('true', '1', 'yes'))
  if (!base::isTRUE(base::getOption(base::paste0(option_prefix, '.response_cache'), TRUE)) || !base::isFALSE(dry)) {
    base::return(base::do.call(api_request, arguments))
  }
  # Entries are kept apart by credential without storing one: the key holds a hash of each credential value.
  identity <- arguments
  variables <- base::unique(base::unlist(base::lapply(arguments$auth, function(requirement) base::lapply(requirement, function(scheme) scheme$envvar)), use.names = FALSE))
  identity$auth <- base::lapply(stats::setNames(base::as.list(variables), variables), function(name) rlang::hash(base::Sys.getenv(name)))
  # The request options, the shared response policy and the batch flag all change what the helper returns.
  key <- rlang::hash(base::list(.operation, identity, base::getOption(base::paste0(option_prefix, '.request')), base::getOption(base::paste0(option_prefix, '.response_policy')), api_request_batch_state$active))
  store <- api_request_cache_store(.settings)
  hit <- store$get(key)
  if (!cachem::is.key_missing(hit)) base::return(hit$value)
  result <- base::do.call(api_request, arguments)
  # Only a response policy can return the raw response, so only its results are searched for one.
  policy <- if ('response_policy' %in% base::names(arguments)) arguments[['response_policy']] else base::getOption(base::paste0(option_prefix, '.response_policy'))
  raw <- function(x) {
    base::inherits(x, base::c('httr2_request', 'httr2_response')) ||
      (base::is.list(x) && !base::is.data.frame(x) && base::any(base::vapply(x, raw, base::logical(1)))) ||
      base::any(base::vapply(base::unname(base::attributes(x)), raw, base::logical(1)))
  }
  if (!base::inherits(result, 'httr2_request') && (base::is.null(policy) || !raw(result))) store$set(key, base::list(value = result))
  result
}

# Forgets every stored response of this helper, in memory and on disk.
api_request_cache_clear <- function() {
  for (id in base::ls(api_request_cache_state)) api_request_cache_state[[id]]$reset()
  base::rm(list = base::ls(api_request_cache_state), envir = api_request_cache_state)
  base::unlink(api_request_cache_dir(), recursive = TRUE)
  base::invisible(NULL)
}
