adoption_acceptance <- function() {
  setup <- function() {
    root <- tempfile('adoption-')
    dir.create(root)
    fixture <- system.file('catalogue', package = 'specmill', mustWork = TRUE)
    stopifnot(all(file.copy(list.files(fixture, full.names = TRUE), root, recursive = TRUE)))
    writeLines(c('config_version: 1', 'services: [service.yml]'), file.path(root, 'specmill.yml'))
    writeLines(c(
      'id: mapped',
      'schemas: {files: [schema.json]}',
      'helper: catalogue_request',
      'documentation: true',
      'selection: {methods: [GET], exclude: ["^/items$"]}',
      'operations:',
      '  GET /items/{item_id}:',
      '    extra_parameters:',
      '      format: {type: character, default: [compact, tidy]}',
      '    docs:',
      '      title: Fetch an item',
      '      examples: [{item_id: a}]'
    ), file.path(root, 'service.yml'))
    root
  }
  # The generated wrapper, minus its header, stands in for an equivalent hand-written one.
  scratch <- setup()
  invisible(specmill::generate_client(scratch, config = 'specmill.yml', mode = 'apply', artifacts = 'wrappers'))
  text <- grep('^# Generated', readLines(file.path(scratch, 'R/get_item.R')), value = TRUE, invert = TRUE)
  verify <- function(edit = identity) {
    root <- setup()
    writeLines(edit(text), file.path(root, 'R/items.R'))
    before <- tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE))
    result <- specmill::verify_adoption(root)
    stopifnot(identical(tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE)), before))
    result
  }

  verified <- verify()
  stopifnot(
    identical(verified$operations$get_item$status, 'verified'),
    identical(names(verified$files), 'R/items.R'),
    identical(verified$contracts$get_item$calls[[1L]]$helper, 'catalogue_request'),
    identical(verified$contracts$get_item$inputs$language, 'en')
  )
  getFromNamespace('validate_fixed_contract', 'specmill')(verified$contracts$get_item)

  reason <- function(edit) {
    result <- verify(edit)
    stopifnot(!length(result$files), !length(result$contracts))
    result$operations$get_item$reason
  }
  stopifnot(
    identical(reason(function(t) sub('"tidy"))', '"raw"))', t, fixed = TRUE)), 'Formals differ'),
    identical(
      reason(function(t) sub('"/items/{item_id}"', '"/items/{item_id}/"', t, fixed = TRUE)),
      'Behaviour differs with required inputs'
    ),
    identical(reason(function(t) sub("#' Fetch an item", "#' Get an item", t, fixed = TRUE)), 'Documentation differs'),
    grepl('separate it before adoption', reason(function(t) c(t, 'other <- function() NULL')))
  )
  cat('Adoption: equivalent wrappers verify; formals, behaviour, documentation, and grouped-file differences fail.\n')
}
if (sys.nframe() == 0L) {
  adoption_acceptance()
}
