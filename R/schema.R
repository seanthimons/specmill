# Generic compatibility helpers. Native readers live in importer_openapi.R.

schema_type_is <- function(type, value) {
  is.character(type) &&
    length(type) == 1L &&
    !is.na(type) &&
    identical(unname(type), value)
}
