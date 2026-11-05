# Source from the repository root, then call check_importer_boundary().
# This checks native document access; JSON Schema fragments are tracked in #279.
importer_boundary_findings <- function(expression) {
  fields <- c(
    'components',
    'definitions',
    'securitySchemes',
    'securityDefinitions',
    'openapi',
    'swagger',
    'paths',
    'requestBody'
  )
  findings <- character()
  walk <- function(node) {
    if (!is.call(node) && !is.expression(node) && !is.pairlist(node)) {
      return(invisible(NULL))
    }
    if (is.call(node)) {
      operator <- as.character(node[[1L]])
      if (
        length(operator) == 1L &&
          operator %in% c('$', '[[', '[') &&
          length(node) >= 3L &&
          !identical(node[[3L]], quote(expr = ))
      ) {
        field <- node[[3L]]
        if (is.symbol(field) && operator == '$') {
          field <- as.character(field)
        }
        if (is.character(field) && length(field) == 1L && field %in% fields) {
          # testing_project() returns an R function table named definitions.
          function_table <- identical(node[[2L]], as.name('loaded')) &&
            field == 'definitions'
          if (!function_table) {
            findings <<- c(
              findings,
              paste(deparse(node, width.cutoff = 500L), collapse = ' ')
            )
          }
        }
      }
      if (identical(node[[1L]], as.name('read_schema_document'))) {
        findings <<- c(findings, 'read_schema_document()')
      }
    }
    children <- as.list(node)
    for (i in seq_along(children)) {
      # Missing function arguments cannot be bound to an ordinary loop variable.
      if (!identical(children[[i]], quote(expr = ))) walk(children[[i]])
    }
    invisible(NULL)
  }
  walk(expression)
  unique(findings)
}

check_importer_boundary <- function(root = '.') {
  # The source loader/reference resolver and formal source validator deliberately
  # work on documents. All generation and compatibility readers belong to import.
  exemptions <- c(
    'importer_openapi.R',
    'schema_document.R',
    'schema_references.R',
    'schema_validation.R'
  )
  files <- list.files(
    file.path(root, 'R'),
    pattern = '\\.R$',
    full.names = TRUE
  )
  files <- files[!basename(files) %in% exemptions]
  findings <- unlist(
    lapply(files, function(file) {
      hits <- importer_boundary_findings(parse(file))
      if (length(hits)) paste(file, hits, sep = ': ')
    }),
    use.names = FALSE
  )
  stopifnot(
    length(importer_boundary_findings(quote(document$components$schemas))) ==
      1L,
    length(importer_boundary_findings(quote(document[['definitions']]))) == 1L,
    length(importer_boundary_findings(quote(read_schema_document(path)))) == 1L,
    length(importer_boundary_findings(quote(loaded$definitions))) == 0L,
    length(importer_boundary_findings(quote(list('components', function(x, y) {
      x
    })))) ==
      0L
  )
  if (length(findings)) {
    stop(paste(findings, collapse = '\n'))
  }
  cli::cli_alert_success(
    'OpenAPI source access is confined to the importer and source-validation helpers'
  )
  invisible(findings)
}
