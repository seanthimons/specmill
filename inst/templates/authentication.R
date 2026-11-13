# Generated with specmill; do not edit by hand.

#' Read a configured API credential
#' @param scheme Security scheme name; optional when only one is configured.
#' @return Credential string. Treat this value as a secret.
#' @export
api_token <- function(scheme = NULL) {
  envvars <- AUTH_ENVVARS
  if (is.null(scheme) && length(envvars) == 1L) {
    scheme <- names(envvars)[[1L]]
  }
  if (
    !is.character(scheme) ||
      length(scheme) != 1L ||
      is.na(scheme) ||
      !scheme %in% names(envvars)
  ) {
    stop(errorCondition(
      paste0(
        'Choose a configured credential scheme: ',
        paste(names(envvars), collapse = ', ')
      ),
      class = 'specmill_call_error',
      call = NULL
    ))
  }
  value <- Sys.getenv(envvars[[scheme]], unset = '')
  if (!nzchar(trimws(value))) {
    stop(errorCondition(
      paste0(
        'Missing credential for ',
        scheme,
        '. Set ',
        envvars[[scheme]],
        ' or call set_api_token(token, scheme = "',
        scheme,
        '").'
      ),
      class = 'specmill_call_error',
      call = NULL
    ))
  }
  if (grepl('[\r\n]', value)) {
    stop(errorCondition(
      'Credential contains a line break',
      class = 'specmill_call_error',
      call = NULL
    ))
  }
  value
}

#' Set an API credential for this session or save it for future sessions
#' @param token Credential supplied by the user. Never put it in tracked files.
#' @param scheme Security scheme name; optional when only one is configured.
#' @param persist Save to a user environment file when TRUE. Defaults to session only.
#' @param file Environment file used when persist is TRUE. Defaults to R_ENVIRON_USER
#'   when set, otherwise the user home .Renviron. A project .Renviron may take precedence.
#' @return Invisibly NULL. The token is never printed or returned.
#' @details Saved credentials are plain text. Existing unrelated lines are preserved.
#' No environment file is read or written when the package loads.
#' @export
set_api_token <- function(token, scheme = NULL, persist = FALSE,
  file = Sys.getenv('R_ENVIRON_USER', unset = path.expand('~/.Renviron'))) {
  envvars <- AUTH_ENVVARS
  if (is.null(scheme) && length(envvars) == 1L) scheme <- names(envvars)[[1L]]
  if (!is.character(scheme) || length(scheme) != 1L || is.na(scheme) || !scheme %in% names(envvars)) {
    stop('Choose a configured credential scheme: ', paste(names(envvars), collapse = ', '), call. = FALSE)
  }
  if (!is.character(token) || length(token) != 1L || is.na(token) ||
      !nzchar(trimws(token)) || grepl('[\r\n]', token)) stop('Supply one nonempty token without line breaks', call. = FALSE)
  if (!is.logical(persist) || length(persist) != 1L || is.na(persist)) stop('persist must be TRUE or FALSE')
  envvar <- envvars[[scheme]]
  if (persist) {
    # Reject values that R's startup-file expansion could change; session use is unrestricted.
    if (grepl('["\'\\\\]', token) || grepl('${', token, fixed = TRUE) || nchar(token, type = 'bytes') > 90000L) {
      stop('Token cannot be safely saved in .Renviron; use persist = FALSE', call. = FALSE)
    }
    if (!is.character(file) || length(file) != 1L || is.na(file) || !nzchar(file)) stop('Supply an environment file path')
    file <- path.expand(file)
    existing <- file.exists(file)
    before <- if (existing) readLines(file, warn = FALSE) else character()
    lines <- before[!grepl(paste0('^[[:space:]]*', envvar, '[[:space:]]*='), before)]
    lines <- c(lines, paste0(envvar, '="', token, '"'))
    staged <- tempfile('.api-env-', tmpdir = dirname(file))
    backup <- tempfile('.api-env-backup-', tmpdir = dirname(file))
    keep_backup <- FALSE
    on.exit({ unlink(staged); if (!keep_backup) unlink(backup) }, add = TRUE)
    writeLines(lines, staged, useBytes = TRUE)
    Sys.chmod(staged, '0600')
    if (existing && !file.copy(file, backup)) stop('Cannot back up environment file')
    if (existing && !identical(before, readLines(file, warn = FALSE))) stop('Environment file changed; retry')
    if (!file.copy(staged, file, overwrite = TRUE)) {
      if (existing && !file.copy(backup, file, overwrite = TRUE)) {
        keep_backup <- TRUE
        stop('Could not restore environment file; recover the backup at ', backup, call. = FALSE)
      }
      stop('Cannot save environment file', call. = FALSE)
    }
    if (!existing) Sys.chmod(file, '0600')
    message('Credential saved to ', file, '. It is also available in this R session.')
  }
  do.call(Sys.setenv, stats::setNames(base::list(token), envvar))
  invisible(NULL)
}

