freeze_references_acceptance <- function() {
  root <- tempfile('freeze-references-')
  served <- file.path(root, 'served')
  project <- file.path(root, 'project')
  dir.create(file.path(served, 'ogc'), recursive = TRUE)
  dir.create(project)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  sortby <- c(
    'name: sortby',
    'in: query',
    'schema:',
    '  type: array',
    '  items:',
    '    type: string',
    'explode: false',
    'style: form'
  )
  writeLines(sortby, file.path(served, 'ogc', 'sortby.yaml'))
  writeLines('name: [unclosed', file.path(served, 'ogc', 'broken.yaml'))
  port_file <- file.path(root, 'port')
  # Serves the current bytes on disk, so tests can change "upstream".
  server <- callr::r_bg(
    function(served, port_file) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          path <- file.path(served, req$PATH_INFO)
          if (!file.exists(path)) {
            return(list(status = 404L, headers = list(), body = 'missing'))
          }
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/yaml'),
            body = readBin(path, 'raw', file.size(path))
          )
        })
      )
      on.exit(server$stop())
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    args = list(served, port_file),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  for (i in seq_len(200L)) {
    if (file.exists(port_file) || !server$is_alive()) {
      break
    }
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  origin <- paste0('http://127.0.0.1:', readLines(port_file))
  url <- paste0(origin, '/ogc/sortby.yaml')
  schema <- file.path(project, 'openapi.json')
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Freeze references', version = '1'),
      servers = list(list(url = 'https://references.invalid')),
      paths = list(
        '/items' = list(
          get = list(
            operationId = 'list_items',
            parameters = list(list('$ref' = url)),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    ),
    schema,
    auto_unbox = TRUE
  )
  lock <- file.path(project, 'specmill-references.yml')
  fails <- function(...) {
    before <- list.files(project, recursive = TRUE)
    bytes <- if (file.exists(lock)) readBin(lock, 'raw', 1e6)
    error <- tryCatch(
      specmill::freeze_references(schema, ...),
      error = identity
    )
    stopifnot(
      inherits(error, 'error'),
      identical(list.files(project, recursive = TRUE), before),
      identical(if (file.exists(lock)) readBin(lock, 'raw', 1e6), bytes)
    )
    conditionMessage(error)
  }

  # Invalid input, failed downloads and unparseable content change nothing.
  stopifnot(
    specmill::read_operations(schema)$diagnostics[[1L]]$code ==
      'external_reference'
  )
  fails(paste0(url, '#/x'))
  fails(paste0(url, '?v=1'))
  fails(paste0(origin, '/ogc/'))
  fails(paste0(origin, '/ogc/../ogc/sortby.yaml'))
  fails(c(url, paste0(origin, '/ogc/missing.yaml')))
  fails(c(url, paste0(origin, '/ogc/broken.yaml')))

  # Batch files cannot be each other's directories; existing unmapped files
  # and symlinked escapes are refused.
  stopifnot(grepl(
    'already in use',
    fails(c(url, paste0(origin, '/OGC'))),
    fixed = TRUE
  ))
  occupied <- file.path(
    project,
    'references',
    paste0('127.0.0.1_', readLines(port_file)),
    'ogc'
  )
  dir.create(occupied, recursive = TRUE)
  writeLines('mine', file.path(occupied, 'sortby.yaml'))
  stopifnot(grepl('already in use', fails(url), fixed = TRUE))
  unlink(file.path(project, 'references'), recursive = TRUE)
  if (.Platform$OS.type != 'windows') {
    outside <- file.path(root, 'outside')
    dir.create(outside)
    file.symlink(outside, file.path(project, 'references'))
    stopifnot(grepl('escapes', fails(url), fixed = TRUE))
    stopifnot(!length(list.files(outside)))
    unlink(file.path(project, 'references'))
  }

  # Freezing records provenance and resolves offline.
  added <- specmill::freeze_references(schema, c(url, url))
  file <- file.path(project, added$file)
  stopifnot(
    identical(added$status, 'added'),
    startsWith(added$file, 'references/127.0.0.1_'),
    identical(added$sha256, digest::digest(file = file, algo = 'sha256'))
  )
  entry <- yaml::read_yaml(lock)$references[[1L]]
  stopifnot(
    identical(entry$url, url),
    identical(entry$sha256, added$sha256),
    grepl('^\\d{4}-\\d{2}-\\d{2}T', entry$retrieved)
  )
  parsed <- specmill::read_operations(schema)
  stopifnot(
    length(parsed$operations) == 1L,
    identical(parsed$operations[[1L]]$parameters[[1L]]$style, 'form')
  )

  # An unchanged re-run leaves the lock byte-identical; edited copies restore.
  bytes <- readBin(lock, 'raw', 1e6)
  stopifnot(identical(
    specmill::freeze_references(schema, url)$status,
    'unchanged'
  ))
  writeLines('edited', file)
  stopifnot(identical(
    specmill::freeze_references(schema, url)$status,
    'restored'
  ))
  stopifnot(
    identical(readBin(lock, 'raw', 1e6), bytes),
    identical(digest::digest(file = file, algo = 'sha256'), added$sha256)
  )

  # A changed upstream needs explicit refresh.
  writeLines(
    c(sortby, 'description: changed'),
    file.path(served, 'ogc', 'sortby.yaml')
  )
  message <- fails(url)
  stopifnot(grepl('refresh = TRUE', message, fixed = TRUE))
  refreshed <- specmill::freeze_references(schema, url, refresh = TRUE)
  stopifnot(
    identical(refreshed$status, 'refreshed'),
    identical(refreshed$file, added$file),
    !identical(refreshed$sha256, added$sha256),
    identical(yaml::read_yaml(lock)$references[[1L]]$sha256, refreshed$sha256),
    identical(
      specmill::read_operations(schema)$operations[[1L]]$parameters[[1L]]$name,
      'sortby'
    )
  )

  # A failed write puts back copies the batch already overwrote.
  # Read-only files do not stop root, so the case is skipped there.
  if (
    .Platform$OS.type != 'windows' &&
      Sys.info()[['effective_user']] != 'root'
  ) {
    other <- paste0(origin, '/ogc/other.yaml')
    writeLines(sortby, file.path(served, 'ogc', 'other.yaml'))
    other_file <- file.path(
      project,
      specmill::freeze_references(schema, other)$file
    )
    writeLines('edited', other_file)
    Sys.chmod(other_file, '444')
    writeLines(
      c(sortby, 'description: changed again'),
      file.path(served, 'ogc', 'sortby.yaml')
    )
    before <- readBin(file, 'raw', 1e6)
    stopifnot(grepl(
      'Cannot write',
      fails(c(url, other), refresh = TRUE),
      fixed = TRUE
    ))
    stopifnot(
      identical(readBin(file, 'raw', 1e6), before),
      identical(readLines(other_file), 'edited')
    )
    Sys.chmod(other_file, '644')
  }
  cat(
    'Freeze references: explicit download, provenance, no-op rerun, restore, refresh gate, write rollback and failure atomicity passed against localhost.\n'
  )
}

test_that('frozen references acceptance', {
  freeze_references_acceptance()
  succeed()
})
