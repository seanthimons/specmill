# GraphQL protocol callbacks. This code is owned by the generated client.
api_request_graphql_response <- function(response, context, decode) {
  # A GraphQL error can arrive with any status, including 200 beside partial data.
  # An error status whose body cannot be decoded is left to the status check.
  result <- base::tryCatch(decode(check_status = FALSE), error = function(e) {
    if (context$status >= 400L) NULL else base::stop(e)
  })
  errors <- if (base::is.list(result)) result[['errors']]
  if (base::length(errors)) {
    # Error messages can echo variable values, so they are attached to the
    # condition instead of being copied into its message.
    base::stop(base::errorCondition(
      base::paste0('GraphQL request failed with ', base::length(errors), ' error(s); inspect the errors field of this condition'),
      class = 'specmill_call_error', errors = errors, call = NULL))
  }
  if (context$status >= 400L) base::return(decode())
  if (!base::is.list(result) || base::is.null(result[['data']])) {
    base::stop(base::errorCondition('GraphQL response has no data', class = 'specmill_call_error', call = NULL))
  }
  # A generated document selects one root field; a reviewed document may select several.
  if (base::length(result[['data']]) == 1L) result[['data']][[1L]] else result[['data']]
}
