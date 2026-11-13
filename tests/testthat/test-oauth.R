# A deterministic local OAuth 2.0 provider and API. Control files in `state`
# change its behaviour; it records requests in `log`.
oauth_server <- function(state) {
  callr::r_bg(
    function(state) {
      read_flag <- function(name, default = '') {
        path <- file.path(state, name)
        if (file.exists(path)) readLines(path, warn = FALSE)[[1L]] else default
      }
      log <- function(line) {
        cat(line, '\n', file = file.path(state, 'log'), append = TRUE, sep = '')
      }
      b64url <- function(raw) {
        gsub('=+$', '', chartr('+/', '-_', openssl::base64_encode(raw)))
      }
      form <- function(req) {
        body <- rawToChar(req$rook.input$read())
        pairs <- strsplit(
          strsplit(body, '&', fixed = TRUE)[[1L]],
          '=',
          fixed = TRUE
        )
        stats::setNames(
          lapply(pairs, function(x) {
            utils::URLdecode(gsub('+', ' ', x[2L], fixed = TRUE))
          }),
          vapply(pairs, `[[`, character(1), 1L)
        )
      }
      query <- function(req) {
        q <- sub('^\\?', '', req$QUERY_STRING)
        if (!nzchar(q)) {
          return(list())
        }
        pairs <- strsplit(
          strsplit(q, '&', fixed = TRUE)[[1L]],
          '=',
          fixed = TRUE
        )
        stats::setNames(
          lapply(pairs, function(x) utils::URLdecode(x[2L])),
          vapply(pairs, `[[`, character(1), 1L)
        )
      }
      json <- function(status, value) {
        list(
          status = status,
          headers = list('Content-Type' = 'application/json'),
          body = as.character(jsonlite::toJSON(value, auto_unbox = TRUE))
        )
      }
      codes <- list()
      tokens <- list()
      issued <- 0L
      issue <- function(scope, refresh = TRUE) {
        issued <<- issued + 1L
        access <- paste0('at-', issued)
        tokens[[access]] <<- scope
        c(
          list(
            access_token = access,
            token_type = 'Bearer',
            expires_in = 3600L,
            scope = scope
          ),
          if (refresh) list(refresh_token = paste0('rt-', issued))
        )
      }
      refresh_tokens <- character()
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          path <- req$PATH_INFO
          log(paste(req$REQUEST_METHOD, path))
          if (path == '/authorize') {
            q <- query(req)
            if (!identical(q$client_id, 'test-client')) {
              return(json(400L, list(error = 'invalid_client')))
            }
            log(paste('nonce', !is.null(q$nonce)))
            if (identical(read_flag('deny'), 'yes')) {
              location <- paste0(
                q$redirect_uri,
                '?error=access_denied&state=',
                q$state
              )
            } else {
              withheld <- read_flag('withhold')
              granted <- setdiff(strsplit(q$scope, ' ')[[1L]], withheld)
              codes[['c1']] <<- list(
                challenge = q$code_challenge,
                method = q$code_challenge_method,
                scope = paste(granted, collapse = ' ')
              )
              location <- paste0(q$redirect_uri, '?code=c1&state=', q$state)
            }
            return(list(
              status = 302L,
              headers = list(Location = location),
              body = ''
            ))
          }
          if (path == '/token') {
            f <- form(req)
            if (identical(f$grant_type, 'authorization_code')) {
              code <- codes[[f$code]]
              verifier <- b64url(openssl::sha256(charToRaw(f$code_verifier)))
              if (
                is.null(code) ||
                  !identical(code$method, 'S256') ||
                  !identical(verifier, code$challenge)
              ) {
                return(json(400L, list(error = 'invalid_grant')))
              }
              codes[[f$code]] <<- NULL
              token <- issue(code$scope)
              refresh_tokens[[token$refresh_token]] <<- code$scope
              return(json(200L, token))
            }
            if (identical(f$grant_type, 'refresh_token')) {
              scope <- refresh_tokens[f$refresh_token]
              if (identical(read_flag('revoke'), 'yes') || is.na(scope)) {
                return(json(400L, list(error = 'invalid_grant')))
              }
              # No new refresh token: the client must keep the old one.
              return(json(200L, issue(unname(scope), refresh = FALSE)))
            }
            return(json(400L, list(error = 'unsupported_grant_type')))
          }
          if (path == '/oauth2/metadata') {
            return(list(
              status = 200L,
              headers = list(Location = paste0('http://127.0.0.1:', port)),
              body = ''
            ))
          }
          auth <- req$HTTP_AUTHORIZATION %||% ''
          bearer <- sub('^Bearer ', '', auth)
          if (path == '/api/public') {
            return(json(200L, list(ok = TRUE, auth = nzchar(auth))))
          }
          if (
            path %in%
              c('/api/either', '/api/adminkey') &&
              identical(req$HTTP_X_API_KEY, 'fixture-key')
          ) {
            return(json(200L, list(ok = TRUE, via = 'key')))
          }
          if (!startsWith(auth, 'Bearer ') || is.null(tokens[[bearer]])) {
            return(json(401L, list(error = 'invalid_token')))
          }
          json(200L, list(ok = TRUE, token = bearer))
        })
      )
      on.exit(httpuv::stopServer(server))
      writeLines(as.character(port), file.path(state, 'port'))
      repeat {
        httpuv::service(100)
      }
    },
    args = list(state),
    supervise = TRUE
  )
}

