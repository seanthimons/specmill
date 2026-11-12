# Google API Discovery protocol callbacks. This code is owned by the generated client.
api_request_discovery_next_page_token <- function(response) {
  if (!base::is.list(response)) {
    base::stop(base::errorCondition('Paged response is not an object', class = 'specmill_call_error', call = NULL))
  }
  token <- response$nextPageToken
  if (base::is.null(token)) base::return(NULL)
  if (!base::is.character(token) || base::length(token) != 1L || base::is.na(token)) {
    base::stop(base::errorCondition('Invalid nextPageToken in response', class = 'specmill_call_error', call = NULL))
  }
  token
}
