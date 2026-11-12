validate_response_correction <- function(correction) {
  config_fields(
    correction,
    c('status', 'media_type', 'description', 'reason'),
    'response_correction'
  )
  for (field in c('status', 'media_type', 'description', 'reason')) {
    config_string(correction[[field]], paste('response_correction', field))
  }
  if (
    !grepl('^[1-5][0-9]{2}$', correction$status) ||
      !identical(correction$media_type, 'application/json')
  ) {
    stop(
      'response_correction requires an HTTP status and application/json media'
    )
  }
}
