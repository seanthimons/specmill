# Reproducible installed-client checks. All HTTP goes to a local recording server.
verify_hardened_clients <- function(
  output = tempfile('specmill-hardened-clients-')
) {
  output <- normalizePath(output, mustWork = FALSE)
  if (
    dir.exists(output) &&
      length(list.files(output, all.files = TRUE, no.. = TRUE))
  ) {
    stop('Choose an empty output directory; prior results are retained')
  }
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  source <- new.env(parent = baseenv())
  sys.source('R/generation.R', source)
  stopifnot(identical(
    body(source$render_operation),
    body(specmill::render_operation)
  ))
  installed <- list(
    version = as.character(utils::packageVersion('specmill')),
    library = find.package('specmill'),
    source_commit = system2('git', c('rev-parse', 'HEAD'), stdout = TRUE),
    installed_renderer_matches_source = TRUE,
    installed_code_sha256 = digest::digest(
      file = file.path(find.package('specmill'), 'R/specmill.rdb'),
      algo = 'sha256'
    )
  )
  port_file <- file.path(output, 'port')
  server <- callr::r_bg(
    function(port_file) {
      count <- 0L
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          if (req$PATH_INFO != '/count') {
            count <<- count + 1L
          }
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(
              list(
                count = count,
                method = req$REQUEST_METHOD,
                content_type = req$CONTENT_TYPE,
                path = req$PATH_INFO,
                query = req$QUERY_STRING,
                header = req$HTTP_X_TEST,
                key = req$HTTP_X_KEY,
                bytes = as.integer(req$rook.input$read())
              ),
              auto_unbox = TRUE,
              null = 'null'
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
    list(port_file),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  for (i in seq_len(200L)) {
    if (file.exists(port_file)) {
      break
    }
    if (!server$is_alive()) {
      server$get_result()
    }
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  origin <- paste0('http://127.0.0.1:', readLines(port_file))
  count <- function() {
    httr2::resp_body_json(httr2::req_perform(httr2::request(paste0(
      origin,
      '/count'
    ))))$count
  }
  integer <- list(
    type = 'integer',
    minimum = 0L,
    maximum = 1L,
    enum = list(0L, 1L)
  )
  string <- list(type = 'string')
  operation <- function(name, ...) {
    c(
      list(
        operationId = name,
        responses = list('200' = list(description = 'OK'))
      ),
      list(...)
    )
  }
  request_body <- function(schema, media = 'application/json') {
    list(
      required = TRUE,
      content = setNames(list(list(schema = schema)), media)
    )
  }
  object <- list(
    type = 'object',
    required = list('text', 'amount'),
    additionalProperties = FALSE,
    properties = list(text = string, amount = integer)
  )
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'Installed hardening', version = '1'),
    servers = list(list(url = origin)),
    paths = list(
      '/wire/{segment}' = list(
        get = operation(
          'get_wire',
          parameters = list(
            list(
              name = 'segment',
              'in' = 'path',
              required = TRUE,
              schema = string
            ),
            list(
              name = 'amount',
              'in' = 'query',
              required = TRUE,
              schema = integer
            ),
            list(
              name = 'x-test',
              'in' = 'header',
              required = TRUE,
              schema = integer
            )
          )
        )
      ),
      '/json' = list(
        post = operation('post_json', requestBody = request_body(object))
      ),
      '/form' = list(
        post = operation(
          'post_form',
          requestBody = request_body(
            object,
            'application/x-www-form-urlencoded'
          )
        )
      ),
      '/hook' = list(
        post = operation('post_hook', requestBody = request_body(integer))
      ),
      '/exception' = list(
        post = operation('post_exception', requestBody = request_body(integer))
      ),
      '/skip' = list(
        post = operation('post_skip', requestBody = request_body(integer))
      )
    )
  )
  results <- list()
  library <- file.path(output, 'library')
  dir.create(library)
  run <- function(args, log) {
    status <- system2(
      file.path(R.home('bin'), 'R'),
      args,
      stdout = log,
      stderr = log,
      env = c('NOT_CRAN=true', '_R_CHECK_FORCE_SUGGESTS_=false')
    )
    if (status != 0L) stop('Command failed; inspect ', log)
  }
  for (auth in c(FALSE, TRUE)) {
    package <- if (auth) 'hardauth' else 'hardpublic'
    root <- file.path(output, package)
    schema <- file.path(output, paste0(package, '.json'))
    current <- document
    if (auth) {
      current$components <- list(
        securitySchemes = list(
          key = list(type = 'apiKey', 'in' = 'header', name = 'X-Key')
        )
      )
      current$security <- list(list(key = list()))
    }
    jsonlite::write_json(current, schema, auto_unbox = TRUE)
    specmill::initialize_client(
      root,
      schema,
      package = package,
      title = 'Installed Hardening Client',
      author = list(
        given = 'Test',
        family = 'Maintainer',
        email = 'test@example.org'
      ),
      license = 'MIT + file LICENSE',
      base_url = origin
    )
    writeLines(
      c(
        'reshape <- function(state) {',
        '  state$sentinel <- 42L',
        '  state$request <- list(body = list(inputType = "MOL", amount = as.character(state$params$body)),',
        '    options = list(timeout = 5, max_retries = 0))',
        '  state',
        '}',
        'extract <- function(state) {',
        '  stopifnot(identical(state$sentinel, 42L))',
        '  state$result$hook_state <- state$sentinel',
        '  state$result',
        '}',
        'throw <- function(state) stop("client hook failed")',
        'skip <- function(state) {',
        '  state$sentinel <- 42L',
        '  state$skip_request <- TRUE',
        '  state$result <- list(skipped = TRUE)',
        '  state',
        '}',
        'run_hook <- function(name, stage, state) {',
        '  if (stage == "post_response") return(extract(state))',
        '  if (name == "post_exception") return(throw(state))',
        '  if (name == "post_skip") return(skip(state))',
        '  reshape(state)',
        '}'
      ),
      file.path(root, 'R/run_hook.R')
    )
    project <- yaml::read_yaml(file.path(root, 'specmill.yml'))
    service_file <- file.path(root, project$services[[1L]])
    service <- yaml::read_yaml(service_file)
    service$schemas$files <- as.list(service$schemas$files)
    service$hooks <- list(
      post_hook = list(
        pre_request = list('reshape'),
        post_response = list('extract')
      ),
      post_exception = list(pre_request = list('throw')),
      post_skip = list(
        pre_request = list('skip'),
        post_response = list('extract')
      )
    )
    binding <- function(...) list(from = list(...))
    service$operations <- list(
      'POST /hook' = list(
        post_state = 'hook_state',
        request = list(
          arguments = list(
            method = list(value = 'POST'),
            path = list(value = '/hook'),
            path_params = list(value = list()),
            query = list(value = list()),
            body = binding('hook_state', 'request', 'body'),
            request_controls = binding('hook_state', 'request', 'options')
          )
        )
      ),
      'POST /skip' = list(post_state = 'hook_state', post_on_skip = TRUE)
    )
    yaml::write_yaml(service, service_file)
    generated <- specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'apply',
      artifacts = c('wrappers', 'documentation')
    )
    stopifnot(
      length(generated$operations) == 6L,
      !length(generated$diagnostics)
    )
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'check',
      artifacts = c('wrappers', 'documentation')
    )
    old <- setwd(output)
    tryCatch(
      {
        run(
          c('CMD', 'build', '--no-build-vignettes', shQuote(root)),
          file.path(output, paste0(package, '-build.log'))
        )
        tarball <- list.files(
          output,
          pattern = paste0('^', package, '_.*[.]tar[.]gz$'),
          full.names = TRUE
        )
        stopifnot(length(tarball) == 1L)
        run(
          c(
            'CMD',
            'INSTALL',
            paste0('--library=', shQuote(library)),
            shQuote(tarball)
          ),
          file.path(output, paste0(package, '-install.log'))
        )
        run(
          c('CMD', 'check', '--no-manual', '--no-vignettes', shQuote(tarball)),
          file.path(output, paste0(package, '-check.log'))
        )
      },
      finally = setwd(old)
    )
    ns <- loadNamespace(package, lib.loc = library)
    stopifnot(identical(exists('api_auth', envir = ns, inherits = FALSE), auth))
    if (auth) {
      get('set_api_token', ns)('localhost-fixture-key', scheme = 'key')
    }
    invoke <- function(name, ...) getExportedValue(package, name)(...)
    wire <- function(result) as.raw(unlist(result$bytes))
    text <- paste0(
      'NBSP',
      '\u00a0',
      'half',
      '\u00bd',
      'degree',
      '\u00b0',
      'emoji',
      '\U0001f642'
    )
    segment <- paste0('a:/', '\u00e9')
    result <- invoke('get_wire', segment, 0L, 1L)
    stopifnot(
      result$method == 'GET',
      is.null(result$content_type),
      result$path == paste0('/wire/a%3A%2F%C3%A9'),
      result$query == '?amount=0',
      result$header == '1'
    )
    if (auth) {
      stopifnot(result$key == 'localhost-fixture-key')
    } else {
      stopifnot(is.null(result$key))
    }
    json <- invoke('post_json', list(text = text, amount = 0L))
    stopifnot(
      json$method == 'POST',
      json$path == '/json',
      startsWith(json$content_type, 'application/json')
    )
    stopifnot(identical(
      wire(json),
      charToRaw(enc2utf8(paste0('{"text":"', text, '","amount":0}')))
    ))
    form <- invoke('post_form', list(text = text, amount = 0L))
    stopifnot(
      form$method == 'POST',
      form$path == '/form',
      startsWith(form$content_type, 'application/x-www-form-urlencoded')
    )
    expected_form <- paste0(
      'text=',
      utils::URLencode(enc2utf8(text), reserved = TRUE, repeated = TRUE),
      '&amount=0'
    )
    stopifnot(identical(wire(form), charToRaw(expected_form)))
    hook <- invoke('post_hook', 1L)
    stopifnot(
      hook$method == 'POST',
      hook$path == '/hook',
      startsWith(hook$content_type, 'application/json')
    )
    stopifnot(
      identical(wire(hook), charToRaw('{"inputType":"MOL","amount":"1"}')),
      hook$hook_state == 42L
    )
    before <- count()
    rejected <- list(
      function() invoke('get_wire', segment, 2L, 1L),
      function() invoke('get_wire', segment, '0', 1L),
      function() invoke('get_wire', segment, 0L, 2L),
      function() invoke('post_json', list(text = text, amount = 2L)),
      function() invoke('post_form', list(text = text, amount = 2L)),
      function() invoke('post_exception', 1L)
    )
    for (call in rejected) {
      stopifnot(inherits(tryCatch(call(), error = identity), 'error'))
    }
    skipped <- invoke('post_skip', 1L)
    stopifnot(skipped$skipped, skipped$hook_state == 42L, count() == before)
    check <- readLines(file.path(
      output,
      paste0(package, '.Rcheck'),
      '00check.log'
    ))
    stopifnot(
      any(grepl('Status: OK', check, fixed = TRUE)),
      !any(grepl('no visible global function definition for.*api_auth', check))
    )
    results[[package]] <- list(
      authentication = auth,
      operations = 6L,
      exact_wire_checks = 4L,
      rejected_without_http = length(rejected),
      invalid_public_inputs_without_http = length(rejected) - 1L,
      hook_exceptions_without_http = 1L,
      hook_skip_without_http = TRUE,
      freshness = 'passed',
      package_check = 'OK',
      schema_sha256 = digest::digest(file = schema, algo = 'sha256')
    )
  }
  report <- list(
    specmill = installed,
    packages = results,
    live_behavior = 'unverified; localhost only'
  )
  jsonlite::write_json(
    report,
    file.path(output, 'results.json'),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  print(report)
  invisible(report)
}
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  verify_hardened_clients(
    if (length(args)) args[[1L]] else tempfile('specmill-hardened-clients-')
  )
}