# A stand-in browser: follows the provider's redirect to the loopback
# listener, retrying until the listener (started after the browser opens)
# answers. If it never does, it sends an error so the sign-in cannot hang.
# Handles are kept: processx kills a background process when its handle is
# garbage collected.
oauth_browser <- function(callback) {
  processes <- list()
  function(url) {
    processes[[length(processes) + 1L]] <<- callr::r_bg(
      function(url, callback) {
        for (i in seq_len(60L)) {
          Sys.sleep(0.5)
          handle <- curl::new_handle(followlocation = TRUE, timeout = 5)
          result <- try(
            curl::curl_fetch_memory(url, handle = handle),
            silent = TRUE
          )
          if (
            !inherits(result, 'try-error') && startsWith(result$url, callback)
          ) {
            return(invisible(TRUE))
          }
        }
        try(
          curl::curl_fetch_memory(
            paste0(callback, '?error=browser_failed'),
            handle = curl::new_handle(timeout = 5)
          ),
          silent = TRUE
        )
      },
      args = list(url, paste0('http://127.0.0.1:', callback, '/callback'))
    )
    invisible(NULL)
  }
}

# Replace the project authentication block written by initialize_client().
oauth_set_authentication <- function(root, lines) {
  path <- file.path(root, 'specmill.yml')
  x <- readLines(path)
  i <- which(x == 'authentication:')
  stopifnot(length(i) == 1L)
  j <- i
  while (j < length(x) && grepl('^  ', x[[j + 1L]])) {
    j <- j + 1L
  }
  writeLines(
    c(x[seq_len(i - 1L)], 'authentication:', lines, x[-seq_len(j)]),
    path
  )
}

oauth_schema <- function(port, auth_host) {
  provider <- paste0('http://', auth_host, ':', port)
  get <- function(id, security = NULL) {
    op <- list(
      operationId = id,
      summary = id,
      responses = list('200' = list(description = 'OK'))
    )
    if (!is.null(security)) {
      op$security <- security
    }
    list(get = op)
  }
  list(
    openapi = '3.0.3',
    info = list(title = 'OAuth fixture', version = '1'),
    servers = list(list(url = paste0('http://127.0.0.1:', port))),
    security = list(list(sfn = list('read'))),
    paths = list(
      '/api/items' = get('items'),
      '/api/admin' = get('admin', list(list(sfn = list('admin')))),
      '/api/either' = get(
        'either',
        list(list(sfn = list('read')), list(key = list()))
      ),
      '/api/adminkey' = get(
        'adminkey',
        list(list(sfn = list('admin')), list(key = list()))
      ),
      '/api/public' = get('public', list())
    ),
    components = list(
      securitySchemes = list(
        sfn = list(
          type = 'oauth2',
          flows = list(
            authorizationCode = list(
              authorizationUrl = paste0(provider, '/authorize'),
              tokenUrl = paste0(provider, '/token'),
              scopes = list(read = 'Read', admin = 'Administer')
            )
          )
        ),
        key = list(type = 'apiKey', `in` = 'header', name = 'X-API-Key')
      )
    )
  )
}

