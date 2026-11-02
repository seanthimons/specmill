reviewed_names_groups <- function() {
  root <- tempfile('reviewed-names-groups-')
  dir.create(file.path(root, 'schema'), recursive = TRUE)
  dir.create(file.path(root, 'apis'))
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  op <- function() list(responses = list('200' = list(description = 'OK')))
  jsonlite::write_json(
    list(
      openapi = '3.0.3',
      info = list(title = 'Amos', version = '1'),
      paths = list(
        '/classify/{id}' = list(
          get = c(
            op(),
            list(
              parameters = list(list(
                name = 'id',
                'in' = 'path',
                required = TRUE,
                schema = list(type = 'string')
              ))
            )
          )
        ),
        '/fresh' = list(get = op())
      )
    ),
    file.path(root, 'schema', 'amos.json'),
    auto_unbox = TRUE
  )
  # Two reviewed groups wrap the same route under different names.
  writeLines(
    c(
      'api: amos',
      'groups:',
      '  raw:',
      '    names:',
      '      GET /classify/{id}: amos_classify_raw',
      '  formatted:',
      '    names:',
      '      GET /classify/{id}: amos_classify'
    ),
    file.path(root, 'apis', 'amos.yml')
  )
  manifest <- data.frame(
    api = 'amos',
    schema = 'schema/amos.json',
    base_url = 'https://example.org',
    include = TRUE
  )
  warnings <- character()
  proposal <- withCallingHandlers(
    specmill::configure_client(
      root,
      manifest,
      package = 'demo',
      naming = 'path',
      group_by = 'none',
      mode = 'plan'
    ),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart('muffleWarning')
    }
  )
  names <- setNames(
    vapply(proposal$operations, `[[`, character(1), 'name'),
    vapply(proposal$operations, `[[`, character(1), 'key')
  )
  stopifnot(
    identical(names[['GET /classify/{id}']], 'amos_classify_raw'),
    !names[['GET /fresh']] %in% c('amos_classify_raw', 'amos_classify'),
    length(warnings) == 1L,
    grepl(
      'keeps only amos_classify_raw (also: amos_classify)',
      warnings,
      fixed = TRUE
    ),
    !any(vapply(
      proposal$diagnostics,
      function(x) x$code == 'group_collision',
      logical(1)
    ))
  )
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  reviewed_names_groups()
  cat('reviewed-names-groups: ok\n')
}