# OAuth 2.0 authorization code with PKCE. Tokens are kept for the session and
# in a per-user cache file (mode 0600) under tools::R_user_dir(), never in the
# package or project. Requests never open a browser; api_login() does.
api_oauth_tokens <- new.env(parent = emptyenv())

api_oauth_stop <- function(...) {
  stop(errorCondition(paste0(...), class = 'specmill_call_error', call = NULL))
}

api_oauth_setting <- function(credential) {
  settings <- AUTH_OAUTH
  if (is.null(credential) && length(settings) == 1L) {
    credential <- names(settings)[[1L]]
  }
  if (
    !is.character(credential) ||
      length(credential) != 1L ||
      is.na(credential) ||
      !credential %in% names(settings)
  ) {
    api_oauth_stop(
      'Choose a configured OAuth credential: ',
      paste(names(settings), collapse = ', ')
    )
  }
  c(list(credential = credential), settings[[credential]])
}

api_oauth_file <- function(credential) {
  package <- environmentName(topenv(environment(api_oauth_file)))
  file.path(
    tools::R_user_dir(package, 'cache'),
    paste0('oauth-', credential, '.rds')
  )
}

api_oauth_read <- function(credential) {
  stored <- api_oauth_tokens[[credential]]
  if (is.null(stored)) {
    path <- api_oauth_file(credential)
    if (file.exists(path)) {
      stored <- tryCatch(readRDS(path), error = function(e) NULL)
      if (!is.null(stored)) assign(credential, stored, envir = api_oauth_tokens)
    }
  }
  stored
}

api_oauth_write <- function(credential, stored) {
  assign(credential, stored, envir = api_oauth_tokens)
  path <- api_oauth_file(credential)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE, mode = '0700')
  staged <- tempfile('.oauth-', tmpdir = dirname(path))
  on.exit(unlink(staged), add = TRUE)
  file.create(staged)
  Sys.chmod(staged, '0600')
  saveRDS(stored, staged)
  if (!file.rename(staged, path)) api_oauth_stop('Cannot save the OAuth token')
  invisible(NULL)
}

api_oauth_forget <- function(credential) {
  if (exists(credential, envir = api_oauth_tokens, inherits = FALSE)) {
    rm(list = credential, envir = api_oauth_tokens)
  }
  unlink(api_oauth_file(credential))
}

api_oauth_url <- function(url, label) {
  if (
    !is.character(url) ||
      length(url) != 1L ||
      is.na(url) ||
      !grepl('^https?://[^/?#@]+(/[^#]*)?$', url)
  ) {
    api_oauth_stop('OAuth ', label, ' must be an absolute HTTP(S) URL')
  }
  url
}

api_oauth_origin <- function(url) sub('^(https?://[^/?#]+).*$', '\\1', url)

# Current OAuth token values, so recordings can be scanned for them.
api_oauth_secrets <- function() {
  values <- unlist(lapply(names(AUTH_OAUTH), function(credential) {
    token <- api_oauth_read(credential)$token
    c(token$access_token, token$refresh_token)
  }))
  as.character(values)
}

