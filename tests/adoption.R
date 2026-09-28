adoption_acceptance <- function() {
  # The prelude example from propose_mappings.Rd; Rd2ex comments out its \dontrun block.
  example <- tempfile(fileext = '.R')
  tools::Rd2ex(tools::Rd_db('specmill')[['propose_mappings.Rd']], example)
  source(example, local = TRUE)
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

  # Proposals: one wrapper per selected operation, plus wrappers that must be retained.
  root <- setup()
  # Markdown clients render badge blocks without an explicit @md, as generated blocks do.
  write('Roxygen: list(markdown = TRUE)', file.path(root, 'DESCRIPTION'), append = TRUE)
  writeLines(c('id: mapped', 'schemas: {files: [schema.json]}', 'helper: catalogue_request', 'documentation: true'),
    file.path(root, 'service.yml'))
  wrapper <- function(file, lines) writeLines(lines, file.path(root, 'R', file))
  wrapper('fetch.R', c(
    "#' Fetch an item", "#'", "#' @param id Item ID.", "#' @param lang Language.", "#' @return The item.",
    "#' @export", "#' @examples", "#' \\dontrun{", "#' fetch_item(id = \"a\")", "#' }",
    "fetch_item <- function(id, lang = 'en') {",
    "  result <- catalogue_request(method = 'GET', path = '/items/{item_id}',",
    "    path_params = list(item_id = id), query = list(language = lang), body = NULL)",
    "  result", "}"
  ))
  wrapper('search.R', c(
    "#' Search items", "#'", "#' @description", "#' `r lifecycle::badge(\"stable\")`", "#' @param language Language.", "#' @return Items.", "#' @export",
    "search_items <- function(language = NULL) {",
    "  query <- list()", "  if (!is.null(language)) query$language <- language",
    "  catalogue_request(method = 'GET', path = '/items', path_params = list(), query = query, body = NULL)", "}"
  ))
  wrapper('trigger.R', c(
    "#' Refresh the catalogue", "#'", "#' @return Status.", "#' @export",
    "trigger_refresh <- function() {",
    "  catalogue_request(method = 'POST', path = paste0('/', 'refresh'), path_params = list(), query = list(), body = NULL)",
    "}"
  ))
  wrapper('custom.R', c("custom_item <- function(id) {", "  id <- trimws(id)",
    "  catalogue_request(method = 'GET', path = '/items/{item_id}', path_params = list(item_id = id), query = list(), body = NULL)", "}"))
  wrapper('positional.R', c("#' Fetch", "#'", "#' @param id ID.", "#' @return Item.", "#' @export", "#' @examples",
    "#' positional_item('a')", "positional_item <- function(id) {",
    "  catalogue_request(method = 'POST', path = '/items', path_params = list(), query = list(), body = list(id = id))", "}"))
  files <- c('R/fetch.R', 'R/search.R', 'R/trigger.R', 'R/custom.R', 'R/positional.R')
  before <- tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE))
  route <- function(name, call) if (identical(name, 'trigger_refresh')) 'POST /refresh' else NULL
  bindings <- function(x) if (identical(x, quote(paste0('/', 'refresh')))) list(value = '/refresh')
  proposed <- specmill::propose_mappings(root, files, 'mapped', prelude = query_prelude)
  status <- vapply(proposed$operations, `[[`, character(1), 'status')
  stopifnot(
    identical(tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE)), before),
    identical(status, c(fetch_item = 'proposed', search_items = 'proposed', trigger_refresh = 'retained',
      custom_item = 'retained', positional_item = 'retained')),
    identical(proposed$operations$trigger_refresh$reason, 'Helper call has no literal method and path; supply route'),
    identical(proposed$operations$custom_item$reason, 'Body is not a single call to catalogue_request'),
    identical(proposed$operations$positional_item$reason, 'Documentation differs'),
    identical(names(proposed$files), c('R/fetch.R', 'R/search.R')),
    identical(names(proposed$proposals), c('GET /items/{item_id}', 'GET /items')),
    identical(proposed$proposals[['GET /items']]$request$arguments$query,
      list(compact_object = list(language = list(from = list('params', 'language')))))
  )
  # Applying the YAML and deleting the listed files reproduces a verified client.
  service <- yaml::read_yaml(file.path(root, 'service.yml'), handlers = list(seq = function(x) as.list(x)))
  service$operations <- yaml::yaml.load(proposed$yaml)$operations
  yaml::write_yaml(service, file.path(root, 'service.yml'))
  stopifnot(all(vapply(specmill::verify_adoption(root, wrappers = c('fetch_item', 'search_items'))$operations,
    function(x) identical(x$status, 'verified'), logical(1))))
  routed <- specmill::propose_mappings(root, 'R/trigger.R', 'mapped', route = route, bindings = bindings)
  stopifnot(
    identical(proposed$proposals[['GET /items']]$docs$lifecycle, 'stable'),
    identical(routed$operations$trigger_refresh$status, 'proposed'),
    identical(routed$proposals[['POST /refresh']]$request$arguments$path, list(value = '/refresh'))
  )
  cat('Adoption: equivalent wrappers verify and are proposed; formals, behaviour, documentation, custom bodies,',
    'and grouped-file differences are retained.\n')
}
if (sys.nframe() == 0L) {
  adoption_acceptance()
}
