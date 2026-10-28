split_owned_file_acceptance <- function() {
  root <- tempfile('split-owned-')
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    root,
    system.file('catalogue/schema.json', package = 'specmill'),
    package = 'splittest',
    title = 'Split Owned Test',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://example.invalid'
  )
  policy <- file.path(root, 'apis/default.yml')
  initial <- readLines(policy)
  split <- initial[seq_len(match('names:', initial) - 1L)]
  # All operations share R/list_items.R, the file `list_items` keeps afterwards.
  writeLines(c(split, 'defaults: {file: R/list_items.R}'), policy)
  run <- function(mode) {
    specmill::generate_client(
      validation = FALSE,
      root,
      config = 'specmill.yml',
      mode = mode,
      artifacts = c('wrappers', 'documentation')
    )
  }
  run('apply')
  shared <- file.path(root, 'R/list_items.R')
  original <- readLines(shared)
  find_defs <- getFromNamespace('tg_find_function_defs_in_file', 'specmill')
  wanted <- c('get_item', 'list_items', 'create_item', 'refresh')
  stopifnot(setequal(names(find_defs(shared)), wanted))

  # Splitting an edited owned file stays refused.
  writeLines(split, policy)
  writeLines(c(original, '# edit'), shared)
  error <- tryCatch(run('plan'), error = identity)
  stopifnot(inherits(error, 'error'))
  writeLines(original, shared)

  # An unedited owned file may be split across the files that now own its parts.
  run('plan')
  run('apply')
  stopifnot(
    identical(names(find_defs(shared)), 'list_items'),
    all(file.exists(file.path(
      root,
      'R',
      paste0(setdiff(wanted, 'list_items'), '.R')
    )))
  )
  defined <- unlist(lapply(
    list.files(file.path(root, 'R'), '\\.R$', full.names = TRUE),
    function(path) names(find_defs(path))
  ))
  stopifnot(
    !anyDuplicated(defined),
    all(wanted %in% defined)
  )
  before <- tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE))
  run('check')
  run('apply')
  stopifnot(identical(
    before,
    tools::md5sum(list.files(root, recursive = TRUE, full.names = TRUE))
  ))
  cat(
    'Split owned file: unedited owned output may split across new files; edited output stays blocked; repeat generation stable.\n'
  )
}
if (sys.nframe() == 0L) {
  split_owned_file_acceptance()
}