# Why a stored OAuth token cannot serve this requirement entry, or NULL.
# A token is offered only to allowed origins and with every required scope.
api_oauth_problem <- function(scheme, url) {
  credential <- scheme$scheme
  stored <- api_oauth_read(credential)
  if (is.null(stored)) {
    return(paste0('sign in with api_login("', credential, '")'))
  }
  origin <- api_oauth_origin(url)
  if (!isTRUE(stored$replay) && !origin %in% stored$origins) {
    return(paste0(
      'the ', credential, ' token is not sent to ', origin,
      '; to allow it, sign in with api_login("', credential,
      '", origin = "', origin, '")'
    ))
  }
  granted <- stored$token$scope
  granted <- if (is.character(granted) && length(granted) == 1L && nzchar(granted)) {
    strsplit(trimws(granted), '[[:space:]]+')[[1L]]
  } else {
    stored$scopes
  }
  missing <- setdiff(unlist(scheme$scopes), granted)
  if (length(missing)) {
    return(paste0(
      'the ', credential, ' sign-in lacks scope ',
      paste(missing, collapse = ', '),
      '; sign in again with api_login("', credential, '")'
    ))
  }
  NULL
}

# Refresh a stored token that expires within `margin` seconds. Only the
# provider's refusal ends the sign-in; network errors leave it in place.
api_oauth_refresh <- function(credential, stored, margin) {
  token <- stored$token
  expires <- token$expires_at
  if (is.null(expires) || expires > as.numeric(Sys.time()) + margin) {
    return(stored)
  }
  expired <- function() {
    api_oauth_forget(credential)
    api_oauth_stop(
      'The ', credential, ' sign-in expired; sign in again with api_login("',
      credential, '")'
    )
  }
  if (is.null(token$refresh_token)) expired()
  client_id <- Sys.getenv(stored$client_id, unset = '')
  if (!nzchar(trimws(client_id))) {
    api_oauth_stop(
      'Set ', stored$client_id, ' to the OAuth client ID to refresh the ',
      credential, ' sign-in'
    )
  }
  client <- httr2::oauth_client(
    id = client_id,
    token_url = stored$token_url,
    auth = 'body'
  )
  refreshed <- tryCatch(
    withCallingHandlers(
      httr2::oauth_flow_refresh(client, refresh_token = token$refresh_token),
      # A rotated refresh token is saved below.
      warning = function(w) {
        if (grepl('Refresh token has changed', conditionMessage(w), fixed = TRUE)) {
          invokeRestart('muffleWarning')
        }
      }
    ),
    httr2_oauth = function(e) NULL
  )
  if (is.null(refreshed)) expired()
  if (is.null(refreshed$refresh_token)) {
    refreshed$refresh_token <- token$refresh_token
  }
  stored$token <- refreshed
  api_oauth_write(credential, stored)
  stored
}

# The access token for one requirement entry, refreshed when it is about to
# expire.
api_oauth_bearer <- function(scheme, url) {
  problem <- api_oauth_problem(scheme, url)
  if (!is.null(problem)) api_oauth_stop('OAuth: ', problem)
  stored <- api_oauth_refresh(scheme$scheme, api_oauth_read(scheme$scheme), 30)
  stored$token$access_token
}

# Replayed tests: a dummy token for every OAuth credential, restored when
# `frame` exits. The token cache is not read.
api_oauth_replay <- function(frame) {
  for (credential in names(AUTH_OAUTH)) {
    local({
      name <- credential
      setting <- AUTH_OAUTH[[name]]
      previous <- api_oauth_tokens[[name]]
      scopes <- unlist(setting$scopes)
      assign(
        name,
        list(
          token = list(
            access_token = 'replay-dummy',
            token_type = 'bearer',
            scope = paste(scopes, collapse = ' ')
          ),
          token_url = setting$token_url,
          client_id = setting$client_id,
          scopes = scopes,
          replay = TRUE
        ),
        envir = api_oauth_tokens
      )
      withr::defer(
        if (is.null(previous)) {
          rm(list = name, envir = api_oauth_tokens)
        } else {
          assign(name, previous, envir = api_oauth_tokens)
        },
        envir = frame
      )
    })
  }
}

