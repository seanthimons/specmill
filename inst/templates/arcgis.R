# ArcGIS protocol callbacks. This code is owned by the generated client.
api_request_arcgis_response <- function(response, context, decode) {
  result <- decode()
  if (base::is.list(result) && !base::is.null(result$error)) {
    error <- result$error
    code <- if (base::is.list(error)) error$code else NULL
    # Server error messages can echo query strings or credentials. Preserve the
    # service code without copying response text or request URLs into an error.
    base::stop(base::errorCondition(
      base::paste0('ArcGIS service error', if (base::is.numeric(code) && base::length(code) == 1L && base::is.finite(code)) base::paste0(' (', code, ')')),
      class = 'specmill_call_error', code = code, call = NULL))
  }
  result
}

api_request_arcgis_completed <- function(response, state) {
  flag <- response$exceededTransferLimit
  if (!base::is.null(flag) && (!base::is.logical(flag) || base::length(flag) != 1L || base::is.na(flag))) {
    base::stop(base::errorCondition('Invalid ArcGIS exceededTransferLimit flag', class = 'specmill_call_error', call = NULL))
  }
  !base::isTRUE(flag)
}

api_request_arcgis_features <- function(response) {
  if (!base::is.list(response) || base::is.null(response$features) || !base::is.list(response$features) || !base::is.null(base::names(response$features))) {
    base::stop(base::errorCondition('ArcGIS response has no feature array', class = 'specmill_call_error', call = NULL))
  }
  response$features
}

api_request_arcgis_related <- function(response) {
  if (!base::is.list(response) || base::is.null(response$relatedRecordGroups) || !base::is.list(response$relatedRecordGroups)) {
    base::stop(base::errorCondition('ArcGIS response has no related-record groups', class = 'specmill_call_error', call = NULL))
  }
  for (group in response$relatedRecordGroups) {
    if (!base::is.list(group) || base::is.null(group$relatedRecords) || !base::is.list(group$relatedRecords) || !base::is.null(base::names(group$relatedRecords))) {
      base::stop(base::errorCondition('ArcGIS response has no related-record array', class = 'specmill_call_error', call = NULL))
    }
  }
  response$relatedRecordGroups
}

# Some related-record endpoints omit the flag for pages below the service's
# configured transfer limit. A full related-record page needs another probe.
api_request_arcgis_related_completed <- function(response, state) {
  if (!base::is.null(response$exceededTransferLimit)) {
    base::return(api_request_arcgis_completed(response, state))
  }
  groups <- api_request_arcgis_related(response)
  base::sum(base::vapply(groups, function(group) base::length(group$relatedRecords), base::integer(1))) < state$page_size
}