test_that('OAuth authorization-code login, refresh, scopes and logout', {
  for (package in c(
    'httr2',
    'httpuv',
    'callr',
    'curl',
    'openssl',
    'pkgload',
    'rlang'
  )) {
    skip_if_not_installed(package)
  }
  state <- withr::local_tempdir()
  server <- oauth_server(state)
  withr::defer(server$kill())
  for (i in seq_len(200L)) {
    if (file.exists(file.path(state, 'port'))) {
      break
    }
    if (!server$is_alive()) {
      server$get_result()
    }
    Sys.sleep(0.05)
  }
  port <- readLines(file.path(state, 'port'))
  callback <- httpuv::randomPort()
  flag <- function(name, value) writeLines(value, file.path(state, name))
  requests <- function(pattern) {
    log <- file.path(state, 'log')
    if (!file.exists(log)) {
      return(0L)
    }
    sum(grepl(pattern, readLines(log, warn = FALSE), fixed = TRUE))
  }

  # Generate a client whose sfn scheme uses a reviewed OAuth credential. The
  # schema names the provider as localhost; discovery points it at 127.0.0.1.
  root <- file.path(withr::local_tempdir(), 'oauthclient')
  schema <- tempfile(fileext = '.json')
  jsonlite::write_json(
    oauth_schema(port, '127.0.0.1'),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'oauthclient',
    title = 'OAuth Client',
    license = 'MIT + file LICENSE',
    author = list(given = 'A', family = 'B', email = 'a@example.org')
  )
  oauth_set_authentication(
    root,
    c(
      '  sfn:',
      '    oauth:',
      '      client_id: OAUTH_TEST_CLIENT',
      paste0('      redirect_uri: http://127.0.0.1:', callback, '/callback'),
      '      scopes: [openid]',
      '  key: OAUTH_TEST_KEY'
    )
  )
  result <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  expect_length(result$diagnostics, 0L)
  auth <- paste(readLines(file.path(root, 'R', 'api_auth.R')), collapse = '\n')
  expect_match(auth, 'OAUTH_TEST_CLIENT', fixed = TRUE)
  expect_false(grepl('test-client', auth, fixed = TRUE))
  sources <- setdiff(
    list.files(file.path(root, 'R'), full.names = TRUE),
    file.path(root, 'R', 'api_auth.R')
  )
  wrappers <- paste(unlist(lapply(sources, readLines)), collapse = '\n')
  expect_match(wrappers, 'oauth2_code', fixed = TRUE)
  expect_false(grepl('token_url', wrappers, fixed = TRUE))

  withr::local_envvar(
    R_USER_CACHE_DIR = withr::local_tempdir(),
    OAUTH_TEST_CLIENT = 'test-client',
    OAUTH_TEST_KEY = NA
  )
  rlang::local_interactive(TRUE)
  # The browser follows the provider's redirect to the loopback listener,
  # after the listener has started.
  withr::local_options(browser = oauth_browser(callback))
  client <- pkgload::load_all(root, quiet = TRUE, export_all = TRUE)$env
  withr::defer(pkgload::unload('oauthclient'))
  cache <- function() {
    file.path(tools::R_user_dir('oauthclient', 'cache'), 'oauth-sfn.rds')
  }
  no_secret <- function(error) {
    !grepl('at-|rt-|test-client', conditionMessage(error))
  }

  # Before sign-in: OAuth operations ask for api_login(); the alternative and
  # anonymous operations are unaffected.
  error <- tryCatch(client$items(), error = identity)
  expect_match(conditionMessage(error), 'api_login("sfn")', fixed = TRUE)
  expect_identical(requests('GET /api/items'), 0L)
  expect_true(client$public()$ok)
  Sys.setenv(OAUTH_TEST_KEY = 'fixture-key')
  expect_identical(client$either()$via, 'key')
  Sys.unsetenv('OAUTH_TEST_KEY')

  # A cancelled sign-in stores nothing.
  flag('deny', 'yes')
  expect_error(client$api_login())
  expect_false(file.exists(cache()))
  flag('deny', 'no')

  # Sign-in: PKCE verified by the provider, token cached with mode 0600.
  flag('withhold', 'admin')
  expect_true(client$api_login())
  expect_true(file.exists(cache()))
  expect_identical(
    format(file.info(cache())$mode),
    '600'
  )
  expect_identical(client$items()$token, 'at-1')
  expect_identical(client$either()$token, 'at-1')
  expect_true(client$public()$ok)

  # A required scope the provider did not grant fails before the request.
  error <- tryCatch(client$admin(), error = identity)
  expect_match(conditionMessage(error), 'lacks scope admin', fixed = TRUE)
  expect_identical(requests('GET /api/admin'), 0L)
  expect_true(no_secret(error))

  # An OAuth alternative the token cannot serve gives way to the next one.
  Sys.setenv(OAUTH_TEST_KEY = 'fixture-key')
  expect_identical(client$adminkey()$via, 'key')
  Sys.unsetenv('OAUTH_TEST_KEY')

  # Replayed tests use a dummy token and leave the real one in place.
  expect_identical(client$api_oauth_signed_in(), 'sfn')
  local({
    restore <- client$api_oauth_replay('sfn')
    withr::defer(restore())
    withr::local_options(oauthclient.dry_run = TRUE)
    request <- client$items()
    expect_identical(
      httr2::req_get_headers(request, 'reveal')$Authorization,
      'Bearer replay-dummy'
    )
  })
  expect_identical(client$api_oauth_read('sfn')$token$access_token, 'at-1')

  # The token is not sent to another origin.
  withr::with_options(
    list(
      oauthclient.request = list(base_url = paste0('http://localhost:', port))
    ),
    {
      error <- tryCatch(client$items(), error = identity)
      expect_match(conditionMessage(error), 'is not sent to', fixed = TRUE)
    }
  )

  # Expiry refreshes the token and keeps the old refresh token.
  stored <- client$api_oauth_read('sfn')
  stored$token$expires_at <- 0
  client$api_oauth_write('sfn', stored)
  expect_identical(client$items()$token, 'at-2')
  expect_identical(requests('POST /token'), 2L)
  expect_identical(client$api_oauth_read('sfn')$token$refresh_token, 'rt-1')

  # Recording refreshes a token that would expire during the scenario.
  stored <- client$api_oauth_read('sfn')
  stored$token$expires_at <- as.numeric(Sys.time()) + 120
  client$api_oauth_write('sfn', stored)
  client$api_oauth_prepare_recording()
  expect_identical(client$api_oauth_read('sfn')$token$access_token, 'at-3')

  # A network failure during refresh keeps the sign-in.
  stored <- client$api_oauth_read('sfn')
  saved <- stored
  stored$token_url <- 'http://127.0.0.1:1/token'
  stored$token$expires_at <- 0
  client$api_oauth_write('sfn', stored)
  expect_error(client$items())
  expect_true(file.exists(cache()))
  client$api_oauth_write('sfn', saved)

  # A new session reads the cached token.
  rm(list = 'sfn', envir = client$api_oauth_tokens)
  expect_identical(client$items()$token, 'at-3')

  # A refresh the provider rejects requires a new sign-in.
  flag('revoke', 'yes')
  stored <- client$api_oauth_read('sfn')
  stored$token$expires_at <- 0
  client$api_oauth_write('sfn', stored)
  error <- tryCatch(client$items(), error = identity)
  expect_match(conditionMessage(error), 'expired', fixed = TRUE)
  expect_true(no_secret(error))
  expect_false(file.exists(cache()))
  flag('revoke', 'no')

  # Tokens are offered to recording scans, and logout removes them.
  expect_true(client$api_login())
  expect_true(all(c('at-4', 'rt-4') %in% client$api_oauth_secrets()))
  # Replaying a recording made without signing in: no token, even though a
  # real one is cached, and the cache is left alone.
  before <- tools::md5sum(cache())
  restore <- client$api_oauth_replay(character())
  expect_length(client$api_oauth_signed_in(), 0L)
  error <- tryCatch(client$items(), error = identity)
  expect_match(conditionMessage(error), 'api_login("sfn")', fixed = TRUE)
  restore()
  expect_identical(tools::md5sum(cache()), before)
  expect_identical(client$api_oauth_signed_in(), 'sfn')
  client$api_logout()
  expect_false(file.exists(cache()))
  expect_length(client$api_oauth_signed_in(), 0L)
  expect_length(client$api_oauth_secrets(), 0L)

  # Without an interactive session there is no browser sign-in.
  rlang::with_interactive(
    expect_error(client$api_login(), 'interactive'),
    value = FALSE
  )
})

