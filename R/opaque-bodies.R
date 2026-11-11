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

# Only reference failures and dynamic keywords matter here; literal JSON is data.
opaque_reference_findings <- function(node) {
  if (!is.list(node)) {
    return(character())
  }
  error <- node[['x-specmill-reference-error']]
  own <- c(error$code, if ('$dynamicRef' %in% names(node)) 'dynamic_reference')
  children <- node[setdiff(
    names(node),
    c('example', 'examples', 'default', 'enum', 'const')
  )]
  if (is.null(names(node))) {
    children <- node
  }
  unique(c(
    own,
    unlist(lapply(children, opaque_reference_findings), use.names = FALSE)
  ))
}

opaque_body_document <- function(
  file,
  reviews,
  document = NULL,
  policy = list()
) {
  if (is.null(document)) {
    document <- read_schema_document(file, resolve_references = FALSE)
  }
  if (length(Filter(Negate(is.null), reviews)) && !is.null(document$swagger)) {
    stop('opaque_body requires an OpenAPI 3 application/json request schema')
  }
  raw <- document
  document <- resolve_schema_references(document, file)
  applied <- list()
  findings_cache <- list()
  for (key in names(reviews)) {
    review <- reviews[[key]]
    if (is.null(review)) {
      next
    }
    validate_opaque_body(review)
    method <- tolower(sub(' .*', '', key))
    path <- sub('^[^ ]+ ', '', key)
    if (
      is.null(raw$paths[[path]][[method]]) ||
        length(operation_selection_reason(key, path, toupper(method), policy))
    ) {
      next
    }
    at <- schema_location(
      schema_location(
        schema_location(
          schema_location(
            schema_location('#/paths', path),
            method
          ),
          'requestBody'
        ),
        'content'
      ),
      'application/json'
    )
    at <- schema_location(at, 'schema')
    body <- document$paths[[path]][[method]]$requestBody$content[[
      'application/json'
    ]]$schema
    source <- if (is.list(body)) body[['x-specmill-opaque-source']]
    original <- raw$paths[[path]][[method]]$requestBody$content[[
      'application/json'
    ]]$schema
    reference <- source$reference %or% if (is.list(original)) original[['$ref']]
    # Repeated direct references share the same verified target in this document.
    cache_key <- if (
      is.list(original) && !is.null(original[['$ref']]) && !is.null(source)
    ) {
      paste(source$reference, source$sha256)
    }
    findings <- findings_cache[[cache_key %or% '']] %or%
      opaque_reference_findings(body)
    if (!is.null(cache_key)) {
      findings_cache[[cache_key]] <- findings
    }
    if (
      length(setdiff(findings, c('recursive_reference', 'dynamic_reference')))
    ) {
      next
    }
    if (
      !identical(reference, review$reference) ||
        is.null(source$sha256) ||
        !length(findings) ||
        !length(intersect(
          findings,
          c('recursive_reference', 'dynamic_reference')
        ))
    ) {
      body <- schema_reference_error(
        review$reference,
        'opaque_body_review',
        'opaque_body requires the exact recursive remote application/json body reference'
      )
    } else {
      applied[[key]] <- c(
        review,
        list(
          code = 'opaque_body',
          level = 'info',
          source_location = at,
          sha256 = source$sha256,
          message = 'Request body schema shape is not validated locally.'
        )
      )
      body <- list(
        description = paste(
          'JSON body following',
          review$reference,
          'The schema shape is not validated locally.'
        )
      )
    }
    # Other reference failures, including hash mismatches, remain blocking.
    document$paths[[path]][[method]]$requestBody$content[[
      'application/json'
    ]]$schema <- body
  }
  attr(document, 'specmill_opaque_bodies') <- applied
  document
}
