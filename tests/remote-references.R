remote_references_acceptance <- function() {
  root <- tempfile('remote-references-')
  dir.create(file.path(root, 'vendor', 'flat'), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  write <- function(value, path) {
    jsonlite::write_json(value, path, auto_unbox = TRUE, pretty = TRUE)
  }
  vendor <- function(name, text) {
    writeLines(text, file.path(root, 'vendor', name))
    file.path('vendor', name)
  }
  sha <- function(path) {
    digest::digest(file = file.path(root, path), algo = 'sha256')
  }
  base <- 'https://deps.invalid/ogc/'
  sortby <- c(
    'name: sortby',
    'in: query',
    'required: false',
    'schema:',
    '  type: array',
    '  minItems: 1',
    '  items:',
    '    type: string',
    'explode: false',
    'style: form'
  )
  # Storage layout differs from URL layout: api.yaml's '../schemas/limit.yaml'
  # resolves against its URL, then through the lock to vendor/flat.
  files <- list(
    sortby = vendor('sortby.yaml', sortby),
    api = vendor(
      'api.yaml',
      c(
        'components:',
        '  parameters:',
        '    limit:',
        '      name: limit',
        '      in: query',
        '      schema:',
        "        $ref: '../schemas/limit.yaml#/Limit'"
      )
    ),
    limit = vendor(
      'flat/limit-file.yaml',
      c('Limit:', '  type: integer', '  minimum: 1')
    ),
    tampered = vendor('tampered.yaml', sortby),
    malformed = vendor('malformed.yaml', 'name: [unclosed'),
    cycle_a = vendor('cycle-a.yaml', "$ref: 'cycle-b.yaml'"),
    cycle_b = vendor('cycle-b.yaml', "$ref: 'cycle-a.yaml'"),
    rebased = vendor(
      'rebased.yaml',
      c(
        'name: rebased',
        'in: query',
        'schema:',
        "  $id: 'https://elsewhere.invalid/schema.json'",
        '  type: string'
      )
    )
  )
  urls <- c(
    sortby = paste0(base, 'parameters/sortby.yaml'),
    api = paste0(base, 'api/api.yaml'),
    limit = paste0(base, 'schemas/limit.yaml'),
    missing = paste0(base, 'missing.yaml'),
    tampered = paste0(base, 'tampered.yaml'),
    malformed = paste0(base, 'malformed.yaml'),
    cycle_a = paste0(base, 'cycle-a.yaml'),
    cycle_b = paste0(base, 'cycle-b.yaml'),
    rebased = paste0(base, 'rebased.yaml')
  )
  lock_entries <- function(hashes = list()) {
    lapply(names(urls), function(name) {
      file <- files[[name]] %||% 'vendor/missing.yaml'
      list(
        url = urls[[name]],
        file = file,
        sha256 = hashes[[name]] %||%
          if (file.exists(file.path(root, file))) {
            sha(file)
          } else {
            strrep('0', 64)
          },
        retrieved = 'fixture'
      )
    })
  }
  write_lock <- function(entries, dir = root) {
    yaml::write_yaml(
      list(references = entries),
      file.path(dir, 'specmill-references.yml')
    )
  }
  write_lock(lock_entries(list(tampered = strrep('a', 64))))
  operation <- function(id, parameter) {
    list(
      get = list(
        operationId = id,
        parameters = list(parameter),
        responses = list('200' = list(description = 'OK'))
      )
    )
  }
  ref <- function(url) list('$ref' = url)
  document <- function(paths) {
    list(
      openapi = '3.0.3',
      info = list(title = 'Remote references', version = '1'),
      servers = list(list(url = 'https://references.invalid')),
      paths = paths
    )
  }
  schema <- file.path(root, 'openapi.json')
  write(
    document(list(
      '/items' = operation('list_items', ref(urls[['sortby']])),
      '/inline' = operation(
        'inline_items',
        yaml::yaml.load(paste(sortby, collapse = '\n'))
      ),
      '/nested' = operation(
        'nested_items',
        ref(paste0(urls[['api']], '#/components/parameters/limit'))
      )
    )),
    schema
  )
  failures <- c(
    '/unmapped' = 'external_reference',
    '/scheme' = 'external_reference',
    '/missing' = 'unresolved_reference',
    '/tampered' = 'reference_hash_mismatch',
    '/malformed' = 'invalid_reference',
    '/cycle' = 'recursive_reference',
    '/rebased' = 'reference_base'
  )
  failure_refs <- c(
    '/unmapped' = 'https://deps.invalid/unmapped.yaml',
    '/scheme' = 'ftp://deps.invalid/ogc/parameters/sortby.yaml',
    '/missing' = urls[['missing']],
    '/tampered' = urls[['tampered']],
    '/malformed' = urls[['malformed']],
    '/cycle' = urls[['cycle_a']],
    '/rebased' = urls[['rebased']]
  )
  failure_schema <- file.path(root, 'failures.json')
  write(
    document(c(
      list('/ok' = operation('ok_items', ref(urls[['sortby']]))),
      stats::setNames(
        lapply(names(failure_refs), function(path) {
          operation(sub('^/', '', path), ref(failure_refs[[path]]))
        }),
        names(failure_refs)
      )
    )),
    failure_schema
  )
  by_key <- function(records, key) {
    found <- Filter(function(x) identical(x$key, key), records)
    stopifnot(length(found) == 1L)
    found[[1L]]
  }

  # Mapped references resolve offline to the inline contract.
  parsed <- specmill::read_operations(schema)
  stopifnot(length(parsed$operations) == 3L, !length(parsed$diagnostics))
  contract <- function(key) {
    lapply(by_key(parsed$operations, key)$parameters, function(x) {
      x[setdiff(names(x), 'source_location')]
    })
  }
  stopifnot(identical(contract('GET /items'), contract('GET /inline')))
  nested <- by_key(parsed$operations, 'GET /nested')$parameters[[1L]]
  stopifnot(
    identical(nested$name, 'limit'),
    identical(nested$schema$type, 'integer'),
    identical(nested$schema$minimum, 1L)
  )
  read_document <- getFromNamespace('read_schema_document', 'specmill')
  dependencies <- attr(read_document(schema), 'specmill_reference_dependencies')
  expected_inputs <- normalizePath(
    file.path(
      root,
      c('specmill-references.yml', files$sortby, files$api, files$limit)
    ),
    winslash = '/'
  )
  stopifnot(setequal(names(dependencies)[-1L], expected_inputs))
  stopifnot(identical(
    dependencies,
    attr(read_document(schema), 'specmill_reference_dependencies')
  ))
  stopifnot(identical(specmill::validate_schema(schema)$status, 'passed'))

  # Failures stay source-located while unrelated operations still parse.
  failed <- specmill::read_operations(failure_schema)
  stopifnot(
    identical(
      unname(vapply(failed$operations, `[[`, character(1), 'key')),
      'GET /ok'
    ),
    length(failed$inventory) == length(failures) + 1L
  )
  for (path in names(failures)) {
    diagnostic <- by_key(failed$diagnostics, paste('GET', path))
    stopifnot(
      identical(diagnostic$code, failures[[path]]),
      identical(
        diagnostic$source_location,
        paste0(
          '#/paths/~1',
          sub('^/', '', path),
          '/get/parameters/0',
          if (path == '/rebased') '/schema' else ''
        )
      ),
      nzchar(diagnostic$reason)
    )
  }
  stopifnot(
    grepl(
      'Remote reference is not fetched',
      by_key(failed$diagnostics, 'GET /unmapped')$reason,
      fixed = TRUE
    ),
    grepl(
      urls[['cycle_a']],
      by_key(failed$diagnostics, 'GET /cycle')$reason,
      fixed = TRUE
    ),
    grepl(
      sha(files$tampered),
      by_key(failed$diagnostics, 'GET /tampered')$reason,
      fixed = TRUE
    ),
    identical(specmill::validate_schema(failure_schema)$status, 'unsupported')
  )

  # Without a lock file, remote references keep today's diagnostic.
  unlocked <- tempfile('remote-references-unlocked-')
  dir.create(unlocked)
  on.exit(unlink(unlocked, recursive = TRUE), add = TRUE)
  stopifnot(file.copy(schema, unlocked))
  plain <- specmill::read_operations(file.path(unlocked, 'openapi.json'))
  stopifnot(
    length(plain$operations) == 1L,
    all(
      vapply(plain$diagnostics, `[[`, character(1), 'code') ==
        'external_reference'
    )
  )

  # Malformed lock data is a configuration error naming the lock.
  invalid_locks <- list(
    escape = list(list(
      url = urls[['sortby']],
      file = '../outside.yaml',
      sha256 = strrep('0', 64)
    )),
    absolute = list(list(
      url = urls[['sortby']],
      file = file.path(root, files$sortby),
      sha256 = strrep('0', 64)
    )),
    duplicate = lock_entries()[c(1L, 1L)],
    hash = list(list(
      url = urls[['sortby']],
      file = files$sortby,
      sha256 = 'x'
    )),
    fragment = list(list(
      url = paste0(urls[['sortby']], '#/x'),
      file = files$sortby,
      sha256 = strrep('0', 64)
    )),
    field = list(c(lock_entries()[[1L]], list(base_url = base))),
    directory = list(list(
      url = urls[['sortby']],
      file = '.',
      sha256 = strrep('0', 64)
    ))
  )
  probe <- tempfile('remote-references-lock-')
  dir.create(probe)
  on.exit(unlink(probe, recursive = TRUE), add = TRUE)
  stopifnot(file.copy(schema, probe))
  outside <- tempfile('remote-references-outside-', fileext = '.yaml')
  on.exit(unlink(outside), add = TRUE)
  writeLines(sortby, outside)
  if (.Platform$OS.type != 'windows') {
    file.symlink(outside, file.path(probe, 'link.yaml'))
    invalid_locks$symlink <- list(list(
      url = urls[['sortby']],
      file = 'link.yaml',
      sha256 = digest::digest(file = outside, algo = 'sha256')
    ))
  }
  for (entries in invalid_locks) {
    write_lock(entries, probe)
    error <- tryCatch(
      specmill::read_operations(file.path(probe, 'openapi.json')),
      error = identity
    )
    stopifnot(
      inherits(error, 'error'),
      grepl('specmill-references.yml', conditionMessage(error), fixed = TRUE)
    )
  }

  # A configured source + lock project tracks dependency drift and accepts an
  # explicitly reviewed refresh under default validation.
  author <- list(
    given = 'Test',
    family = 'Maintainer',
    email = 'test@example.org'
  )
  tracking <- tempfile('remote-reference-inputs-')
  on.exit(unlink(tracking, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    tracking,
    schema,
    package = 'remotereferenceinputs',
    title = 'Remote reference inputs',
    author = author,
    license = 'MIT + file LICENSE'
  )
  for (path in c('openapi.json', 'specmill-references.yml', unlist(files))) {
    destination <- file.path(tracking, 'schema', path)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    stopifnot(file.copy(file.path(root, path), destination, overwrite = TRUE))
  }
  dependency <- normalizePath(
    file.path(tracking, 'schema', files$sortby),
    winslash = '/'
  )
  first <- specmill::generate_client(
    tracking,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(
    length(first$operations) == 3L,
    dependency %in% names(first$manifest$inputs)
  )
  writeLines(c(sortby, 'description: Reviewed refresh'), dependency)
  stale <- specmill::read_operations(file.path(
    tracking,
    'schema',
    'openapi.json'
  ))
  stopifnot(identical(
    by_key(stale$diagnostics, 'GET /items')$code,
    'reference_hash_mismatch'
  ))
  refreshed <- lock_entries()
  refreshed[[1L]]$sha256 <- digest::digest(file = dependency, algo = 'sha256')
  write_lock(refreshed, file.path(tracking, 'schema'))
  second <- specmill::generate_client(
    tracking,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(
    length(second$operations) == 3L,
    !identical(
      first$manifest$inputs[[dependency]],
      second$manifest$inputs[[dependency]]
    )
  )

  # Initialization bundles reviewed dependencies; the client generates and
  # sends the resolved query after the source tree is gone.
  client <- tempfile('remote-reference-client-')
  on.exit(unlink(client, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    client,
    schema,
    package = 'remotereferences',
    title = 'Remote references',
    author = author,
    license = 'MIT + file LICENSE'
  )
  unlink(root, recursive = TRUE)
  stopifnot(identical(
    specmill::validate_schema(file.path(
      client,
      'schema',
      'openapi.json'
    ))$status,
    'passed'
  ))
  plan <- specmill::generate_client(
    client,
    config = 'specmill.yml',
    mode = 'apply'
  )
  stopifnot(length(plan$operations) == 3L, !length(plan$diagnostics))
  specmill::generate_client(client, config = 'specmill.yml', mode = 'check')
  port_file <- tempfile('remote-reference-port-')
  on.exit(unlink(port_file), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(
              list(path = req$PATH_INFO, query = req$QUERY_STRING),
              auto_unbox = TRUE
            )
          )
        })
      )
      on.exit(server$stop())
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    args = list(port_file),
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
  runtime <- callr::r(
    function(client, base_url) {
      env <- new.env(parent = baseenv())
      for (file in list.files(file.path(client, 'R'), full.names = TRUE)) {
        sys.source(file, env)
      }
      options(remotereferences.request = list(base_url = base_url))
      list(
        items = env$list_items(sortby = c('+name', '-datetime')),
        nested = env$nested_items(limit = 5L),
        specmill = 'specmill' %in% loadedNamespaces()
      )
    },
    args = list(client, paste0('http://127.0.0.1:', readLines(port_file)))
  )
  stopifnot(
    identical(runtime$items$path, '/items'),
    identical(runtime$items$query, '?sortby=%2Bname,-datetime'),
    identical(runtime$nested$query, '?limit=5'),
    !runtime$specmill
  )
  cat(
    'Remote references: reviewed lock mappings, nested URI resolution, hash enforcement, failures, drift, bundling and localhost requests passed offline.\n'
  )
}

if (sys.nframe() == 0L) {
  remote_references_acceptance()
}