test_that('a client discovery function supplies OAuth endpoints and parameters', {
  for (package in c(
    'httr2',
    'httpuv',
    'callr',
    'curl',
    'openssl',
    'pkgload',
    'rlang'
  )) {
    skip_if_not_installed(package)
  }
  state <- withr::local_tempdir()
  server <- oauth_server(state)
  withr::defer(server$kill())
  for (i in seq_len(200L)) {
    if (file.exists(file.path(state, 'port'))) {
      break
    }
    if (!server$is_alive()) {
      server$get_result()
    }
    Sys.sleep(0.05)
  }
  port <- readLines(file.path(state, 'port'))
  callback <- httpuv::randomPort()
  root <- file.path(withr::local_tempdir(), 'oauthclient')
  schema <- tempfile(fileext = '.json')
  # The schema's provider host does not resolve; discovery replaces it.
  jsonlite::write_json(
    oauth_schema(port, 'provider.invalid'),
    schema,
    auto_unbox = TRUE
  )
  specmill::initialize_client(
    root,
    schema,
    package = 'oauthclient',
    title = 'OAuth Client',
    license = 'MIT + file LICENSE',
    author = list(given = 'A', family = 'B', email = 'a@example.org')
  )
  writeLines(
    c(
      '# Client-owned: find the provider from the API metadata Location header.',
      'discover_provider <- function(credential, endpoints, base_url) {',
      "  request <- httr2::req_options(httr2::request(paste0(base_url, '/oauth2/metadata')), followlocation = FALSE)",
      "  provider <- httr2::resp_header(httr2::req_perform(request), 'location')",
      "  list(auth_url = paste0(provider, '/authorize'), token_url = paste0(provider, '/token'),",
      "    auth_params = list(nonce = 'fixture-nonce'))",
      '}'
    ),
    file.path(root, 'R', 'discovery.R')
  )
  oauth_set_authentication(
    root,
    c(
      '  sfn:',
      '    oauth:',
      '      client_id: OAUTH_TEST_CLIENT',
      paste0('      redirect_uri: http://127.0.0.1:', callback, '/callback'),
      '      discovery: discover_provider',
      '  key: OAUTH_TEST_KEY'
    )
  )
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')

  withr::local_envvar(
    R_USER_CACHE_DIR = withr::local_tempdir(),
    OAUTH_TEST_CLIENT = 'test-client'
  )
  rlang::local_interactive(TRUE)
  withr::local_options(browser = oauth_browser(callback))
  client <- pkgload::load_all(root, quiet = TRUE, export_all = TRUE)$env
  withr::defer(pkgload::unload('oauthclient'))
  expect_true(client$api_login())
  log <- readLines(file.path(state, 'log'), warn = FALSE)
  expect_true('GET /oauth2/metadata' %in% log)
  expect_true('nonce TRUE' %in% log)
  expect_identical(client$items()$token, 'at-1')
})
