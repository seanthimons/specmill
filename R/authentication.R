validate_security_correction <- function(correction) {
  config_fields(correction, c('requirements', 'reason'), 'security_correction')
  config_string(correction$reason, 'security_correction reason')
  requirements <- correction$requirements
  if (!is.list(requirements) || !is.null(names(requirements))) {
    stop('security_correction requirements must be a sequence')
  }
  for (requirement in requirements) {
    config_fields(
      requirement,
      names(requirement),
      'security_correction requirement'
    )
    for (scopes in requirement) {
      config_sequence(scopes, 'security_correction scopes')
    }
  }
}


# Warns when one schema file protects some operations and leaves others without
# `security`: OpenAPI reads the gap as public, but it is often a schema omission.
warn_unsecured_operations <- function(operations) {
  for (source in unique(vapply(
    operations,
    function(op) op$source,
    character(1)
  ))) {
    own <- Filter(function(op) identical(op$source, source), operations)
    protected <- vapply(
      own,
      function(op) length(op$security) > 0L,
      logical(1)
    )
    missing <- vapply(
      own,
      function(op) is.null(op$security) && length(op$security_schemes) > 0L,
      logical(1)
    )
    if (any(protected) && any(missing)) {
      warning(
        basename(source),
        ': operations without security while others declare it (treated as public): ',
        paste(
          vapply(own[missing], function(op) op$id, character(1)),
          collapse = ', '
        ),
        '. Check the schema.',
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}
