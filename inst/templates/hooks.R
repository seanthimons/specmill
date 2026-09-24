# Client-owned hook executor. Edit this file; regeneration preserves it.
read_hook_config <- function() {
  # ponytail: read once per stage; cache with an explicit reload if profiling warrants it.
  path <- system.file('hooks.yml', package = CLIENT_PACKAGE, mustWork = TRUE)
  config <- yaml::read_yaml(path, eval.expr = FALSE)
  if (
    !is.list(config) ||
      (length(config) &&
        (is.null(names(config)) || anyDuplicated(names(config))))
  ) {
    stop('hooks.yml must map public function names to hook stages')
  }
  config
}

run_hook <- function(fn_name, hook_type, data) {
  if (
    length(hook_type) != 1L ||
      is.na(hook_type) ||
      !hook_type %in% c('pre_request', 'post_response')
  ) {
    stop('Unsupported hook stage')
  }
  entry <- read_hook_config()[[fn_name]]
  if (
    !is.null(entry) &&
      (!is.list(entry) ||
        is.null(names(entry)) ||
        anyDuplicated(names(entry)) ||
        any(!names(entry) %in% c('pre_request', 'post_response')))
  ) {
    stop('Invalid hook stages for ', fn_name)
  }
  chain <- entry[[hook_type]]
  if (is.null(chain) || !length(chain)) {
    return(if (hook_type == 'post_response') data$result else data)
  }
  if (
    !(is.character(chain) || is.list(chain)) ||
      !is.null(names(chain)) ||
      !all(vapply(
        chain,
        function(x) {
          is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
        },
        logical(1)
      ))
  ) {
    stop('Hook chain must be a sequence of function names for ', fn_name)
  }
  for (hook_name in chain) {
    data <- tryCatch(
      {
        hook <- get(hook_name, envir = environment(run_hook), inherits = FALSE)
        if (!is.function(hook)) {
          stop('Configured hook is not a function')
        }
        hook(data)
      },
      error = function(parent) {
        stop(errorCondition(
          paste(
            fn_name,
            hook_type,
            hook_name,
            conditionMessage(parent),
            sep = ': '
          ),
          class = 'client_hook_error',
          parent = parent,
          function_name = fn_name,
          hook_name = hook_name,
          stage = hook_type
        ))
      }
    )
  }
  data
}
