selection_policy_acceptance <- function() {
  root <- tempfile('selection-policy-')
  dir.create(root)
  fixture <- system.file('catalogue', package = 'specmill', mustWork = TRUE)
  stopifnot(all(file.copy(
    list.files(fixture, full.names = TRUE),
    root,
    recursive = TRUE
  )))
  dir.create(file.path(root, 'schema'))
  dir.create(file.path(root, 'apis'))
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  op <- list(responses = list(`200` = list(description = 'ok')))
  jsonlite::write_json(
    list(
      swagger = '2.0',
      info = list(title = 'demo', version = '1'),
      paths = list(
        `/api/a` = list(get = op),
        `/api/b` = list(get = op),
        `/api/thing` = list(get = op, post = op)
      )
    ),
    file.path(root, 'schema/demo.json'),
    auto_unbox = TRUE
  )
  write_config <- function(project, ...) {
    yaml::write_yaml(
      c(list(config_version = 1L, validation = FALSE), project),
      file.path(root, 'specmill.yml')
    )
    services <- list(...)
    for (id in names(services)) {
      yaml::write_yaml(
        c(
          list(
            id = id,
            schemas = list(files = list('schema/demo.json')),
            helper = 'catalogue_request'
          )[setdiff(c('id', 'schemas', 'helper'), names(services[[id]]))],
          services[[id]]
        ),
        file.path(root, 'apis', paste0(id, '.yml'))
      )
    }
  }
  plan <- function() {
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'plan',
      validation = FALSE
    )
  }
  keys <- function(x) {
    vapply(
      x$operations,
      function(o) paste(o$service, o$method, o$path),
      character(1)
    )
  }

  # #189: a method-qualified exclusion drops only that method.
  for (level in c('project', 'service')) {
    entry <- list(exclude = list('POST ^/api/thing/?$'))
    write_config(
      c(
        list(services = list('apis/demo.yml')),
        if (level == 'project') list(selection = entry)
      ),
      demo = if (level == 'service') list(selection = entry) else list()
    )
    selected <- keys(plan())
    stopifnot(
      'demo GET /api/thing' %in% selected,
      !'demo POST /api/thing' %in% selected
    )
  }
  write_config(
    list(
      services = list('apis/demo.yml'),
      selection = list(
        methods = list('GET', 'POST'),
        exclude = list('^/api/thing/?$')
      )
    ),
    demo = list()
  )
  stopifnot(!any(grepl('/api/thing', keys(plan()), fixed = TRUE)))
  write_config(
    list(
      services = list('apis/demo.yml'),
      selection = list(exclude = list('POST ^/api/thing/?$'))
    ),
    demo = list()
  )
  printed <- paste(capture.output(print(plan())), collapse = '\n')
  stopifnot(grepl(
    'Matches project exclusion: POST ^/api/thing/?$',
    printed,
    fixed = TRUE
  ))
  write_config(
    list(
      services = list('apis/demo.yml'),
      selection = list(exclude = list('POST ['))
    ),
    demo = list()
  )
  stopifnot(inherits(
    tryCatch(specmill::load_project(root), error = identity),
    'error'
  ))

  # #190: an unclaimed service skips what a sibling includes or maps.
  write_config(
    list(services = list('apis/owner.yml', 'apis/rest.yml')),
    owner = list(
      selection = list(include = list('GET /api/a')),
      names = list(`GET /api/a` = 'demo_a')
    ),
    rest = list(selection = list(unclaimed = TRUE))
  )
  selected <- keys(plan())
  stopifnot(
    'owner GET /api/a' %in% selected,
    !'rest GET /api/a' %in% selected,
    'rest GET /api/b' %in% selected
  )
  printed <- paste(capture.output(print(plan())), collapse = '\n')
  stopifnot(grepl('Claimed by service owner', printed, fixed = TRUE))
  # A claim made through a different schema file on the same server still counts.
  document <- jsonlite::read_json(file.path(root, 'schema/demo.json'))
  document$host <- 'example.org'
  jsonlite::write_json(
    document,
    file.path(root, 'schema/demo.json'),
    auto_unbox = TRUE
  )
  document$paths <- document$paths['/api/a']
  jsonlite::write_json(
    document,
    file.path(root, 'schema/overlay.json'),
    auto_unbox = TRUE
  )
  write_config(
    list(services = list('apis/owner.yml', 'apis/rest.yml')),
    owner = list(
      schemas = list(files = list('schema/overlay.json')),
      selection = list(include = list('GET /api/a')),
      names = list(`GET /api/a` = 'demo_a')
    ),
    rest = list(selection = list(unclaimed = TRUE))
  )
  selected <- keys(plan())
  stopifnot(
    'owner GET /api/a' %in% selected,
    !'rest GET /api/a' %in% selected,
    'rest GET /api/b' %in% selected
  )
  # A different server does not claim.
  document$host <- 'other.example.org'
  jsonlite::write_json(
    document,
    file.path(root, 'schema/overlay.json'),
    auto_unbox = TRUE
  )
  stopifnot('rest GET /api/a' %in% keys(plan()))
  # Without the flag the duplicate selection remains.
  write_config(
    list(services = list('apis/owner.yml', 'apis/rest.yml')),
    owner = list(
      selection = list(include = list('GET /api/a')),
      names = list(`GET /api/a` = 'demo_a')
    ),
    rest = list()
  )
  stopifnot(
    'owner GET /api/a' %in% keys(plan()),
    'rest GET /api/a' %in% keys(plan())
  )
  write_config(
    list(services = list('apis/owner.yml', 'apis/rest.yml')),
    owner = list(),
    rest = list(
      selection = list(
        unclaimed = TRUE,
        include = list('GET /api/b')
      )
    )
  )
  stopifnot(inherits(
    tryCatch(specmill::load_project(root), error = identity),
    'error'
  ))
  cat('Selection policy: method-qualified exclusions and unclaimed services.\n')
}
if (sys.nframe() == 0L) {
  selection_policy_acceptance()
}
