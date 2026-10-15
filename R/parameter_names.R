parameter_names <- function(parameters) {
  result <- make.names(vapply(
    parameters,
    function(p) p$public_name %or% p$name,
    character(1)
  ))
  reserved <- grepl('^\\.\\.([0-9]+|\\.)$', result)
  result[reserved] <- paste0('value', result[reserved])
  make.unique(result)
}

# The wrapper's request-body argument: the configured name, else `body` made
# unique against the public parameter names (`body.1` when a parameter has it).
body_argument_name <- function(op) {
  op$body_name %or%
    tail(make.unique(c(parameter_names(op$parameters), 'body')), 1L)
}
