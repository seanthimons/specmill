validate_opaque_body <- function(review) {
  config_fields(review, c('reference', 'reason'), 'opaque_body')
  config_string(review$reference, 'opaque_body.reference')
  config_string(review$reason, 'opaque_body.reason')
  if (
    !grepl('^https?://[^/?#]+/', review$reference) ||
      grepl('[[:space:]]', review$reference)
  ) {
    stop('opaque_body.reference must be an absolute HTTP(S) reference')
  }
}