# Recording: refresh tokens that would expire during the scenario before the
# cassette opens, so no token request is recorded.
api_oauth_prepare_recording <- function() {
  for (credential in names(AUTH_OAUTH)) {
    stored <- api_oauth_read(credential)
    if (!is.null(stored)) api_oauth_refresh(credential, stored, 600)
  }
  invisible(NULL)
}

api_auth <- function(request, requirements) {
  if (!length(requirements) || any(vapply(requirements, function(x) !length(x), logical(1)))) return(request)
  available <- function(scheme) {
    if (identical(scheme$type, 'oauth2_code')) return(is.null(api_oauth_problem(scheme, request$url)))
    scheme$type %in% c('apiKey', 'bearer') && nzchar(trimws(Sys.getenv(scheme$envvar, unset = '')))
  }
  for (requirement in requirements) {
    if (!all(vapply(requirement, available, logical(1)))) next
    for (scheme in requirement) {
      if (scheme$type == 'oauth2_code') {
        request <- httr2::req_auth_bearer_token(request, api_oauth_bearer(scheme, request$url))
        next
      }
      token <- api_token(scheme$scheme)
      if (scheme$type == 'bearer') {
        request <- httr2::req_auth_bearer_token(request, token)
      } else if (scheme$location == 'header') {
        request <- do.call(httr2::req_headers, base::c(base::list(request, .redact = scheme$name), stats::setNames(base::list(token), scheme$name)))
      } else if (scheme$location == 'query') {
        request <- do.call(httr2::req_url_query, base::c(base::list(request), stats::setNames(base::list(token), scheme$name)))
      } else {
        cookie <- paste0(utils::URLencode(scheme$name, reserved = TRUE), '=', utils::URLencode(token, reserved = TRUE))
        prior <- request$headers[['Cookie']]
        if (!is.null(prior)) cookie <- paste(prior, cookie, sep = '; ')
        request <- httr2::req_headers(request, Cookie = cookie, .redact = 'Cookie')
      }
    }
    return(request)
  }
  choices <- vapply(requirements, function(requirement) paste(vapply(requirement, function(scheme) {
    if (scheme$type %in% c('apiKey', 'bearer')) paste0(scheme$scheme, ' (', scheme$envvar, ')')
    else if (scheme$type == 'oauth2_code') paste0(scheme$scheme, ' (', if (is.null(problem <- api_oauth_problem(scheme, request$url))) 'signed in' else problem, ')')
    else if (scheme$type == 'oauth2') paste0(scheme$scheme, ' [only the OAuth authorization-code flow with a reviewed oauth credential is supported]')
    else paste0(scheme$scheme, ' [', scheme$type, ' authentication is not implemented]')
  }, character(1)), collapse = ' + '), character(1))
  settable <- unique(unlist(lapply(requirements, function(requirement) {
    vapply(
      Filter(
        function(scheme) scheme$type %in% c('apiKey', 'bearer'),
        requirement
      ),
      function(scheme) scheme$scheme,
      character(1)
    )
  })))
  advice <- if (length(settable)) {
    paste0(
      ' Use ',
      paste0(
        'set_api_token(token, scheme = "',
        settable,
        '")',
        collapse = ' and/or '
      ),
      ' to set ',
      if (length(settable) == 1L) 'it.' else 'them.'
    )
  } else {
    ''
  }
  stop(errorCondition(
    paste0(
      'Authentication required. Configure one complete option: ',
      paste(choices, collapse = ' OR '),
      '.',
      advice
    ),
    class = 'specmill_call_error',
    call = NULL
  ))
}
