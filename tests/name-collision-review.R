name_collision_review_acceptance <- function() {
  root <- tempfile('name-collision-review-')
  schema <- tempfile(fileext = '.json')
  on.exit(unlink(c(root, schema), recursive = TRUE), add = TRUE)
  operation <- function() {
    list(
      tags = list('Default API'),
      operationId = 'default_api_reaction_map_DL_options',
      responses = list('200' = list(description = 'OK'))
    )
  }
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'CHET', version = '1'),
    paths = list(
      '/reaction/map_DL' = list(options = operation()),
      '/reaction/batchsearch' = list(options = operation())
    )
  )
  write <- function() jsonlite::write_json(document, schema, auto_unbox = TRUE)
  write()
  created <- specmill::initialize_client(
    root,
    schema,
    package = 'chetclient',
    title = 'CHET client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://example.invalid'
  )
  initial <- attr(created, 'configuration')
  collisions <- Filter(
    function(x) x$code == 'name_collision',
    initial$diagnostics
  )
  stopifnot(setequal(
    vapply(collisions, `[[`, character(1), 'key'),
    c('OPTIONS /reaction/map_DL', 'OPTIONS /reaction/batchsearch')
  ))

  service <- file.path(root, 'apis/default_api.yml')
  text <- readLines(service)
  text <- sub(
    'OPTIONS /reaction/batchsearch: default_api_reaction_map_DL_options',
    'OPTIONS /reaction/batchsearch: default_api_reaction_batchsearch_options',
    text,
    fixed = TRUE
  )
  writeLines(text, service)
  reviewed <- specmill::configure_client(root, schema)
  stopifnot(
    !any(vapply(
      reviewed$diagnostics,
      function(x) x$code == 'name_collision',
      logical(1)
    )),
    identical(
      reviewed$operations[[1L]]$name,
      'default_api_reaction_batchsearch_options'
    ),
    all(vapply(
      reviewed$changes,
      function(x) x$action == 'unchanged',
      logical(1)
    ))
  )

  document$paths <- rev(document$paths)
  write()
  reordered <- specmill::configure_client(root, schema)
  stopifnot(identical(
    setNames(
      vapply(reordered$operations, `[[`, character(1), 'name'),
      vapply(reordered$operations, `[[`, character(1), 'key')
    ),
    setNames(
      vapply(reviewed$operations, `[[`, character(1), 'name'),
      vapply(reviewed$operations, `[[`, character(1), 'key')
    )
  ))
  specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply',
    artifacts = 'wrappers'
  )
  specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'check',
    artifacts = 'wrappers'
  )
  wrappers <- readLines(file.path(root, 'R/default_api.R'))
  stopifnot(all(vapply(
    vapply(reviewed$operations, `[[`, character(1), 'name'),
    function(name) any(startsWith(wrappers, paste0(name, ' <- function('))),
    logical(1)
  )))
  collision_keys <- function(plan) {
    vapply(
      Filter(function(x) x$code == 'name_collision', plan$diagnostics),
      `[[`,
      character(1),
      'key'
    )
  }
  document$paths[['/reaction/map_DL']]$options$operationId <- 'getThing'
  document$paths[['/reaction/batchsearch']]$options$operationId <- 'get_thing'
  write()
  normalized <- specmill::configure_client(
    tempfile('normalized-collision-'),
    schema,
    package = 'normalizedclient',
    naming = 'tag_prefix'
  )
  stopifnot(length(collision_keys(normalized)) == 2L)
  document$paths[['/reaction/map_DL']]$options$operationId <- 'same_name'
  document$paths[['/reaction/map_DL']]$options$tags <- list('Map')
  document$paths[['/reaction/batchsearch']]$options$operationId <- 'same_name'
  document$paths[['/reaction/batchsearch']]$options$tags <- list('Batch')
  write()
  cross_service <- specmill::configure_client(
    tempfile('cross-service-collision-'),
    schema,
    package = 'crossserviceclient'
  )
  stopifnot(length(collision_keys(cross_service)) == 2L)

  multi_root <- tempfile('multi-name-collision-')
  dir.create(multi_root)
  on.exit(unlink(multi_root, recursive = TRUE), add = TRUE)
  file.copy(schema, file.path(multi_root, 'chet.json'))
  apis <- data.frame(
    schema = 'chet.json',
    api = 'chet',
    base_url = 'https://example.invalid',
    include = TRUE
  )
  multi <- specmill::configure_client(
    multi_root,
    apis,
    package = 'multicollision',
    mode = 'apply'
  )
  multi_collisions <- Filter(
    function(x) x$code == 'name_collision',
    multi$diagnostics
  )
  stopifnot(
    length(multi_collisions) == 2L,
    all(vapply(multi_collisions, `[[`, character(1), 'api') == 'chet'),
    all(grepl(
      'chet_same_name',
      vapply(multi_collisions, `[[`, character(1), 'message'),
      fixed = TRUE
    ))
  )
  multi_file <- file.path(multi_root, 'apis/chet.yml')
  multi_text <- readLines(multi_file)
  multi_text <- sub(
    'OPTIONS /reaction/batchsearch: chet_same_name',
    'OPTIONS /reaction/batchsearch: chet_batchsearch_options',
    multi_text,
    fixed = TRUE
  )
  writeLines(multi_text, multi_file)
  multi_reviewed <- specmill::configure_client(
    multi_root,
    apis,
    package = 'multicollision'
  )
  stopifnot(
    !length(collision_keys(multi_reviewed)),
    'chet_batchsearch_options' %in%
      vapply(multi_reviewed$operations, `[[`, character(1), 'name')
  )
  cat(
    'Name collisions: complete evidence, reviewed-name persistence and stable generation passed.\n'
  )
}
if (sys.nframe() == 0L) {
  name_collision_review_acceptance()
}
